--!strict
-- roblox-kit Theme v1
-- Copia del original del plugin (kit/juego/). No se edita en el juego: se actualiza desde el plugin.
--
-- Lee la hoja de estilo del juego (src/shared/Data/Style.luau) y la da en tipos de Roblox:
-- colores por nombre de la paleta (o hex), la fuente y los niveles de fuerza (small, normal, epic).

local Style = require("../Data/Style")

local Theme = {}

Theme.style = Style

local cache: { [string]: Color3 } = {}

-- Color de la paleta por nombre ("green") o en hex ("#FFFFFF").
function Theme.color(name: string): Color3
	local found = cache[name]
	if found then
		return found
	end
	local hex = (Style.palette :: { [string]: string })[name] or name
	local ok, color = pcall(Color3.fromHex, hex)
	if not ok then
		error(`Theme: "{name}" is not a palette color nor a hex color`, 2)
	end
	cache[name] = color
	return color
end

function Theme.font(weight: Enum.FontWeight?): Font
	local font = Font.fromEnum((Enum.Font :: any)[Style.font])
	if weight then
		font.Weight = weight
	end
	return font
end

export type Tier = "small" | "normal" | "epic"

-- Multiplicador de un nivel de fuerza para un oficio ("vfx", "sound" o "animation").
function Theme.tier(craft: "vfx" | "sound" | "animation", tier: Tier?): number
	local tiers = (Style :: any)[craft].tiers :: { [string]: number }
	return tiers[tier or "normal"] or 1
end

return Theme
