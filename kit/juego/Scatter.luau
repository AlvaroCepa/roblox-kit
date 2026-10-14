--!strict
-- roblox-kit Scatter v1
-- Copia del original del plugin (kit/juego/). No se edita en el juego: se actualiza desde el plugin.
--
-- Reparte copias de prefabs (ServerStorage.Prefabs) por una zona, en modo EDICIÓN con execute_luau. Así no
-- se colocan piezas una a una. Solo para el primer boceto de un trozo: después se retoca a mano y vive en su
-- archivo (nunca se vuelve a lanzar sobre un trozo ya retocado).
--   require(game.ReplicatedStorage.Shared.Kit.Scatter).run({
--       prefabs = { "Tree", "Rock" },     -- nombres en ServerStorage.Prefabs (con peso: { Tree = 3, Rock = 1 })
--       zone = workspace.Map.Forest.ScatterZone,   -- una parte (caja) que marca la zona
--       parent = workspace.Map.Forest,    -- dónde quedan las copias (en una carpeta Scatter_<semilla>)
--       density = 0.5,                    -- copias por cada 100 studs² (aprox.)
--       scale = { 0.8, 1.25 }, seed = 1,  -- escala al azar y semilla (misma semilla, mismo resultado)
--       gap = 6,                          -- distancia mínima entre copias
--   })
-- Respeta los huecos: nada cae dentro de una parte con la etiqueta NoScatter ni encima de una marca.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local Assembler = require("./Assembler")
local Markers = require("./Markers")

local Scatter = {}

export type Options = {
	prefabs: { string } | { [string]: number },
	zone: BasePart,
	parent: Instance,
	density: number,
	scale: { number }?,
	seed: number?,
	gap: number?,
}

function Scatter.run(options: Options): string
	local source = ServerStorage:FindFirstChild("Prefabs")
	if not source then
		return "Scatter: no hay ServerStorage.Prefabs"
	end
	local weights: { { model: Model, weight: number } } = {}
	local total = 0
	for k, v in options.prefabs :: any do
		local name = if typeof(k) == "number" then v else k
		local weight = if typeof(k) == "number" then 1 else v
		local model = source:FindFirstChild(name)
		if not model or not model:IsA("Model") then
			return `Scatter: "{name}" no es un Model en ServerStorage.Prefabs`
		end
		table.insert(weights, { model = model, weight = weight })
		total += weight
	end
	local seed = options.seed or 1
	local rng = Assembler.random(seed)
	local zone = options.zone
	local count = math.floor(zone.Size.X * zone.Size.Z / 100 * options.density)
	local folder = Instance.new("Folder")
	folder.Name = `Scatter_{seed}`

	local avoid = CollectionService:GetTagged("NoScatter")
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { zone, folder }
	local placed: { Vector3 } = {}
	local gap = options.gap or 4
	local scaleRange = options.scale or { 1, 1 }
	local made, tries = 0, 0
	while made < count and tries < count * 6 do
		tries += 1
		local local_ = Vector3.new((rng() - 0.5) * zone.Size.X, zone.Size.Y / 2, (rng() - 0.5) * zone.Size.Z)
		local top = zone.CFrame:PointToWorldSpace(local_)
		local hit = workspace:Raycast(top, Vector3.new(0, -zone.Size.Y - 50, 0), params)
		if not hit then
			continue
		end
		local blocked = false
		for _, a in avoid do
			if a:IsA("BasePart") and Markers.inside(a, hit.Position) then
				blocked = true
				break
			end
		end
		for _, p in placed do
			if (p - hit.Position).Magnitude < gap then
				blocked = true
				break
			end
		end
		if blocked then
			continue
		end
		local pick = rng() * total
		local chosen = weights[#weights].model
		for _, w in weights do
			pick -= w.weight
			if pick < 0 then
				chosen = w.model
				break
			end
		end
		local copy = chosen:Clone()
		copy:ScaleTo(scaleRange[1] + rng() * (scaleRange[2] - scaleRange[1]))
		local _, size = copy:GetBoundingBox()
		local yaw = rng() * math.pi * 2
		copy:PivotTo(CFrame.new(hit.Position + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, yaw, 0))
		copy.Parent = folder
		table.insert(placed, hit.Position)
		made += 1
		if made % 200 == 0 then
			-- A trozos: no congela Studio.
			task.wait()
		end
	end
	folder.Parent = options.parent
	return `Scatter: {made} copias en {folder:GetFullName()} (semilla {seed})`
end

return Scatter
