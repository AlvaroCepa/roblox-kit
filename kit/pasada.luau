--!strict
-- pasada: apunta que el comprobador en Studio de la UI o del mapa ha pasado bien con los archivos de ahora.
-- Lo lanza solo el hook del plugin al ver «roblox-kit comprobar-ui: bien» (o -mapa) en la salida de
-- execute_luau; a mano no hace falta. Desde la carpeta del juego:
--   lune run <plugin>/kit/pasada.luau ui|mapa
local fs = require("@lune/fs")
local process = require("@lune/process")

local Comun = require("./comun")

local opciones, sueltos = Comun.argumentos()
local raiz = if typeof(opciones.raiz) == "string" then opciones.raiz else process.cwd
local nombre = sueltos[1]
if nombre ~= "ui" and nombre ~= "mapa" then
	print("Uso: lune run <plugin>/kit/pasada.luau ui|mapa")
	process.exit(1)
end
fs.writeFile(Comun.rutaPasada(raiz, nombre), Comun.huella(raiz, Comun.HUELLAS[nombre]))
print(`pasada: {nombre} apuntada como buena`)
