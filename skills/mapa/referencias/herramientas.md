# Herramientas del mapa

## Copia local del juego
Cada uno trabaja en su copia (sin Team Create). Después de `git pull`:
`lune run <kit>/kit/montar.luau` crea `<Nombre>.rbxl` con código, trozos y ambiente (`--rehacer` para rehacerla;
guarda la anterior en `.kit/copias/`). Se abre en Studio y se conecta `rojo serve` (default.project.json).
**Antes de rehacerla, guarda el mapa** con `guardar-mapa`: lo que no esté guardado se perdería.

## guardar-mapa
`node <kit>/kit/guardar-mapa.js [Trozo ...]` desde la carpeta del juego, con su copia abierta en Studio.
- Cada hijo de `Workspace.Map`, `ServerStorage.MapPieces` y `ServerStorage.Prefabs` → su `.rbxm`.
- Serializa en Studio (SerializationService), viaja en base64 por trozos y se comprueba con una suma en los dos lados.
- Sin nombres, también escribe `map/Ambience.project.json` (Lighting, Atmosphere, Sky, Bloom, ColorCorrection,
  SunRays, DepthOfField, Blur; solo lo que no es lo de Roblox).
- No borra archivos de trozos que ya no están en Studio: avisa.
- Habla con el MCP de Studio por su cuenta (no por el chat). Probado en el ensayo: un mapa pequeño con su ambiente
  en menos de 1 s. Falta verlo con un mapa grande. Si falla al conectar, prueba con Studio en primer plano y repite.

## Scatter (repartir prefabs)
En modo Edit con execute_luau:
```lua
return require(game.ReplicatedStorage.Shared.Kit.Scatter).run({
	prefabs = { Tree = 3, Rock = 1 },              -- pesos; nombres en ServerStorage.Prefabs
	zone = workspace.Map.Forest.ScatterZone,       -- parte que marca la zona (se puede borrar después)
	parent = workspace.Map.Forest,
	density = 0.5, scale = { 0.8, 1.25 }, seed = 1, gap = 6,
})
```
Huecos: nada cae dentro de partes con la etiqueta `NoScatter`. Misma semilla, mismo resultado; para otro reparto,
otra semilla (y borra la carpeta `Scatter_<semilla>` anterior).

## Marcas
Parte invisible (Transparency 1), anclada, CanCollide/CanTouch/CanQuery apagados, etiqueta de CollectionService
(Tag) y datos en atributos. Marcas del kit: `Spawn`, `CameraPoint` (atributo `Chunk` = trozo; su CFrame es la
cámara de las capturas), `OutOfBounds` (cajas a las que no se debe llegar), `NoScatter`, `Floating` (piezas que
flotan a propósito). Las del juego van en la ficha (`marks`, con `count`/`min`, `reach` y `attributes`).
Al arrancar, el servidor puede llamar a `Markers.check()`: avisa por nombre de cada marca que falte.

## Mapas que se montan al jugar
- Piezas hechas a mano en `ServerStorage.MapPieces`, cada una un Model con enganches: Attachment con la etiqueta
  `Connector`, atributo `Kind` (`door`, `tunnel`...) y `Role` = `in` o `out`. Solo encajan los del mismo Kind.
- La elección de piezas es lógica pura en `shared/Rules` (pesos, profundidad, rarezas) y se prueba con Lune;
  `Assembler.order` y `Assembler.random` (con semilla) sirven tal cual.
- Montar: `Assembler.build({ pieces = ServerStorage.MapPieces, rules = ..., count = 8, seed = s, parent = ...,
  start = CFrame })`. Con la misma semilla sale la misma partida (para buscar fallos).
- El comprobador del mapa mira cada pieza suelta (en `comprobar`: que tenga enganche de entrada) y unas cuantas
  uniones de prueba con semillas fijas (móntalas en Studio y pasa `MapCheck`).

## Comprobador en Studio (MapCheck)
Rayos hacia abajo cada 2 studs (más si el mapa es enorme) dan los sitios de pie; se unen andando (escalón) o
saltando (alcance con la velocidad, el salto y la gravedad de la ficha) y se recorre desde `Spawn`. Mira: marcas,
piezas flotando, que se llegue a cada marca con `reach`, zonas `OutOfBounds` alcanzables, hoyos sin salida, caídas
más altas que `maxFall`, piezas repetidas y caras que parpadean, distancias en serie, líneas de visión y triángulos.
En `swim`/`fly` no hay saltos ni caídas (el alcance en 3D está por hacer: hoy solo marcas, flotantes, solapes,
series, visión y triángulos). Cada juego enciende lo que le sirve en `checks`.

## Luz y ambiente
Sale de las mismas imágenes de concepto (hora, colores, niebla, Atmosphere, Bloom, corrección de color). Se ajusta
en Studio, se comprueba con la captura al lado del concepto y `guardar-mapa` la escribe en `map/Ambience.project.json`.
Si cambia por zonas (más oscuro al bajar), cada zona lleva su ajuste en `shared/Data` y un sistema lo aplica al entrar.

## Por probar
- Terreno (agua, montañas): en su propio trozo con `Terrain:CopyRegion` (TerrainRegion) pegado al arrancar.
- guardar-mapa en un mapa grande de verdad.
