# Sube assets/ del juego al GRUPO con Asphalt y la clave de Open Cloud del PC, y regenera src/shared/Assets.
# Lee la clave cifrada (DPAPI) de %LOCALAPPDATA%\RobloxOpenCloud\clave.dat y se la pasa SOLO al proceso hijo
# (variable ASPHALT_API_KEY de ese proceso). Nunca la imprime ni la deja en este proceso.
# El hook del plugin pregunta antes de lanzarlo: si Roblox modera algo, cae sobre el grupo o la cuenta bot.
# Uso, desde la carpeta del juego:
#   powershell -NoProfile -ExecutionPolicy Bypass -File <plugin>\kit\subir-assets.ps1 [--dry-run]
#   --dry-run: solo dice qué se subiría (no sube nada ni pide permiso).
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath 'asphalt.toml')) {
    Write-Output 'subir-assets: no hay asphalt.toml aquí. Lánzalo desde la carpeta del juego.'
    exit 1
}
$archivo = Join-Path $env:LOCALAPPDATA 'RobloxOpenCloud\clave.dat'
if (-not (Test-Path -LiteralPath $archivo)) {
    Write-Output 'subir-assets: falta la clave en este PC. Guárdala antes con scripts\claves\GuardarClaveOpenCloud.ps1.'
    exit 1
}

# Asphalt: el de Rokit (versión fijada por el juego); si no, el del PATH.
$asphalt = Join-Path $env:USERPROFILE '.rokit\bin\asphalt.exe'
if (-not (Test-Path -LiteralPath $asphalt)) { $asphalt = 'asphalt' }

$segura = Get-Content -LiteralPath $archivo | ConvertTo-SecureString
$puntero = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($segura)
try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $asphalt
    $psi.Arguments = if ($args -contains '--dry-run') { 'sync cloud --dry-run' } else { 'sync cloud' }
    $psi.WorkingDirectory = (Get-Location).Path
    $psi.UseShellExecute = $false
    $psi.EnvironmentVariables['ASPHALT_API_KEY'] = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($puntero)
    $proceso = [System.Diagnostics.Process]::Start($psi)
    $psi.EnvironmentVariables.Remove('ASPHALT_API_KEY')
    $proceso.WaitForExit()
    $codigo = $proceso.ExitCode
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($puntero)
}

if ($args -contains '--dry-run') { exit $codigo }
if ($codigo -eq 0) {
    Write-Output 'subir-assets: subido y src/shared/Assets al día. Ojo: Roblox tarda unos minutos en moderar lo nuevo; mientras, sale en blanco o PreloadAsync falla (no es un fallo del juego). asphalt.lock.toml y src/shared/Assets van en el commit.'
}
else {
    Write-Output "subir-assets: Asphalt terminó con código $codigo (mira el mensaje de arriba)."
}
exit $codigo
