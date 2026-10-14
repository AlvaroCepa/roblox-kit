---
name: vfx
description: Cómo se hacen los efectos visuales de los juegos de Roblox con roblox-kit (efectos como datos hechos de piezas de packs gratis de la Toolbox, lanzados con una línea con Kit/Effects en el cliente, niveles pequeño/normal/épico, menos partículas en móvil, revisión con capturas congeladas). Úsala SIEMPRE que haya que crear, cambiar o revisar partículas, destellos, chispas, humo, explosiones, estelas, auras o cualquier efecto visual, aunque no se diga «VFX».
---

# Efectos visuales

**Nunca de cero.** Los efectos se hacen combinando **piezas** (chispas, humo, destellos, estelas, rayos...) sacadas
de **packs gratis de la Toolbox**, guardadas como datos. Nano Banana solo muy de vez en cuando, para una textura
que no tenga ningún pack (sobre fondo negro, subida al grupo como los iconos).

## Primero, la biblioteca (pendiente)
Álvaro pidió que, **al empezar con VFX por primera vez**, Claude investigue a fondo los **mejores packs gratuitos**
de VFX de la Toolbox y preseleccione unos cuantos (licencia, estilo, cuántas piezas útiles, scripts dentro).
De ahí sale la biblioteca de piezas: `biblioteca/` de esta skill (una pieza = textura + propiedades, ver abajo).
Hasta entonces la biblioteca está vacía: díselo a Álvaro y empieza por eso antes del primer efecto.
- Todo lo que se inserta de la Toolbox pasa la revisión de scripts (el hook lo recuerda tras `insert_asset`).
- Las texturas de las piezas se copian a `assets/vfx/` del juego y se suben con `kit/subir-assets.ps1`.

## Cómo se usa en el juego
- `src/shared/Data/Effects.luau`: cada efecto es una lista de piezas. Pieza = `texture` (nombre en Assets,
  `"vfx/sparkle"`), `count` (partículas de golpe en nivel normal), `color` (de la paleta) y `properties` (las del
  ParticleEmitter que cambian: Lifetime, Speed, Size, SpreadAngle, LightEmission...).
- Se lanza con UNA línea, **siempre en el cliente** (el servidor solo avisa por Zap):
  `Effects.play("Purchase", part)` o `Effects.play("LegendaryHatch", position, "epic")`.
- Estilo en `Data/Style.luau` (`vfx`): cartoon o realista, tamaño, **tres niveles** (small, normal, epic) y el
  factor de móvil (en móvil se emiten menos partículas solas).

## Reglas (con su porqué)
1. **Emitir de golpe** (`Rate = 0` y `:Emit(n)`, lo hace el kit), nada de emisores encendidos siempre en enemigos o
   disparos: con muchos a la vez el móvil se arrastra.
2. **Vida corta** (≤ 1,5 s) y texturas pequeñas (≤ 256 px). Tope de partículas por efecto en `Style.vfx.maxParticles`:
   `comprobar` lo mira en nivel épico.
3. **Texturas por nombre** (`Asset.get`), nunca ids sueltos.
4. Un efecto de compra y uno de huevo legendario tienen que parecer **del mismo juego**: mismas piezas y paleta,
   distinta fuerza (nivel).

## Revisión
1. `node <kit>/kit/captura.js vfx <Efecto> [small|normal|epic]` (modo edición): lo congela al principio, a la
   mitad y al final y lo junta en una imagen. Míralo con Read.
2. Si algo falla (se sale de la paleta, demasiado grande, no se ve), corrígelo tú: **hasta 3 veces**. Después,
   enséñale a Álvaro lo que no sale.
3. **Si queda bien en el juego lo juzga siempre Álvaro**, en Play.
