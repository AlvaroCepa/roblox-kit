--!strict
-- Funciones comunes de los scripts de roblox-kit (corren con Lune, igual en Windows que en el Linux de la CI).

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

local Comun = {}

Comun.windows = process.os == "windows"

-- Une trozos de ruta con "/" (Windows también lo acepta).
function Comun.unir(...: string): string
	local partes = {}
	for i, parte in { ... } do
		local limpia = string.gsub(parte, "\\", "/")
		if i > 1 then
			limpia = string.gsub(limpia, "^/+", "")
		end
		if i < select("#", ...) then
			limpia = string.gsub(limpia, "/+$", "")
		end
		table.insert(partes, limpia)
	end
	return table.concat(partes, "/")
end

-- Carpeta de este plugin (la que contiene kit/), sacada de la ruta de este archivo.
function Comun.raizPlugin(): string
	local fuente = debug.info(1, "s")
	fuente = string.gsub(string.gsub(fuente, "^@", ""), "\\", "/")
	local kit = string.match(fuente, "^(.*)/[^/]+$") or "."
	return string.match(kit, "^(.*)/[^/]+$") or "."
end

-- Lee los argumentos "--opcion valor", "--bandera" y los sueltos.
function Comun.argumentos(lista: { string }?): ({ [string]: string | boolean }, { string })
	local opciones: { [string]: string | boolean } = {}
	local sueltos = {}
	local args = lista or process.args
	local i = 1
	while i <= #args do
		local a = args[i]
		local nombre, valor = string.match(a, "^%-%-([%w%-]+)=(.*)$")
		if nombre then
			opciones[nombre] = valor :: string
		elseif string.sub(a, 1, 2) == "--" then
			local siguiente = args[i + 1]
			if siguiente and string.sub(siguiente, 1, 2) ~= "--" and Comun.esOpcionConValor(string.sub(a, 3)) then
				opciones[string.sub(a, 3)] = siguiente
				i += 1
			else
				opciones[string.sub(a, 3)] = true
			end
		else
			table.insert(sueltos, a)
		end
		i += 1
	end
	return opciones, sueltos
end

-- Opciones que llevan valor detrás (el resto son banderas).
local conValor = { pasos = true, raiz = true, filtro = true, universo = true, sitio = true, nombre = true }
function Comun.esOpcionConValor(nombre: string): boolean
	return conValor[nombre] == true
end

-- Ruta de una herramienta: primero la de Rokit, para que Foreman (si está antes en el PATH) no meta otra versión.
function Comun.herramienta(nombre: string): string
	local casa = process.env.USERPROFILE or process.env.HOME
	if casa then
		local ruta = Comun.unir(casa, ".rokit", "bin", nombre .. (if Comun.windows then ".exe" else ""))
		if fs.isFile(ruta) then
			return ruta
		end
	end
	return nombre
end

export type Resultado = { ok: boolean, codigo: number, salida: string, stdout: string, falta: boolean }

-- Ejecuta una herramienta en `carpeta` y devuelve su código y todo lo que escribió.
function Comun.ejecutar(nombre: string, args: { string }, carpeta: string, env: { [string]: string }?): Resultado
	local ok, r = pcall(process.exec, Comun.herramienta(nombre), args, { cwd = carpeta, env = env })
	if not ok then
		return { ok = false, codigo = -2, salida = `No se puede ejecutar '{nombre}': {r}`, stdout = "", falta = true }
	end
	local salida = string.gsub(r.stdout .. "\n" .. r.stderr, "^%s+", "")
	salida = string.gsub(salida, "%s+$", "")
	-- Rokit avisa así cuando la herramienta no está en rokit.toml.
	local falta = string.find(salida, "is not a known", 1, true) ~= nil
		or string.find(salida, "not managed by Rokit", 1, true) ~= nil
	return { ok = r.ok, codigo = r.code, salida = salida, stdout = r.stdout, falta = falta }
end

-- Todos los archivos bajo `carpeta` (rutas relativas a ella, con "/"), ordenados.
function Comun.archivos(carpeta: string, filtro: ((string) -> boolean)?): { string }
	local lista = {}
	local function recorrer(relativa: string)
		local completa = if relativa == "" then carpeta else Comun.unir(carpeta, relativa)
		for _, nombre in fs.readDir(completa) do
			local hija = if relativa == "" then nombre else relativa .. "/" .. nombre
			local ruta = Comun.unir(carpeta, hija)
			if fs.isDir(ruta) then
				recorrer(hija)
			elseif not filtro or filtro(hija) then
				table.insert(lista, hija)
			end
		end
	end
	if fs.isDir(carpeta) then
		recorrer("")
	end
	table.sort(lista)
	return lista
end

-- Carpeta .kit/ del juego: temporales y marcas de este PC. Se ignora sola en git.
function Comun.carpetaKit(raiz: string): string
	local carpeta = Comun.unir(raiz, ".kit")
	if not fs.isDir(carpeta) then
		fs.writeDir(carpeta)
	end
	local ignorar = Comun.unir(carpeta, ".gitignore")
	if not fs.isFile(ignorar) then
		fs.writeFile(ignorar, "*\n")
	end
	return carpeta
end

-- Huella de un conjunto de carpetas y archivos del juego (los que no existen no cuentan).
function Comun.huella(raiz: string, rutas: { string }): string
	local trozos = {}
	local function sumar(relativa: string)
		table.insert(trozos, relativa)
		local contenido = fs.readFile(Comun.unir(raiz, relativa))
		-- Los de texto, sin \r: la huella sale igual en Windows y en Linux.
		if not string.match(relativa, "%.rbxm$") and not string.match(relativa, "%.png$") then
			contenido = string.gsub(contenido, "\r\n", "\n")
		end
		table.insert(trozos, contenido)
	end
	for _, ruta in rutas do
		local completa = Comun.unir(raiz, ruta)
		if fs.isDir(completa) then
			for _, archivo in Comun.archivos(completa) do
				sumar(ruta .. "/" .. archivo)
			end
		elseif fs.isFile(completa) then
			sumar(ruta)
		end
	end
	return serde.hash("sha256", table.concat(trozos, "\0"))
end

-- Qué mira cada pasada que se apunta (nube = probar-nube; ui y mapa = sus comprobadores en Studio).
Comun.HUELLAS = {
	nube = { "src/server", "src/shared", "default.project.json", "build.project.json", "net.zap" },
	ui = {
		"src/client/UI",
		"src/shared/Data/Style.luau",
		"src/shared/Data/Texts.luau",
		"src/shared/Kit/UI.luau",
		"src/shared/Kit/Screens.luau",
		"assets/ui",
	},
	mapa = { "map", "src/shared/Data/Map.luau" },
}

-- Huella del código que corre en el servidor. probar-nube la guarda al pasar y comprobar --parada la compara
-- para saber si toca volver a probar en la nube.
function Comun.huellaServidor(raiz: string): string
	return Comun.huella(raiz, Comun.HUELLAS.nube)
end

-- Archivo donde se apunta la última pasada buena de `nombre` (nube, ui, mapa).
function Comun.rutaPasada(raiz: string, nombre: string): string
	return Comun.unir(Comun.carpetaKit(raiz), nombre .. "-ok.txt")
end

function Comun.rutaHuellaNube(raiz: string): string
	return Comun.rutaPasada(raiz, "nube")
end

-- ¿Ha cambiado `nombre` desde su última pasada buena?
function Comun.pendiente(raiz: string, nombre: string): boolean
	local ruta = Comun.rutaPasada(raiz, nombre)
	local guardada = if fs.isFile(ruta) then fs.readFile(ruta) else ""
	return guardada ~= Comun.huella(raiz, Comun.HUELLAS[nombre])
end

-- Carga un archivo de datos del juego (Luau puro, como src/shared/Data/Style.luau) y devuelve lo que devuelve.
-- Tiene a mano los tipos de Roblox (Vector3, NumberRange, Enum...). Lune no deja hacer require de rutas
-- absolutas, por eso se carga el texto.
function Comun.cargarDatos(ruta: string): any
	local roblox = require("@lune/roblox") :: any
	local luau = require("@lune/luau")
	local entorno = {}
	for clave, valor in roblox do
		if typeof(clave) == "string" and string.match(clave, "^%u") then
			entorno[clave] = valor
		end
	end
	return luau.load(fs.readFile(ruta), { debugName = ruta, environment = entorno })()
end

-- ¿Hay clave de Open Cloud en este PC (o en la CI)?
function Comun.hayClaveNube(): boolean
	if process.env.ROBLOX_API_KEY and process.env.ROBLOX_API_KEY ~= "" then
		return true
	end
	local local_ = process.env.LOCALAPPDATA
	return local_ ~= nil and fs.isFile(Comun.unir(local_, "RobloxOpenCloud", "clave.dat"))
end

-- Reemplaza texto literal (sin patrones).
function Comun.reemplazar(texto: string, buscar: string, poner: string): string
	if buscar == "" then
		return texto
	end
	local partes = {}
	local desde = 1
	while true do
		local i, j = string.find(texto, buscar, desde, true)
		if not i then
			break
		end
		table.insert(partes, string.sub(texto, desde, i - 1))
		table.insert(partes, poner)
		desde = j + 1
	end
	table.insert(partes, string.sub(texto, desde))
	return table.concat(partes)
end

-- Quita la ruta de la carpeta del juego de un texto, con barras de un tipo o del otro: mensajes más cortos.
function Comun.sinRaiz(texto: string, raiz: string): string
	local base = string.gsub(string.gsub(raiz, "\\", "/"), "/+$", "") .. "/"
	-- La letra de la unidad puede llegar en mayúscula o minúscula (luau-lsp la da en minúscula).
	local variantes = { base, string.upper(string.sub(base, 1, 1)) .. string.sub(base, 2) }
	variantes[3] = string.lower(string.sub(base, 1, 1)) .. string.sub(base, 2)
	for _, v in variantes do
		texto = Comun.reemplazar(texto, v, "")
		texto = Comun.reemplazar(texto, (string.gsub(v, "/", "\\")), "")
	end
	return texto
end

-- Primeras `n` líneas no vacías de un texto.
function Comun.primeras(texto: string, n: number): string
	local lineas = {}
	for linea in string.gmatch(texto, "[^\r\n]+") do
		if string.find(linea, "%S") then
			if #lineas >= n then
				table.insert(lineas, "  ...")
				break
			end
			table.insert(lineas, linea)
		end
	end
	return table.concat(lineas, "\n")
end

function Comun.segundos(desde: number): string
	return string.format("%.1f s", os.clock() - desde)
end

function Comun.error(texto: string)
	stdio.ewrite(texto .. "\n")
end

return Comun
