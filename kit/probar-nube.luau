--!strict
-- probar-nube: prueba el juego en un servidor de Roblox de verdad, con Open Cloud, en el sitio de pruebas.
--   1. Construye el sitio con rojo y le mete las pruebas de nube (tests/**/*.cloud.spec.luau) y el probador.
--   2. Lo sube a «Pruebas» GUARDADO, nunca publicado.
--   3. Ejecuta en ESA versión exacta (así dos personas subiendo a la vez no se pisan):
--      que el juego arranca sin errores y las pruebas de nube.
--   4. Da el resumen en una línea si va bien. Si va bien, apunta la huella del código de servidor en
--      .kit/nube-ok.txt (el hook de Stop la compara para saber si hay que volver a probar).
--
-- La clave va en la variable ROBLOX_API_KEY y nunca se imprime. En Windows, lánzalo con probar-nube.ps1, que la
-- lee cifrada de %LOCALAPPDATA%\RobloxOpenCloud\clave.dat; en la CI sale de los secretos del repo.
-- Opciones: --universo <id> --sitio <id> (o ROBLOX_UNIVERSE_ID / ROBLOX_PLACE_ID). Por defecto, «Pruebas».
-- Reglas (APIs externas): nunca un juego publicado; solo sitios de prueba.

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local task = require("@lune/task")

local Comun = require("./comun")

local PRUEBAS_UNIVERSO = "10770494073"
local PRUEBAS_SITIO = "105671962169214"

local inicio = os.clock()
local opciones = Comun.argumentos()
local raiz = if typeof(opciones.raiz) == "string" then opciones.raiz else process.cwd
local universo = (if typeof(opciones.universo) == "string" then opciones.universo else nil)
	or process.env.ROBLOX_UNIVERSE_ID
	or PRUEBAS_UNIVERSO
local sitio = (if typeof(opciones.sitio) == "string" then opciones.sitio else nil)
	or process.env.ROBLOX_PLACE_ID
	or PRUEBAS_SITIO
local nombreSitio = if sitio == PRUEBAS_SITIO then "Pruebas" else `el sitio {sitio}`

local function fallar(texto: string)
	print(`probar-nube: {texto}`)
	process.exit(1)
end

local clave = process.env.ROBLOX_API_KEY
if not clave or clave == "" then
	fallar(
		"falta la clave. En Windows lánzalo con kit/probar-nube.ps1 (lee la clave cifrada del PC); "
			.. "en la CI, el secreto ROBLOX_API_KEY."
	)
end
local cabeceras = { ["x-api-key"] = clave :: string }

local kit = Comun.carpetaKit(raiz)
local registro: { string } = {}
local function guardarRegistro()
	fs.writeFile(Comun.unir(kit, "probar-nube.log"), table.concat(registro, "\n"))
end

-- 1. Construir e inyectar las pruebas de nube.
local proyecto = if fs.isFile(Comun.unir(raiz, "build.project.json"))
	then "build.project.json"
	else "default.project.json"
if not fs.isFile(Comun.unir(raiz, proyecto)) then
	fallar("no hay proyecto de Rojo (default.project.json) en esta carpeta")
end
local construido = Comun.unir(kit, "nube.rbxl")
local build = Comun.ejecutar("rojo", { "build", proyecto, "-o", construido }, raiz)
if not build.ok then
	fallar("rojo build falla:\n" .. Comun.primeras(Comun.sinRaiz(build.salida, raiz), 10))
end

local juego = roblox.deserializePlace(fs.readFile(construido))
local carpeta = roblox.Instance.new("Folder")
carpeta.Name = "KitCloudTests"
local probador = roblox.Instance.new("ModuleScript")
probador.Name = "_Probador"
probador.Source = fs.readFile(Comun.unir(Comun.raizPlugin(), "kit", "probador.luau"))
probador.Parent = carpeta
local specs = Comun.archivos(Comun.unir(raiz, "tests"), function(ruta)
	return string.match(ruta, "%.cloud%.spec%.luau$") ~= nil
end)
for _, ruta in specs do
	local modulo = roblox.Instance.new("ModuleScript")
	modulo.Name = "tests/" .. ruta
	modulo.Source = fs.readFile(Comun.unir(raiz, "tests", ruta))
	modulo.Parent = carpeta
end
carpeta.Parent = juego:GetService("ServerStorage")
local contenido = roblox.serializePlace(juego)
fs.writeFile(construido, contenido)

-- Llamada a Open Cloud. Nunca imprime cabeceras (llevan la clave).
local function pedir(metodo: string, url: string, cuerpo: string?, tipo: string?): any
	local h = table.clone(cabeceras)
	if tipo then
		h["Content-Type"] = tipo
	end
	for intento = 1, 3 do
		local ok, r = pcall(net.request, { url = url, method = metodo :: any, headers = h, body = cuerpo })
		if not ok then
			table.insert(registro, `{metodo} {url}: {r}`)
			if intento == 3 then
				fallar(`no se pudo conectar con Roblox ({r})`)
			end
		elseif r.statusCode == 429 or r.statusCode >= 500 then
			-- Demasiadas peticiones o fallo de Roblox: se espera y se repite.
			table.insert(registro, `{metodo} {url}: HTTP {r.statusCode} {r.body}`)
			if intento == 3 then
				fallar(`Roblox responde HTTP {r.statusCode}: {string.sub(r.body, 1, 300)}`)
			end
		elseif not r.ok then
			table.insert(registro, `{metodo} {url}: HTTP {r.statusCode} {r.body}`)
			guardarRegistro()
			local pista = if r.statusCode == 401 or r.statusCode == 403
				then " (¿clave caducada o sin permiso para este sitio?)"
				else ""
			fallar(`Roblox responde HTTP {r.statusCode}{pista}: {string.sub(r.body, 1, 300)}`)
		else
			return if r.body == "" then {} else serde.decode("json", r.body)
		end
		task.wait(2 * intento)
	end
	return nil
end

-- 2. Subir como versión guardada (no publicada).
local subida = pedir(
	"POST",
	`https://apis.roblox.com/universes/v1/{universo}/places/{sitio}/versions?versionType=Saved`,
	contenido,
	"application/octet-stream"
)
local version = subida.versionNumber
if not version then
	fallar("Roblox no devolvió el número de versión: " .. serde.encode("json", subida))
end
table.insert(registro, `Subida la versión {version} de {nombreSitio} ({#contenido} bytes).`)

-- 3. El script que corre en el servidor. Si los scripts del juego no arrancan solos en la sesión, arranca el
-- servidor con el cargador del kit (solo si el juego lo usa), para comprobar igualmente que arranca sin errores.
-- Comprobado el 13/10/2026: en Luau Execution los scripts del sitio NO arrancan solos; por eso se espera poco.
local SCRIPT_NUBE = [==[
local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local server = ServerScriptService:FindFirstChild("Server")
local usaCargador = server ~= nil and server:FindFirstChild("Systems") ~= nil
	and ReplicatedStorage:FindFirstChild("Shared") ~= nil and ReplicatedStorage.Shared:FindFirstChild("Kit") ~= nil
local arranqueManual = false
if usaCargador then
	local limite = os.clock() + 2
	while ServerScriptService:GetAttribute("KitReady") == nil and os.clock() < limite do
		task.wait(0.2)
	end
	if ServerScriptService:GetAttribute("KitReady") == nil then
		arranqueManual = true
		require(ReplicatedStorage.Shared.Kit.Loader).run(server.Systems)
	end
end
task.wait(3)

local errores = {}
for _, m in LogService:GetLogHistory() do
	if m.messageType == Enum.MessageType.MessageError then
		table.insert(errores, m.message)
	end
end

local carpeta = ServerStorage:FindFirstChild("KitCloudTests")
local Probador = require(carpeta._Probador)
local specs = {}
for _, modulo in carpeta:GetChildren() do
	if modulo.Name ~= "_Probador" then
		table.insert(specs, Probador.cargar(modulo.Name, function()
			return require(modulo)
		end))
	end
end
table.sort(specs, function(a, b) return a.nombre < b.nombre end)
local r = Probador.correr(specs)

return {
	usaCargador = usaCargador,
	arranqueManual = arranqueManual,
	listo = ServerScriptService:GetAttribute("KitReady") == true,
	fallidos = ServerScriptService:GetAttribute("KitFailed"),
	errores = errores,
	pruebas = Probador.resumen(r),
	total = r.total,
	fallos = #r.fallos,
}
]==]

local base = `https://apis.roblox.com/cloud/v2/universes/{universo}/places/{sitio}/versions/{version}`
local tarea = pedir(
	"POST",
	base .. "/luau-execution-session-tasks",
	serde.encode("json", { script = SCRIPT_NUBE, timeout = "180s" }),
	"application/json"
)

local limite = os.clock() + 300
while (tarea.state == "QUEUED" or tarea.state == "PROCESSING") and os.clock() < limite do
	task.wait(3)
	tarea = pedir("GET", "https://apis.roblox.com/cloud/v2/" .. tarea.path)
end

-- Consola del servidor, para el registro (y para el resumen si algo falla).
local consola: { string } = {}
local okLogs, logs = pcall(pedir, "GET", "https://apis.roblox.com/cloud/v2/" .. tarea.path .. "/logs")
if okLogs and logs and logs.luauExecutionSessionTaskLogs then
	for _, bloque in logs.luauExecutionSessionTaskLogs do
		for _, mensaje in bloque.messages or {} do
			table.insert(consola, mensaje)
		end
	end
end
table.insert(registro, "== consola del servidor\n" .. table.concat(consola, "\n"))
table.insert(registro, "== tarea\n" .. serde.encode("json", tarea, true))
guardarRegistro()

local donde = `versión {version} de {nombreSitio}`
if tarea.state ~= "COMPLETE" then
	local motivo = if tarea.error then `{tarea.error.code}: {tarea.error.message}` else tarea.state
	local cola = {}
	for i = math.max(1, #consola - 10), #consola do
		table.insert(cola, "  " .. consola[i])
	end
	fallar(
		`la tarea no terminó bien en la {donde} ({motivo}).\n{table.concat(cola, "\n")}\nDetalle: .kit/probar-nube.log`
	)
end

local resultado = tarea.output and tarea.output.results and tarea.output.results[1]
if typeof(resultado) ~= "table" then
	fallar(`la tarea no devolvió resultado en la {donde}. Detalle: .kit/probar-nube.log`)
end
-- Una lista vacía puede llegar como nada en el JSON.
resultado.errores = resultado.errores or {}
resultado.total = resultado.total or 0
resultado.fallos = resultado.fallos or 0

local problemas = {}
if resultado.usaCargador and not resultado.listo then
	table.insert(problemas, "el cargador no terminó de arrancar el servidor")
end
if resultado.fallidos then
	table.insert(problemas, `sistemas que fallan al arrancar: {resultado.fallidos}`)
end
if #resultado.errores > 0 then
	local lista = {}
	for i = 1, math.min(10, #resultado.errores) do
		-- Fuera las marcas vacías de pila que añade Roblox.
		local texto = string.gsub(resultado.errores[i], "%s*Stack Begin%s*Stack End%s*", "")
		table.insert(lista, "  " .. string.sub(texto, 1, 400))
	end
	table.insert(problemas, `{#resultado.errores} error(es) en la consola:\n{table.concat(lista, "\n")}`)
end
if resultado.fallos > 0 then
	table.insert(problemas, resultado.pruebas)
end

local arranque = if resultado.arranqueManual then "arranque lanzado por probar-nube" else "arranque solo"
if #problemas > 0 then
	fallar(`falla en la {donde} ({arranque}):\n{table.concat(problemas, "\n")}\nDetalle: .kit/probar-nube.log`)
end

fs.writeFile(Comun.rutaHuellaNube(raiz), Comun.huellaServidor(raiz))
local pruebasNube = if resultado.total > 0 then `, {resultado.pruebas}` else ""
print(`probar-nube: bien en {Comun.segundos(inicio)} ({donde}, arranca sin errores{pruebasNube}; {arranque})`)
