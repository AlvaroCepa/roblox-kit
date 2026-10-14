---
name: modelos-3d
description: Cómo se hacen los modelos 3D de los juegos de Roblox con roblox-kit (hoja de estilo 3D, ficha por modelo, vía según el tipo, mascotas con imagen de Nano Banana + forma con TRELLIS en Kaggle + color con reglas en Blender, revisión en tres filtros, subida al grupo, iconos desde el modelo). Úsala SIEMPRE que haya que crear, conseguir, retocar, revisar, subir o meter en el juego un modelo 3D (mascotas, huevos, objetos, armas, decoración, edificios), o usar Blender, Kaggle o mallas, aunque no se diga «3D».
---

# Modelos 3D

**Método aprobado por Álvaro (prueba del 12/10/2026).** El estilo de cada juego lo pone su hoja de estilo 3D, no
el método. Álvaro siempre juzga cómo se ve al final.

## Qué vía para cada modelo
| Modelo | Vía |
|---|---|
| Relleno sencillo (caja, barril) | `generate_mesh` de Studio (da forma, sin color: el hook pregunta) |
| Bordes duros (armas, edificios, muebles) | Librerías gratis (Poly Pizza, Poly Haven; licencia mirada una a una) o script de Blender sin ventana |
| Mascotas y modelos «normales» | Nano Banana → **TRELLIS en Kaggle** (solo forma) → **color con reglas en Blender** (MCP) → script final |
| Uno suelto y urgente | Hugging Face ZeroGPU (~3 al día) |
Nunca: Hunyuan3D (su licencia excluye la UE), Rodin, Tripo ni Meshy (de pago). No pagamos ningún servicio.

## Reglas (con su porqué)
1. **Hoja de estilo 3D por juego** (`assets/3d/estilo3d.toml`, desde la imagen de concepto): paleta, liso o
   facetado, detalle, tamaños al lado del jugador, triángulos. Las fichas **solo** usan colores de esa paleta y
   se rechazan los modelos de librería que no encajen: si no, el juego parece hecho de piezas sueltas.
2. **La IA 3D solo da la FORMA.** Saca una sola «piel» y los ojos o las rayas son solo color: el color automático
   (proyectar la imagen o el color propio de TRELLIS) salió manchado y se descartó. El color lo pone Claude con
   **reglas** (óvalos y bandas en la ficha) y lo nítido (ojos con brillo, nariz) son **piezas de verdad**.
3. **Los bordes de color se calculan píxel a píxel**, no por triángulo (salían en zigzag, como pelo).
4. **Sin mapa de normales** (Álvaro: «sin relieve mucho mejor»).
5. **Cambiar la ficha regenera el modelo** sin repetir lo caro. En git: ficha, imagen de partida y modelo final
   ligero. La malla en bruto de Kaggle **no** va a git: se queda en Kaggle (generar otra vez nunca da la misma forma).
6. **Máximo 3 intentos** de Claude por modelo; al tercero fallido, se enseña a Álvaro qué falla. No gastes horas
   de Kaggle sin control.
7. **Tiempo honesto:** di el tiempo real de principio a fin (el perro llevó ~20 min, no «segundos»). Lanza la
   tanda de Kaggle en segundo plano y sigue con otra cosa.
8. **En Roblox:** mascotas y decoración sin colisión; lo que choca, `CollisionFidelity` Box o Hull; RenderFidelity
   automático. Colores en una textura lisa (`SurfaceAppearance.ColorMap`); cada mutación es la misma malla con
   otro `SurfaceAppearance` ya hecho (no se puede cambiar desde scripts al jugar). Ids por nombre (`Asset.get`).

## Pasos (mascotas y modelos «normales»)
1. **Ficha** en `assets/3d/<modelo>/ficha.toml` (copia `plantillas/ficha.toml`): qué es, tamaño, triángulos, zonas
   de color de la paleta, mutaciones e imagen de partida.
2. **Imágenes** de todos los modelos a la vez con Nano Banana (prompt base en `referencias/metodo.md`), en
   `assets/3d/imagenes/<modelo>.png`. Álvaro elige.
3. **Formas en Kaggle, una tanda** (en segundo plano):
   `powershell -NoProfile -ExecutionPolicy Bypass -File <kit>/skills/modelos-3d/scripts/trellis.ps1 -Imagenes assets/3d/imagenes -Juego <Nombre>`
   → `.kit/kaggle/salida/<modelo>.glb`.
4. **Pintar en Blender en directo** (MCP de Blender, Álvaro mirando si quiere): carga la forma orientada, pon la
   imagen al lado y ajusta reglas y piezas en la ficha con `scripts/blender/vista_reglas.py` (ver `referencias/metodo.md`).
5. **Script final** (sin ventana, ~30 s): reduce, pinta desde la ficha, hace las mutaciones, comprueba y saca la
   hoja de vistas: `scripts/blender.ps1 scripts/blender/procesar.py '<json>'`.
6. **Revisión:** (1) comprobaciones automáticas del informe; (2) Claude mira la hoja de vistas contra la imagen;
   (3) **Álvaro** ve el modelo al lado del jugador, de otros modelos del juego y con todas sus mutaciones.
7. **Subir** (con el sí de Álvaro): el GLB y las texturas a `assets/models/<modelo>/` y `kit/subir-assets.ps1`.
   Después, montarlo en Studio y guardarlo en el repo: `referencias/llevar-a-roblox.md`.
8. **Icono** desde el modelo final (Blender sin ventana, fondo transparente) → `assets/ui/icons/` (skill `ui`).

## Más detalle
- `referencias/metodo.md`: prompt base, reglas y piezas de la ficha, cómo usar la vista en directo, qué salió en la prueba.
- `referencias/llevar-a-roblox.md`: de las ids subidas a un modelo en `ReplicatedStorage.Models` guardado en el repo.
- `referencias/blender.md`: lecciones de Blender (MCP, unidades, ejes, UV, sin ventana).
- `plantillas/estilo3d.toml` y `plantillas/ficha.toml`: para copiar al juego.
