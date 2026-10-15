# Método de las mascotas (y modelos «normales»)

Probado el 12/10/2026 con mapache, perro y búho, de la imagen a Studio. Kaggle gastó < 1 h de las ~30 semanales.

## 1. Imágenes (Nano Banana en Google Flow, gratis)
- Agente apagado; «Activador de ajustes»: Imagen, 1:1, Nano Banana, x1 → «0 puntos». Descargar «1K Tamaño original».
- Prompt base (cambia lo de estilo según la hoja del juego): *stylized 3D cartoon <qué>, full body, 3/4 front view,
  chunky shapes, matte, plain light grey background, no ground shadow, centred, nothing cropped, no text*.
- Todas las del juego a la vez. Tres cuartos de frente SIEMPRE: el script final usa la imagen para saber dónde
  está el frente.

## 2. Forma con TRELLIS (Kaggle)
- `scripts/trellis.ps1` sube las imágenes a un dataset privado del juego, lanza `scripts/kaggle/trellis.py` en
  GPU y baja las mallas. Entorno propio (uv, Python 3.10, torch 2.4 cu121, ~45 s); arreglos ya puestos: sin el
  import de open3d, módulo mínimo en vez de kaolin.
- ~30 s por modelo y ~3 min fijos por tanda; a veces hay cola (hasta 30 min).
- Hi3DGen dio formas parecidas pero más lento (~50 s) y peor orientado: se usa TRELLIS. TRELLIS.2 pide ~24 GB
  (no cabe en Kaggle).
- La primera vez de cada persona: cuenta de Kaggle con el teléfono verificado (si no, no hay GPU) y su token
  guardado con `scripts/claves/GuardarClaveKaggle.ps1`. `trellis.ps1 -Usuario <usuario>` la primera vez.
- `trellis.ps1` junta todos los pasos. Probado de principio a fin en el ensayo: 2 mascotas en ~7 min.

## 3. Color con reglas, en directo (MCP de Blender)
1. Pasa el script final con `"guardar_alta": true` para que deje la malla alta ya orientada (`alta.glb`).
2. En Blender (MCP): importa `alta.glb`, pon la imagen de partida al lado y
   `exec(open(r"<kit>/skills/modelos-3d/scripts/blender/vista_reglas.py").read())`; luego
   `pintar(bpy.data.objects["alta"], r"<ficha.toml>", r"<estilo3d.toml>")` (y `mutacion="dorado"` para verlas).
3. Ajusta la ficha y repite: cada `[[regla]]` pinta encima de las anteriores. Coordenadas en studs:
   x = lado, -y = frente, z = arriba desde el suelo.
   - `tipo = "elipsoide"`: `centro`, `radios`, `espejo` (también al otro lado), `solo_frente`.
   - `tipo = "rayas"`: bandas (colas, lomos).
   - `[[pieza]]`: ojo o nariz de verdad; `en = [x, z]` (rayo desde delante), `radio`, `brillo`, `espejo`.
   - `girar_180 = true` si la IA lo dejó mirando atrás.
4. `get_viewport_screenshot` al lado de la imagen si Álvaro quiere opinar.

## 4. Script final (Blender sin ventana, en el PC)
```
powershell -NoProfile -ExecutionPolicy Bypass -File <kit>/skills/modelos-3d/scripts/blender.ps1 <kit>/skills/modelos-3d/scripts/blender/procesar.py '{"malla": ".kit/kaggle/salida/perro.glb", "imagen": "assets/3d/imagenes/perro.png", "ficha": "assets/3d/perro/ficha.toml", "estilo": "assets/3d/estilo3d.toml", "salida": ".kit/3d/perro", "mascota": "perro", "fuente": "trellis"}'
```
Hace: limpiar y apoyar en el suelo → encajar la cámara de la imagen, buscar el plano de simetría y el frente →
reducir a los triángulos de la ficha → hornear el color (zonas por píxel, con las reglas) → ojos y nariz como
piezas → colores exactos de la paleta y mutaciones → exportar GLB + texturas → comprobaciones → hoja de vistas.
Salida en `.kit/3d/<modelo>/`: `<modelo>.glb`, texturas, `vista_*.png` e `informe.json` (triángulos, altura,
apoyado, aristas abiertas, solo colores de la paleta). ~30 s más ~30 s de arrancar Blender.
Ignora `vista_con_normal.png`: el mapa de normales no se usa.

## Qué falta por probar
- Cronometrar una mascota nueva de principio a fin con todo ya montado, incluido el color en Blender.
- El estilo definitivo de los juegos (lo pone la hoja de cada juego).
