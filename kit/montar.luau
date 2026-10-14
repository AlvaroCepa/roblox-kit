--!strict
-- montar: monta TU copia local del juego (código, trozos del mapa y ambiente) en <nombre>.rbxl, para abrirla
-- en Studio y trabajar con `rojo serve`. Cada uno trabaja en su copia (sin Team Create): es un borrador; el
-- juego de verdad es main en GitHub. Desde la carpeta del juego, después de `git pull`:
--   lune run <plugin>/kit/montar.luau             la primera vez
--   lune run <plugin>/kit/montar.luau --rehacer   rehace la copia con lo último del repo
-- --rehacer guarda la copia anterior en .kit/copias/ (las 3 últimas): lo que se cambió en el mapa y no se
-- guardó con guardar-mapa se perdería si no. Si Studio tiene la copia abierta, no la toca.

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Comun = require("./comun")

local opciones = Comun.argumentos()
local raiz = if typeof(opciones.raiz) == "string" then opciones.raiz else process.cwd

local proyecto = if fs.isFile(Comun.unir(raiz, "build.project.json"))
	then "build.project.json"
	else "default.project.json"
if not fs.isFile(Comun.unir(raiz, proyecto)) then
	print("montar: no hay proyecto de Rojo aquí (¿estás en la carpeta del juego?)")
	process.exit(1)
end
local nombre = serde.decode("json", fs.readFile(Comun.unir(raiz, proyecto))).name or "juego"
nombre = string.gsub(nombre, "[^%w%-_ ]", "")
local archivo = Comun.unir(raiz, nombre .. ".rbxl")

if fs.isFile(archivo .. ".lock") then
	print(`montar: Studio tiene abierta {nombre}.rbxl. Ciérrala (guardando con guardar-mapa lo del mapa) y repite.`)
	process.exit(1)
end
if fs.isFile(archivo) then
	if not opciones.rehacer then
		print(`montar: ya existe {nombre}.rbxl. Ábrela en Studio. Para rehacerla con lo último del repo: --rehacer`)
		process.exit(0)
	end
	local copias = Comun.unir(Comun.carpetaKit(raiz), "copias")
	fs.writeDir(copias)
	fs.move(archivo, Comun.unir(copias, `{nombre}-{os.date("%Y%m%d-%H%M%S")}.rbxl`), { overwrite = true })
	local viejas = Comun.archivos(copias)
	for i = 1, #viejas - 3 do
		fs.removeFile(Comun.unir(copias, viejas[i]))
	end
end

local r = Comun.ejecutar("rojo", { "build", proyecto, "-o", archivo }, raiz)
if not r.ok then
	print("montar: rojo build falla:\n" .. Comun.primeras(Comun.sinRaiz(r.salida, raiz), 10))
	process.exit(1)
end
print(
	`montar: lista {nombre}.rbxl ({proyecto}). Ábrela en Studio y conecta Rojo con «rojo serve» (default.project.json:`
		.. " sincroniza el código y nunca toca el mapa)."
)
