# Prueba mínima de Open Cloud Luau Execution: ejecuta un script en el sitio de pruebas
# y muestra el resultado. Lee la clave cifrada y nunca la muestra.
# Por defecto usa «Pruebas», el sitio de pruebas compartido del grupo.
# Uso: powershell -NoProfile -ExecutionPolicy Bypass -File ProbarOpenCloud.ps1 [-Script 'return 1 + 1']
param(
    [string]$UniverseId = '10770494073',
    [string]$PlaceId = '105671962169214',
    [string]$Script = 'return 1 + 1'
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$archivo = Join-Path $env:LOCALAPPDATA 'RobloxOpenCloud\clave.dat'
if (-not (Test-Path $archivo)) {
    Write-Host 'Falta la clave. Ejecuta antes GuardarClaveOpenCloud.ps1.'
    exit 1
}
$segura = Get-Content -Path $archivo | ConvertTo-SecureString
$clave = [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($segura))
$cabeceras = @{ 'x-api-key' = $clave }
$clave = $null

$base = 'https://apis.roblox.com/cloud/v2'
$cuerpo = @{ script = $Script } | ConvertTo-Json
try {
    $tarea = Invoke-RestMethod -Method Post -Uri "$base/universes/$UniverseId/places/$PlaceId/luau-execution-session-tasks" `
        -Headers $cabeceras -ContentType 'application/json' -Body $cuerpo
    Write-Host "Tarea creada: estado $($tarea.state)"

    $limite = (Get-Date).AddMinutes(2)
    while ($tarea.state -in @('QUEUED', 'PROCESSING') -and (Get-Date) -lt $limite) {
        Start-Sleep -Seconds 3
        $tarea = Invoke-RestMethod -Method Get -Uri "$base/$($tarea.path)" -Headers $cabeceras
    }

    Write-Host "Estado final: $($tarea.state)"
    if ($tarea.output) { Write-Host "Resultado: $($tarea.output.results | ConvertTo-Json -Compress)" }
    if ($tarea.error) { Write-Host "Error: $($tarea.error.code) - $($tarea.error.message)" }
    if ($tarea.state -ne 'COMPLETE') { exit 1 }
}
catch {
    $codigo = $_.Exception.Response.StatusCode.value__
    Write-Host "Fallo HTTP $codigo"
    if ($_.ErrorDetails.Message) { Write-Host $_.ErrorDetails.Message }
    exit 1
}
