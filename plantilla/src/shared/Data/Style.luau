--!strict
-- Hoja de estilo del juego: UI, efectos, sonido y animación. Todo lo que se ve o se oye sale de aquí.
-- TEMPORAL: valores sacados a ojo de la UI de Steal a Brainrot (decidido el 13/10/2026). Se cambia cuando
-- Álvaro elija las 3-5 capturas de referencia del juego (skill de UI del plugin).
--
-- Solo datos, sin Roblox: los colores en hex y la fuente por nombre. Así la leen igual el juego y los scripts
-- del plugin (el generador de botones y paneles, comprobar). Tras cambiar `ui.body`, se regeneran las
-- imágenes con kit/ui-generar.luau.

return {
	-- Paleta (5-6 colores). Los botones son blancos y se tiñen con estos.
	palette = {
		green = "#3CD34B",
		red = "#F2434B",
		yellow = "#FFCB2E",
		blue = "#3AA7FF",
		purple = "#A45BFF",
		dark = "#14142B",
		light = "#FFFFFF",
		panel = "#2E3266",
	},

	-- Fuente de todo el juego (nombre de Enum.Font).
	font = "FredokaOne",

	ui = {
		-- El ÚNICO grosor de contorno, en fracción del lado corto del elemento (UIStroke en ScaledSize).
		-- Grosores distintos delatan a la IA.
		stroke = 0.07,
		strokeColor = "dark",
		-- Contorno del texto, en fracción de la altura del texto.
		textStroke = 0.12,
		-- Esquinas de lo que se hace nativo, en fracción del lado corto (0.5 = píldora).
		corner = 0.22,

		-- Cuerpo de botones y paneles: imagen blanca en 9-slice generada desde estos números (px de la imagen).
		body = {
			size = 128, -- lado de la imagen
			corner = 30, -- radio de las esquinas
			stroke = 7, -- contorno oscuro (mismo aspecto que `stroke`)
			lip = 10, -- labio 3D de abajo
			shadowOffset = 6, -- sombra desplazada hacia abajo
			shadowColor = "#0B0B33",
			shadowAlpha = 0.45,
			gradientTop = 0.88, -- brillo arriba del degradado (1 = blanco; por debajo de 1 deja ver el brillo)
			gradientBottom = 0.7, -- brillo abajo
			highlight = 0.7, -- opacidad del brillo de arriba
			lipShade = 0.5, -- oscuridad del labio
		},
		-- Qué parte del lado corto del botón ocupa la esquina al dibujarlo (escala el 9-slice con la pantalla).
		bodyCorner = 0.3,

		-- Texto
		maxTextSize = 64,
		minTextSize = 12,
	},

	-- Tiempos y tamaños de las animaciones de la UI (segundos y escalas).
	motion = {
		popIn = 0.28,
		popOut = 0.14,
		press = 0.07,
		pressScale = 0.92,
		hoverScale = 1.06,
		countUp = 0.6,
		toast = 2.5,
	},

	-- Efectos visuales.
	vfx = {
		look = "cartoon", -- cartoon | realistic
		size = 1, -- tamaño respecto al jugador
		tiers = { small = 0.6, normal = 1, epic = 2 },
		mobileFactor = 0.5, -- en móvil, partículas × esto
		maxParticles = 300, -- tope de partículas vivas de un efecto (lo vigila comprobar)
	},

	-- Sonido.
	sound = {
		tone = "cartoon",
		volumes = { music = 0.35, sfx = 0.7, ui = 0.55 },
		tiers = { small = 0.6, normal = 1, epic = 1.3 },
		musicFade = 1.5, -- segundos del fundido entre pistas
		maxSame = 6, -- copias del mismo sonido sonando a la vez
	},

	-- Animación hecha con código (botar, girar, temblar...).
	animation = {
		speed = 1,
		bounce = 0.15,
		tiers = { small = 0.5, normal = 1, epic = 1.8 },
	},
}
