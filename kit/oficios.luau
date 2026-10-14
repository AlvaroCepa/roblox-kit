--!strict
-- Pasos de comprobar de los oficios (UI, mapa, efectos, sonido) y de los módulos del kit. Sin Studio: leen
-- los archivos del juego, así corren en cada turno y en la CI. La mitad «en Studio» de la UI y del mapa está
-- en kit/juego/UICheck.luau y MapCheck.luau.
-- Cada paso devuelve { nombre, ok, detalle?, aviso? } o nil si no aplica a este juego.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local Comun = require("./comun")

local Oficios = {}

export type Paso = { nombre: string, ok: boolean, nota: string?, detalle: string?, aviso: string? }

-- Código que no es nuestro, es generado o es del kit (se revisa en el plugin).
local AJENO = { "^src/server/Vendor/", "^src/shared/Net/", "^src/shared/Assets/", "^src/shared/Kit/" }

local function esAjeno(relativa: string): boolean
	for _, patron in AJENO do
		if string.find(relativa, patron) then
			return true
		end
	end
	return false
end

-- Archivos .luau de una carpeta del juego (rutas relativas a la raíz).
local function luau(raiz: string, carpeta: string): { string }
	local lista = {}
	for _, archivo in
		Comun.archivos(Comun.unir(raiz, carpeta), function(r)
			return string.match(r, "%.luau?$") ~= nil
		end)
	do
		local relativa = carpeta .. "/" .. archivo
		if not esAjeno(relativa) then
			table.insert(lista, relativa)
		end
	end
	return lista
end

-- Líneas de un archivo sin los comentarios (con su número).
local function lineas(raiz: string, relativa: string): { { n: number, texto: string } }
	local codigo = fs.readFile(Comun.unir(raiz, relativa))
	codigo = string.gsub(codigo, "%-%-%[(=*)%[.-%]%1%]", function(c)
		return (string.gsub(c, "[^\n]", ""))
	end)
	local lista = {}
	local n = 0
	for linea in string.gmatch(codigo .. "\n", "([^\n]*)\n") do
		n += 1
		local sin = string.gsub(linea, "%-%-[^\n]*$", "")
		if string.find(sin, "%S") then
			table.insert(lista, { n = n, texto = sin })
		end
	end
	return lista
end

local function resultado(nombre: string, explicacion: string, problemas: { string }, aviso: string?): Paso
	if #problemas == 0 then
		return { nombre = nombre, ok = true, aviso = aviso }
	end
	return {
		nombre = nombre,
		ok = false,
		detalle = explicacion .. "\n" .. Comun.primeras(table.concat(problemas, "\n"), 15),
		aviso = aviso,
	}
end

-- Módulos del kit: la copia del juego viene del plugin. Si el plugin tiene una versión nueva, solo avisa.
function Oficios.kit(raiz: string, plugin: string): Paso?
	local delJuego = Comun.unir(raiz, "src/shared/Kit")
	if not fs.isDir(delJuego) then
		return nil
	end
	local function version(ruta: string): number
		return tonumber(string.match(fs.readFile(ruta), "roblox%-kit %w+ v(%d+)")) or 0
	end
	local viejos, faltan = {}, {}
	for _, archivo in Comun.archivos(Comun.unir(plugin, "kit", "juego")) do
		local copia = Comun.unir(delJuego, archivo)
		if not fs.isFile(copia) then
			table.insert(faltan, archivo)
		elseif version(copia) < version(Comun.unir(plugin, "kit", "juego", archivo)) then
			table.insert(viejos, archivo)
		end
	end
	local partes = {}
	if #viejos > 0 then
		table.insert(partes, `hay versión nueva en el plugin de {table.concat(viejos, ", ")}`)
	end
	if #faltan > 0 then
		table.insert(partes, `el juego no tiene {table.concat(faltan, ", ")}`)
	end
	local aviso = if #partes > 0
		then `kit: {table.concat(partes, "; ")}. Se copian de <kit>/kit/juego/ a src/shared/Kit/ cuando convenga`
		else nil
	return { nombre = "kit", ok = true, aviso = aviso }
end

-- Ningún id suelto en el código: imágenes, sonidos, animaciones y mallas salen de Assets por nombre.
function Oficios.ids(raiz: string): Paso?
	if not fs.isDir(Comun.unir(raiz, "src")) then
		return nil
	end
	local problemas = {}
	for _, relativa in luau(raiz, "src") do
		for _, l in lineas(raiz, relativa) do
			local t = l.texto
			local suelto = string.find(t, "rbxassetid://", 1, true)
				or string.find(t, "rbxasset://", 1, true)
				or string.find(t, "rbxthumb://", 1, true)
				or string.find(t, "roblox%.com/asset")
				or string.find(t, "[Ii]d%s*=%s*[\"']?%d%d%d%d%d%d")
				or string.find(t, "Image%s*=%s*[\"']%d")
				or string.find(t, "Texture%s*=%s*[\"']%d")
			if suelto then
				table.insert(problemas, `{relativa}:{l.n}: {string.gsub(t, "^%s+", "")}`)
			end
		end
	end
	-- Assets hecho con «asphalt sync studio» (rutas locales): sirve para mirar, no para git ni para el juego.
	local aviso: string? = nil
	for _, archivo in Comun.archivos(Comun.unir(raiz, "src/shared/Assets")) do
		if string.find(fs.readFile(Comun.unir(raiz, "src/shared/Assets", archivo)), "rbxasset://.asphalt", 1, true) then
			aviso =
				`src/shared/Assets/{archivo} es de «asphalt sync studio» (solo vale en este Studio): no lo subas a git; se rehace con kit/subir-assets.ps1`
		end
	end
	return resultado(
		"ids",
		'Ids sueltos: los assets se piden por nombre con Kit/Asset (Asset.get("ui/...")); los ids los genera '
			.. 'Asphalt en src/shared/Assets. Los de la biblioteca de audio de Roblox, como "library:<id>" en Data/Sounds.',
		problemas,
		aviso
	)
end

-- UI: textos de Data/Texts, colores y fuente de la hoja de estilo, sin emojis, CanvasGroup ni UIScale.
function Oficios.ui(raiz: string): Paso?
	local carpeta = Comun.unir(raiz, "src/client/UI")
	if not fs.isDir(carpeta) then
		return nil
	end
	local problemas = {}
	for _, relativa in luau(raiz, "src/client/UI") do
		local esEstilo = string.match(relativa, "/Style%.luau$") ~= nil
		for _, l in lineas(raiz, relativa) do
			local t = l.texto
			local donde = `{relativa}:{l.n}`
			if string.find(t, "Text%s*=%s*[\"'`][^\"'`]*%a") then
				table.insert(problemas, `{donde}: texto escrito en el código (va en Data/Texts)`)
			end
			if not esEstilo and (string.find(t, "Color3%.%a+%(") or string.find(t, "BrickColor%.")) then
				table.insert(problemas, `{donde}: color fuera de la hoja de estilo (Theme.color("nombre"))`)
			end
			if not esEstilo and (string.find(t, "Enum%.Font%.") or string.find(t, "Font%.%a+%(")) then
				table.insert(problemas, `{donde}: fuente fuera de la hoja de estilo (Theme.font())`)
			end
			if string.find(t, "CanvasGroup") then
				table.insert(problemas, `{donde}: CanvasGroup emborrona; se desvanece pieza a pieza`)
			end
			if string.find(t, "UIScale") then
				table.insert(problemas, `{donde}: UIScale descuadra los UIStroke en ScaledSize; se anima Size`)
			end
		end
	end
	-- Emojis (bytes F0 9F...) en los textos y en la UI: prohibidos como iconos.
	for _, relativa in { "src/shared/Data/Texts.luau", table.unpack(luau(raiz, "src/client/UI")) } do
		local ruta = Comun.unir(raiz, relativa)
		if fs.isFile(ruta) and string.find(fs.readFile(ruta), "\240\159") then
			table.insert(problemas, `{relativa}: tiene emojis (los iconos son imágenes)`)
		end
	end
	return resultado("ui", "La UI rompe reglas de la skill de UI:", problemas)
end

-- Efectos y sonidos: datos con sentido y dentro de los topes de la hoja de estilo.
function Oficios.efectos(raiz: string): Paso?
	local rutaEfectos = Comun.unir(raiz, "src/shared/Data/Effects.luau")
	local rutaSonidos = Comun.unir(raiz, "src/shared/Data/Sounds.luau")
	local rutaEstilo = Comun.unir(raiz, "src/shared/Data/Style.luau")
	if not fs.isFile(rutaEstilo) or not (fs.isFile(rutaEfectos) or fs.isFile(rutaSonidos)) then
		return nil
	end
	local estilo = Comun.cargarDatos(rutaEstilo)
	local problemas, avisos = {}, {}
	if fs.isFile(rutaEfectos) then
		local epico = estilo.vfx.tiers.epic or 1
		for nombre, efecto in Comun.cargarDatos(rutaEfectos) do
			local total = 0
			for i, pieza in efecto.pieces or {} do
				if typeof(pieza.texture) ~= "string" or not string.find(pieza.texture, "/") then
					table.insert(
						problemas,
						`Effects.{nombre} pieza {i}: texture debe ser un nombre de Assets ("vfx/...")`
					)
				end
				total += (pieza.count or 0) * epico
				local vida = pieza.properties and pieza.properties.Lifetime
				if vida and vida.Max > 1.5 then
					table.insert(avisos, `Effects.{nombre}: vida de {vida.Max} s (mejor 1,5 s como mucho)`)
				end
			end
			if total > estilo.vfx.maxParticles then
				table.insert(
					problemas,
					`Effects.{nombre}: {total} partículas en nivel épico (tope {estilo.vfx.maxParticles} en Data/Style)`
				)
			end
		end
	end
	if fs.isFile(rutaSonidos) then
		for nombre, sonido in Comun.cargarDatos(rutaSonidos) do
			local asset = sonido.asset
			if typeof(asset) ~= "string" or not (string.find(asset, "/") or string.match(asset, "^library:%d+$")) then
				table.insert(problemas, `Sounds.{nombre}: asset debe ser "sounds/..." o "library:<id>"`)
			end
			if sonido.channel and not ({ music = true, sfx = true, ui = true })[sonido.channel] then
				table.insert(problemas, `Sounds.{nombre}: canal "{sonido.channel}" (music, sfx o ui)`)
			end
		end
	end
	local aviso = if #avisos > 0 then table.concat(avisos, "; ") else nil
	return resultado("efectos", "Efectos o sonidos fuera de las reglas:", problemas, aviso)
end

-- Mitad del comprobador del mapa que no necesita Studio: lee los .rbxm de map/.
function Oficios.mapa(raiz: string): Paso?
	local rutaFicha = Comun.unir(raiz, "src/shared/Data/Map.luau")
	if not fs.isDir(Comun.unir(raiz, "map")) or not fs.isFile(rutaFicha) then
		return nil
	end
	local ficha = Comun.cargarDatos(rutaFicha)
	local limites = ficha.limits or {}
	local problemas, avisos = {}, {}
	local etiquetas: { [string]: { any } } = {}
	local partes, luces, emisores, sonidos = 0, 0, 0, 0
	local archivos = {}
	local trozosFicha: { [string]: string } = {}
	for _, t in ficha.chunks or {} do
		trozosFicha[t.name] = t.kind
	end

	for _, carpeta in { "fixed", "pieces", "prefabs" } do
		for _, archivo in
			Comun.archivos(Comun.unir(raiz, "map", carpeta), function(r)
				return string.match(r, "%.rbxm$") ~= nil
			end)
		do
			local nombre = string.gsub(archivo, "%.rbxm$", "")
			archivos[nombre] = true
			local donde = `map/{carpeta}/{archivo}`
			if carpeta ~= "prefabs" and not trozosFicha[nombre] then
				table.insert(avisos, `{donde} no está en chunks de Data/Map`)
			end
			local ok, raices = pcall(roblox.deserializeModel, fs.readFile(Comun.unir(raiz, "map", carpeta, archivo)))
			if not ok then
				table.insert(problemas, `{donde}: no se puede leer ({raices})`)
				continue
			end
			local entradas, salidas = 0, 0
			for _, r in raices do
				local todos = r:GetDescendants()
				table.insert(todos, r)
				for _, d in todos do
					if d:IsA("LuaSourceContainer") then
						table.insert(problemas, `{donde}: script dentro del mapa ({d:GetFullName()})`)
					end
					if d:IsA("Light") then
						luces += 1
						if (d :: any).Shadows then
							table.insert(problemas, `{donde}: luz con Shadows encendido ({d:GetFullName()})`)
						end
					elseif d:IsA("ParticleEmitter") then
						emisores += 1
					elseif d:IsA("Sound") then
						sonidos += 1
					elseif d:IsA("Attachment") and d:HasTag("Connector") then
						local rol = d:GetAttribute("Role")
						if rol == "in" then
							entradas += 1
						elseif rol == "out" then
							salidas += 1
						end
					end
					if d:IsA("BasePart") then
						if carpeta == "fixed" then
							partes += 1
						end
						local p = d :: any
						if carpeta ~= "prefabs" and not p.Anchored then
							table.insert(problemas, `{donde}: pieza sin anclar ({d:GetFullName()})`)
						end
						local pequena = p.Size.X < 1 and p.Size.Y < 1 and p.Size.Z < 1
						if pequena and (p.CanCollide or p.CastShadow) and #avisos < 30 then
							table.insert(avisos, `{donde}: decoración pequeña con colisión o sombra ({d.Name})`)
						end
					end
					if carpeta == "fixed" then
						for _, etiqueta in d:GetTags() do
							etiquetas[etiqueta] = etiquetas[etiqueta] or {}
							table.insert(etiquetas[etiqueta], d)
						end
					end
				end
			end
			if carpeta == "pieces" and entradas == 0 then
				table.insert(
					problemas,
					`{donde}: pieza para montar sin enganche de entrada (Connector con Role = "in")`
				)
			end
			if carpeta == "pieces" and salidas == 0 then
				table.insert(avisos, `{donde}: pieza sin enganche de salida (solo vale como pieza final)`)
			end
		end
	end
	for nombre, tipo in trozosFicha do
		if not archivos[nombre] then
			local carpeta = if tipo == "piece" then "pieces" else "fixed"
			table.insert(
				avisos,
				`falta map/{carpeta}/{nombre}.rbxm (está en Data/Map; ¿sin guardar con guardar-mapa?)`
			)
		end
	end

	-- Marcas en los trozos fijos (las de las piezas para montar dependen de cada partida).
	if ficha.kind ~= "assembled" and next(archivos) then
		for etiqueta, regla in ficha.marks or {} do
			local lista = etiquetas[etiqueta] or {}
			if regla.count and #lista ~= regla.count then
				table.insert(problemas, `marca {etiqueta}: {#lista} en map/fixed (deben ser {regla.count})`)
			elseif regla.min and #lista < regla.min then
				table.insert(problemas, `marca {etiqueta}: {#lista} en map/fixed (al menos {regla.min})`)
			end
			for _, m in lista do
				local p = m :: any
				if m:IsA("BasePart") and (p.Transparency < 1 or p.CanCollide or not p.Anchored) then
					table.insert(problemas, `marca {etiqueta} ({m:GetFullName()}): invisible, sin colisión y anclada`)
				end
				for _, atributo in regla.attributes or {} do
					if m:GetAttribute(atributo) == nil then
						table.insert(problemas, `marca {etiqueta} ({m:GetFullName()}): falta el atributo {atributo}`)
					end
				end
			end
		end
	end

	local function tope(cantidad: number, limite: number?, que: string)
		if limite and cantidad > limite then
			table.insert(problemas, `{cantidad} {que} (límite {limite} en Data/Map)`)
		end
	end
	tope(partes, limites.parts, "piezas en los trozos fijos")
	tope(luces, limites.lights, "luces")
	tope(emisores, limites.particles, "emisores de partículas")
	tope(sonidos, limites.sounds, "sonidos")

	local aviso = if #avisos > 0 then "mapa: " .. table.concat(avisos, "; ") else nil
	return resultado("mapa", "El mapa rompe reglas de la skill de mapa:", problemas, aviso)
end

return Oficios
