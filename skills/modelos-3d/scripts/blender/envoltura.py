# roblox-kit: corre otro script dentro de Blender sin ventana y apunta todo lo que escribe en un archivo.
# blender-launcher (Blender de la Microsoft Store) se separa de la consola y pierde la salida: por eso.
# Lo usa scripts/blender.ps1: blender -b --factory-startup -P envoltura.py -- <script.py> <log> [args del script...]
import runpy
import sys
import traceback

args = sys.argv[sys.argv.index("--") + 1:]
script, log = args[0], args[1]
# El script ve sus argumentos detrás de "--", como si lo hubieran lanzado solo.
sys.argv = [sys.argv[0], "--"] + args[2:]
with open(log, "w", encoding="utf-8", buffering=1) as f:
    sys.stdout = sys.stderr = f
    codigo = 0
    try:
        runpy.run_path(script, run_name="__main__")
    except SystemExit as e:
        codigo = e.code if isinstance(e.code, int) else 0
    except BaseException:
        traceback.print_exc()
        codigo = 1
    print(f"ROBLOX-KIT FIN {codigo}", flush=True)
