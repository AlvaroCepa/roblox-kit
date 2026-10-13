--!strict
-- Corre las pruebas de Lune de un juego: tests/**/*.spec.luau (menos las *.cloud.spec.luau, que son de probar-nube).
-- Uso, desde la carpeta del juego:  lune run <plugin>/kit/probar.luau [--filtro texto]
-- Una línea si todo va bien; si algo falla, una línea por fallo. Código de salida 1 si falla algo.
--
-- Lune no deja hacer require de rutas absolutas, así que este script escribe en .kit/ del juego un archivo que
-- hace require de cada prueba con ruta relativa, y lo ejecuta en un proceso aparte.

local fs = require("@lune/fs")
local process = require("@lune/process")

local Comun = require("./comun")

local opciones = Comun.argumentos()
local raiz = if typeof(opciones.raiz) == "string" then opciones.raiz else process.cwd
local filtro = if typeof(opciones.filtro) == "string" then opciones.filtro else nil

local carpetaPruebas = Comun.unir(raiz, "tests")
local specs = Comun.archivos(carpetaPruebas, function(ruta)
	return string.match(ruta, "%.spec%.luau$") ~= nil and string.match(ruta, "%.cloud%.spec%.luau$") == nil
end)

if #specs == 0 then
	print("pruebas: no hay ninguna")
	process.exit(0)
end

local kit = Comun.carpetaKit(raiz)
fs.writeFile(Comun.unir(kit, "probador.luau"), fs.readFile(Comun.unir(Comun.raizPlugin(), "kit", "probador.luau")))

local lineas = {
	"-- Generado por roblox-kit (kit/probar.luau). No se edita: se rehace en cada pasada.",
	'local process = require("@lune/process")',
	'local Probador = require("./probador")',
	"local specs = {}",
}
for _, ruta in specs do
	local sinExtension = string.gsub(ruta, "%.luau$", "")
	table.insert(
		lineas,
		string.format(
			"table.insert(specs, Probador.cargar(%q, function() return require(%q) end))",
			"tests/" .. ruta,
			"../tests/" .. sinExtension
		)
	)
end
table.insert(
	lineas,
	string.format("local r = Probador.correr(specs, %s)", if filtro then string.format("%q", filtro) else "nil")
)
table.insert(lineas, "print(Probador.resumen(r))")
table.insert(lineas, "process.exit(if #r.fallos > 0 then 1 else 0)")

local entrada = Comun.unir(kit, "pruebas.luau")
fs.writeFile(entrada, table.concat(lineas, "\n") .. "\n")

local r = Comun.ejecutar("lune", { "run", entrada }, raiz)
-- Si el probador llegó a dar su resumen, basta con él (Lune repite en stderr los errores de require ya contados).
local salida = if string.find(r.stdout, "^pruebas: ") then r.stdout else r.salida
-- Las rutas del archivo generado (.kit/pruebas) no dicen nada a quien lee: se dejan solo las de las pruebas.
salida = string.gsub(salida, "%[Stack Begin%].-%[Stack End%]", "")
salida = string.gsub(Comun.sinRaiz(salida, raiz), "%s+$", "")
print(salida)
process.exit(if r.ok then 0 else 1)
