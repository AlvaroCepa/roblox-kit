--!strict
-- ui-generar: dibuja los cuerpos de botones y paneles desde la hoja de estilo (src/shared/Data/Style.luau,
-- apartado ui.body) y los deja en assets/ui/kit/ como SVG. Asphalt los pasa a PNG al subirlos.
--   lune run <plugin>/kit/ui-generar.luau            (desde la carpeta del juego)
-- Son blancos y grises: en el juego se tiñen con ImageColor3 (un botón da el verde, el rojo y el dorado).
-- El «depth stack»: sombra desplazada, labio 3D abajo, cara con degradado, brillo arriba y un contorno
-- uniforme. Si cambia la ficha, se vuelven a generar todos. Para verlos sin subir: asphalt sync debug.

local fs = require("@lune/fs")
local process = require("@lune/process")

local Comun = require("./comun")

local opciones = Comun.argumentos()
local raiz = if typeof(opciones.raiz) == "string" then opciones.raiz else process.cwd
local rutaEstilo = Comun.unir(raiz, "src/shared/Data/Style.luau")
if not fs.isFile(rutaEstilo) then
	print("ui-generar: no está src/shared/Data/Style.luau (¿estás en la carpeta del juego?)")
	process.exit(1)
end

local estilo = Comun.cargarDatos(rutaEstilo)
local b = estilo.ui.body
local paleta = estilo.palette :: { [string]: string }
local contorno = paleta[estilo.ui.strokeColor] or estilo.ui.strokeColor

local function gris(brillo: number): string
	local v = math.clamp(math.round(brillo * 255), 0, 255)
	return string.format("#%02X%02X%02X", v, v, v)
end

local function n(x: number): string
	return string.format("%.2f", x)
end

-- Un cuerpo: `labio` en px (0 = plano, para paneles) y cuánto brillo lleva.
local function cuerpo(labio: number, brillo: number): string
	local s = b.size
	local m = b.stroke / 2
	local ancho = s - 2 * m
	local alto = s - 2 * m - b.shadowOffset
	local cara = alto - labio
	local r = b.corner
	local dentro = b.stroke + 5
	-- Un rectángulo redondeado del tamaño del cuerpo, desplazado `dy` hacia abajo, con su alto y lo demás.
	local function caja(dy: number, h: number, resto: string): string
		return string.format(
			'<rect x="%s" y="%s" width="%s" height="%s" rx="%d" %s/>',
			n(m),
			n(m + dy),
			n(ancho),
			n(h),
			r,
			resto
		)
	end
	local brilloRect = string.format(
		'<rect x="%s" y="%s" width="%s" height="%s" rx="%s" fill="#FFFFFF" fill-opacity="%s"/>',
		n(m + dentro),
		n(m + b.stroke + 3),
		n(ancho - 2 * dentro),
		n(cara * 0.32),
		n(r * 0.55),
		n(brillo)
	)
	local partes = {
		string.format(
			'<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">',
			s,
			s,
			s,
			s
		),
		"<defs>",
		string.format(
			'<linearGradient id="cara" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>',
			gris(b.gradientTop),
			gris(b.gradientBottom)
		),
		'<clipPath id="dentro">' .. caja(0, alto, "") .. "</clipPath>",
		"</defs>",
		-- Sombra desplazada hacia abajo.
		caja(b.shadowOffset, alto, string.format('fill="%s" fill-opacity="%s"', b.shadowColor, n(b.shadowAlpha))),
		-- Cuerpo entero en el tono del labio; la cara tapa todo menos la franja de abajo.
		caja(0, alto, string.format('fill="%s"', gris(b.lipShade))),
		'<g clip-path="url(#dentro)">' .. caja(0, cara, 'fill="url(#cara)"') .. "</g>",
		-- Brillo arriba.
		brilloRect,
		-- Contorno uniforme (el único grosor de la ficha).
		caja(0, alto, string.format('fill="none" stroke="%s" stroke-width="%s"', contorno, n(b.stroke))),
		"</svg>",
	}
	return table.concat(partes, "\n") .. "\n"
end

local carpeta = Comun.unir(raiz, "assets/ui/kit")
fs.writeDir(carpeta)
fs.writeFile(Comun.unir(carpeta, "button.svg"), cuerpo(b.lip, b.highlight))
fs.writeFile(Comun.unir(carpeta, "panel.svg"), cuerpo(0, b.highlight * 0.5))
print("ui-generar: assets/ui/kit/button.svg y panel.svg. Verlos sin subir: asphalt sync debug (.asphalt-debug/).")
