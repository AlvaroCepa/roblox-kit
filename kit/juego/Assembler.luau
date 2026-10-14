--!strict
-- roblox-kit Assembler v1
-- Copia del original del plugin (kit/juego/). No se edita en el juego: se actualiza desde el plugin.
--
-- Mapas que se montan al jugar: junta copias de piezas hechas a mano (ServerStorage.MapPieces). Nunca crea
-- ni borra nada hecho a mano: solo coloca copias.
-- - Cada pieza lleva enganches: Attachment con la etiqueta Connector y los atributos Kind ("door",
--   "tunnel"...) y Role ("in" o "out"). Solo encajan enganches del mismo Kind.
-- - La elección es lógica pura con semilla (Assembler.order, Assembler.random): una partida se puede
--   repetir con la misma semilla para buscar un fallo, y se prueba con Lune.
-- - Si una pieza se mete en otra ya colocada (cajas que chocan), se prueba la siguiente candidata.

local Assembler = {}

-- Números al azar con semilla, en Luau puro (igual en Roblox y en Lune). Devuelve números en [0, 1).
function Assembler.random(seed: number): () -> number
	local state = math.floor(seed) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function(): number
		state = (state * 48271) % 2147483647
		return (state - 1) / 2147483646
	end
end

export type PieceRule = {
	name: string,
	weight: number,
	minDepth: number?,
	maxDepth: number?,
}

-- Candidatas para el paso `depth`, en orden de preferencia: al azar según su peso, sin repetir la pieza
-- anterior y solo las permitidas a esa profundidad. Lógica pura.
function Assembler.order(rules: { PieceRule }, rng: () -> number, depth: number, previous: string?): { string }
	local pool = {}
	for _, rule in rules do
		local allowed = rule.weight > 0
			and rule.name ~= previous
			and (rule.minDepth == nil or depth >= rule.minDepth)
			and (rule.maxDepth == nil or depth <= rule.maxDepth)
		if allowed then
			table.insert(pool, rule)
		end
	end
	local ordered = {}
	while #pool > 0 do
		local total = 0
		for _, rule in pool do
			total += rule.weight
		end
		local pick = rng() * total
		local index = #pool
		for i, rule in pool do
			pick -= rule.weight
			if pick < 0 then
				index = i
				break
			end
		end
		table.insert(ordered, pool[index].name)
		table.remove(pool, index)
	end
	return ordered
end

local function connectors(model: Instance, role: string): { Attachment }
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Attachment") and d:HasTag("Connector") and d:GetAttribute("Role") == role then
			table.insert(list, d)
		end
	end
	return list
end

type Box = { cframe: CFrame, size: Vector3 }

local function overlaps(a: Box, b: Box): boolean
	-- Cajas alineadas con los ejes del mundo (aproximación: basta para descartar choques claros).
	local amin, amax = a.cframe.Position - a.size / 2, a.cframe.Position + a.size / 2
	local bmin, bmax = b.cframe.Position - b.size / 2, b.cframe.Position + b.size / 2
	local margin = 0.5
	return amin.X < bmax.X - margin
		and amax.X > bmin.X + margin
		and amin.Y < bmax.Y - margin
		and amax.Y > bmin.Y + margin
		and amin.Z < bmax.Z - margin
		and amax.Z > bmin.Z + margin
end

export type Options = {
	pieces: Instance, -- carpeta con los modelos (ServerStorage.MapPieces)
	rules: { PieceRule },
	count: number,
	seed: number,
	parent: Instance,
	start: CFrame, -- dónde va el enganche "in" de la primera pieza
}

-- Monta la secuencia y devuelve los nombres colocados (en orden).
function Assembler.build(options: Options): { string }
	local rng = Assembler.random(options.seed)
	local placed: { Box } = {}
	local names: { string } = {}
	local anchor = options.start
	local kind: any = nil
	for depth = 1, options.count do
		local done = false
		for _, name in Assembler.order(options.rules, rng, depth, names[#names]) do
			local source = options.pieces:FindFirstChild(name)
			if not source or not source:IsA("Model") then
				warn(`Assembler: piece "{name}" is not a Model in {options.pieces:GetFullName()}`)
				continue
			end
			local entries = connectors(source, "in")
			local entry: Attachment? = nil
			for _, c in entries do
				if kind == nil or c:GetAttribute("Kind") == kind then
					entry = c
					break
				end
			end
			if not entry then
				continue
			end
			local copy = source:Clone()
			local copyEntry = copy:FindFirstChild(entry.Name, true) :: Attachment
			-- La entrada de la copia mira al revés que la salida anterior: giro de 180° sobre Y.
			local target = anchor * CFrame.Angles(0, math.pi, 0)
			copy:PivotTo(target * copyEntry.WorldCFrame:ToObjectSpace(copy:GetPivot()))
			local cf, size = copy:GetBoundingBox()
			local box = { cframe = cf, size = size }
			local clash = false
			for i = 1, #placed - 1 do -- la anterior se toca a propósito
				if overlaps(box, placed[i]) then
					clash = true
					break
				end
			end
			local exits = connectors(copy, "out")
			if clash or #exits == 0 and depth < options.count then
				copy:Destroy()
				continue
			end
			copy.Name = `{depth}_{name}`
			copy.Parent = options.parent
			table.insert(placed, box)
			table.insert(names, name)
			if exits[1] then
				anchor = exits[1].WorldCFrame
				kind = exits[1]:GetAttribute("Kind")
			end
			done = true
			break
		end
		if not done then
			warn(`Assembler: no piece fits at step {depth} (seed {options.seed}); stopping`)
			break
		end
	end
	return names
end

return Assembler
