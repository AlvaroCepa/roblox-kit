# roblox-kit (skill modelos-3d): imagen -> forma 3D con TRELLIS (microsoft/TRELLIS, image-large) en una GPU de Kaggle.
# Una sola tanda para todas las imágenes del dataset (cada PNG = un modelo, con su nombre). Solo interesa la FORMA:
# el color lo pone Claude con reglas en Blender (el color propio de TRELLIS sale sucio; se guarda solo por si acaso).
# Probado el 12/10/2026 (mapache, perro y búho): ~30 s por modelo más ~3 min fijos por tanda.
# Entorno aparte con uv (Python 3.10, torch 2.4) como en el notebook de Hi3DGen. Salida en /kaggle/working/trellis.
import glob, json, os, subprocess, time

T0 = time.time()
tiempos = {}

def sh(paso, cmd, cwd=None):
    print(f"\n### {paso}\n$ {cmd}", flush=True)
    t = time.time()
    subprocess.run(cmd, shell=True, check=True, executable="/bin/bash", cwd=cwd)
    tiempos[paso] = round(time.time() - t)
    print(f"[{paso}: {tiempos[paso]} s]", flush=True)

# La carpeta del dataset con las imágenes (la primera que tenga PNG).
entrada = os.path.dirname(sorted(glob.glob("/kaggle/input/**/*.png", recursive=True))[0])
SALIDA = "/kaggle/working/trellis"
os.makedirs(SALIDA, exist_ok=True)
PY = "/tmp/tr/bin/python"
PIP = f"uv pip install --python {PY} -q"

sh("uv", "pip install -q uv")
sh("python310", "uv venv /tmp/tr --python 3.10 -q")
sh("paquetes", f"{PIP} --index-strategy unsafe-best-match --extra-index-url https://download.pytorch.org/whl/cu121 "
   "torch==2.4.0 torchvision==0.19.0 xformers==0.0.27.post2 spconv-cu120==2.3.6 "
   "transformers==4.46.3 huggingface_hub==0.25.2 numpy==1.26.4 pillow tqdm scipy trimesh "
   "opencv-python-headless einops easydict plyfile safetensors rembg onnxruntime "
   "git+https://github.com/EasternJournalist/utils3d.git@9a4eb15e4021b67b12c460c7057d642626897ec8")
sh("repo", "git clone -q --recurse-submodules https://github.com/microsoft/TRELLIS.git /tmp/trellis && git -C /tmp/trellis rev-parse HEAD")
# El pipeline de texto a 3D importa open3d y no se usa: se quita su import.
subprocess.run("sed -i '/trellis_text_to_3d/d' /tmp/trellis/trellis/pipelines/__init__.py", shell=True, check=True)
# FlexiCubes solo usa kaolin para una comprobación de tensores; se sustituye por un módulo mínimo
# en vez de instalar kaolin entero.
os.makedirs("/tmp/trellis/kaolin/utils", exist_ok=True)
for f in ["kaolin/__init__.py", "kaolin/utils/__init__.py"]:
    open(f"/tmp/trellis/{f}", "w").close()
open("/tmp/trellis/kaolin/utils/testing.py", "w").write("def check_tensor(*args, **kwargs):\n    return True\n")

CORRER = r'''
import glob, json, os, sys, time
os.environ["SPCONV_ALGO"] = "native"
import numpy as np, torch, trimesh
from PIL import Image
from trellis.pipelines import TrellisImageTo3DPipeline

entrada, salida = sys.argv[1], sys.argv[2]
t = time.time()
pipe = TrellisImageTo3DPipeline.from_pretrained("JeffreyXiang/TRELLIS-image-large")
pipe.cuda()
informe = {"carga_modelos_s": round(time.time() - t), "mascotas": {}}
print("modelos cargados", informe["carga_modelos_s"], "s", flush=True)

for ruta in sorted(glob.glob(f"{entrada}/*.png")):
    nombre = os.path.splitext(os.path.basename(ruta))[0]
    torch.cuda.reset_peak_memory_stats()
    t = time.time()
    img = pipe.preprocess_image(Image.open(ruta))
    img.save(f"{salida}/{nombre}_recorte.png")
    out = pipe.run(img, seed=42, formats=["mesh", "gaussian"], preprocess_image=False,
                   sparse_structure_sampler_params={"steps": 12, "cfg_strength": 7.5},
                   slat_sampler_params={"steps": 12, "cfg_strength": 3})
    m = out["mesh"][0]
    v = m.vertices.detach().cpu().numpy() @ np.array([[1, 0, 0], [0, 0, -1], [0, 1, 0]])  # Y arriba, como to_glb
    # color de cada vértice: media de las gaussianas cercanas (pesadas por opacidad), sin rasterizador
    g = out["gaussian"][0]
    gx = g.get_xyz.detach().cpu().numpy() @ np.array([[1, 0, 0], [0, 0, -1], [0, 1, 0]])
    grgb = (0.5 + 0.28209479 * g.get_features.detach().cpu().numpy().reshape(len(gx), -1)[:, :3]).clip(0, 1)
    gop = g.get_opacity.detach().cpu().numpy().reshape(-1)
    keep = gop > 0.1
    from scipy.spatial import cKDTree
    d, i = cKDTree(gx[keep]).query(v, k=8)
    w = gop[keep][i] / (d + 1e-3)
    col = (grgb[keep][i] * w[..., None]).sum(1) / w.sum(1)[:, None]
    malla = trimesh.Trimesh(v, m.faces.detach().cpu().numpy(), process=False,
                            vertex_colors=np.concatenate([col * 255, np.full((len(v), 1), 255)], 1).astype(np.uint8))
    malla.merge_vertices()
    np.save(f"{salida}/{nombre}_colores_atributo.npy", m.vertex_attrs.detach().cpu().numpy()[:, :3] if getattr(m, "vertex_attrs", None) is not None else np.zeros(0))
    malla.export(f"{salida}/{nombre}.glb")
    piezas = malla.split(only_watertight=False)
    informe["mascotas"][nombre] = {
        "segundos": round(time.time() - t),
        "vram_pico_gb": round(torch.cuda.max_memory_allocated() / 2**30, 2),
        "vertices": int(len(malla.vertices)), "triangulos": int(len(malla.faces)),
        "piezas_sueltas": len(piezas), "estanca": bool(malla.is_watertight),
        "medidas": [round(float(x), 3) for x in malla.extents],
    }
    print(nombre, informe["mascotas"][nombre], flush=True)
    torch.cuda.empty_cache()
json.dump(informe, open(f"{salida}/informe_modelo.json", "w"), indent=2)
'''
open("/tmp/trellis/correr.py", "w").write(CORRER)
sh("generar", f"ATTN_BACKEND=xformers SPARSE_ATTN_BACKEND=xformers PYTHONPATH=/tmp/trellis {PY} correr.py {entrada} {SALIDA}", cwd="/tmp/trellis")

tiempos["total"] = round(time.time() - T0)
json.dump(tiempos, open(f"{SALIDA}/tiempos.json", "w"), indent=2)
print("\nTIEMPOS", tiempos)
print(open(f"{SALIDA}/informe_modelo.json").read())
