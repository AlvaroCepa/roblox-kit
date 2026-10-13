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

## Qué trae (tanda 1: la base)

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
| Al terminar el turno | Si cambió código: `rojo build` y la comprobación del juego. Frena una vez si falla; después solo avisa |
| Al enviar un mensaje | `#mal <motivo>` se apunta en el registro |

Todo se apunta en `registro.jsonl` (en la carpeta de datos del plugin) para elegir modelo y detectar mejoras.
Una vez al día, `hooks/senales.ps1` convierte las señales repetidas en issues `mejora` (sin duplicados, sin datos
de los juegos).

**Scripts** (`scripts/`):
- `claves/`: guardar y usar las claves de Open Cloud y Kaggle cifradas en el PC (nunca se imprimen).
- `puente/`: puente al MCP de Studio para cuando Claude Code no conecta. Niega lo arriesgado.
- `diagnostico.ps1`: instala y repara todo; se puede repetir.

**Skills** (`skills/`): `puntuar-idea-roblox`.

Próximas tandas: código (`comprobar`, probador, `probar-nube`, arranque, plantilla, CI) y oficios (UI, mapa, 3D,
VFX, sonido, animación, skill jefa, trabajo entre dos).

## Desarrollo
- Probar sin instalar: `claude --plugin-dir "<esta carpeta>"`.
- Validar: `claude plugin validate "<esta carpeta>"`.
- Los `.ps1` van en UTF-8 **con BOM** (PowerShell 5.1 lee mal las tildes sin él) y se llaman en forma exec:
  `powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File ...`.
- Publicar una versión: subir `version` en `.claude-plugin/plugin.json`. Quien lo tenga instalado la recibe al actualizar.
