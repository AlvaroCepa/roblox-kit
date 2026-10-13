# UserPromptSubmit: si el mensaje lleva "#mal <motivo>", lo apunta en el registro.
# Sirve para el informe de modelos y para detectar mejoras. No cambia el mensaje.
. "$PSScriptRoot\comun.ps1"

try {
    $entrada = Leer-Entrada
    $texto = [string]$entrada.prompt
    if ($texto -notmatch '(?i)(^|\s)#mal\b(.*)') { exit 0 }
    $motivo = $matches[2].Trim()
    if ($motivo.Length -gt 300) { $motivo = $motivo.Substring(0, 300) }
    Anotar $entrada 'mal' @{ motivo = $motivo }
    Salir-Json @{ systemMessage = 'roblox-kit: #mal anotado en el registro.' }
}
catch {
    exit 0
}
