# Funciones comunes de los hooks de roblox-kit. Cada hook lo carga con: . "$PSScriptRoot\comun.ps1"
# Un hook recibe un JSON por la entrada estándar y, si quiere decir algo, contesta con JSON por la salida.
# Regla: un hook nunca imprime nada más que ese JSON, y el registro nunca rompe un hook.

$ErrorActionPreference = 'Stop'
$script:utf8 = New-Object System.Text.UTF8Encoding $false

# Se lee y se escribe en bytes UTF-8: así las tildes llegan bien aunque la consola use otra página de códigos.
function Leer-Entrada {
    $lector = New-Object System.IO.StreamReader([Console]::OpenStandardInput(), $script:utf8)
    $texto = $lector.ReadToEnd()
    if (-not $texto -or -not $texto.Trim()) { return [pscustomobject]@{} }
    return $texto | ConvertFrom-Json
}

function Escribir([string]$Texto) {
    $bytes = $script:utf8.GetBytes($Texto)
    $salida = [Console]::OpenStandardOutput()
    $salida.Write($bytes, 0, $bytes.Length)
    $salida.Flush()
}

# Carpeta del juego: la de la sesión, aunque Claude haya entrado en una subcarpeta.
function Raiz-Proyecto($Entrada) {
    if ($env:CLAUDE_PROJECT_DIR) { return $env:CLAUDE_PROJECT_DIR }
    if ($Entrada -and $Entrada.cwd) { return $Entrada.cwd }
    return (Get-Location).Path
}

# Es un juego de Roblox si tiene un proyecto de Rojo en la raíz.
function Es-ProyectoRoblox([string]$Raiz) {
    if (-not $Raiz -or -not (Test-Path -LiteralPath $Raiz)) { return $false }
    return [bool](Get-ChildItem -LiteralPath $Raiz -Filter '*.project.json' -File -ErrorAction SilentlyContinue | Select-Object -First 1)
}

# Datos del plugin en este PC (registro, marcas). Sobrevive a las actualizaciones del plugin.
function Ruta-Datos {
    $ruta = $env:CLAUDE_PLUGIN_DATA
    if (-not $ruta) { $ruta = Join-Path $env:LOCALAPPDATA 'roblox-kit' }
    if (-not (Test-Path -LiteralPath $ruta)) { New-Item -ItemType Directory -Force -Path $ruta | Out-Null }
    return $ruta
}

# Quién está trabajando: la sesión principal o un subagente concreto.
function Clave-Agente($Entrada) {
    $agente = if ($Entrada.agent_id) { $Entrada.agent_id } else { 'principal' }
    return (("{0}-{1}" -f $Entrada.session_id, $agente) -replace '[^\w\-]', '_')
}

# Añade una línea a registro.jsonl. Sirve para elegir modelo y para detectar mejoras.
function Anotar($Entrada, [string]$Evento, [hashtable]$Detalle = @{}) {
    try {
        $effort = $Entrada.effort
        if (-not $effort) { $effort = $env:CLAUDE_EFFORT }
        $linea = [ordered]@{
            fecha    = (Get-Date).ToString('o')
            pc       = $env:COMPUTERNAME
            proyecto = Split-Path -Leaf (Raiz-Proyecto $Entrada)
            sesion   = $Entrada.session_id
            agente   = $(if ($Entrada.agent_type) { $Entrada.agent_type } else { 'principal' })
            effort   = $effort
            evento   = $Evento
            detalle  = $Detalle
        }
        $json = $linea | ConvertTo-Json -Compress -Depth 6
        [IO.File]::AppendAllText((Join-Path (Ruta-Datos) 'registro.jsonl'), $json + "`n", $script:utf8)
    } catch { }
}

function Salir-Json($Objeto) {
    Escribir ($Objeto | ConvertTo-Json -Compress -Depth 8)
    exit 0
}

# Ejecuta un programa y devuelve su código y todo lo que escribió, con tiempo límite.
# Usa Process y no "& programa 2>&1": en PowerShell 5.1 eso convierte stderr en errores.
function Ejecutar([string]$Programa, [string[]]$Argumentos = @(), [string]$Carpeta = (Get-Location).Path, [int]$Segundos = 300) {
    $ruta = (Get-Command $Programa -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
    if (-not $ruta) { return [pscustomobject]@{ Codigo = -2; Salida = "No se encuentra '$Programa'." } }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $ruta
    $psi.Arguments = ($Argumentos | ForEach-Object { if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } }) -join ' '
    $psi.WorkingDirectory = $Carpeta
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $psi.StandardOutputEncoding = $script:utf8
    $psi.StandardErrorEncoding = $script:utf8
    $p = [System.Diagnostics.Process]::Start($psi)
    $salida = $p.StandardOutput.ReadToEndAsync()
    $errores = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit($Segundos * 1000)) {
        try { $p.Kill() } catch { }
        return [pscustomobject]@{ Codigo = -1; Salida = "Tiempo agotado ($Segundos s)." }
    }
    $p.WaitForExit()
    return [pscustomobject]@{ Codigo = $p.ExitCode; Salida = ($salida.Result + "`n" + $errores.Result).Trim() }
}

# Marca "este agente ha cambiado código desde la última comprobación buena".
function Ruta-Marca($Entrada) {
    $carpeta = Join-Path (Ruta-Datos) 'marcas'
    if (-not (Test-Path -LiteralPath $carpeta)) { New-Item -ItemType Directory -Force -Path $carpeta | Out-Null }
    return (Join-Path $carpeta ((Clave-Agente $Entrada) + '.txt'))
}
