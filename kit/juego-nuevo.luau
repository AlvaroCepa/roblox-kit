--!strict
-- juego-nuevo: crea la carpeta de un juego nuevo a partir de plantilla/ del plugin.
--   lune run <plugin>/kit/juego-nuevo.luau <carpeta-destino> --nombre <nombre-del-juego>
-- Copia la plantilla, pone el nombre y copia los módulos del kit (kit/juego/*, con su versión) a src/shared/Kit.
-- No toca git ni GitHub ni instala nada: eso lo hace la skill juego-nuevo, paso a paso.

local fs = require("@lune/fs")
local process = require("@lune/process")

local Comun = require("./comun")

local opciones, sueltos = Comun.argumentos()
local destino = sueltos[1]
if not destino then
	print('Uso: lune run <plugin>/kit/juego-nuevo.luau <carpeta-destino> --nombre "<nombre>"')
	process.exit(1)
end
destino = string.gsub(destino, "\\", "/")

local nombre = if typeof(opciones.nombre) == "string" then opciones.nombre else string.match(destino, "([^/]+)/*$")
-- Wally solo admite minúsculas, números y guiones en el nombre del paquete.
local nombreWally = string.gsub(string.gsub(string.lower(nombre or "juego"), "[^%w%-]+", "-"), "^%-+", "")

if fs.isDir(destino) and #fs.readDir(destino) > 0 then
	print(`juego-nuevo: {destino} ya existe y no está vacía. No se toca nada.`)
	process.exit(1)
end

local plugin = Comun.raizPlugin()
local plantilla = Comun.unir(plugin, "plantilla")
local TEXTO = { luau = true, json = true, toml = true, md = true, yml = true, zap = true, txt = true }

local copiados = 0
for _, relativa in Comun.archivos(plantilla) do
	local origen = Comun.unir(plantilla, relativa)
	local final = Comun.unir(destino, relativa)
	local carpeta = string.match(final, "^(.*)/[^/]+$")
	if carpeta then
		fs.writeDir(carpeta)
	end
	local contenido = fs.readFile(origen)
	local extension = string.match(relativa, "%.([%w]+)$") or ""
	if TEXTO[extension] or string.match(relativa, "^%.") or string.match(relativa, "/%.[^/]+$") then
		local paraWally = if relativa == "wally.toml" then nombreWally else nombre
		contenido = Comun.reemplazar(contenido, "{{nombre}}", paraWally or "juego")
	end
	fs.writeFile(final, contenido)
	copiados += 1
end

-- Módulos del kit (cargador, UI, marcas, efectos...): copias del plugin con su versión en la segunda línea.
fs.writeDir(Comun.unir(destino, "src/shared/Kit"))
for _, archivo in Comun.archivos(Comun.unir(plugin, "kit", "juego")) do
	local origen = fs.readFile(Comun.unir(plugin, "kit", "juego", archivo))
	fs.writeFile(Comun.unir(destino, "src/shared/Kit", archivo), origen)
	copiados += 1
end

print(`juego-nuevo: creado «{nombre}» en {destino} ({copiados} archivos).`)
