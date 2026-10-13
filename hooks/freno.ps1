# PreToolUse: freno de Studio y de assets. Nunca prohíbe: pide permiso explicando el motivo.
# - multi_edit (edita o crea scripts en Studio) -> preguntar.
# - execute_luau en Edit que toca código (.Source =, UpdateSourceAsync, crea Script/LocalScript/ModuleScript) -> preguntar.
#   En Play (Server/Client) no se frena: se borra al parar.
# - upload_image, store_image y generate_* (Studio y Blender) -> preguntar: suben o crean assets a nombre
#   de quien tiene Studio abierto, no del grupo, o gastan cupo o créditos.
# Si el propio freno falla, también pregunta: un freno roto no debe dejar pasar nada.
. "$PSScriptRoot\comun.ps1"

function Preguntar($Entrada, [string]$Herramienta, [string]$Motivo) {
    Anotar $Entrada 'freno' @{ herramienta = $Herramienta }
    Salir-Json @{
        hookSpecificOutput = @{
            hookEventName            = 'PreToolUse'
            permissionDecision       = 'ask'
            permissionDecisionReason = "roblox-kit: $Motivo"
        }
    }
}

$entrada = $null
try {
    $entrada = Leer-Entrada
    $herramienta = ($entrada.tool_name -split '__')[-1]
    $datos = $entrada.tool_input

    if ($herramienta -eq 'multi_edit') {
        Preguntar $entrada $herramienta ("multi_edit cambia o crea el script '{0}' dentro de Studio. El código vive en los archivos del repo y Rojo lo pasa a Studio: lo editado en Studio se pierde o choca con Rojo. Apruébalo solo si es una prueba a propósito." -f $datos.file_path)
    }

    if ($herramienta -eq 'execute_luau') {
        if ($datos.datamodel_type -ne 'Edit') { exit 0 }
        $codigo = [string]$datos.code
        $tocaCodigo = $codigo -match '\.Source\s*=(?!=)' -or
            $codigo -match '\[\s*["'']Source["'']\s*\]\s*=(?!=)' -or
            $codigo -match 'UpdateSourceAsync' -or
            $codigo -match 'Instance\.new\s*\(\s*["''](Script|LocalScript|ModuleScript)["'']'
        if ($tocaCodigo) {
            Preguntar $entrada $herramienta 'Este execute_luau en modo Edit cambia o crea scripts en Studio. El código vive en los archivos del repo y Rojo lo pasa a Studio. Apruébalo solo si es una prueba a propósito.'
        }
        exit 0
    }

    if ($herramienta -in @('upload_image', 'store_image')) {
        Preguntar $entrada $herramienta 'Esto sube o carga una imagen en Roblox a nombre de quien tiene Studio abierto, no del grupo. Las imágenes del juego se suben al grupo con los scripts del plugin.'
    }

    if ($herramienta -like 'generate_*') {
        if ($herramienta -match 'hunyuan') {
            Preguntar $entrada $herramienta 'Hunyuan3D está descartado: su licencia excluye la UE. Normalmente hay que rechazarlo.'
        }
        if ($herramienta -match 'tripo|hyper3d|rodin') {
            Preguntar $entrada $herramienta 'Este generador es de pago (Tripo o Rodin) y no pagamos servicios. Normalmente hay que rechazarlo.'
        }
        Preguntar $entrada $herramienta "$herramienta genera un asset con IA: puede crearlo a nombre de quien tiene Studio abierto o gastar cupo. Los assets del juego siguen el método de su oficio."
    }

    exit 0
}
catch {
    Preguntar $entrada 'error' ("el freno ha fallado ({0}); por seguridad pide permiso." -f $_.Exception.Message)
}
