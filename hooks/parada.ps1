# Stop y SubagentStop: al terminar cada turno (o un subagente), comprueba el código antes de pasárselo al usuario.
# - Solo si este agente ha cambiado .lua/.luau desde la última comprobación buena (marca de tras-herramienta.ps1).
# - Pasos: rojo build y, si el juego lo tiene, su script de comprobación (luau-lsp).
#   En la tanda 2 del plugin esto pasa a ser el script `comprobar` (StyLua, Selene, luau-lsp, rojo build y Lune).
# - Si algo falla, frena UNA vez para que Claude lo arregle. Si vuelve a fallar, no frena más: avisa al usuario.
. "$PSScriptRoot\comun.ps1"

try {
    $entrada = Leer-Entrada
    $raiz = Raiz-Proyecto $entrada
    if (-not (Es-ProyectoRoblox $raiz)) { exit 0 }
    $marca = Ruta-Marca $entrada
    if (-not (Test-Path -LiteralPath $marca)) { exit 0 }

    $datos = Ruta-Datos
    $fallos = @()
    $registro = @()
    $pasos = @()

    # 1. rojo build: el sitio se construye entero sin Studio.
    $proyecto = Join-Path $raiz 'default.project.json'
    if (Test-Path -LiteralPath $proyecto) {
        $sitio = Join-Path $datos ("build-{0}.rbxl" -f (Clave-Agente $entrada))
        $r = Ejecutar 'rojo' @('build', 'default.project.json', '-o', $sitio) $raiz 120
        $pasos += 'rojo build'
        $registro += "== rojo build (código $($r.Codigo))`n$($r.Salida)"
        if ($r.Codigo -ne 0) { $fallos += "rojo build:`n" + (($r.Salida -split "`n" | Select-Object -Last 15) -join "`n") }
        Remove-Item -LiteralPath $sitio -ErrorAction SilentlyContinue
    }

    # 2. Comprobación propia del juego (tipos con luau-lsp), si existe.
    $comprobar = @('Comprobar.ps1', 'Herramientas\Comprobar.ps1', 'scripts\Comprobar.ps1') |
        ForEach-Object { Join-Path $raiz $_ } | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($comprobar) {
        $r = Ejecutar 'powershell.exe' @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $comprobar) $raiz 300
        $pasos += 'Comprobar.ps1'
        $registro += "== $comprobar (código $($r.Codigo))`n$($r.Salida)"
        if ($r.Codigo -ne 0) { $fallos += "Comprobar.ps1:`n" + (($r.Salida -split "`n" | Where-Object { $_.Trim() } | Select-Object -First 20) -join "`n") }
    }

    $log = Join-Path $datos 'ultima-comprobacion.log'
    Set-Content -LiteralPath $log -Value ($registro -join "`n`n") -Encoding UTF8

    if (-not $fallos.Count) {
        Remove-Item -LiteralPath $marca -ErrorAction SilentlyContinue
        Anotar $entrada 'parada' @{ resultado = 'bien'; pasos = $pasos }
        exit 0
    }

    $repetido = [bool]$entrada.stop_hook_active
    Anotar $entrada 'parada' @{ resultado = 'mal'; pasos = $pasos; fallan = @($fallos | ForEach-Object { ($_ -split ':')[0] }); repetido = $repetido }
    $resumen = $fallos -join "`n`n"

    if ($repetido) {
        # Ya frenó una vez y sigue fallando: no se insiste, se avisa al usuario.
        Salir-Json @{ systemMessage = "roblox-kit: las comprobaciones siguen fallando después de un intento. Detalle en $log`n$resumen" }
    }
    Salir-Json @{
        decision = 'block'
        reason   = "roblox-kit: las comprobaciones fallan. Arréglalo antes de pasarle el trabajo al usuario.`n`n$resumen"
    }
}
catch {
    Anotar $entrada 'error-hook' @{ hook = 'parada'; mensaje = $_.Exception.Message }
    exit 0
}
