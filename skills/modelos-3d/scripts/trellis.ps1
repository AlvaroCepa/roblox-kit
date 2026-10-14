# roblox-kit (skill modelos-3d): formas 3D con TRELLIS en Kaggle, TODAS las imágenes en una tanda.
#   powershell -NoProfile -ExecutionPolicy Bypass -File trellis.ps1 -Imagenes <carpeta> -Juego <nombre> [-Usuario <kaggle>]
# <carpeta>: un PNG por modelo (el nombre del archivo es el del modelo), fondo liso. Desde la carpeta del juego.
# 1. Sube las imágenes a un dataset PRIVADO de Kaggle del juego (<usuario>/<juego>-modelos-3d), versión nueva si ya existe.
# 2. Lanza el notebook (scripts/kaggle/trellis.py) en GPU, privado, y espera (cola + ~3 min + ~30 s por modelo).
# 3. Baja las mallas a .kit/kaggle/salida/ (<modelo>.glb e informe_modelo.json). Las salidas se quedan también en
#    Kaggle (versiones del notebook): la malla en bruto no se puede repetir igual, así no se pierde.
# Tarda: lánzalo en segundo plano y sigue con otra cosa. Gratis (~30 h de GPU a la semana).
# El token va cifrado (scripts/claves/Kaggle.ps1); el usuario de Kaggle se guarda en %LOCALAPPDATA%\Kaggle\usuario.txt.
param(
    [Parameter(Mandatory = $true)][string]$Imagenes,
    [Parameter(Mandatory = $true)][string]$Juego,
    [string]$Usuario,
    [string]$Maquina = 'NvidiaTeslaP100' # la cola de las T4 llegó a 30 min; la P100 cabe igual
)
$ErrorActionPreference = 'Stop'
$kaggle = Join-Path $PSScriptRoot '..\..\..\scripts\claves\Kaggle.ps1'
# Kaggle con el token cifrado. Lo que escriba en stderr no debe parar el script (PowerShell 5.1 lo trata como error).
function K {
    $ErrorActionPreference = 'Continue'
    $salida = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $kaggle @args 2>&1 | ForEach-Object { "$_" }
    return [pscustomobject]@{ Codigo = $LASTEXITCODE; Texto = ($salida -join "`n") }
}
# JSON en UTF-8 sin BOM (Set-Content -Encoding UTF8 de PowerShell 5.1 pone BOM y la CLI de Kaggle no lo lee).
function Escribir-Json($Objeto, [string]$Ruta) {
    [IO.File]::WriteAllText($Ruta, ($Objeto | ConvertTo-Json -Depth 4), (New-Object System.Text.UTF8Encoding $false))
}

$pngs = @(Get-ChildItem -LiteralPath $Imagenes -Filter '*.png' -File)
if (-not $pngs.Count) { Write-Output "trellis: no hay PNG en $Imagenes"; exit 1 }
$slug = ($Juego.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')

# Usuario de Kaggle: el parámetro, el guardado o el de sus notebooks.
$archivoUsuario = Join-Path $env:LOCALAPPDATA 'Kaggle\usuario.txt'
if (-not $Usuario -and (Test-Path -LiteralPath $archivoUsuario)) { $Usuario = (Get-Content -LiteralPath $archivoUsuario -TotalCount 1).Trim() }
if (-not $Usuario) {
    $r = K kernels list --mine --csv
    $fila = ($r.Texto -split "`n" | Select-Object -Skip 1 | Select-Object -First 1)
    if ($fila -match '^([^/,]+)/') { $Usuario = $matches[1] }
}
if (-not $Usuario) { Write-Output 'trellis: no sé tu usuario de Kaggle. Pásalo con -Usuario (se guarda para la próxima).'; exit 1 }
Set-Content -LiteralPath $archivoUsuario -Value $Usuario -Encoding UTF8

$base = Join-Path (Get-Location).Path '.kit\kaggle'
$datos = Join-Path $base 'datos'
$cuaderno = Join-Path $base 'trellis'
$salida = Join-Path $base 'salida'
foreach ($c in @($datos, $cuaderno)) { if (Test-Path -LiteralPath $c) { Remove-Item -LiteralPath $c -Recurse -Force }; New-Item -ItemType Directory -Force -Path $c | Out-Null }

# 1. Dataset privado con las imágenes.
$dataset = "$Usuario/$slug-modelos-3d"
$pngs | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $datos }
Escribir-Json @{ title = "$slug-modelos-3d"; id = $dataset; licenses = @(@{ name = 'other' }) } (Join-Path $datos 'dataset-metadata.json')
$existe = (K datasets files $dataset).Codigo -eq 0
$r = if ($existe) { K datasets version -p $datos -m "imágenes $(Get-Date -Format 'yyyy-MM-dd HH:mm')" } else { K datasets create -p $datos }
if ($r.Codigo -ne 0) { Write-Output "trellis: no se pudo subir el dataset:`n$($r.Texto)"; exit 1 }
Write-Output "trellis: $($pngs.Count) imagen(es) en el dataset privado $dataset"
for ($i = 0; $i -lt 60; $i++) {
    $estado = (K datasets status $dataset).Texto
    if ($estado -match 'ready') { break }
    Start-Sleep -Seconds 5
}

# 2. Notebook en GPU.
$kernel = "$Usuario/$slug-trellis"
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'kaggle\trellis.py') -Destination $cuaderno
Escribir-Json @{
    id = $kernel; title = "$slug-trellis"; code_file = 'trellis.py'; language = 'python'; kernel_type = 'script'
    is_private = $true; enable_gpu = $true; enable_internet = $true; machine_shape = $Maquina
    dataset_sources = @($dataset); kernel_sources = @(); competition_sources = @()
} (Join-Path $cuaderno 'kernel-metadata.json')
$r = K kernels push -p $cuaderno
if ($r.Codigo -ne 0) { Write-Output "trellis: no se pudo lanzar el notebook:`n$($r.Texto)"; exit 1 }
$inicio = Get-Date
Write-Output "trellis: lanzado $kernel ($Maquina). Esperando..."

$fin = $inicio.AddMinutes(90)
$estado = ''
while ((Get-Date) -lt $fin) {
    Start-Sleep -Seconds 30
    $estado = (K kernels status $kernel).Texto
    if ($estado -match '(?i)complete|error|cancel') { break }
}
$minutos = [math]::Round(((Get-Date) - $inicio).TotalMinutes, 1)
if ($estado -notmatch '(?i)complete') { Write-Output "trellis: el notebook no terminó bien tras $minutos min: $estado (mira el registro en kaggle.com/code/$kernel)"; exit 1 }

# 3. Bajar las mallas.
if (Test-Path -LiteralPath $salida) { Remove-Item -LiteralPath $salida -Recurse -Force }
New-Item -ItemType Directory -Force -Path $salida | Out-Null
$r = K kernels output $kernel -p $salida
if ($r.Codigo -ne 0) { Write-Output "trellis: terminó pero no se pudo bajar la salida:`n$($r.Texto)"; exit 1 }
$glbs = @(Get-ChildItem -LiteralPath $salida -Filter '*.glb' -Recurse -File)
Write-Output "trellis: bien en $minutos min. $($glbs.Count) malla(s) en .kit\kaggle\salida: $(($glbs | ForEach-Object { $_.BaseName }) -join ', ')"
