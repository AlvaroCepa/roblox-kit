# Imágenes e iconos

## Subir: siempre con Asphalt, al grupo
- Las imágenes viven en `assets/ui/` del repo. `kit/subir-assets.ps1` las sube al **grupo** con la clave del bot
  (cifrada en el PC, nunca se imprime) y regenera `src/shared/Assets/ui.luau` con los ids. El hook pregunta antes.
- `asphalt.lock.toml` va en git: así nadie vuelve a subir lo mismo.
- Asphalt pasa los SVG a PNG y limpia los bordes de la transparencia. Un SVG con `currentColor` sale blanco.
- **Moderación:** lo recién subido tarda unos minutos en verse; mientras, sale en blanco y `PreloadAsync` falla.
  No es un fallo: espera.
- Para mirar en Studio antes de subir: `asphalt sync studio` (rutas locales; ese `src/shared/Assets` no va a git:
  `comprobar` avisa si lo ve).

## Iconos (monedas, mejoras, menú)
1. **Nano Banana** en Google Flow (gratis: Imagen, 1:1, Nano Banana, x1 = «0 puntos»; Agente apagado). El mismo
   prompt de estilo para todos y una imagen de referencia, para que parezcan de la misma familia. Fondo liso de un
   color que no esté en el icono.
2. Quitar el fondo con **rembg** (sin tarjeta gráfica; lo instala el diagnóstico):
   `& "$env:APPDATA\Python\Python312\Scripts\rembg.exe" i entrada.png salida.png` (o `rembg i ...` si está en el PATH).
   La primera vez baja su modelo (176 MB).
3. Recortar al contenido, cuadrado, 256 o 512 px. Mirarlo reducido a **64 px**: si no se entiende, se repite.
4. Guardar en `assets/ui/icons/<nombre>.png` y usarlo con `Asset.get("ui/icons/<nombre>")`.
- **Iconos de mascotas, huevos y objetos:** captura del propio modelo 3D con Blender sin ventana y fondo
  transparente (skill `modelos-3d`). Así coinciden con el modelo.
- Hojas de iconos (spritesheet) solo para familias de iconos pequeños (monedas, estadísticas).

## Tamaños
- Nada de más de 1024 px. Iconos 256-512. Cuerpos de botón: los de `ui-generar` (128, en 9-slice).
