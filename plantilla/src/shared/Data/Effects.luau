--!strict
-- Efectos visuales del juego. Cada uno es una mezcla de piezas de la biblioteca de VFX del plugin
-- (skill de VFX). Se lanzan con Kit/Effects: Effects.play("Collect", part).
-- Una pieza: textura por nombre (Assets), cuántas partículas emite en nivel normal, color de la paleta y
-- las propiedades del ParticleEmitter que cambian. comprobar vigila el tope de partículas (Style.vfx).
return {
	-- Ejemplo (su textura no está subida: assets/vfx/sparkle.png).
	Collect = {
		pieces = {
			{
				texture = "vfx/sparkle",
				count = 12,
				color = "yellow",
				properties = {
					Lifetime = NumberRange.new(0.4, 0.7),
					Speed = NumberRange.new(6, 10),
					SpreadAngle = Vector2.new(180, 180),
					Size = NumberSequence.new(0.6, 0),
					LightEmission = 0.6,
				},
			},
		},
	},
}
