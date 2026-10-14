# roblox-kit (skill modelos-3d): ejecuta un script de Python dentro de Blender, sin ventana, y espera a que acabe.
#   powershell -NoProfile -ExecutionPolicy Bypass -File blender.ps1 <script.py> [argumentos del script...]
# Ejemplo (script final de un modelo):
#   blender.ps1 <kit>/skills/modelos-3d/scripts/blender/procesar.py '{"malla": "...", "ficha": "...", ...}'
# La salida del script queda en .kit/blender.log (y se enseña al acabar). Sale con el código del script.
# Busca Blender instalado normal; si no, el de la Microsoft Store (blender-launcher.exe), que se separa de la
# consola: por eso todo pasa por envoltura.py y se espera a la línea final del registro.
param([Parameter(Mandatory = $true)][string]$Script, [Parameter(ValueFromRemainingArguments = $true)][string[]]$Resto)
$ErrorActionPreference = 'Stop'

$blender = (Get-Command blender.exe -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $blender) {
    $blender = Get-ChildItem 'C:\Program Files\Blender Foundation\*\blender.exe' -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $blender) {
    $tienda = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\blender-launcher.exe'
    if (Test-Path -LiteralPath $tienda) { $blender = $tienda }
}
if (-not $blender) { Write-Output 'blender: no encuentro Blender. Lo instala scripts\diagnostico.ps1.'; exit 1 }

$carpeta = Join-Path (Get-Location).Path '.kit'
if (-not (Test-Path -LiteralPath $carpeta)) { New-Item -ItemType Directory -Force -Path $carpeta | Out-Null }
$log = Join-Path $carpeta 'blender.log'
Remove-Item -LiteralPath $log -ErrorAction SilentlyContinue
$envoltura = Join-Path $PSScriptRoot 'blender\envoltura.py'

$argumentos = @('-b', '--factory-startup', '-P', $envoltura, '--', (Resolve-Path -LiteralPath $Script).Path, $log) + $Resto
$lista = ($argumentos | ForEach-Object { if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } }) -join ' '
$proceso = Start-Process -FilePath $blender -ArgumentList $lista -WindowStyle Hidden -PassThru

# Espera a «ROBLOX-KIT FIN» en el registro (como mucho 20 min).
$limite = (Get-Date).AddMinutes(20)
$codigo = $null
while ((Get-Date) -lt $limite) {
    Start-Sleep -Seconds 2
    if (Test-Path -LiteralPath $log) {
        $fin = Select-String -LiteralPath $log -Pattern '^ROBLOX-KIT FIN (\d+)' | Select-Object -Last 1
        if ($fin) { $codigo = [int]$fin.Matches[0].Groups[1].Value; break }
    }
    if ($proceso.HasExited -and -not (Get-Process -Name 'blender' -ErrorAction SilentlyContinue) -and -not (Test-Path -LiteralPath $log)) {
        Start-Sleep -Seconds 3
        if (-not (Test-Path -LiteralPath $log)) { Write-Output 'blender: Blender se cerró sin empezar el script.'; exit 1 }
    }
}
if ($null -eq $codigo) { Write-Output "blender: sin terminar en 20 min. Registro: $log"; exit 1 }
Get-Content -LiteralPath $log -Tail 25 -Encoding UTF8 | Where-Object { $_ -notmatch '^ROBLOX-KIT FIN' }
exit $codigo
