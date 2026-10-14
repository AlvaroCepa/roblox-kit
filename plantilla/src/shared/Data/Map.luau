--!strict
-- Ficha del mapa: la leen el juego (Markers avisa de lo que falte), comprobar (mitad sin Studio, sobre
-- map/*.rbxm) y el comprobador del mapa en Studio (Kit/MapCheck). Solo datos, sin Roblox.
-- Cómo se rellena: skill de mapa del plugin. Cada número de movimiento dice de dónde sale.

return {
	-- Tipo de mapa: "fixed" (hecho en Studio), "assembled" (piezas que se juntan al jugar) o "mixed".
	kind = "fixed",

	-- Trozos: un .rbxm por trozo. fixed -> map/fixed/<name>.rbxm -> Workspace.Map.<name>;
	-- piece -> map/pieces/<name>.rbxm -> ServerStorage.MapPieces.<name>. Los prefabs (piezas que se
	-- repiten y se reparten con Kit/Scatter) van en map/prefabs/ -> ServerStorage.Prefabs.
	chunks = {
		-- { name = "Lobby", kind = "fixed" },
	},

	-- Marcas (partes invisibles con etiqueta de CollectionService) que necesita el juego.
	-- count = exactas, min = como mínimo. reach = hay que poder llegar andando o saltando desde Spawn.
	marks = {
		Spawn = { count = 1 },
		-- SafeZone = { count = 1, reach = true },
		-- Nest = { min = 5, reach = true, attributes = { "Biome" } },
	},

	-- Movimiento del jugador (de dónde sale cada número).
	movement = {
		mode = "walk", -- walk | swim | fly
		walkSpeed = 16, -- Humanoid.WalkSpeed por defecto
		jumpHeight = 7.2, -- Humanoid.JumpHeight por defecto
		gravity = 196.2, -- Workspace.Gravity por defecto
		stepHeight = 2, -- lo que sube andando sin saltar (aprox. HipHeight)
		maxSlope = 89, -- Humanoid.MaxSlopeAngle por defecto
		maxFall = nil :: number?, -- caída más alta permitida (nil = sin límite)
	},

	-- Comprobaciones del mapa en Studio que se encienden y sus datos.
	checks = {
		floating = true, -- piezas que flotan (las flotantes a propósito llevan la etiqueta Floating)
		reach = true, -- de Spawn a cada marca con reach, sin zonas fuera (OutOfBounds) ni hoyos sin salida
		overlap = true, -- piezas repetidas o caras que coinciden y parpadean
		triangles = true, -- mallas por encima del límite
		-- Distancias entre marcas en serie (ordenadas por su atributo Order).
		series = {
			-- { tag = "Ring", min = 10, max = 40 },
		},
		-- Líneas de visión entre dos marcas (por etiqueta): open = true debe verse; false, tapada.
		sightlines = {
			-- { from = "Spawn", to = "Shop", open = true },
		},
	},

	-- Límites de rendimiento (los del plugin, salvo que se cambien aquí).
	limits = {
		parts = 3000, -- piezas en todo el Workspace
		meshTriangles = 10000, -- triángulos por malla del mapa
		lights = 4, -- luces (con Shadows apagado)
		particles = 20, -- emisores de partículas en el mapa
		sounds = 10, -- sonidos dentro del mapa
	},

	-- Desde dónde se hacen siempre las capturas de cada trozo: marcas con la etiqueta CameraPoint y el
	-- atributo Chunk = nombre del trozo. Aquí no hace falta nada más.
}
