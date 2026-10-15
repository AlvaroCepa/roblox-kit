--!strict
-- roblox-kit MapCheck v2
-- Copia del original del plugin (kit/juego/). No se edita en el juego: se actualiza desde el plugin.
--
-- Mitad «en Studio» del comprobador del mapa (la otra mitad va en comprobar, sobre los .rbxm). Se lanza en
-- modo EDICIÓN (sin Play) con execute_luau:
--   return require(game.ReplicatedStorage.Shared.Kit.MapCheck).run()
-- Usa la ficha (Data/Map) y rayos sobre Workspace.Map. Comprueba:
--   marcas, piezas flotando, sitios de pie, alcance desde Spawn (andando y saltando), zonas fuera
--   (OutOfBounds), hoyos sin salida, caídas demasiado altas, piezas repetidas o caras que parpadean,
--   distancias en serie, líneas de visión y triángulos de las mallas.
-- Cómo mide el alcance: rayos hacia abajo cada `grid` studs dan los sitios donde se puede estar de pie; dos
-- sitios se unen si se pasa andando (escalón) o saltando (alcance con la velocidad, el salto y la gravedad).
-- Si algo falla, deja marcas rojas en Workspace.KitMapCheck: .topView() pone la cámara encima para la
-- captura y .clear() las quita. Si todo va bien, la línea empieza por "roblox-kit comprobar-mapa: bien"
-- (el hook del plugin apunta la pasada buena).
-- Modo swim/fly: no hay saltos ni caídas; solo marcas, flotantes, solapes, series, visión y triángulos.

local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")

local Map = require("../Data/Map")
local Markers = require("./Markers")

local MapCheck = {}

local FOLDER = "KitMapCheck"
local MAX_COLUMNS = 160000 -- si el mapa es enorme, la rejilla se hace más gruesa

type Cell = { x: number, z: number, y: number, part: BasePart }

local function mapRoot(): Instance?
	return workspace:FindFirstChild("Map")
end

local function solidParts(root: Instance): { BasePart }
	local list = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide and d.Transparency < 1 then
			table.insert(list, d)
		end
	end
	return list
end

-- Caja de todo el mapa. Workspace.Map es una carpeta (Rojo la crea desde map/fixed), y las carpetas no tienen
-- GetBoundingBox: se calcula con las partes.
local function bounds(root: Instance): (CFrame, Vector3)
	local low = Vector3.one * math.huge
	local high = -Vector3.one * math.huge
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			local half = d.Size / 2
			for x = -1, 1, 2 do
				for y = -1, 1, 2 do
					for z = -1, 1, 2 do
						local w = d.CFrame:PointToWorldSpace(half * Vector3.new(x, y, z))
						low = low:Min(w)
						high = high:Max(w)
					end
				end
			end
		end
	end
	if low.X == math.huge then
		return CFrame.new(), Vector3.zero
	end
	return CFrame.new((low + high) / 2), high - low
end

local function markersFolder(): Folder
	local old = workspace:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = FOLDER
	f.Parent = workspace
	return f
end

local function flag(folder: Folder, position: Vector3, text: string)
	local p = Instance.new("Part")
	p.Name = text
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.new(1, 0, 0)
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(3, 3, 3)
	p.Position = position
	p.Parent = folder
end

local function vec(v: Vector3): string
	return string.format("(%d, %d, %d)", v.X, v.Y, v.Z)
end

local function key(ix: number, iz: number): number
	return ix * 100003 + iz
end

-- Rejilla de sitios de pie: por cada columna, todos los suelos (hasta 4 pisos) con hueco para la cabeza.
local function standable(parts: { BasePart }, box: { min: Vector3, max: Vector3 }, grid: number, maxSlope: number)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = (parts :: any) :: { Instance }
	local cells: { Cell } = {}
	local byColumn: { [number]: { number } } = {}
	local cosSlope = math.cos(math.rad(maxSlope))
	local top = box.max.Y + 10
	local count = 0
	for x = box.min.X, box.max.X, grid do
		for z = box.min.Z, box.max.Z, grid do
			local from = Vector3.new(x, top, z)
			for _ = 1, 4 do
				local hit = workspace:Raycast(from, Vector3.new(0, -(from.Y - box.min.Y + 5), 0), params)
				if not hit then
					break
				end
				local head = workspace:Raycast(hit.Position + Vector3.new(0, 0.1, 0), Vector3.new(0, 5, 0), params)
				if hit.Normal.Y >= cosSlope and not head then
					table.insert(cells, { x = x, z = z, y = hit.Position.Y, part = hit.Instance :: BasePart })
					local k = key(math.round(x / grid), math.round(z / grid))
					byColumn[k] = byColumn[k] or {}
					table.insert(byColumn[k], #cells)
				end
				from = hit.Position - Vector3.new(0, 0.2, 0)
			end
			count += 1
			if count % 4000 == 0 then
				task.wait()
			end
		end
	end
	return cells, byColumn
end

-- Vecinos de una celda a los que se llega andando o saltando (o cayendo).
local function neighbours(
	cells: { Cell },
	byColumn: { [number]: { number } },
	index: number,
	grid: number,
	movement: any,
	reach: number
): { number }
	local c = cells[index]
	local out = {}
	local g = movement.gravity
	local v0 = math.sqrt(2 * g * movement.jumpHeight)
	local cx, cz = math.round(c.x / grid), math.round(c.z / grid)
	local r = math.ceil(reach / grid)
	for dx = -r, r do
		for dz = -r, r do
			local list = byColumn[key(cx + dx, cz + dz)]
			if not list then
				continue
			end
			local dist = math.sqrt(dx * dx + dz * dz) * grid
			for _, j in list do
				if j == index then
					continue
				end
				local dy = cells[j].y - c.y
				local ok = false
				if dist <= grid * 1.5 and dy <= movement.stepHeight then
					ok = true -- andando (o bajando un escalón o cayendo al lado)
				elseif dy <= movement.jumpHeight then
					-- Tiempo en el aire hasta caer a la altura dy (subiendo o bajando) y lo que se avanza.
					local disc = v0 * v0 - 2 * g * dy
					if disc >= 0 then
						local t = (v0 + math.sqrt(disc)) / g
						ok = dist <= movement.walkSpeed * t
					end
				end
				if ok then
					table.insert(out, j)
				end
			end
		end
	end
	return out
end

local function bfs(start: { number }, edges: (number) -> { number }): { [number]: boolean }
	local seen: { [number]: boolean } = {}
	local queue = table.clone(start)
	for _, s in start do
		seen[s] = true
	end
	local head = 1
	while head <= #queue do
		local i = queue[head]
		head += 1
		for _, j in edges(i) do
			if not seen[j] then
				seen[j] = true
				table.insert(queue, j)
			end
		end
		if head % 5000 == 0 then
			task.wait()
		end
	end
	return seen
end

local function nearestCells(cells: { Cell }, position: Vector3, radius: number): { number }
	local list = {}
	for i, c in cells do
		if
			math.abs(c.x - position.X) <= radius
			and math.abs(c.z - position.Z) <= radius
			and math.abs(c.y - position.Y) <= 8
		then
			table.insert(list, i)
		end
	end
	return list
end

local function triangles(meshId: string): number?
	local ok, mesh = pcall(function()
		return AssetService:CreateEditableMeshAsync(Content.fromUri(meshId))
	end)
	if not ok or not mesh then
		return nil
	end
	local editable: any = mesh
	local n = #editable:GetFaces()
	editable:Destroy()
	return n
end

function MapCheck.run(): string
	local root = mapRoot()
	if not root then
		return "roblox-kit comprobar-mapa: falla (no hay Workspace.Map)"
	end
	local folder = markersFolder()
	local problems: { string } = {}
	local notes: { string } = {}
	local function bad(text: string, at: Vector3?)
		table.insert(problems, if at then `{text} en {vec(at)}` else text)
		if at then
			flag(folder, at, text)
		end
	end

	local checks = Map.checks :: any
	local movement = Map.movement :: any
	local limits = Map.limits :: any

	-- Marcas de la ficha.
	for _, problem in Markers.check() do
		bad("marcas: " .. problem)
	end

	local parts = solidParts(root)
	local all = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(all, d)
		end
	end
	if #all > limits.parts then
		bad(`{#all} piezas en el mapa (límite {limits.parts})`)
	end

	-- 1. Piezas flotando (las que flotan a propósito llevan la etiqueta Floating).
	if checks.floating then
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		local floating = 0
		for i, p in all do
			if p:HasTag("Floating") or p.Transparency >= 1 or not p.Anchored then
				continue
			end
			overlap.FilterDescendantsInstances = { p, folder }
			local touching = workspace:GetPartBoundsInBox(p.CFrame, p.Size + Vector3.new(0.2, 0.2, 0.2), overlap)
			local grounded = #touching > 0
			if not grounded then
				-- Tocando el terreno también cuenta.
				local hit = workspace:Raycast(p.Position, Vector3.new(0, -(p.Size.Y / 2 + 0.3), 0))
				grounded = hit ~= nil
			end
			if not grounded then
				floating += 1
				if floating <= 10 then
					bad(`pieza flotando: {p:GetFullName()}`, p.Position)
				end
			end
			if i % 500 == 0 then
				task.wait()
			end
		end
		if floating > 10 then
			bad(`... y {floating - 10} piezas flotando más`)
		end
	end

	-- 7. Piezas repetidas (misma caja) y caras de arriba que coinciden (parpadean).
	if checks.overlap then
		local seen: { [string]: BasePart } = {}
		local tops: { [string]: { BasePart } } = {}
		for _, p in parts do
			local k = `{vec(p.Position)}|{vec(p.Size * 10)}`
			local other = seen[k]
			if other and other.CFrame:FuzzyEq(p.CFrame, 0.05) then
				bad(`pieza repetida: {p:GetFullName()} y {other:GetFullName()}`, p.Position)
			end
			seen[k] = p
			if p:IsA("Part") and p.Shape == Enum.PartType.Block and p.CFrame.UpVector.Y > 0.999 then
				local topY = string.format("%.2f", p.Position.Y + p.Size.Y / 2)
				tops[topY] = tops[topY] or {}
				table.insert(tops[topY], p)
			end
		end
		for _, list in tops do
			for i = 1, math.min(#list, 200) do
				for j = i + 1, math.min(#list, 200) do
					local a, b = list[i], list[j]
					local ax, az = a.Size.X / 2, a.Size.Z / 2
					local bx, bz = b.Size.X / 2, b.Size.Z / 2
					local w = math.min(a.Position.X + ax, b.Position.X + bx)
						- math.max(a.Position.X - ax, b.Position.X - bx)
					local d = math.min(a.Position.Z + az, b.Position.Z + bz)
						- math.max(a.Position.Z - az, b.Position.Z - bz)
					if w > 0.5 and d > 0.5 and a.Color ~= b.Color then
						bad(`caras que parpadean: {a.Name} y {b.Name}`, (a.Position + b.Position) / 2)
					end
				end
			end
		end
	end

	-- 8. Distancias en serie.
	for _, serie in checks.series or {} do
		local list = Markers.all(serie.tag)
		table.sort(list, function(a, b)
			return (a:GetAttribute("Order") or 0) < (b:GetAttribute("Order") or 0)
		end)
		for i = 2, #list do
			local d = (list[i].Position - list[i - 1].Position).Magnitude
			if d < serie.min or d > serie.max then
				bad(
					`{serie.tag} {i - 1}->{i} a {math.floor(d)} studs (entre {serie.min} y {serie.max})`,
					list[i].Position
				)
			end
		end
	end

	-- 6. Líneas de visión.
	local sightParams = RaycastParams.new()
	sightParams.FilterType = Enum.RaycastFilterType.Include
	sightParams.FilterDescendantsInstances = (parts :: any) :: { Instance }
	for _, line in checks.sightlines or {} do
		local a, b = Markers.one(line.from), Markers.one(line.to)
		if a and b then
			local hit = workspace:Raycast(a.Position, b.Position - a.Position, sightParams)
			local open = hit == nil
			if open ~= line.open then
				bad(
					`visión {line.from}->{line.to}: {if open
						then "se ve y debería estar tapada"
						else "tapada y debería verse"}`,
					a.Position
				)
			end
		end
	end

	-- 11. Triángulos de cada malla (una vez por malla).
	if checks.triangles then
		local done: { [string]: boolean } = {}
		for _, p in all do
			if p:IsA("MeshPart") and p.MeshId ~= "" and not done[p.MeshId] then
				done[p.MeshId] = true
				local n = triangles(p.MeshId)
				if n and n > limits.meshTriangles then
					bad(`malla de {n} triángulos (límite {limits.meshTriangles}): {p:GetFullName()}`, p.Position)
				end
			end
		end
	end

	-- 2, 3, 4, 5, 9, 10. Sitios de pie y alcance (solo andando).
	if checks.reach and movement.mode == "walk" and #parts > 0 then
		local cf, size = bounds(root)
		local box = { min = cf.Position - size / 2, max = cf.Position + size / 2 }
		local area = size.X * size.Z
		local grid = math.max(2, math.sqrt(area / MAX_COLUMNS))
		local cells, byColumn = standable(parts, box, grid, movement.maxSlope)
		local v0 = math.sqrt(2 * movement.gravity * movement.jumpHeight)
		local reach = movement.walkSpeed * (2 * v0 / movement.gravity) + grid
		local cache: { [number]: { number } } = {}
		local function edges(i: number): { number }
			local found = cache[i]
			if not found then
				found = neighbours(cells, byColumn, i, grid, movement, reach)
				cache[i] = found
			end
			return found
		end
		local spawn = Markers.one("Spawn")
		if not spawn then
			bad("alcance: no hay marca Spawn")
		elseif #cells == 0 then
			bad("alcance: no hay ningún sitio donde estar de pie en Workspace.Map")
		else
			local start = nearestCells(cells, spawn.Position, grid * 2)
			if #start == 0 then
				bad("alcance: Spawn no está sobre un suelo donde se pueda estar de pie", spawn.Position)
			else
				local reached = bfs(start, edges)
				local total = 0
				for _ in reached do
					total += 1
				end
				table.insert(
					notes,
					`{total}/{#cells} sitios de pie alcanzables (rejilla de {math.floor(grid * 10) / 10} studs)`
				)
				-- 10. Cada marca con reach.
				for tag, rule in Map.marks :: any do
					if rule.reach then
						for _, m in Markers.all(tag) do
							local ok = false
							for _, i in nearestCells(cells, m.Position, math.max(4, grid * 2)) do
								if reached[i] then
									ok = true
									break
								end
							end
							if not ok then
								bad(`no se llega desde Spawn a la marca {tag}`, m.Position)
							end
						end
					end
				end
				-- 4. Zonas que no se deberían alcanzar.
				for _, zone in Markers.all("OutOfBounds") do
					for i in reached do
						local c = cells[i]
						if Markers.inside(zone, Vector3.new(c.x, c.y + 1, c.z)) then
							bad("se llega a una zona OutOfBounds", Vector3.new(c.x, c.y, c.z))
							break
						end
					end
				end
				-- 5. Hoyos sin salida: sitios alcanzables desde los que no se vuelve a Spawn.
				local back: { [number]: { number } } = {}
				for i in reached do
					for _, j in edges(i) do
						back[j] = back[j] or {}
						table.insert(back[j], i)
					end
				end
				local returns = bfs(start, function(i)
					return back[i] or {}
				end)
				local stuck = 0
				for i in reached do
					if not returns[i] then
						stuck += 1
						if stuck <= 5 then
							local c = cells[i]
							bad("hoyo sin salida (se cae y no se vuelve)", Vector3.new(c.x, c.y, c.z))
						end
					end
				end
				-- 9. Caídas demasiado altas.
				if movement.maxFall then
					local falls = 0
					for i in reached do
						for _, j in edges(i) do
							if cells[i].y - cells[j].y > movement.maxFall then
								falls += 1
								if falls <= 5 then
									local c = cells[i]
									bad(`caída de más de {movement.maxFall} studs`, Vector3.new(c.x, c.y, c.z))
								end
								break
							end
						end
					end
				end
				-- 3. Zonas altas a las que no se llega (solo aviso: puede ser decoración).
				local unreachable = #cells - total
				if unreachable > 0 then
					table.insert(notes, `{unreachable} sitios de pie no alcanzables (tejados, decoración...)`)
				end
			end
		end
	end

	if #problems == 0 then
		folder:Destroy()
		local extra = if #notes > 0 then "; " .. table.concat(notes, "; ") else ""
		return `roblox-kit comprobar-mapa: bien ({#all} piezas{extra})`
	end
	local shown = {}
	for i = 1, math.min(25, #problems) do
		table.insert(shown, problems[i])
	end
	if #problems > 25 then
		table.insert(shown, `... y {#problems - 25} más`)
	end
	for _, n in notes do
		table.insert(shown, "nota: " .. n)
	end
	return `roblox-kit comprobar-mapa: falla ({#problems} problema(s); marcas rojas en Workspace.{FOLDER})\n`
		.. table.concat(shown, "\n")
end

-- Cámara encima del mapa, mirando abajo, para la captura con las marcas rojas.
function MapCheck.topView(): string
	local root = mapRoot()
	if not root then
		return "no hay Workspace.Map"
	end
	local cf, size = bounds(root)
	local height = math.max(size.X, size.Z) * 0.9 + size.Y
	local camera = workspace.CurrentCamera
	camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, height, 0.01), cf.Position)
	return "cámara encima del mapa"
end

-- Cámara en una marca CameraPoint (por su atributo Chunk), para las capturas fijas de cada trozo.
function MapCheck.cameraAt(chunk: string): string
	for _, point in CollectionService:GetTagged("CameraPoint") do
		if point:IsA("BasePart") and point:GetAttribute("Chunk") == chunk then
			workspace.CurrentCamera.CFrame = point.CFrame
			return `cámara en el punto de {chunk}`
		end
	end
	return `no hay CameraPoint con Chunk = {chunk}`
end

function MapCheck.clear()
	local old = workspace:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
end

return MapCheck
