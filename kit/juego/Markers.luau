--!strict
-- roblox-kit Markers v1
-- Copia del original del plugin (kit/juego/). No se edita en el juego: se actualiza desde el plugin.
--
-- El código encuentra los sitios del mapa por MARCAS, nunca por ruta ni por nombre (workspace.Map.X).
-- Una marca es una parte invisible, anclada y sin colisiones con una etiqueta de CollectionService
-- (Spawn, SafeZone, Exit, CameraPoint...); sus datos van en atributos (Biome = "Forest").
--   Markers.one("Spawn")             la única marca de ese tipo (avisa si hay 0 o varias)
--   Markers.all("Nest")              todas
--   Markers.at(position, "Zone")     en qué caja de ese tipo está una posición (o nil)
--   Markers.check()                  avisa por nombre de cada marca que falte según Data/Map

local CollectionService = game:GetService("CollectionService")

local Map = require("../Data/Map")

local Markers = {}

function Markers.all(tag: string): { BasePart }
	local list = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") then
			table.insert(list, instance)
		end
	end
	return list
end

function Markers.one(tag: string): BasePart?
	local list = Markers.all(tag)
	if #list ~= 1 then
		warn(`Markers: expected exactly one "{tag}" marker, found {#list}`)
	end
	return list[1]
end

-- ¿Está la posición dentro de la caja de la parte?
function Markers.inside(part: BasePart, position: Vector3): boolean
	local localPos = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z
end

function Markers.at(position: Vector3, tag: string): BasePart?
	for _, part in Markers.all(tag) do
		if Markers.inside(part, position) then
			return part
		end
	end
	return nil
end

type MarkRule = { count: number?, min: number?, attributes: { string }? }

-- Lista de problemas con las marcas según la ficha (vacía si todo está bien). También los avisa.
function Markers.check(): { string }
	local problems = {}
	local marks: { [string]: MarkRule } = Map.marks :: any
	for tag, rule in marks do
		local list = Markers.all(tag)
		if rule.count and #list ~= rule.count then
			table.insert(problems, `"{tag}": {#list} marker(s), expected {rule.count}`)
		elseif rule.min and #list < rule.min then
			table.insert(problems, `"{tag}": {#list} marker(s), expected at least {rule.min}`)
		end
		for _, part in list do
			for _, attribute in (rule.attributes or {}) :: { string } do
				if part:GetAttribute(attribute) == nil then
					table.insert(problems, `"{tag}" marker {part:GetFullName()} has no attribute {attribute}`)
				end
			end
		end
	end
	for _, problem in problems do
		warn("Markers: " .. problem)
	end
	return problems
end

return Markers
