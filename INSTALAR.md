# Instalar roblox-kit (guía para la IA)

Esta guía es para **Claude Code**, no para la persona. La persona solo te ha pedido algo como:
«Instala roblox-kit siguiendo https://github.com/AlvaroCepa/roblox-kit/blob/main/INSTALAR.md».

**Objetivo:** que la persona casi no haga nada. Tú instalas el plugin y todo lo que necesita. Ella solo hace lo
que es de su cuenta (contraseñas y permisos), que tú no puedes ni debes hacer.

**Solo Windows** de momento. Si el PC no es Windows, díselo y para.

## Reglas
- **Nunca** pidas ni escribas contraseñas, claves, tokens ni códigos en el chat. Las claves las guardan los scripts
  de `scripts/claves/` leyendo el portapapeles y cifrándolas en el PC; ni tú ni el chat las veis.
- No borres ni cambies la configuración que la persona ya tenga (MCP propios, skills) sin preguntarle.
- Explica en lenguaje sencillo, sin tecnicismos, qué vas a hacer antes de cada bloque.
- El script se puede repetir: si algo falla, arregla la causa y vuelve a pasarlo.

## Pasos

### 1. Bajar el plugin
`git` puede no estar instalado todavía, así que baja el zip del repo (es público) a una carpeta temporal nueva:

```powershell
$carpeta = Join-Path $env:TEMP 'roblox-kit-instalar'
Remove-Item -Recurse -Force $carpeta -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $carpeta | Out-Null
Invoke-WebRequest 'https://github.com/AlvaroCepa/roblox-kit/archive/refs/heads/main.zip' -OutFile "$carpeta\kit.zip" -UseBasicParsing
Expand-Archive "$carpeta\kit.zip" -DestinationPath $carpeta -Force
```

El script queda en `$carpeta\roblox-kit-main\scripts\diagnostico.ps1`.

### 2. Mirar qué falta
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$carpeta\roblox-kit-main\scripts\diagnostico.ps1" -SoloMirar
```
Da una línea por pieza: `bien`, `falta` (lo instalas tú), `te toca` (paso de la persona) o `aviso`.
Enséñaselo resumido y dile **todo junto** lo que va a tener que hacer ella (sección 4), para que no le pille por sorpresa.

### 3. Instalar lo que falta
Con su visto bueno, el mismo script sin `-SoloMirar`. Instala con `winget` lo que falte (Git, GitHub CLI, Node,
Python, uv, Blender), Rokit, la CLI de Kaggle, el addon de Blender, la copia arreglada del MCP de Google Flow,
apaga la telemetría de Blender y añade el plugin desde el marketplace:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$carpeta\roblox-kit-main\scripts\diagnostico.ps1"
```
Puede tardar varios minutos y Windows puede pedir permiso de administrador para algún programa: avisa a la persona.

### 4. Los pasos de la persona
Guíala **de uno en uno**, esperando a que diga que lo ha hecho. Son los `te toca` del diagnóstico:
1. **GitHub:** `gh auth login --web` (lo lanzas tú; ella inicia sesión en el navegador) y aceptar las invitaciones
   a los repos (el plugin, los juegos y `ideas-roblox`) en github.com/notifications.
2. **MCP de Studio:** abrir Roblox Studio e iniciar sesión. En *Assistant → Manage MCP Servers*, activar
   *Enable Studio as MCP server*.
3. **Clave de Open Cloud:** abrir el Bitwarden Send que le mandó Álvaro y copiar la clave. Ábrele tú una ventana
   con el script, que espera a que pulse Enter y la guarda cifrada:
   ```powershell
   Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"<plugin>\scripts\claves\GuardarClaveOpenCloud.ps1`""
   ```
4. **Kaggle:** crear la cuenta en kaggle.com, verificar el teléfono (lo pide para usar la GPU), en *Settings → API*
   pulsar *Generate New Token* y copiarlo. Después ábrele una ventana con `scripts\claves\GuardarClaveKaggle.ps1` igual que arriba.
5. **Google Flow:** la primera vez que se use, iniciar sesión con su cuenta de Google en la ventana de Chrome que se abre.
6. **Addon de Blender**, si el diagnóstico lo pide: en Blender, *Editar → Preferencias → Complementos*, activar
   «Blender MCP» y desmarcar su casilla de telemetría.

### 5. Comprobar
- Repite el diagnóstico (con `-SoloMirar`) hasta que no quede ningún `falta`.
- Pídele que **reinicie Claude Code**. En la sesión nueva, `/plugin` debe mostrar `roblox-kit` activado
  y `/mcp` los servidores de Studio y Blender.
- Si el diagnóstico avisa de MCP o skills repetidos, explícale qué sobra y quítalo solo si dice que sí.
- Termina con un resumen corto: qué se instaló y si queda algo pendiente.

## Para Álvaro, con cada persona nueva
- Crear su clave «PC Nombre» en la cuenta bot de Roblox (mismos permisos que las otras) y mandársela por un
  Bitwarden Send de 1 acceso y 1 día.
- Invitarle en GitHub a los repos que toque: los juegos e `ideas-roblox`. El plugin es público.
