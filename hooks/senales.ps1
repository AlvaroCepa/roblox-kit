# Convierte señales repetidas del registro en issues «mejora» del repo del plugin (buzón único).
# Lo lanza inicio.ps1 en segundo plano, como mucho una vez al día. No gasta tokens.
# Umbrales (últimos 14 días, en este PC):
#   - la misma regla de Selene salta 15 veces o más;
#   - el mismo paso de comprobación falla al terminar el turno 5 veces o más;
#   - 3 veces o más que las comprobaciones siguen fallando tras el intento de arreglo;
#   - 3 #mal o más;
#   - un hook del plugin falla 3 veces o más.
# Sin duplicados: no abre un issue si ya hay uno abierto con la misma clave o si lo abrió este PC hace menos de 30 días.
# El repo es público: los issues llevan recuentos y nombres de reglas, nunca nombres de juegos ni textos del usuario.
param([string]$Datos = $env:CLAUDE_PLUGIN_DATA)
$ErrorActionPreference = 'Stop'
$repo = 'AlvaroCepa/roblox-kit'

try {
    $registro = Join-Path $Datos 'registro.jsonl'
    if (-not (Test-Path -LiteralPath $registro)) { exit 0 }
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { exit 0 }

    $desde = (Get-Date).AddDays(-14)
    $eventos = Get-Content -LiteralPath $registro -Tail 20000 -Encoding UTF8 | ForEach-Object {
        try { $_ | ConvertFrom-Json } catch { }
    } | Where-Object { $_ -and [datetime]$_.fecha -ge $desde }

    $senales = @()

    $reglas = @{}
    foreach ($e in ($eventos | Where-Object { $_.evento -eq 'selene' })) {
        foreach ($r in $e.detalle.reglas) { $reglas[$r] = 1 + [int]$reglas[$r] }
    }
    foreach ($r in $reglas.Keys) {
        if ($reglas[$r] -ge 15) { $senales += @{ clave = "selene:$r"; texto = "La regla de Selene ``$r`` ha saltado $($reglas[$r]) veces en 14 días. ¿Falta una regla en una skill, o la regla está mal ajustada?" } }
    }

    $paradasMal = @($eventos | Where-Object { $_.evento -eq 'parada' -and $_.detalle.resultado -eq 'mal' })
    $pasos = @{}
    foreach ($e in $paradasMal) { foreach ($p in $e.detalle.fallan) { $pasos[$p] = 1 + [int]$pasos[$p] } }
    foreach ($p in $pasos.Keys) {
        if ($pasos[$p] -ge 5) { $senales += @{ clave = "comprobacion:$p"; texto = "La comprobación ``$p`` ha fallado al terminar el turno $($pasos[$p]) veces en 14 días. ¿Qué error se repite y qué regla o script lo evitaría?" } }
    }
    $atascos = @($paradasMal | Where-Object { $_.detalle.repetido }).Count
    if ($atascos -ge 3) { $senales += @{ clave = 'atasco:comprobaciones'; texto = "$atascos veces en 14 días las comprobaciones siguieron fallando después del intento de arreglo." } }

    $mal = @($eventos | Where-Object { $_.evento -eq 'mal' }).Count
    if ($mal -ge 3) { $senales += @{ clave = 'mal'; texto = "$mal mensajes con #mal en 14 días. Los motivos están en el registro local del PC (registro.jsonl); el informe de modelos los resume." } }

    $hooks = @{}
    foreach ($e in ($eventos | Where-Object { $_.evento -eq 'error-hook' })) { $hooks[$e.detalle.hook] = 1 + [int]$hooks[$e.detalle.hook] }
    foreach ($h in $hooks.Keys) {
        if ($hooks[$h] -ge 3) { $senales += @{ clave = "error-hook:$h"; texto = "El hook ``$h`` del plugin ha fallado $($hooks[$h]) veces en 14 días. El mensaje de error está en el registro local." } }
    }

    if (-not $senales.Count) { exit 0 }

    $enviadasRuta = Join-Path $Datos 'senales-enviadas.json'
    $enviadas = @{}
    if (Test-Path -LiteralPath $enviadasRuta) {
        (Get-Content -LiteralPath $enviadasRuta -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $enviadas[$_.Name] = $_.Value }
    }

    $ErrorActionPreference = 'Continue'
    foreach ($s in $senales) {
        if ($enviadas[$s.clave] -and ((Get-Date) - [datetime]$enviadas[$s.clave]).TotalDays -lt 30) { continue }
        $titulo = "[auto] $($s.clave)"
        $abiertos = gh issue list --repo $repo --state open --search "`"$titulo`" in:title" --json title --jq '.[].title' 2>$null
        if ($LASTEXITCODE -ne 0) { exit 0 }
        if ($abiertos -contains $titulo) { $enviadas[$s.clave] = (Get-Date).ToString('o'); continue }
        $cuerpo = "$($s.texto)`n`nAbierto solo por roblox-kit (señal automática). Lo decide Álvaro."
        gh issue create --repo $repo --title $titulo --body $cuerpo --label mejora 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { gh issue create --repo $repo --title $titulo --body $cuerpo 2>$null | Out-Null }
        if ($LASTEXITCODE -eq 0) { $enviadas[$s.clave] = (Get-Date).ToString('o') }
    }
    $enviadas | ConvertTo-Json | Set-Content -LiteralPath $enviadasRuta -Encoding UTF8
}
catch {
    exit 0
}
