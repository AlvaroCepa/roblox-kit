# roblox-kit

Plugin de Claude Code con el sistema para hacer juegos de Roblox con IA. Lo mantiene solo AlvaroCepa; quien lo
usa lo instala desde aquí y recibe las actualizaciones. Las ideas de mejora llegan como issues con la etiqueta
`mejora`.

**Instalar en un PC nuevo:** pídele a tu Claude Code
«Instala roblox-kit siguiendo https://github.com/AlvaroCepa/roblox-kit/blob/main/INSTALAR.md».

Si ya tienes todo lo demás y solo falta el plugin:
```
/plugin marketplace add AlvaroCepa/roblox-kit
/plugin install roblox-kit@roblox-kit
```

## Qué trae

**MCP** (`.mcp.json`): Roblox Studio (el oficial que viene con Studio) y Blender (`mcp-for-blender`, con la
telemetría apagada). Figma y Google Flow van en la cuenta de cada uno; la copia arreglada de Google Flow está en
`mcp/google-flow` y la instala el diagnóstico.

**Hooks** (`hooks/`, PowerShell 5.1). Solo actúan en juegos (carpetas con un `*.project.json` de Rojo), salvo el freno:
| Cuándo | Qué hace |
|---|---|
| Al empezar sesión | Primera línea de `Estado.md`, rama, cambios sin subir, commits nuevos en GitHub (sin `pull`), si Studio y `rojo serve` están abiertos, y el recordatorio semanal |
| Antes de usar Studio o Blender | Pide permiso para `multi_edit`, `execute_luau` en Edit que toca scripts, subir imágenes y generar assets. Nunca prohíbe |
| Antes de órdenes que salen fuera | Pregunta antes de subir assets al grupo (`subir-assets`, `asphalt sync`) y de un `git push` a `main`. En juegos, **niega `gh pr merge` si la CI no está en verde** o si el PR toca lo compartido (`src/shared/Data`, `CLAUDE.md`, `.claude/`) sin la aprobación de AlvaroCepa: GitHub gratis no deja proteger ramas en repos privados |
| Al editar un `.lua`/`.luau` | StyLua y Selene sobre ese archivo, si el juego tiene `stylua.toml` / `selene.toml` |
| Tras `insert_asset` | Recuerda buscar scripts dentro de lo insertado |
| Tras `execute_luau` | Si el comprobador de UI o de mapa en Studio dice «bien», apunta la pasada (`kit/pasada.luau`) |
| Al terminar el turno | Si cambió código: `comprobar` (o, en juegos antiguos, `rojo build` y su comprobación). Frena una vez si falla; después solo avisa. Si cambió el código de servidor desde la última prueba en la nube, o la UI o el mapa desde su última pasada en Studio, pide esa pasada una vez (si Studio está cerrado, solo avisa) |
| Al enviar un mensaje | `#mal <motivo>` se apunta en el registro |

Todo se apunta en `registro.jsonl` (en la carpeta de datos del plugin) para elegir modelo y detectar mejoras.
Una vez al día, `hooks/senales.ps1` convierte las señales repetidas en issues `mejora` (sin duplicados, sin datos
de los juegos).

**Scripts** (`scripts/`):
- `claves/`: guardar y usar las claves de Open Cloud y Kaggle cifradas en el PC (nunca se imprimen).
- `puente/`: puente al MCP de Studio para cuando Claude Code no conecta. Niega lo arriesgado (`reglas.js`).
- `studio/cliente.js`: cliente de un solo uso del MCP de Studio para los scripts del kit (guardar el mapa, capturas):
  lo pesado no pasa por el chat. Aplica las mismas reglas que el puente.
- `lado-a-lado.py`: junta referencias y capturas en una sola imagen (Pillow).
- `diagnostico.ps1`: instala y repara todo; se puede repetir.

**Kit de código** (`kit/`, en Luau con Lune: igual en Windows y en la CI de Linux). Desde la carpeta del juego:
| Script | Qué hace |
|---|---|
| `lune run <kit>/kit/comprobar.luau` | StyLua (solo mira), Selene, tipos con luau-lsp, `rojo build`, pruebas de Lune, la regla de `Rules` (lógica pura) y los oficios (`kit/oficios.luau`): ids sueltos, textos/colores/fuente de la UI, topes de efectos y sonidos, la mitad sin Studio del mapa (lee los `.rbxm`) y si los módulos del kit del juego son viejos. Una línea si va bien; detalle en `.kit/comprobar.log`. `--pasos a,b` elige pasos; con archivos sueltos, solo StyLua y Selene |
| `lune run <kit>/kit/probar.luau` | Las pruebas de Lune (`tests/**/*.spec.luau`). `--filtro texto` |
| `kit/probar-nube.ps1` | Sube el juego a «Pruebas» **guardado, sin publicar**, y en esa versión comprueba que arranca sin errores y pasa las pruebas `*.cloud.spec.luau`. Lee la clave cifrada del PC (en la CI, el secreto `ROBLOX_API_KEY`) |
| `lune run <kit>/kit/paquetes.luau` | `wally install` y los tipos de los paquetes (`wally-package-types`) |
| `lune run <kit>/kit/juego-nuevo.luau <carpeta> --nombre X` | Crea un juego desde `plantilla/` (lo usa la skill `juego-nuevo`) |
| `lune run <kit>/kit/montar.luau [--rehacer]` | Monta la copia local del juego (código, mapa y ambiente) en `<Nombre>.rbxl` para Studio + `rojo serve` |
| `node <kit>/kit/guardar-mapa.js [Trozo...]` | Guarda los trozos del mapa (`map/`), los modelos montados (`models/`) y el ambiente desde Studio, con suma de control |
| `node <kit>/kit/captura.js ui\|mapa\|mapa-arriba\|vfx ...` | Capturas de Studio en modo edición al lado de las referencias, en `.kit/capturas/` |
| `lune run <kit>/kit/ui-generar.luau` | Cuerpos de botones y paneles (SVG, 9-slice) desde la hoja de estilo |
| `kit/subir-assets.ps1 [--dry-run]` | Sube `assets/` al grupo con Asphalt y la clave cifrada del PC; regenera `src/shared/Assets` |

- `kit/probador.luau`: el probador (Luau puro; el mismo corre en Lune y en Roblox). Una prueba recibe `expect`
  (`toBe`, `toEqual`, `toBeNil`, `toBeTruthy`, `toBeFalsy`, `toBeGreaterThan(OrEqual)`, `toBeLessThan(OrEqual)`,
  `toBeCloseTo`, `toContain`, `toHaveLength`, `toThrow`, y `.never`).
- `kit/juego/`: los originales de los módulos que la plantilla copia a `src/shared/Kit/` del juego, cada uno con
  su versión (`-- roblox-kit <Nombre> vN`); si el del plugin sube, `comprobar` avisa. Cargador (`Loader`), UI
  (`UI`, `Screens`, `List`, `UIMotion`, `Theme`, `UICheck`), ids por nombre (`Asset`), mapa (`Markers`,
  `Assembler`, `Scatter`, `MapCheck`), `Effects`, `Sounds`, `Motion` y `Animations`.
- Los tipos de Roblox para luau-lsp se bajan de la misma versión que luau-lsp y se guardan en la caché del PC.

**Plantilla** (`plantilla/`): `src/server|client|shared` con un sistema de ejemplo (monedas, con su pantalla),
`net.zap`, pruebas, `rokit.toml` con las versiones fijadas (también Asphalt), Wally (Trove), ProfileStore fijado en
`Vendor/`, hoja de estilo (`Data/Style.luau`, TEMPORAL), ficha del mapa (`Data/Map.luau`), efectos, sonidos y
animaciones como datos, `assets/` + `asphalt.toml` (sube al grupo), `map/` y `build.project.json` (el juego entero),
`models/`, configuración estricta, `CLAUDE.md` corto y la CI. Recién creada pasa `comprobar`, la CI y `probar-nube`.

**Skills** (`skills/`), todas se lanzan solas:
| Skill | Para |
|---|---|
| `jefa` | El plan del juego: fases, `Estado.md`, bloques de 5 pasos, lanzamiento, actualizaciones y «adoptar» |
| `puntuar-idea-roblox` | Fase de idea |
| `juego-nuevo` | Crear el repo de un juego desde la plantilla |
| `trabajo-entre-dos` | Ramas, PR con CI en verde, copia local sin Team Create, trozos del mapa |
| `ui` | Pantallas en código, hoja de estilo, botones de imagen, iconos, comprobador y capturas |
| `mapa` | De imágenes de concepto a trozos en el repo, marcas, prefabs, mapas montados, comprobador |
| `modelos-3d` | Hoja 3D, fichas, TRELLIS en Kaggle (`scripts/trellis.ps1`), color con reglas en Blender (`scripts/blender.ps1`) |
| `vfx`, `sonido`, `animacion` | Efectos, sonidos y animaciones como datos lanzados con una línea en el cliente |

**Autoprueba** (`.github/workflows/plantilla.yml`): en cada cambio de `kit/` o `plantilla/`, crea un juego en
Linux y le pasa `comprobar`.

**Probado en Studio** (ensayo general, 0.4.0): TRELLIS en Kaggle de principio a fin, comprobadores de UI y mapa,
capturas, `guardar-mapa`, Scatter, efectos/sonidos/animaciones de una línea, `comprobar` y `probar-nube`.
**Por probar en su primer uso real:** subir de verdad un sonido o una animación al grupo, Rojo en directo, el
terreno, un mapa grande, la prueba R6 y la investigación de packs de VFX y sonido (se hace al empezar con cada oficio).

## Desarrollo
- Probar sin instalar: `claude --plugin-dir "<esta carpeta>"`.
- Validar: `claude plugin validate "<esta carpeta>"`.
- Los `.ps1` van en UTF-8 **con BOM** (PowerShell 5.1 lee mal las tildes sin él) y se llaman en forma exec:
  `powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File ...`.
- Publicar una versión: subir `version` en `.claude-plugin/plugin.json`. Quien lo tenga instalado la recibe al actualizar.
- Si cambia la hoja de estilo base de la plantilla: `lune run ../kit/ui-generar.luau` desde `plantilla/`.
- StyLua formatea el kit con la configuración de la plantilla: `cd plantilla && stylua ../kit/juego ../kit src tests`.
