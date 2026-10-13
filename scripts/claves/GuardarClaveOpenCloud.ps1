# Guarda la clave de Open Cloud cifrada con el usuario de Windows (DPAPI).
# Solo este usuario, en este PC, puede descifrarla. La lee del portapapeles,
# no la muestra en ningún momento y vacía el portapapeles al acabar.
# Uso: powershell -NoProfile -ExecutionPolicy Bypass -File GuardarClaveOpenCloud.ps1
$ErrorActionPreference = 'Stop'
try {
    $carpeta = Join-Path $env:LOCALAPPDATA 'RobloxOpenCloud'
    $archivo = Join-Path $carpeta 'clave.dat'

    Read-Host 'Copia la clave desde Bitwarden y despues pulsa Enter aqui'

    $texto = ((Get-Clipboard) -join '').Trim()
    if ($texto.Length -lt 20 -or $texto -match '\s') {
        throw 'Lo copiado no parece una clave. No se ha guardado nada.'
    }

    $segura = ConvertTo-SecureString -String $texto -AsPlainText -Force
    $longitud = $texto.Length
    $texto = $null

    New-Item -ItemType Directory -Force -Path $carpeta | Out-Null
    $segura | ConvertFrom-SecureString | Set-Content -Path $archivo -Encoding ASCII
    cmd /c 'echo off | clip'

    Write-Host ''
    Write-Host "Guardada cifrada ($longitud caracteres) en:" -ForegroundColor Green
    Write-Host $archivo
    Write-Host 'Portapapeles vaciado.'
}
catch {
    Write-Host ''
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}
Read-Host 'Pulsa Enter para cerrar'
