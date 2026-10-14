# PostToolUse.
# - Edit/Write de un .lua/.luau en un juego: StyLua (formatea) y después Selene (lint) sobre ese archivo.
#   Cada uno solo corre si el juego tiene su configuración (stylua.toml, selene.toml): así un juego
#   antiguo sin configurar no se reformatea entero. Silencio si pasa; si Selene da errores, se los
#   devuelve a Claude. Los avisos (warnings) solo se apuntan en el registro, para no inundar al principio:
#   lo estricto de cada juego se decide en su selene.toml.
#   Además deja la marca de "código cambiado" para el hook de Stop.
# - insert_asset: recuerda revisar si lo insertado trae scripts (la Toolbox puede traer scripts maliciosos).
# - execute_luau: si su salida dice «roblox-kit comprobar-ui: bien» o «comprobar-mapa: bien» (los comprobadores
#   del kit en Studio), apunta la pasada buena con kit/pasada.luau: así el hook de Stop no la vuelve a pedir
#   hasta que cambie la UI o el mapa.
. "$PSScriptRoot\comun.ps1"

try {
    $entrada = Leer-Entrada
    $herramienta = ($entrada.tool_name -split '__')[-1]

    if ($herramienta -eq 'insert_asset') {
        $nombre = $entrada.tool_input.assetName
        if (-not $nombre) { $nombre = $entrada.tool_input.assetId }
        Anotar $entrada 'insertar-asset' @{ asset = [string]$entrada.tool_input.assetId }
        Salir-Json @{
            hookSpecificOutput = @{
                hookEventName     = 'PostToolUse'
                additionalContext = "roblox-kit: acabas de insertar '$nombre'. Los modelos de la Toolbox pueden traer scripts maliciosos. Antes de seguir, busca scripts dentro (execute_luau en Edit: GetDescendants del objeto insertado, filtrando IsA('LuaSourceContainer')). Si hay alguno, enséñale al usuario su nombre y dónde está antes de usarlo o borrarlo."
            }
        }
    }

    if ($herramienta -eq 'execute_luau') {
        $raiz = Raiz-Proyecto $entrada
        if (-not (Test-Path -LiteralPath (Join-Path $raiz 'rokit.toml'))) { exit 0 }
        $respuesta = $entrada.tool_response | ConvertTo-Json -Depth 8 -Compress
        $kit = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
        foreach ($nombre in @('ui', 'mapa')) {
            if ($respuesta -match "roblox-kit comprobar-${nombre}: bien") {
                $r = Ejecutar 'lune' @('run', (Join-Path $kit 'kit\pasada.luau'), $nombre) $raiz 60
                Anotar $entrada 'pasada' @{ que = $nombre; ok = ($r.Codigo -eq 0) }
            }
            elseif ($respuesta -match "roblox-kit comprobar-${nombre}: falla") {
                Anotar $entrada 'pasada' @{ que = $nombre; ok = $false }
            }
        }
        exit 0
    }

    $archivo = [string]$entrada.tool_input.file_path
    if ($archivo -notmatch '\.luau?$') { exit 0 }
    $raiz = Raiz-Proyecto $entrada
    if (-not (Es-ProyectoRoblox $raiz)) { exit 0 }
    if (-not (Test-Path -LiteralPath $archivo)) { exit 0 }

    # Marca para el hook de Stop: este agente ha tocado código.
    Set-Content -LiteralPath (Ruta-Marca $entrada) -Value $archivo -Encoding UTF8

    # Ruta corta, relativa al juego: los mensajes gastan menos y se leen mejor.
    $completa = [IO.Path]::GetFullPath($archivo)
    $base = [IO.Path]::GetFullPath($raiz).TrimEnd('\') + '\'
    $relativa = if ($completa.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) { $completa.Substring($base.Length) } else { $completa }

    $problemas = @()
    $faltan = @()

    if ((Test-Path (Join-Path $raiz 'stylua.toml')) -or (Test-Path (Join-Path $raiz '.stylua.toml'))) {
        $r = Ejecutar 'stylua' @('--respect-ignores', $relativa) $raiz 30
        if ($r.Codigo -eq -2) { $faltan += 'stylua' }
        elseif ($r.Codigo -ne 0) { $problemas += "StyLua no puede formatearlo (suele ser un error de sintaxis):`n" + (($r.Salida -split "`n" | Select-Object -First 15) -join "`n") }
    }

    if (Test-Path (Join-Path $raiz 'selene.toml')) {
        $r = Ejecutar 'selene' @('--display-style=quiet', '--no-summary', $relativa) $raiz 30
        if ($r.Codigo -eq -2) { $faltan += 'selene' }
        else {
            $lineas = $r.Salida -split "`r?`n" | Where-Object { $_ -match ':\s*(error|warning)\[' }
            $errores = @($lineas | Where-Object { $_ -match ':\s*error\[' })
            $reglas = @($lineas | ForEach-Object { if ($_ -match '(error|warning)\[([^\]]+)\]') { $matches[2] } })
            if ($reglas.Count) { Anotar $entrada 'selene' @{ archivo = (Split-Path -Leaf $archivo); errores = $errores.Count; reglas = $reglas } }
            if ($errores.Count) { $problemas += "Selene, $($errores.Count) error(es):`n" + (($errores | Select-Object -First 15) -join "`n") }
            elseif ($r.Codigo -ne 0 -and -not $lineas) { $problemas += "Selene no pudo revisarlo:`n" + (($r.Salida -split "`n" | Select-Object -First 10) -join "`n") }
        }
    }

    if ($problemas.Count) {
        Salir-Json @{
            decision = 'block'
            reason   = "roblox-kit, ${relativa}:`n" + ($problemas -join "`n`n")
        }
    }

    # Si falta StyLua o Selene, se avisa a Claude una sola vez por sesión (y se apunta siempre).
    if ($faltan.Count) {
        Anotar $entrada 'falta-herramienta' @{ herramienta = $faltan }
        $aviso = Join-Path (Ruta-Datos) ("aviso-herramientas-{0}.txt" -f (Clave-Agente $entrada))
        if (-not (Test-Path -LiteralPath $aviso)) {
            Set-Content -LiteralPath $aviso -Value (Get-Date).ToString('o')
            Salir-Json @{
                hookSpecificOutput = @{
                    hookEventName     = 'PostToolUse'
                    additionalContext = "roblox-kit: este juego está configurado para usar $($faltan -join ' y '), pero falta instalarlo, así que el archivo no se ha formateado o revisado. Díselo al usuario: se instala con «rokit install» en la carpeta del juego."
                }
            }
        }
    }
    exit 0
}
catch {
    # Un fallo de este hook no debe frenar el trabajo: se apunta y sigue.
    Anotar $entrada 'error-hook' @{ hook = 'tras-herramienta'; mensaje = $_.Exception.Message }
    exit 0
}
