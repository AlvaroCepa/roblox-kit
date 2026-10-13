--!strict
-- paquetes: instala los paquetes de Wally del juego y arregla sus tipos para luau-lsp.
-- Desde la carpeta del juego:  lune run <plugin>/kit/paquetes.luau
-- Pasos: wally install, rojo sourcemap y wally-package-types sobre Packages/ y ServerPackages/.
-- Sin wally-package-types, los paquetes llegan sin tipos y el modo estricto se queja de todo lo que los usa.

local fs = require("@lune/fs")
local process = require("@lune/process")

local Comun = require("./comun")

local opciones = Comun.argumentos()
local raiz = if typeof(opciones.raiz) == "string" then opciones.raiz else process.cwd
local inicio = os.clock()

if not fs.isFile(Comun.unir(raiz, "wally.toml")) then
	print("paquetes: este juego no usa Wally (no hay wally.toml)")
	process.exit(0)
end

local function paso(nombre: string, programa: string, args: { string })
	local r = Comun.ejecutar(programa, args, raiz)
	if not r.ok then
		print(`paquetes: falla {nombre}`)
		print(Comun.primeras(Comun.sinRaiz(r.salida, raiz), 15))
		if r.falta then
			print("Falta la herramienta. En la carpeta del juego: rokit install")
		end
		process.exit(1)
	end
end

paso("wally install", "wally", { "install" })

local proyecto = if fs.isFile(Comun.unir(raiz, "build.project.json"))
	then "build.project.json"
	else "default.project.json"
local hechas = {}
for _, carpeta in { "Packages", "ServerPackages" } do
	if fs.isDir(Comun.unir(raiz, carpeta)) then
		if #hechas == 0 then
			paso("rojo sourcemap", "rojo", { "sourcemap", proyecto, "-o", "sourcemap.json", "--include-non-scripts" })
		end
		paso(`tipos de {carpeta}`, "wally-package-types", { "--sourcemap", "sourcemap.json", carpeta .. "/" })
		table.insert(hechas, carpeta)
	end
end

print(`paquetes: bien en {Comun.segundos(inicio)} ({if #hechas > 0 then table.concat(hechas, ", ") else "ninguno"})`)
