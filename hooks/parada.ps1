# Stop y SubagentStop: al terminar cada turno (o un subagente), comprueba el código antes de pasárselo al usuario.
# - Solo si este agente ha cambiado .lua/.luau desde la última comprobación buena (marca de tras-herramienta.ps1).
# - Juegos con el kit (rokit.toml): kit/comprobar.luau --parada (StyLua, Selene, luau-lsp, rojo build, Lune,
#   reglas y oficios). Si todo va bien pero falta una pasada que no hace comprobar, frena una vez para pedirla
#   (no las lanza el hook):
#     nube: el código de servidor cambió desde la última probar-nube (sube a «Pruebas», un minuto);
#     ui / mapa: cambiaron desde la última pasada buena de su comprobador en Studio. Si Studio está cerrado,
#     no frena: solo avisa al usuario.
# - Juegos antiguos (sin rokit.toml): rojo build y su Comprobar.ps1, si lo tienen.
# - Si algo falla, frena UNA vez para que Claude lo arregle. Si vuelve a fallar, no frena más: avisa al usuario.
. "$PSScriptRoot\comun.ps1"

try {
    $entrada = Leer-Entrada
    $raiz = Raiz-Proyecto $entrada
    if (-not (Es-ProyectoRoblox $raiz)) { exit 0 }
    $marca = Ruta-Marca $entrada
    if (-not (Test-Path -LiteralPath $marca)) { exit 0 }

    $datos = Ruta-Datos
    $repetido = [bool]$entrada.stop_hook_active
    $fallos = @()
    $pasos = @()
    $nombresFallan = @()

    if (Test-Path -LiteralPath (Join-Path $raiz 'rokit.toml')) {
        # Juego con el kit: un solo script hace todo.
        $kit = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
        $comprobar = Join-Path $kit 'kit\comprobar.luau'
        $r = Ejecutar 'lune' @('run', $comprobar, '--parada') $raiz 300
        $log = Join-Path $raiz '.kit\comprobar.log'
        $pasos += 'comprobar'

        if ($r.Codigo -eq 0) {
            Remove-Item -LiteralPath $marca -ErrorAction SilentlyContinue
            Anotar $entrada 'parada' @{ resultado = 'bien'; pasos = $pasos }
            exit 0
        }
        if ($r.Codigo -eq 3) {
            # Comprobaciones bien; faltan pasadas que no hace comprobar (líneas «pendiente: x»).
            Remove-Item -LiteralPath $marca -ErrorAction SilentlyContinue
            $pendientes = @([regex]::Matches($r.Salida, '(?m)^pendiente: (\w+)') | ForEach-Object { $_.Groups[1].Value })
            Anotar $entrada 'parada' @{ resultado = 'bien'; pasos = $pasos; pendientes = $pendientes }
            if ($repetido) { exit 0 }
            $studio = [bool](Get-Process -Name 'RobloxStudioBeta' -ErrorAction SilentlyContinue)
            $kitR = $kit -replace '\\', '/'
            $pedir = @()
            $avisar = @()
            if ($pendientes -contains 'nube') {
                $pedir += "- probar-nube (el código de servidor cambió; sube a «Pruebas» guardado y tarda un minuto): powershell -NoProfile -ExecutionPolicy Bypass -File `"$kitR/kit/probar-nube.ps1`""
            }
            foreach ($que in @('ui', 'mapa')) {
                if ($pendientes -notcontains $que) { continue }
                $modulo = if ($que -eq 'ui') { 'UICheck' } else { 'MapCheck' }
                if ($studio) {
                    $pedir += "- el comprobador de $que en Studio (cambió desde su última pasada buena; con Rojo conectado, en modo Edit): execute_luau `"return require(game.ReplicatedStorage.Shared.Kit.$modulo).run()`""
                }
                else { $avisar += $que }
            }
            $salida = @{}
            if ($avisar.Count) { $salida.systemMessage = "roblox-kit: cambió $($avisar -join ' y ') y Studio está cerrado: falta pasar su comprobador en Studio antes de darlo por bueno." }
            if ($pedir.Count) {
                $salida.decision = 'block'
                $salida.reason = "roblox-kit: comprobar va bien, pero antes de enseñárselo al usuario falta:`n$($pedir -join "`n")`nSi falla, arréglalo. Si el usuario ha dicho que ahora no, sigue sin lanzarlo."
            }
            if ($salida.Count) { Salir-Json $salida }
            exit 0
        }
        if ($r.Codigo -eq -2) {
            # Sin Lune no hay comprobar: se avisa una vez al usuario y no se frena.
            Remove-Item -LiteralPath $marca -ErrorAction SilentlyContinue
            Anotar $entrada 'falta-herramienta' @{ herramienta = @('lune') }
            Salir-Json @{ systemMessage = 'roblox-kit: no se ha podido comprobar el código porque falta Lune. En la carpeta del juego: rokit install' }
        }
        $fallos += $r.Salida
        $primera = ($r.Salida -split "`n")[0]
        if ($primera -match 'falla ([^(]+)\(') { $nombresFallan = @($matches[1].Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
        else { $nombresFallan = @('comprobar') }
    }
    else {
        # Juego antiguo: lo que hubiera antes del kit.
        $registro = @()
        $proyecto = Join-Path $raiz 'default.project.json'
        if (Test-Path -LiteralPath $proyecto) {
            $sitio = Join-Path $datos ("build-{0}.rbxl" -f (Clave-Agente $entrada))
            $r = Ejecutar 'rojo' @('build', 'default.project.json', '-o', $sitio) $raiz 120
            $pasos += 'rojo build'
            $registro += "== rojo build (código $($r.Codigo))`n$($r.Salida)"
            if ($r.Codigo -ne 0) {
                $fallos += "rojo build:`n" + (($r.Salida -split "`n" | Select-Object -Last 15) -join "`n")
                $nombresFallan += 'rojo build'
            }
            Remove-Item -LiteralPath $sitio -ErrorAction SilentlyContinue
        }
        $propio = @('Comprobar.ps1', 'Herramientas\Comprobar.ps1', 'scripts\Comprobar.ps1') |
            ForEach-Object { Join-Path $raiz $_ } | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
        if ($propio) {
            $r = Ejecutar 'powershell.exe' @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $propio) $raiz 300
            $pasos += 'Comprobar.ps1'
            $registro += "== $propio (código $($r.Codigo))`n$($r.Salida)"
            if ($r.Codigo -ne 0) {
                $fallos += "Comprobar.ps1:`n" + (($r.Salida -split "`n" | Where-Object { $_.Trim() } | Select-Object -First 20) -join "`n")
                $nombresFallan += 'Comprobar.ps1'
            }
        }
        $log = Join-Path $datos 'ultima-comprobacion.log'
        Set-Content -LiteralPath $log -Value ($registro -join "`n`n") -Encoding UTF8

        if (-not $fallos.Count) {
            Remove-Item -LiteralPath $marca -ErrorAction SilentlyContinue
            Anotar $entrada 'parada' @{ resultado = 'bien'; pasos = $pasos }
            exit 0
        }
    }

    Anotar $entrada 'parada' @{ resultado = 'mal'; pasos = $pasos; fallan = $nombresFallan; repetido = $repetido }
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
