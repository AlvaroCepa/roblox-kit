# Ejecuta la CLI de Kaggle con el token cifrado por GuardarClaveKaggle.ps1.
# El token solo se pasa al proceso de Kaggle y nunca se imprime.
# Ejemplo: powershell -NoProfile -ExecutionPolicy Bypass -File Kaggle.ps1 kernels list --mine
$ErrorActionPreference = 'Stop'

$archivo = Join-Path $env:LOCALAPPDATA 'Kaggle\clave.dat'
if (-not (Test-Path $archivo)) {
    Write-Host 'Falta el token. Ejecuta antes GuardarClaveKaggle.ps1.'
    exit 1
}

# La CLI se instala con `py -m pip install --user kaggle`, en la carpeta Scripts de esa versión de Python.
$kaggle = (Get-Command kaggle.exe -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $kaggle) {
    $kaggle = Get-ChildItem (Join-Path $env:APPDATA 'Python\Python3*\Scripts\kaggle.exe') -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $kaggle) {
    Write-Host 'Falta la CLI de Kaggle. Instala con: py -m pip install --user kaggle'
    exit 1
}

# Sin esto la CLI falla al escribir tildes o emojis en la consola de Windows.
$env:PYTHONIOENCODING = 'utf-8'
$env:PYTHONUTF8 = '1'

$seguro = Get-Content $archivo | ConvertTo-SecureString
$puntero = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($seguro)
try {
    $env:KAGGLE_API_TOKEN = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($puntero)
    & $kaggle @args
    $codigo = $LASTEXITCODE
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($puntero)
    Remove-Item Env:KAGGLE_API_TOKEN -ErrorAction SilentlyContinue
}
exit $codigo
