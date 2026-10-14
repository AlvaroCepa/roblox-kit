# Lecciones de Blender (de Protect the Pyramid y la prueba de las mascotas)

- **MCP de Blender:** en Blender, N → pestaña BlenderMCP → Connect to MCP server. Cada llamada empieza con las
  variables vacías: los modelos se hacen con un script guardado en el repo y se ejecutan con `exec(open(ruta).read())`.
- Antes de escribir código: `get_addon_status()` (versión) y `get_scene_info()`. Nodos de shader por TIPO, nunca
  por nombre (en Blender en español «Principled BSDF» no existe). No escribas identificadores de enums a mano: léelos.
- **1 unidad de Blender = 1 stud.** Al importar un `.glb` en Studio, la cara −Y de Blender queda hacia −Z (y X al
  revés): gíralo 180° si importa hacia dónde mira.
- **Los materiales de Roblox (Sandstone, Wood...) necesitan UV**; sin ellas salen de un color liso (usa proyección de caja).
- **Sin ventana:** `scripts/blender.ps1 <script.py> [args]`. Encuentra Blender, también el de la Microsoft Store
  (su `blender.exe` da «Acceso denegado» y su lanzador pierde la salida: por eso pasa por `envoltura.py` y deja
  todo en `.kit/blender.log`). Arrancar Blender tarda ~30 s.
- **Cambiar la malla de una pieza ya montada en Studio:** importar y `MeshPart:ApplyMesh` desde execute_luau
  (mantiene nombre y propiedades, pero deja `CollisionFidelity` en Default). Nunca dejar mallas de `EditableMesh`:
  no se guardan.
- El PC de Álvaro no tiene tarjeta gráfica (Intel UHD, 8 GB): lo pesado (formas 3D) va a Kaggle; Blender local
  solo reduce, pinta y renderiza vistas pequeñas.
- Telemetría del MCP de Blender apagada (variable `BLENDER_MCP_DISABLE_TELEMETRY` y casilla del addon).
- Generadores del addon: Hunyuan3D nunca (licencia fuera de la UE); Rodin, Tripo y Meshy no (de pago). El hook pregunta.
