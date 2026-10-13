# SessionStart: al abrir, reanudar, /clear o compactar. Solo en juegos de Roblox.
# Le cuenta a Claude (y en corto al usuario) por dónde vais:
# - la primera línea de Estado.md;
# - rama, cambios sin subir y commits nuevos del otro en GitHub (git fetch, nunca pull);
# - si están abiertos Studio y rojo serve;
# - una vez por semana, el recordatorio de la revisión semanal.
# Además, una vez al día lanza en segundo plano senales.ps1, que convierte señales repetidas en issues.
. "$PSScriptRoot\comun.ps1"

try {
    $entrada = Leer-Entrada
    $raiz = Raiz-Proyecto $entrada
    if (-not (Es-ProyectoRoblox $raiz)) { exit 0 }
    $datos = Ruta-Datos
    Anotar $entrada 'inicio' @{ origen = [string]$entrada.source; modelo = [string]$entrada.model }

    $contexto = @()
    $usuario = @()

    # Estado.md: su primera línea tiene siempre el mismo formato (skill jefa).
    $estado = Join-Path $raiz 'Estado.md'
    if (Test-Path -LiteralPath $estado) {
        $primera = Get-Content -LiteralPath $estado -TotalCount 1 -Encoding UTF8
        if ($primera) {
            $contexto += "Estado.md: $primera"
            $usuario += $primera
        }
    }

    # Git
    if (Test-Path -LiteralPath (Join-Path $raiz '.git')) {
        $env:GIT_TERMINAL_PROMPT = '0'
        $rama = (Ejecutar 'git' @('rev-parse', '--abbrev-ref', 'HEAD') $raiz 10).Salida
        $cambios = @((Ejecutar 'git' @('status', '--porcelain') $raiz 15).Salida -split "`n" | Where-Object { $_.Trim() })
        $linea = "Rama: $rama"
        if ($cambios.Count) { $linea += ", $($cambios.Count) archivo(s) con cambios sin commit" }
        $contexto += $linea

        if ($entrada.source -eq 'startup' -or -not $entrada.source) {
            $fetch = Ejecutar 'git' @('fetch', '--quiet') $raiz 10
            if ($fetch.Codigo -ne 0) { $contexto += 'git fetch no respondió (sin red o sin permiso): no sé si hay commits nuevos en GitHub.' }
        }
        # Commits que hay en GitHub y no aquí: los de tu rama y los de main (los del otro llegan por main).
        $remotas = @('@{u}')
        if ($rama -ne 'main') { $remotas += 'origin/main' }
        foreach ($remota in $remotas) {
            $r = Ejecutar 'git' @('log', "HEAD..$remota", '--format=%an: %s', '-n', '6') $raiz 10
            if ($r.Codigo -eq 0 -and $r.Salida) {
                $nuevos = @($r.Salida -split "`n" | Where-Object { $_.Trim() })
                $nombre = if ($remota -eq '@{u}') { 'tu rama en GitHub' } else { 'main' }
                $contexto += "Commits nuevos en $nombre que no tienes (no se ha hecho pull):`n  " + ($nuevos -join "`n  ")
                $usuario += "Hay commits nuevos en $nombre sin traer."
            }
        }
    }

    # Studio y rojo serve
    $studio = [bool](Get-Process -Name 'RobloxStudioBeta' -ErrorAction SilentlyContinue)
    $rojo = [bool](Get-Process -Name 'rojo' -ErrorAction SilentlyContinue)
    $contexto += "Studio abierto: $(if ($studio) { 'sí' } else { 'no' }). rojo serve: $(if ($rojo) { 'en marcha' } else { 'parado' })."
    if ($studio -and -not $rojo) { $usuario += 'Studio está abierto pero rojo serve no: los cambios de código no llegarán a Studio.' }

    # Recordatorio semanal (una vez cada 7 días en este PC).
    $marcaSemana = Join-Path $datos 'ultima-revision-semanal.txt'
    $ultima = if (Test-Path -LiteralPath $marcaSemana) { [datetime](Get-Content -LiteralPath $marcaSemana -TotalCount 1) } else { [datetime]::MinValue }
    if (((Get-Date) - $ultima).TotalDays -ge 7) {
        $contexto += 'Toca la revisión semanal: ofrece al usuario mirar los issues «mejora» del repo AlvaroCepa/roblox-kit y, cuando exista, el informe de modelos.'
        $usuario += 'Toca la revisión semanal de mejoras del plugin.'
        Set-Content -LiteralPath $marcaSemana -Value (Get-Date).ToString('o')
    }

    # Señales -> issues, como mucho una vez al día y en segundo plano (no hace esperar).
    $marcaSenales = Join-Path $datos 'ultimas-senales.txt'
    $ultimas = if (Test-Path -LiteralPath $marcaSenales) { [datetime](Get-Content -LiteralPath $marcaSenales -TotalCount 1) } else { [datetime]::MinValue }
    if (((Get-Date) - $ultimas).TotalHours -ge 24) {
        Set-Content -LiteralPath $marcaSenales -Value (Get-Date).ToString('o')
        Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @(
            '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSScriptRoot\senales.ps1`"", "`"$datos`"")
    }

    $salida = @{
        hookSpecificOutput = @{
            hookEventName     = 'SessionStart'
            additionalContext = "roblox-kit:`n" + ($contexto -join "`n")
        }
    }
    if ($usuario.Count) { $salida.systemMessage = 'roblox-kit: ' + ($usuario -join ' | ') }

    # Limpieza: marcas y avisos de sesiones de hace más de una semana.
    $viejo = (Get-Date).AddDays(-7)
    @(Get-ChildItem -LiteralPath (Join-Path $datos 'marcas') -File -ErrorAction SilentlyContinue) +
    @(Get-ChildItem -LiteralPath $datos -Filter 'aviso-*.txt' -File -ErrorAction SilentlyContinue) |
        Where-Object { $_.LastWriteTime -lt $viejo } | Remove-Item -ErrorAction SilentlyContinue
    Salir-Json $salida
}
catch {
    Anotar $entrada 'error-hook' @{ hook = 'inicio'; mensaje = $_.Exception.Message }
    exit 0
}
