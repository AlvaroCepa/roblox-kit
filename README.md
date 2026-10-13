# roblox-kit

Plugin de Claude Code con el sistema para hacer juegos de Roblox con IA. Lo mantiene solo AlvaroCepa; quien lo
usa lo instala desde aquí y recibe las actualizaciones. Las ideas de mejora llegan como issues con la etiqueta
`mejora`.

**Instalar en un PC nuevo:** pídele a tu Claude Code
«Instala roblox-kit siguiendo https://github.com/AlvaroCepa/roblox-kit/blob/main/INSTALAR.md».

Si ya tienes todo lo demás y solo falta el plugin:
```
/plugin install roblox-kit --marketplace AlvaroCepa/roblox-kit
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
| Al editar un `.lua`/`.luau` | StyLua y Selene sobre ese archivo, si el juego tiene `stylua.toml` / `selene.toml` |
| Tras `insert_asset` | Recuerda buscar scripts dentro de lo insertado |
| Al terminar el turno | Si cambió código: `comprobar` (o, en juegos antiguos, `rojo build` y su comprobación). Frena una vez si falla; después solo avisa. Si el código de servidor cambió desde la última prueba en la nube, pide `probar-nube` una vez |
| Al enviar un mensaje | `#mal <motivo>` se apunta en el registro |

Todo se apunta en `registro.jsonl` (en la carpeta de datos del plugin) para elegir modelo y detectar mejoras.
Una vez al día, `hooks/senales.ps1` convierte las señales repetidas en issues `mejora` (sin duplicados, sin datos
de los juegos).

**Scripts** (`scripts/`):
- `claves/`: guardar y usar las claves de Open Cloud y Kaggle cifradas en el PC (nunca se imprimen).
- `puente/`: puente al MCP de Studio para cuando Claude Code no conecta. Niega lo arriesgado.
- `diagnostico.ps1`: instala y repara todo; se puede repetir.

**Kit de código** (`kit/`, en Luau con Lune: igual en Windows y en la CI de Linux). Desde la carpeta del juego:
| Script | Qué hace |
|---|---|
| `lune run <kit>/kit/comprobar.luau` | StyLua (solo mira), Selene, tipos con luau-lsp, `rojo build`, pruebas de Lune y la regla de `Rules` (lógica pura). Una línea si va bien; detalle en `.kit/comprobar.log`. `--pasos a,b` elige pasos; con archivos sueltos, solo StyLua y Selene |
| `lune run <kit>/kit/probar.luau` | Las pruebas de Lune (`tests/**/*.spec.luau`). `--filtro texto` |
| `kit/probar-nube.ps1` | Sube el juego a «Pruebas» **guardado, sin publicar**, y en esa versión comprueba que arranca sin errores y pasa las pruebas `*.cloud.spec.luau`. Lee la clave cifrada del PC (en la CI, el secreto `ROBLOX_API_KEY`) |
| `lune run <kit>/kit/paquetes.luau` | `wally install` y los tipos de los paquetes (`wally-package-types`) |
| `lune run <kit>/kit/juego-nuevo.luau <carpeta> --nombre X` | Crea un juego desde `plantilla/` (lo usa la skill `juego-nuevo`) |

- `kit/probador.luau`: el probador (Luau puro; el mismo corre en Lune y en Roblox). Una prueba recibe `expect`
  (`toBe`, `toEqual`, `toBeNil`, `toBeTruthy`, `toBeFalsy`, `toBeGreaterThan(OrEqual)`, `toBeLessThan(OrEqual)`,
  `toBeCloseTo`, `toContain`, `toHaveLength`, `toThrow`, y `.never`).
- `kit/Loader.luau`: el original del cargador de sistemas (dos fases, cada sistema protegido). La plantilla lo
  copia al juego; si el del plugin sube de versión, `comprobar` avisa.
- Los tipos de Roblox para luau-lsp se bajan de la misma versión que luau-lsp y se guardan en la caché del PC.

**Plantilla** (`plantilla/`): `src/server|client|shared` con un sistema de ejemplo (monedas), `net.zap`,
pruebas, `rokit.toml` con las versiones fijadas, Wally (Trove), ProfileStore fijado en `Vendor/`, configuración
estricta, `CLAUDE.md` corto y la CI (`.github/workflows/ci.yml`). Recién creada pasa `comprobar` y la CI.

**Skills** (`skills/`): `puntuar-idea-roblox` y `juego-nuevo`.

**Autoprueba** (`.github/workflows/plantilla.yml`): en cada cambio de `kit/` o `plantilla/`, crea un juego en
Linux y le pasa `comprobar`.

Próxima tanda: oficios (UI, mapa, 3D, VFX, sonido, animación, skill jefa, trabajo entre dos).

## Desarrollo
- Probar sin instalar: `claude --plugin-dir "<esta carpeta>"`.
- Validar: `claude plugin validate "<esta carpeta>"`.
- Los `.ps1` van en UTF-8 **con BOM** (PowerShell 5.1 lee mal las tildes sin él) y se llaman en forma exec:
  `powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File ...`.
- Publicar una versión: subir `version` en `.claude-plugin/plugin.json`. Quien lo tenga instalado la recibe al actualizar.
