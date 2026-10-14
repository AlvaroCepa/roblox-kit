--!strict
-- comprobar: todas las comprobaciones de un juego en un solo script, igual en Windows y en la CI de Linux.
-- Lo usan el hook de Stop, la CI y quien quiera a mano. Desde la carpeta del juego:
--   lune run <plugin>/kit/comprobar.luau                       todos los pasos
--   lune run <plugin>/kit/comprobar.luau --pasos tipos,pruebas  solo esos
--   lune run <plugin>/kit/comprobar.luau src/x.luau ...         solo esos archivos (por defecto stylua y selene)
--   --parada  (lo usa el hook de Stop) sale con código 3 si todo va bien pero falta una pasada que no hace
--             comprobar: «pendiente: nube» (el código de servidor cambió desde la última probar-nube),
--             «pendiente: ui» o «pendiente: mapa» (cambiaron desde la última pasada buena en Studio).
--
-- Pasos: stylua (solo mira, no cambia nada), selene, tipos (luau-lsp), build (rojo), pruebas (Lune), reglas
-- (los módulos de Rules no usan game ni servicios), ids (nada de ids sueltos), ui (textos, colores y fuente
-- de la hoja de estilo), efectos (topes de VFX y sonidos bien escritos), mapa (los .rbxm de map/ sin Studio)
-- y kit (aviso si los módulos del kit del juego son más viejos que los del plugin). Los de oficios, en oficios.luau.
-- Pasa todos aunque falle uno. Si todo va bien, una línea; si algo falla, el resumen, y el detalle en
-- .kit/comprobar.log. Lo estricto de cada juego va en su configuración (selene.toml, .luaurc), no aquí.

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")

local Comun = require("./comun")
local Oficios = require("./oficios")

local inicio = os.clock()
local opciones, sueltos = Comun.argumentos()
local raiz = if typeof(opciones.raiz) == "string" then opciones.raiz else process.cwd
local kit = Comun.unir(Comun.raizPlugin(), "kit")

local function existe(relativa: string): boolean
	local ruta = Comun.unir(raiz, relativa)
	return fs.isFile(ruta) or fs.isDir(ruta)
end

-- Carpetas de código que se miran (las que existan).
local carpetas = {}
for _, c in { "src", "tests" } do
	if existe(c) then
		table.insert(carpetas, c)
	end
end

-- Código que no es nuestro o es generado: no se le exige nada.
local IGNORAR =
	{ "Packages/**", "ServerPackages/**", "src/server/Vendor/**", "src/shared/Net/**", "src/shared/Assets/**" }

local todos = { "stylua", "selene", "tipos", "build", "pruebas", "reglas", "ids", "ui", "efectos", "mapa", "kit" }
local elegidos: { [string]: boolean } = {}
if typeof(opciones.pasos) == "string" then
	for paso in string.gmatch(opciones.pasos, "[^,%s]+") do
		elegidos[paso] = true
	end
elseif #sueltos > 0 then
	elegidos = { stylua = true, selene = true }
else
	for _, paso in todos do
		elegidos[paso] = true
	end
end

local proyecto = if existe("build.project.json") then "build.project.json" else "default.project.json"
local hayProyecto = existe(proyecto)

type Paso = { nombre: string, ok: boolean, nota: string?, detalle: string?, aviso: string? }
local pasos: { Paso } = {}
local registro: { string } = {}

local function apuntar(nombre: string, r: Comun.Resultado)
	table.insert(registro, `== {nombre} (código {r.codigo})\n{r.salida}\n`)
end

local function faltaHerramienta(nombre: string, r: Comun.Resultado): Paso?
	if r.falta or r.codigo == -2 then
		return {
			nombre = nombre,
			ok = false,
			detalle = `Falta la herramienta. En la carpeta del juego: rokit install\n{Comun.primeras(r.salida, 3)}`,
		}
	end
	return nil
end

-- Los paquetes de Wally (Packages/) no van en git: si el proyecto los usa y no están, se avisa claro.
local function faltanPaquetes(): string?
	if not hayProyecto then
		return nil
	end
	local texto = fs.readFile(Comun.unir(raiz, proyecto))
	for _, carpeta in { "Packages", "ServerPackages" } do
		if string.find(texto, `"$path": "{carpeta}"`, 1, true) and not existe(carpeta) then
			return `Faltan los paquetes ({carpeta}/). Instálalos con: lune run "{Comun.unir(kit, "paquetes.luau")}"`
		end
	end
	return nil
end

local archivosLuau = {}
for _, a in sueltos do
	if string.match(a, "%.luau?$") then
		table.insert(archivosLuau, (string.gsub(a, "\\", "/")))
	end
end
local objetivos = if #sueltos > 0 then archivosLuau else carpetas

-- 1. StyLua: solo mira el formato. Para arreglarlo: stylua src tests
local function pasoStylua(): Paso?
	if not (existe("stylua.toml") or existe(".stylua.toml")) or #objetivos == 0 then
		return nil
	end
	local args = { "--check", "--output-format=summary" }
	for _, o in objetivos do
		table.insert(args, o)
	end
	local r = Comun.ejecutar("stylua", args, raiz)
	apuntar("stylua", r)
	local falta = faltaHerramienta("stylua", r)
	if falta then
		return falta
	end
	if r.ok then
		return { nombre = "stylua", ok = true }
	end
	-- Fuera las líneas de progreso de StyLua («Checking formatting...», «All files are correctly formatted»).
	local utiles = {}
	for linea in string.gmatch(r.salida, "[^\r\n]+") do
		if not string.find(linea, "^!") and not string.find(linea, "correctly formatted", 1, true) then
			table.insert(utiles, linea)
		end
	end
	return {
		nombre = "stylua",
		ok = false,
		detalle = `Sin formatear o sin poder leerlo (se formatea con «stylua {table.concat(objetivos, " ")}»):\n{Comun.primeras(
			table.concat(utiles, "\n"),
			10
		)}`,
	}
end

-- 2. Selene: solo los errores hacen fallar; los avisos se cuentan.
local function pasoSelene(): Paso?
	if not existe("selene.toml") or #objetivos == 0 then
		return nil
	end
	local args = { "--display-style=quiet", "--no-summary" }
	for _, o in objetivos do
		table.insert(args, o)
	end
	local r = Comun.ejecutar("selene", args, raiz)
	apuntar("selene", r)
	local falta = faltaHerramienta("selene", r)
	if falta then
		return falta
	end
	local errores, avisos = {}, 0
	for linea in string.gmatch(r.salida, "[^\r\n]+") do
		if string.find(linea, ":%s*error%[") then
			table.insert(errores, linea)
		elseif string.find(linea, ":%s*warning%[") then
			avisos += 1
		end
	end
	local aviso = if avisos > 0 then `selene: {avisos} aviso(s), detalle en .kit/comprobar.log` else nil
	if #errores > 0 then
		return {
			nombre = "selene",
			ok = false,
			detalle = Comun.primeras(table.concat(errores, "\n"), 15),
			aviso = aviso,
		}
	end
	if not r.ok and avisos == 0 then
		return { nombre = "selene", ok = false, detalle = Comun.primeras(r.salida, 10) }
	end
	return { nombre = "selene", ok = true, aviso = aviso }
end

-- Tipos de Roblox para luau-lsp, de la MISMA versión que luau-lsp (en Steal an Egg se bajaban sin fijar).
-- Se guardan en la caché del PC y solo se bajan una vez por versión.
local function definiciones(): (string?, string?)
	local v = Comun.ejecutar("luau-lsp", { "--version" }, raiz)
	if not v.ok then
		return nil, Comun.primeras(v.salida, 3)
	end
	local version = string.match(v.salida, "(%d+%.%d+%.%d+)")
	if not version then
		return nil, `No se entiende la versión de luau-lsp: {v.salida}`
	end
	local cache = if process.env.LOCALAPPDATA
		then Comun.unir(process.env.LOCALAPPDATA, "roblox-kit", "tipos")
		else Comun.unir(
			process.env.XDG_CACHE_HOME or Comun.unir(process.env.HOME or ".", ".cache"),
			"roblox-kit",
			"tipos"
		)
	local archivo = Comun.unir(cache, `globalTypes.None-{version}.d.luau`)
	if fs.isFile(archivo) then
		return archivo, nil
	end
	local url = `https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/{version}/scripts/globalTypes.None.d.luau`
	local ok, respuesta = pcall(net.request, url)
	if not ok or not respuesta.ok then
		return nil, `No se pudieron bajar los tipos de Roblox ({url}).`
	end
	fs.writeDir(cache)
	fs.writeFile(archivo, respuesta.body)
	return archivo, nil
end

-- 3. luau-lsp: tipos (--!strict y lo que diga .luaurc) de todo src.
local function pasoTipos(): Paso?
	if not hayProyecto or not existe("src") then
		return nil
	end
	local paquetes = faltanPaquetes()
	if paquetes then
		return { nombre = "tipos", ok = false, detalle = paquetes }
	end
	local mapa =
		Comun.ejecutar("rojo", { "sourcemap", proyecto, "-o", "sourcemap.json", "--include-non-scripts" }, raiz)
	apuntar("rojo sourcemap", mapa)
	local falta = faltaHerramienta("tipos", mapa)
	if falta then
		return falta
	end
	if not mapa.ok then
		return { nombre = "tipos", ok = false, detalle = "rojo sourcemap:\n" .. Comun.primeras(mapa.salida, 10) }
	end
	local defs, problema = definiciones()
	if not defs then
		return { nombre = "tipos", ok = false, detalle = problema }
	end
	local args = { "analyze", `--definitions=@roblox={defs}`, "--sourcemap=sourcemap.json" }
	for _, patron in IGNORAR do
		table.insert(args, `--ignore={patron}`)
	end
	local hayArchivos = false
	if #sueltos > 0 then
		for _, a in archivosLuau do
			if string.sub(a, 1, 4) == "src/" then
				table.insert(args, a)
				hayArchivos = true
			end
		end
		if not hayArchivos then
			return nil
		end
	else
		table.insert(args, "src")
	end
	local r = Comun.ejecutar("luau-lsp", args, raiz)
	apuntar("luau-lsp", r)
	falta = faltaHerramienta("tipos", r)
	if falta then
		return falta
	end
	if r.ok then
		return { nombre = "tipos", ok = true }
	end
	-- Solo los errores: fuera las líneas [INFO]/[WARN] de luau-lsp y los repetidos.
	local errores, vistos = {}, {}
	for linea in string.gmatch(Comun.sinRaiz(r.salida, raiz), "[^\r\n]+") do
		if not string.find(linea, "^%[%u+%]") and not vistos[linea] then
			vistos[linea] = true
			table.insert(errores, linea)
		end
	end
	return { nombre = "tipos", ok = false, detalle = Comun.primeras(table.concat(errores, "\n"), 20) }
end

-- 4. rojo build: el sitio se construye entero sin Studio.
local function pasoBuild(): Paso?
	if not hayProyecto then
		return nil
	end
	local paquetes = faltanPaquetes()
	if paquetes then
		return { nombre = "build", ok = false, detalle = paquetes }
	end
	local salida = Comun.unir(Comun.carpetaKit(raiz), "build.rbxl")
	local r = Comun.ejecutar("rojo", { "build", proyecto, "-o", salida }, raiz)
	apuntar("rojo build", r)
	local falta = faltaHerramienta("build", r)
	if falta then
		return falta
	end
	if r.ok then
		return { nombre = "build", ok = true }
	end
	return { nombre = "build", ok = false, detalle = Comun.primeras(Comun.sinRaiz(r.salida, raiz), 15) }
end

-- 5. Pruebas de Lune (kit/probar.luau), en un proceso aparte: una prueba colgada o rota no tumba comprobar.
local function pasoPruebas(): Paso?
	if not existe("tests") then
		return nil
	end
	local r = Comun.ejecutar("lune", { "run", Comun.unir(kit, "probar.luau"), "--raiz", raiz }, raiz)
	apuntar("pruebas", r)
	local falta = faltaHerramienta("pruebas", r)
	if falta then
		return falta
	end
	local primera = string.match(r.stdout, "^pruebas: ([^\r\n]*)")
	if r.ok then
		return { nombre = "pruebas", ok = true, nota = primera }
	end
	return { nombre = "pruebas", ok = false, detalle = Comun.primeras(r.stdout ~= "" and r.stdout or r.salida, 25) }
end

-- Quita comentarios y textos de un código Luau (lo justo para buscar palabras sin falsos avisos).
local function sinComentariosNiTextos(codigo: string): string
	codigo = string.gsub(codigo, "%-%-%[(=*)%[.-%]%1%]", function(c)
		return (string.gsub(c, "[^\n]", ""))
	end)
	codigo = string.gsub(codigo, "%[(=*)%[.-%]%1%]", '""')
	codigo = string.gsub(codigo, "%-%-[^\n]*", "")
	codigo = string.gsub(codigo, '"[^"\n]*"', '""')
	codigo = string.gsub(codigo, "'[^'\n]*'", "''")
	codigo = string.gsub(codigo, "`[^`\n]*`", "``")
	return codigo
end

-- 6. Regla: los módulos de Rules son lógica pura (sin game ni servicios), para probarlos con Lune.
local PROHIBIDO = {
	{ "%f[%w_]game%f[^%w_]", "game" },
	{ "%f[%w_]workspace%f[^%w_]", "workspace" },
	{ "%f[%w_]script%f[^%w_]", "script" },
	{ "GetService", "GetService" },
	{ "%f[%w_]Instance%.new", "Instance.new" },
}
local function pasoReglas(): Paso?
	local carpeta = Comun.unir(raiz, "src/shared/Rules")
	if not fs.isDir(carpeta) then
		return nil
	end
	local problemas = {}
	for _, archivo in
		Comun.archivos(carpeta, function(r)
			return string.match(r, "%.luau?$") ~= nil
		end)
	do
		local codigo = sinComentariosNiTextos(fs.readFile(Comun.unir(carpeta, archivo)))
		local n = 0
		for linea in string.gmatch(codigo .. "\n", "([^\n]*)\n") do
			n += 1
			for _, p in PROHIBIDO do
				if string.find(linea, p[1]) then
					table.insert(problemas, `src/shared/Rules/{archivo}:{n}: usa {p[2]}`)
				end
			end
		end
	end
	if #problemas == 0 then
		return { nombre = "reglas", ok = true }
	end
	return {
		nombre = "reglas",
		ok = false,
		detalle = "Los módulos de Rules son lógica pura, sin Roblox (si no, no se pueden probar con Lune). "
			.. "Pasa lo de Roblox al sistema que los usa:\n"
			.. Comun.primeras(table.concat(problemas, "\n"), 15),
	}
end

local funciones: { [string]: () -> Paso? } = {
	stylua = pasoStylua,
	selene = pasoSelene,
	tipos = pasoTipos,
	build = pasoBuild,
	pruebas = pasoPruebas,
	reglas = pasoReglas,
	ids = function()
		return Oficios.ids(raiz)
	end,
	ui = function()
		return Oficios.ui(raiz)
	end,
	efectos = function()
		return Oficios.efectos(raiz)
	end,
	mapa = function()
		return Oficios.mapa(raiz)
	end,
	kit = function()
		return Oficios.kit(raiz, Comun.raizPlugin())
	end,
}

for _, nombre in todos do
	if elegidos[nombre] then
		local ok, paso = pcall(funciones[nombre])
		if not ok then
			table.insert(pasos, { nombre = nombre, ok = false, detalle = `Error del propio paso: {paso}` })
		elseif paso then
			table.insert(pasos, paso)
		end
	end
end
for nombre in elegidos do
	if not funciones[nombre] then
		table.insert(
			pasos,
			{ nombre = nombre, ok = false, detalle = `No existe el paso. Pasos: {table.concat(todos, ", ")}` }
		)
	end
end

fs.writeFile(Comun.unir(Comun.carpetaKit(raiz), "comprobar.log"), table.concat(registro, "\n"))

local hechos, fallan, avisos = {}, {}, {}
for _, p in pasos do
	table.insert(hechos, if p.nota then `{p.nombre}: {p.nota}` else p.nombre)
	if not p.ok then
		table.insert(fallan, p)
	end
	if p.aviso then
		table.insert(avisos, "aviso: " .. p.aviso)
	end
end

if #pasos == 0 then
	print("comprobar: nada que comprobar aquí (no hay src/, tests/ ni proyecto de Rojo)")
	process.exit(0)
end

if #fallan == 0 then
	print(`comprobar: bien en {Comun.segundos(inicio)} ({table.concat(hechos, ", ")})`)
	for _, a in avisos do
		print(a)
	end
	if opciones.parada then
		-- Pasadas que no hace comprobar: las pide el hook de Stop (una vez) si cambió lo suyo.
		local pendientes = {}
		if existe("src") and Comun.hayClaveNube() and Comun.pendiente(raiz, "nube") then
			table.insert(pendientes, "nube")
		end
		if existe("src/client/UI") and Comun.pendiente(raiz, "ui") then
			table.insert(pendientes, "ui")
		end
		local hayMapa = #Comun.archivos(Comun.unir(raiz, "map"), function(r)
			return string.match(r, "%.rbxm$") ~= nil
		end) > 0
		if hayMapa and Comun.pendiente(raiz, "mapa") then
			table.insert(pendientes, "mapa")
		end
		for _, p in pendientes do
			print("pendiente: " .. p)
		end
		if #pendientes > 0 then
			process.exit(3)
		end
	end
	process.exit(0)
end

local nombres = {}
for _, p in fallan do
	table.insert(nombres, p.nombre)
end
local lineas =
	{ `comprobar: falla {table.concat(nombres, ", ")} ({Comun.segundos(inicio)}). Detalle: .kit/comprobar.log` }
for _, p in fallan do
	table.insert(lineas, `== {p.nombre}`)
	table.insert(lineas, p.detalle or "")
end
for _, a in avisos do
	table.insert(lineas, a)
end
print(table.concat(lineas, "\n"))
process.exit(1)
