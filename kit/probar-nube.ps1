# Lanza kit/probar-nube.luau en Windows con la clave de Open Cloud del PC.
# Lee la clave cifrada (DPAPI) de %LOCALAPPDATA%\RobloxOpenCloud\clave.dat y se la pasa SOLO al proceso hijo
# (variable ROBLOX_API_KEY de ese proceso). Nunca la imprime ni la deja en este proceso.
# Uso, desde la carpeta del juego:
#   powershell -NoProfile -ExecutionPolicy Bypass -File <plugin>\kit\probar-nube.ps1 [--universo <id> --sitio <id>]
$ErrorActionPreference = 'Stop'

$archivo = Join-Path $env:LOCALAPPDATA 'RobloxOpenCloud\clave.dat'
if (-not (Test-Path -LiteralPath $archivo)) {
    Write-Output 'probar-nube: falta la clave en este PC. Guárdala antes con scripts\claves\GuardarClaveOpenCloud.ps1.'
    exit 1
}

# Lune: el de Rokit (versión fijada por el juego); si no, el del PATH.
$lune = Join-Path $env:USERPROFILE '.rokit\bin\lune.exe'
if (-not (Test-Path -LiteralPath $lune)) { $lune = 'lune' }

$segura = Get-Content -LiteralPath $archivo | ConvertTo-SecureString
$puntero = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($segura)
try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $lune
    $argumentos = @('run', (Join-Path $PSScriptRoot 'probar-nube.luau')) + $args
    $psi.Arguments = ($argumentos | ForEach-Object { if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } }) -join ' '
    $psi.WorkingDirectory = (Get-Location).Path
    $psi.UseShellExecute = $false
    $psi.EnvironmentVariables['ROBLOX_API_KEY'] = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($puntero)
    $proceso = [System.Diagnostics.Process]::Start($psi)
    $psi.EnvironmentVariables.Remove('ROBLOX_API_KEY')
    $proceso.WaitForExit()
    exit $proceso.ExitCode
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($puntero)
}
