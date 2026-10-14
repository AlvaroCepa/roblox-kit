# PreToolUse de Bash y PowerShell: frenos de las órdenes que salen hacia fuera.
# - Subir assets al grupo (kit/subir-assets.ps1 o «asphalt sync» a la nube) -> preguntar: si Roblox modera
#   algo, cae sobre el grupo o la cuenta bot. Ver sin subir (--dry-run, asphalt sync studio/debug) no frena.
# - gh pr merge en un juego -> solo con la CI en verde (GitHub gratis no deja exigirlo en repos privados, por
#   eso lo hace este hook). Si el PR toca lo compartido (src/shared/Data, CLAUDE.md, .claude/) y no es del
#   dueño del plugin, además hace falta su aprobación en el PR (lo que haría CODEOWNERS).
# - git push a main en un juego -> preguntar: main solo cambia con un PR (trabajo entre dos).
# Si no puede comprobar algo (sin red, gh sin sesión), pregunta en vez de negar.
. "$PSScriptRoot\comun.ps1"

$DUENO = 'AlvaroCepa'
$COMPARTIDO = '^(src/shared/Data/|CLAUDE\.md$|\.claude/)'

function Decidir($Entrada, [string]$Decision, [string]$Motivo, [string]$Que) {
    Anotar $Entrada 'freno' @{ herramienta = $Que; decision = $Decision }
    Salir-Json @{
        hookSpecificOutput = @{
            hookEventName            = 'PreToolUse'
            permissionDecision       = $Decision
            permissionDecisionReason = "roblox-kit: $Motivo"
        }
    }
}

$entrada = $null
try {
    $entrada = Leer-Entrada
    $orden = [string]$entrada.tool_input.command
    if (-not $orden) { exit 0 }
    $raiz = Raiz-Proyecto $entrada

    # Subir assets al grupo.
    $subeAssets = ($orden -match 'subir-assets(\.ps1)?' -and $orden -notmatch '--dry-run') -or
        ($orden -match '\basphalt(\.exe)?\s+sync\b' -and $orden -notmatch '\bsync\s+(studio|debug)\b' -and $orden -notmatch '--dry-run')
    if ($subeAssets) {
        Decidir $entrada 'ask' 'Esto sube los assets nuevos de assets/ al grupo de Roblox con la clave del bot. Si Roblox modera algo, cae sobre el grupo. Apruébalo si el usuario ya ha dado el visto bueno a lo que se sube.' 'subir-assets'
    }

    if (-not (Es-ProyectoRoblox $raiz) -or -not (Test-Path -LiteralPath (Join-Path $raiz '.git'))) { exit 0 }

    # Fusionar un PR: solo con la CI en verde.
    if ($orden -match '\bgh\s+pr\s+merge\b(.*)') {
        $resto = $matches[1]
        $numero = if ($resto -match '(?:^|\s)#?(\d+)(?:\s|$)') { $matches[1] } else { '' }
        $argumentos = @('pr', 'view')
        if ($numero) { $argumentos += $numero }
        $argumentos += @('--json', 'number,author,files,reviews,statusCheckRollup')
        $r = Ejecutar 'gh' $argumentos $raiz 30
        if ($r.Codigo -ne 0) {
            Decidir $entrada 'ask' "No he podido mirar la CI del PR (gh: $((($r.Salida -split "`n") | Select-Object -First 1))). Fusiona solo si la CI está en verde." 'gh pr merge'
        }
        $pr = $r.Salida | ConvertFrom-Json
        $checks = @($pr.statusCheckRollup)
        if (-not $checks.Count) {
            Decidir $entrada 'ask' "El PR #$($pr.number) no tiene ninguna comprobación de CI. Normalmente main solo recibe PRs con la CI en verde." 'gh pr merge'
        }
        $malos = @($checks | Where-Object {
                $estado = if ($_.conclusion) { [string]$_.conclusion } else { [string]$_.state }
                $estado -notin @('SUCCESS', 'NEUTRAL', 'SKIPPED')
            } | ForEach-Object { "$($_.name): $(if ($_.conclusion) { $_.conclusion } elseif ($_.status) { $_.status } else { $_.state })" })
        if ($malos.Count) {
            Decidir $entrada 'deny' "La CI del PR #$($pr.number) no está en verde ($($malos -join ', ')). main solo recibe PRs con la CI en verde: espera a que termine o arregla lo que falla." 'gh pr merge'
        }
        $tocaCompartido = @($pr.files | Where-Object { $_.path -match $COMPARTIDO })
        if ($tocaCompartido.Count -and $pr.author.login -ne $DUENO) {
            $aprobado = @($pr.reviews | Where-Object { $_.author.login -eq $DUENO -and $_.state -eq 'APPROVED' })
            if (-not $aprobado.Count) {
                Decidir $entrada 'deny' "El PR #$($pr.number) toca lo compartido ($((@($tocaCompartido | Select-Object -First 3 | ForEach-Object { $_.path })) -join ', ')) y necesita la aprobación de $DUENO en GitHub antes de fusionar." 'gh pr merge'
            }
        }
        exit 0
    }

    # Empujar directo a main.
    if ($orden -match '\bgit\s+push\b(.*)') {
        $resto = $matches[1]
        $rama = (Ejecutar 'git' @('rev-parse', '--abbrev-ref', 'HEAD') $raiz 10).Salida
        $aMain = $resto -match '(^|\s|:)main(\s|$)' -or ($rama -eq 'main' -and $resto -notmatch '\s[\w./-]+:[\w./-]+' -and $resto -notmatch '\b(bloque|claude)/')
        if ($aMain -and $resto -notmatch '--tags\b') {
            Decidir $entrada 'ask' 'Esto sube commits directamente a main. main solo debería cambiar con un PR con la CI en verde (cada bloque en su rama). Apruébalo solo si es el primer push de un repo nuevo o el usuario lo ha pedido.' 'git push main'
        }
    }
    exit 0
}
catch {
    Anotar $entrada 'error-hook' @{ hook = 'freno-ordenes'; mensaje = $_.Exception.Message }
    Decidir $entrada 'ask' ("el freno de órdenes ha fallado ({0}); por seguridad pide permiso." -f $_.Exception.Message) 'error'
}
