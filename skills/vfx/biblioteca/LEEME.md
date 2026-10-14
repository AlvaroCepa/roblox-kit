# Biblioteca de piezas de VFX

Vacía hasta la investigación de packs (la primera vez que se trabaje en VFX). Una pieza por archivo
`<pieza>.luau`, que devuelve una pieza lista para `Data/Effects.luau` del juego, más su textura:

```lua
-- Chispas cartoon (pack «...», autor, licencia, id de la Toolbox).
return {
	texture = "vfx/sparkle", -- la textura (sparkle.png, junto a este archivo) se copia a assets/vfx/ del juego
	count = 12,
	properties = {
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(6, 10),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(0.6, 0),
		LightEmission = 0.6,
	},
}
```
Clasificadas por tipo en el nombre: `chispas-*`, `humo-*`, `destello-*`, `estela-*`, `rayo-*`, `anillo-*`...
