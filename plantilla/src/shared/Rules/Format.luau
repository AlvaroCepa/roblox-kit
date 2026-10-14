--!strict
-- Formatos de números para la UI (1.2K, 3.4M, 1.2T, 3:05). Lógica pura, probada con Lune.
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

-- Número corto con un decimal como mucho: 999 -> "999", 1250 -> "1.2K", 1.2e12 -> "1.2T".
function Format.short(n: number): string
	local sign = if n < 0 then "-" else ""
	local value = math.abs(n)
	local index = 1
	while value >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end
	if index == 1 then
		return sign .. tostring(math.floor(value))
	end
	-- Se corta (no se redondea) para no enseñar más de lo que hay: 1999 -> 1.9K.
	local cut = math.floor(value * 10 + 1e-6) / 10 -- (el 1e-6 evita que 1.2 en coma flotante salga 1.1)
	local text = if cut == math.floor(cut) then tostring(math.floor(cut)) else string.format("%.1f", cut)
	return sign .. text .. SUFFIXES[index]
end

-- Segundos a "m:ss" (o "h:mm:ss" si pasa de una hora).
function Format.time(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local h, m = s // 3600, (s // 60) % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s % 60)
	end
	return string.format("%d:%02d", m, s % 60)
end

return Format
