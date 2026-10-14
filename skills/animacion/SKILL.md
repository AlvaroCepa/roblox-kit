---
name: animacion
description: Cómo se anima en los juegos de Roblox con roblox-kit (casi todo con código con Kit/Motion: flotar, botar, girar, temblar, aparecer; personajes con las animaciones de Roblox, packs gratis o Mixamo adaptados en Blender; R6 hecho por Claude solo para lo importante y preguntando antes; animaciones como datos lanzadas con Kit/Animations en el cliente). Úsala SIEMPRE que algo tenga que moverse o animarse (mascotas, huevos, monedas, puertas, personajes, emotes, golpes), aunque no se diga «animación».
---

# Animación

## 1. Casi todo, con código
Mascotas que flotan o botan, huevos que tiemblan y se abren, puertas, monedas que giran: **con código**, sin
archivos de animación ni subidas. Los modelos 3D se animan moviendo el modelo entero; **no se les ponen huesos**
salvo que de verdad haga falta.
- `Motion.bob(pet)`, `Motion.spin(coin)`, `Motion.shake(egg, 0.6, "epic")`, `Motion.pop(model)`. Cada uno
  devuelve una función para pararlo. Todo va en **un solo bucle** del kit (nunca un bucle por objeto).
- Velocidad, rebote y **tres niveles** (small, normal, epic) en `Data/Style.luau` (`animation`).
- Si hace falta un movimiento nuevo de este tipo, se añade al juego con la misma forma (o se propone para el kit).

## 2. Personajes
1. **Andar, saltar, moverse:** las de Roblox que ya vienen.
2. **Acciones especiales:** primero packs gratis o **Mixamo** (gratis, uso comercial). Claude las adapta al cuerpo
   de Roblox en Blender (skill `modelos-3d`, lecciones de Blender).
3. **Si nada encaja, Claude la anima en R6:** poses clave como datos, Blender o Studio rellenan el movimiento y
   Claude revisa una hoja de fotogramas. Va bien en acciones cortas y claras (saludar, celebrar, golpear, coger);
   cuesta más el «peso» y lo largo. **Solo para animaciones importantes y preguntando a Álvaro antes.**
   (Prueba pendiente: un «celebrar» en R6 para ver si el nivel vale.)
- Se suben **al grupo** (`assets/anims/<nombre>.rbxm` + `kit/subir-assets.ps1`, que pregunta): Roblox solo
  reproduce animaciones del dueño del juego.
- `src/shared/Data/Animations.luau`: asset por nombre, prioridad, velocidad, bucle y fundido.
  En el cliente: `Animations.play(humanoid, "Wave")` / `Animations.stop(humanoid, "Wave")`.

## 3. Revisión
- Claude no ve el movimiento: saca capturas del **principio, la mitad y el final** (modo edición; para Motion,
  `execute_luau` que lo arranca, espera y para, con `screen_capture` en cada momento) y lo reintenta **como mucho
  3 veces**.
- **Si se siente bien lo juzga siempre Álvaro, en Play.**
