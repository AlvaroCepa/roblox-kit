---
name: mapa
description: Cómo se hace el mapa de un juego de Roblox con roblox-kit (de imágenes de concepto a trozos guardados en el repo con guardar-mapa, marcas leídas con Kit/Markers, prefabs repartidos con Kit/Scatter, mapas montados al jugar con Kit/Assembler, luz y ambiente, comprobador del mapa y capturas al lado del concepto). Úsala SIEMPRE que haya que crear, cambiar, decorar, guardar, revisar o arreglar el mapa, el mundo, un nivel, una zona, un bioma, el lobby, el terreno, la luz o las marcas de un juego, aunque no se diga «mapa».
---

# Mapa

El mapa sale de **imágenes de concepto** y se corrige con texto. Se edita en Studio (a mano o con Claude), pero
**vive en el repo en trozos** (`map/`), así `rojo build`, la CI y «Pruebas» montan el juego entero.

## Dónde está cada cosa (en el juego)
- `src/shared/Data/Map.luau`: la **ficha**: tipo de mapa, trozos, marcas que hacen falta, números de movimiento
  (cada uno con de dónde sale), comprobaciones encendidas y límites. La leen el juego, `comprobar` y `MapCheck`.
- `map/fixed/<Trozo>.rbxm` → `Workspace.Map.<Trozo>`; `map/pieces/` → `ServerStorage.MapPieces` (piezas que se
  juntan al jugar); `map/prefabs/` → `ServerStorage.Prefabs` (piezas que se repiten y se reparten).
- `map/Ambience.project.json`: luz y ambiente (solo lo que cambia respecto a Roblox), legible en git.
- `build.project.json` mete todo eso; `default.project.json` (el de `rojo serve`) **no toca el mapa nunca**: así un
  guardado de Rojo no pisa lo que se hace en Studio.
- Imágenes de concepto: `assets/concept/map/`.
- Kit: `Markers`, `Assembler`, `Scatter`, `MapCheck`. Scripts: `kit/guardar-mapa.js`, `kit/captura.js`, `kit/montar.luau`.

## Reglas (con su porqué)
1. **Nunca un script que rehaga un trozo ya retocado a mano.** `GenerarMapa` (Steal an Egg) borraba lo hecho a
   mano. Los scripts de generar o repartir solo valen para el **primer boceto** de un trozo.
2. **El código encuentra los sitios por marcas** (`Markers.one("Spawn")`, `Markers.all("Nest")`,
   `Markers.at(pos, "Zone")`), nunca por ruta o nombre (`workspace.Map.X`): así el mapa se reorganiza sin romper
   nada. Una marca es una parte invisible, anclada, sin colisión, sin CanTouch ni CanQuery, con su etiqueta de
   CollectionService y sus datos en atributos.
3. **Ningún script dentro del mapa.** Los modelos de la Toolbox pueden traerlos escondidos (`comprobar` lo vigila).
4. **Piezas que se repiten = un prefab + `Scatter`**, no cientos de piezas colocadas una a una (el mapa de Darío
   costó muchísimo por colocar ~2.000 piezas a mano con capturas).
5. **Rendimiento** (límites en la ficha): < 3.000 piezas en todo el Workspace; mallas ≤ 10.000 triángulos; 4 luces
   como mucho y con Shadows apagado (lo que brilla, con neón); todo anclado; la decoración pequeña sin colisión,
   CanTouch, CanQuery ni sombra. Mejor pocas mallas grandes que muchas piezas pequeñas.
6. **Un trozo, una persona a la vez** (son binarios: git no los mezcla). Quién tiene cada trozo va en `Estado.md`.
7. **Gasta pocos tokens:** un trozo cada vez, capturas solo desde los puntos fijos (`CameraPoint`), y guardar
   siempre con `guardar-mapa` (no pasa por el chat).

## Pasos
1. **Concepto:** imágenes con Nano Banana (mismo prompt de estilo): una del mapa entero desde arriba y una o dos
   por trozo a la altura del jugador. **Álvaro elige** y se guardan en `assets/concept/map/`.
2. **Ficha y medidas:** escribe en `Data/Map.luau` los trozos, las marcas y un plano con medidas en studs
   (el jugador mide ~5 studs: úsalo de regla). Álvaro corrige con texto.
3. **Esbozo gris** (opcional): bloques con las medidas y las marcas, para que Álvaro pruebe andando las distancias.
   Si en la práctica no aporta, se salta (y se dice, para quitarlo de esta skill).
4. **Aspecto, trozo a trozo:** prefabs en `ServerStorage.Prefabs` y `Scatter.run{...}` para repartirlos (ver
   `referencias/herramientas.md`); piezas simples con Part, lo orgánico con mallas (skill `modelos-3d`).
5. **Captura al lado del concepto:** `node <kit>/kit/captura.js mapa <Trozo> --ref assets/concept/map/<img>`.
   Mírala con Read antes. **Lo juzga Álvaro** y corrige con texto; se repite hasta que le guste.
6. **Guardar:** `node <kit>/kit/guardar-mapa.js` (todos, o los trozos que digas) con la copia del juego abierta.
7. **Comprobar:** `comprobar` hace la mitad sin Studio (marcas, topes, scripts, anclado). La mitad en Studio:
   execute_luau `return require(game.ReplicatedStorage.Shared.Kit.MapCheck).run()` (modo Edit). Si falla, deja
   marcas rojas: `node <kit>/kit/captura.js mapa-arriba` y después `MapCheck.clear()`.
8. **Commit** diciendo qué trozo cambió y qué (git no ve dentro del .rbxm).

Tipos de mapa (fijo, montado al jugar, mezcla), cómo se escriben las piezas con enganches, luz por zonas y las
cosas por probar: `referencias/herramientas.md`.
