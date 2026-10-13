# Guarda el token de la API de Kaggle cifrado con DPAPI (solo tu usuario de Windows puede leerlo).
# Uso: en kaggle.com/settings > API > "Generate New Token", copia el token y ejecuta este script.
# Lee el token del portapapeles, lo cifra en %LOCALAPPDATA%\Kaggle\clave.dat y vacía el portapapeles.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms

$token = (Get-Clipboard -Raw)
if ($token) { $token = $token.Trim() }
if (-not $token -or $token.Length -lt 20 -or $token -match '\s') {
    Write-Host 'El portapapeles no parece tener un token de Kaggle. No se ha guardado nada.'
    exit 1
}

$carpeta = Join-Path $env:LOCALAPPDATA 'Kaggle'
New-Item -ItemType Directory -Force -Path $carpeta | Out-Null
ConvertTo-SecureString $token -AsPlainText -Force |
    ConvertFrom-SecureString |
    Set-Content -Path (Join-Path $carpeta 'clave.dat') -Encoding ascii

[System.Windows.Forms.Clipboard]::Clear()
$token = $null
Write-Host "Token guardado cifrado en $carpeta\clave.dat. Portapapeles vaciado."
