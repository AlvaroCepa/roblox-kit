# Hoja de estilo de la UI

Vive en `src/shared/Data/Style.luau` del juego, junto con las líneas de efectos, sonido y animación. Es solo
datos (colores en hex, la fuente por nombre) para que la lean igual el juego y los scripts del plugin.

## De dónde sale
1. Álvaro elige **3-5 capturas** de juegos cuya UI le guste (ahora, TEMPORAL: Steal a Brainrot). Se guardan en
   `assets/concept/ui/` del juego.
2. Claude las mira y saca los números: paleta (5-6 colores), fuente (de las de Roblox: FredokaOne, LuckiestGuy,
   Bangers, GothamBold...), **un** grosor de contorno, radio de esquinas, sombra (desplazamiento, color, opacidad),
   degradado (claro arriba, oscuro abajo), brillo de arriba, labio 3D y los tiempos de las animaciones.
3. `lune run <kit>/kit/ui-generar.luau` rehace `assets/ui/kit/button.svg` y `panel.svg`.
4. `asphalt sync debug` los pasa a PNG en `.asphalt-debug/` sin subir nada: míralos (Read) teñidos de un par de
   colores de la paleta. Después, la pantalla de ejemplo en Studio (`asphalt sync studio` + `captura.js ui`) al
   lado de las capturas de referencia. **Álvaro juzga**; se ajustan los números y se repite.

## Qué es cada número (`ui.body`, en píxeles de la imagen de 128)
- `corner`: radio de las esquinas. `stroke`: contorno oscuro. `lip`: alto del labio 3D de abajo.
- `shadowOffset`, `shadowColor`, `shadowAlpha`: sombra desplazada hacia abajo (azulada queda mejor que negra).
- `gradientTop` / `gradientBottom`: brillo de la cara arriba y abajo. **Por debajo de 1**, si no el brillo no se ve.
- `highlight`: opacidad del brillo de arriba. `lipShade`: lo oscuro del labio.
- `ui.bodyCorner`: qué parte del lado corto del botón ocupa la esquina en pantalla (el 9-slice se reescala con
  el tamaño del botón; `Style.luau` del juego lo hace).

## Por qué imágenes blancas teñidas
Un botón blanco con `ImageColor3` da el verde, el rojo y el dorado con UNA subida. Al teñir se multiplica: el
contorno oscuro sigue oscuro y el brillo blanco toma el color del botón.
