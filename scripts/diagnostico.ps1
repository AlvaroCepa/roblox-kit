# Diagnóstico e instalación de roblox-kit en un PC con Windows.
# Mira pieza a pieza qué falta, instala lo que puede sola y al final da una línea por pieza.
# Se puede repetir sin romper nada: lo que ya está bien no se toca. Sirve también de «médico».
# Uso: powershell -NoProfile -ExecutionPolicy Bypass -File diagnostico.ps1 [-SoloMirar]
#   -SoloMirar: no instala nada, solo dice qué falta.
param([switch]$SoloMirar)
$ErrorActionPreference = 'Continue'
$raizPlugin = Split-Path $PSScriptRoot -Parent
$resultados = New-Object System.Collections.ArrayList

function Apuntar([string]$Pieza, [string]$Estado, [string]$Detalle = '') {
    [void]$resultados.Add([pscustomobject]@{ Pieza = $Pieza; Estado = $Estado; Detalle = $Detalle })
}
function Hay([string]$Comando) { [bool](Get-Command $Comando -ErrorAction SilentlyContinue) }
function Refrescar-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}
function Instalar-Winget([string]$Id) {
    Write-Host "Instalando $Id con winget..."
    winget install --id $Id -e --silent --accept-package-agreements --accept-source-agreements | Out-Null
    Refrescar-Path
}

# Programa que se instala con winget si falta.
function Pieza-Programa([string]$Pieza, [string]$Comando, [string]$WingetId) {
    if (Hay $Comando) { Apuntar $Pieza 'bien'; return }
    if ($SoloMirar) { Apuntar $Pieza 'falta' "winget install --id $WingetId -e"; return }
    Instalar-Winget $WingetId
    if (Hay $Comando) { Apuntar $Pieza 'instalado' } else { Apuntar $Pieza 'falta' "No se pudo instalar $WingetId. Prueba a mano: winget install --id $WingetId -e" }
}

if ($env:OS -ne 'Windows_NT') { Write-Host 'roblox-kit de momento solo funciona en Windows.'; exit 1 }
Refrescar-Path

# 1. Programas básicos
Pieza-Programa 'Git' 'git' 'Git.Git'
Pieza-Programa 'GitHub CLI' 'gh' 'GitHub.cli'
Pieza-Programa 'Node.js' 'node' 'OpenJS.NodeJS.LTS'
Pieza-Programa 'Python (py)' 'py' 'Python.Python.3.12'
Pieza-Programa 'uv (para el MCP de Blender)' 'uvx' 'astral-sh.uv'

if (Hay 'node') {
    $v = [version]((node --version) -replace '^v', '')
    if ($v -lt [version]'22.13') { Apuntar 'Node.js 22.13 o más' 'falta' "Tienes $v. Actualiza: winget upgrade --id OpenJS.NodeJS.LTS -e" }
}

# 2. Sesión de GitHub (paso de la persona)
if (Hay 'gh') {
    gh auth status 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { Apuntar 'Sesión de GitHub' 'bien' }
    else { Apuntar 'Sesión de GitHub' 'te toca' 'Ejecuta "gh auth login --web", inicia sesión en el navegador y acepta las invitaciones a los repos (plugin, juegos, ideas-roblox).' }
}

# 3. Rokit (instala las herramientas de cada juego con versión fija)
if (Hay 'rokit') { Apuntar 'Rokit' 'bien' }
elseif ($SoloMirar) { Apuntar 'Rokit' 'falta' 'Se instala desde github.com/rojo-rbx/rokit (v1.2.0).' }
else {
    try {
        $tmp = Join-Path $env:TEMP 'roblox-kit-rokit'
        New-Item -ItemType Directory -Force $tmp | Out-Null
        $zip = Join-Path $tmp 'rokit.zip'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest 'https://github.com/rojo-rbx/rokit/releases/download/v1.2.0/rokit-1.2.0-windows-x86_64.zip' -OutFile $zip -UseBasicParsing
        Expand-Archive $zip -DestinationPath $tmp -Force
        & (Join-Path $tmp 'rokit.exe') self-install | Out-Null
        Refrescar-Path
        $env:Path += ';' + (Join-Path $env:USERPROFILE '.rokit\bin')
        if (Hay 'rokit') { Apuntar 'Rokit' 'instalado' } else { Apuntar 'Rokit' 'falta' 'self-install no dejó rokit en el PATH.' }
    } catch { Apuntar 'Rokit' 'falta' $_.Exception.Message }
}

# 4. Blender, su addon del MCP y la telemetría apagada
$blenderTienda = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Packages') -Directory -Filter 'BlenderFoundation.Blender_*' -ErrorAction SilentlyContinue | Select-Object -First 1
if ((Hay 'blender-launcher') -or (Hay 'blender') -or $blenderTienda -or (Test-Path 'C:\Program Files\Blender Foundation')) { Apuntar 'Blender' 'bien' }
elseif ($SoloMirar) { Apuntar 'Blender' 'falta' 'winget install --id BlenderFoundation.Blender -e' }
else {
    Instalar-Winget 'BlenderFoundation.Blender'
    if (Test-Path 'C:\Program Files\Blender Foundation') { Apuntar 'Blender' 'instalado' } else { Apuntar 'Blender' 'falta' 'No se pudo instalar Blender con winget.' }
}

# Blender guarda sus addons por versión; la de la Tienda de Microsoft los guarda dentro de su paquete.
$basesBlender = @(Join-Path $env:APPDATA 'Blender Foundation\Blender')
if ($blenderTienda) { $basesBlender += Join-Path $blenderTienda.FullName 'LocalCache\Roaming\Blender Foundation\Blender' }
$carpetasAddons = @(foreach ($b in $basesBlender) {
    Get-ChildItem $b -Directory -ErrorAction SilentlyContinue | Where-Object Name -match '^\d+\.\d+' |
        Sort-Object { [version]$_.Name } -Descending | ForEach-Object { Join-Path $_.FullName 'scripts\addons' }
})
$addon = $carpetasAddons | ForEach-Object { Join-Path $_ 'blender_mcp.py'; Join-Path $_ 'addon.py' } | Where-Object { Test-Path $_ } | Select-Object -First 1
$pasoAddon = 'En Blender: Editar > Preferencias > Complementos, activa "Blender MCP" y desmarca la casilla de telemetría.'
if ($addon) { Apuntar 'Addon de Blender' 'bien' "Comprueba que está activado y con la telemetría desmarcada." }
elseif (-not $carpetasAddons) { Apuntar 'Addon de Blender' 'te toca' 'Abre Blender una vez y ciérralo (crea su carpeta de usuario). Después repite este diagnóstico.' }
elseif ($SoloMirar -or -not (Hay 'uvx')) { Apuntar 'Addon de Blender' 'falta' 'uvx mcp-for-blender@2.1.3 install-addon' }
else {
    uvx mcp-for-blender@2.1.3 install-addon --addons-dir $carpetasAddons[0] | Out-Null
    if ($LASTEXITCODE -eq 0) { Apuntar 'Addon de Blender' 'te toca' "Copiado. $pasoAddon" } else { Apuntar 'Addon de Blender' 'falta' 'install-addon falló.' }
}

if ([Environment]::GetEnvironmentVariable('BLENDER_MCP_DISABLE_TELEMETRY', 'User') -eq 'true') { Apuntar 'Telemetría de Blender apagada' 'bien' }
elseif ($SoloMirar) { Apuntar 'Telemetría de Blender apagada' 'falta' 'Variable de usuario BLENDER_MCP_DISABLE_TELEMETRY=true' }
else {
    [Environment]::SetEnvironmentVariable('BLENDER_MCP_DISABLE_TELEMETRY', 'true', 'User')
    Apuntar 'Telemetría de Blender apagada' 'instalado' 'Variable de usuario puesta. La casilla del addon también hay que desmarcarla.'
}

# 5. CLI de Kaggle (modelos 3D en la nube)
function Ruta-Kaggle {
    $k = (Get-Command kaggle.exe -ErrorAction SilentlyContinue | Select-Object -First 1).Source
    if (-not $k) { $k = Get-ChildItem (Join-Path $env:APPDATA 'Python\Python3*\Scripts\kaggle.exe') -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName }
    return $k
}
if (Ruta-Kaggle) { Apuntar 'CLI de Kaggle' 'bien' }
elseif ($SoloMirar -or -not (Hay 'py')) { Apuntar 'CLI de Kaggle' 'falta' 'py -m pip install --user kaggle==2.2.4' }
else {
    py -m pip install --user --quiet kaggle==2.2.4 | Out-Null
    if (Ruta-Kaggle) { Apuntar 'CLI de Kaggle' 'instalado' } else { Apuntar 'CLI de Kaggle' 'falta' 'pip no pudo instalar kaggle.' }
}

# 6. MCP de Google Flow (copia arreglada que lleva el plugin; va en la cuenta de cada uno)
$mcpUsuario = @{}
if (Hay 'node') {
    $texto = node (Join-Path $PSScriptRoot 'mcp-usuario.js')
    ($texto | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $mcpUsuario[$_.Name] = $_.Value }
}
if ($mcpUsuario.ContainsKey('google-flow')) { Apuntar 'MCP de Google Flow' 'bien' }
elseif ($SoloMirar -or -not (Hay 'npm') -or -not (Hay 'claude')) { Apuntar 'MCP de Google Flow' 'falta' 'Se instala desde mcp/google-flow del plugin.' }
else {
    $destino = Join-Path $env:USERPROFILE '.claude\mcp-servers\google-flow-roblox-kit'
    New-Item -ItemType Directory -Force $destino | Out-Null
    Copy-Item -Recurse -Force (Join-Path $raizPlugin 'mcp\google-flow\*') $destino
    Push-Location $destino
    npm install --omit=dev --no-audit --no-fund --silent | Out-Null
    Pop-Location
    $indice = Join-Path $destino 'dist\src\index.js'
    claude mcp add --scope user google-flow -- node $indice | Out-Null
    if ($LASTEXITCODE -eq 0) { Apuntar 'MCP de Google Flow' 'te toca' 'Instalado. La primera vez que Claude abra Flow, inicia sesión con tu cuenta de Google en la ventana de Chrome.' }
    else { Apuntar 'MCP de Google Flow' 'falta' 'No se pudo registrar en Claude Code.' }
}

# 7. Roblox Studio y su MCP (paso de la persona)
if (-not (Test-Path (Join-Path $env:LOCALAPPDATA 'Roblox\Versions'))) { Apuntar 'Roblox Studio' 'te toca' 'Instala Roblox Studio desde create.roblox.com e inicia sesión.' }
elseif (Test-Path (Join-Path $env:LOCALAPPDATA 'Roblox\mcp.bat')) { Apuntar 'MCP de Studio' 'bien' }
else { Apuntar 'MCP de Studio' 'te toca' 'En Studio: Assistant > Manage MCP Servers > Enable Studio as MCP server.' }

# 8. Claves cifradas (pasos de la persona: nunca pasan por el chat)
$claves = Join-Path $PSScriptRoot 'claves'
if (Test-Path (Join-Path $env:LOCALAPPDATA 'RobloxOpenCloud\clave.dat')) { Apuntar 'Clave de Open Cloud' 'bien' }
else { Apuntar 'Clave de Open Cloud' 'te toca' "Abre el Bitwarden Send que te mandó Álvaro, copia la clave y ejecuta en una ventana tuya: powershell -NoProfile -ExecutionPolicy Bypass -File `"$claves\GuardarClaveOpenCloud.ps1`"" }
if (Test-Path (Join-Path $env:LOCALAPPDATA 'Kaggle\clave.dat')) { Apuntar 'Token de Kaggle' 'bien' }
else { Apuntar 'Token de Kaggle' 'te toca' "Crea tu cuenta en kaggle.com, verifica el teléfono, en Settings > API pulsa Generate New Token, cópialo y ejecuta en una ventana tuya: powershell -NoProfile -ExecutionPolicy Bypass -File `"$claves\GuardarClaveKaggle.ps1`"" }

# 9. El plugin
$pluginInstalado = $false
if (Hay 'claude') {
    $lista = claude plugin list 2>$null | Out-String
    $pluginInstalado = $lista -match 'roblox-kit'
    if ($pluginInstalado) { Apuntar 'Plugin roblox-kit' 'bien' }
    elseif ($SoloMirar) { Apuntar 'Plugin roblox-kit' 'falta' 'claude plugin marketplace add AlvaroCepa/roblox-kit; claude plugin install roblox-kit@roblox-kit' }
    else {
        claude plugin marketplace add AlvaroCepa/roblox-kit | Out-Null
        claude plugin install roblox-kit@roblox-kit | Out-Null
        $pluginInstalado = (claude plugin list 2>$null | Out-String) -match 'roblox-kit'
        if ($pluginInstalado) { Apuntar 'Plugin roblox-kit' 'instalado' 'Reinicia Claude Code para que cargue los hooks y los MCP.' } else { Apuntar 'Plugin roblox-kit' 'falta' 'No se pudo instalar desde el marketplace.' }
    }
} else { Apuntar 'Claude Code' 'falta' 'No se encuentra el comando claude.' }

# 10. Duplicados que conviene quitar (no se quitan solos)
if ($pluginInstalado) {
    foreach ($n in @('Roblox_Studio', 'blender')) {
        if ($mcpUsuario.ContainsKey($n)) { Apuntar "MCP $n repetido" 'aviso' "El plugin ya lo trae. Quita el tuyo con: claude mcp remove $n -s user" }
    }
}
if (Test-Path (Join-Path $env:USERPROFILE '.claude\skills\puntuar-idea-roblox')) {
    Apuntar 'Skill puntuar-idea-roblox repetida' 'aviso' 'El plugin ya la trae. La personal de ~/.claude/skills sobra.'
}

# Resumen: una línea por pieza
Write-Host ''
Write-Host 'roblox-kit: diagnóstico' -ForegroundColor Cyan
$colores = @{ 'bien' = 'Green'; 'instalado' = 'Green'; 'falta' = 'Red'; 'te toca' = 'Yellow'; 'aviso' = 'Yellow' }
foreach ($r in $resultados) {
    $linea = '[{0}] {1}' -f $r.Estado, $r.Pieza
    if ($r.Detalle) { $linea += ': ' + $r.Detalle }
    Write-Host $linea -ForegroundColor $colores[$r.Estado]
}
$faltan = @($resultados | Where-Object Estado -eq 'falta').Count
$teToca = @($resultados | Where-Object Estado -eq 'te toca').Count
Write-Host ''
Write-Host ("Faltan {0}. Pasos tuyos: {1}." -f $faltan, $teToca)
if ($faltan) { exit 1 } else { exit 0 }
