# roblox-kit (skill modelos-3d). Se ejecuta DENTRO de Blender sin ventana, con scripts/blender.ps1:
#   blender.ps1 procesar.py '<json>'   (json: malla, ficha, estilo, salida, mascota, fuente, guardar_alta...)
# Malla en bruto (Hi3DGen o TRELLIS) -> limpia, a escala y apoyada -> zonas de color desde la imagen de partida
# -> mirando al frente -> baja de triángulos -> horneado de color (zonas) y relieve (normal map) -> mutaciones
# -> exportación OBJ + PNG -> vistas para la revisión -> comprobaciones en informe.json.
import bpy, bmesh, sys, os, json, math, time, tomllib
import numpy as np
from mathutils import Vector, Matrix, kdtree
from mathutils.bvhtree import BVHTree

T0 = time.time()
cfg = json.loads(sys.argv[sys.argv.index("--") + 1])
OUT = cfg["salida"]
os.makedirs(OUT, exist_ok=True)
ficha = tomllib.load(open(cfg["ficha"], "rb"))
estilo = tomllib.load(open(cfg["estilo"], "rb"))
PALETA = estilo["paleta"]
ALTURA = float(ficha.get("altura", estilo["tamanos"]["mascota"]))
TRIS = int(ficha.get("triangulos", estilo["triangulos"]["mascota"]))
RES_TEX = cfg.get("res_textura", 1024)
informe = {"fuente": cfg["fuente"], "mascota": cfg["mascota"], "pasos_s": {}}


def paso(nombre, t):
    informe["pasos_s"][nombre] = round(time.time() - t, 1)
    print(f"[{cfg['fuente']}/{cfg['mascota']}] {nombre}: {informe['pasos_s'][nombre]} s", flush=True)


def hex_rgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.float64) / 255.0


def srgb_a_lineal(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


ZONAS = list(ficha["zonas"].keys())
EN_IMAGEN = np.array([hex_rgb(ficha["zonas"][z]["en_imagen"]) for z in ZONAS])
BASE = np.array([hex_rgb(PALETA[ficha["zonas"][z]["color"]]) for z in ZONAS])
I_OJOS = next((i for i, z in enumerate(ZONAS) if z.startswith("ojos")), None)


def colores_mutacion(m):
    cambios = ficha["mutaciones"][m]
    return np.array([hex_rgb(PALETA[cambios.get(z, ficha["zonas"][z]["color"])]) for z in ZONAS])


def seleccionar(objs, activo):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = activo


def verts_np(me):
    v = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", v)
    return v.reshape(-1, 3)


# ---------------------------------------------------------------- 1. importar y limpiar
t = time.time()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=cfg["malla"])
mallas = [o for o in bpy.context.scene.objects if o.type == "MESH"]
seleccionar(mallas, mallas[0])
if len(mallas) > 1:
    bpy.ops.object.join()
H = bpy.context.view_layer.objects.active
H.name = "alta"
H.parent = None
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for o in list(bpy.context.scene.objects):
    if o != H:
        bpy.data.objects.remove(o, do_unlink=True)
informe["triangulos_bruto"] = sum(len(p.vertices) - 2 for p in H.data.polygons)

if informe["triangulos_bruto"] > 200_000:  # trabajar con una copia más ligera; sigue sobrando detalle para hornear
    mod = H.modifiers.new("pre", "DECIMATE")
    mod.ratio = 200_000 / informe["triangulos_bruto"]
    bpy.ops.object.modifier_apply(modifier=mod.name)

bm = bmesh.new()
bm.from_mesh(H.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5 * max(H.dimensions))
bm.verts.ensure_lookup_table()
# piezas sueltas: etiquetado por componentes con numpy (unión por aristas)
aristas = np.array([[e.verts[0].index, e.verts[1].index] for e in bm.edges], dtype=np.int64)
etiqueta = np.arange(len(bm.verts))
while True:
    m = np.minimum(etiqueta[aristas[:, 0]], etiqueta[aristas[:, 1]])
    nueva = etiqueta.copy()
    np.minimum.at(nueva, aristas[:, 0], m)
    np.minimum.at(nueva, aristas[:, 1], m)
    nueva = nueva[nueva]
    if np.array_equal(nueva, etiqueta):
        break
    etiqueta = nueva
ids, cuenta = np.unique(etiqueta, return_counts=True)
grandes = set(ids[cuenta >= 0.02 * cuenta.max()].tolist())
borrar = [v for v in bm.verts if etiqueta[v.index] not in grandes]
informe["piezas_sueltas_quitadas"] = int(len(ids) - len(grandes))
bmesh.ops.delete(bm, geom=borrar, context="VERTS")
bm.to_mesh(H.data)
bm.free()

# color propio de la malla (TRELLIS lo trae por vértice): se lee en sRGB o lineal, lo que case mejor con la ficha
COL_MALLA = None
if H.data.color_attributes:
    ca = H.data.color_attributes[0]
    opciones = []
    for campo in ("color_srgb", "color"):
        c = np.empty(len(ca.data) * 4, dtype=np.float32)
        ca.data.foreach_get(campo, c)
        c = c.reshape(-1, 4)[:, :3].astype(np.float64)
        if ca.domain == "CORNER":
            vi = np.empty(len(H.data.loops), dtype=np.int64)
            H.data.loops.foreach_get("vertex_index", vi)
            suma = np.zeros((len(H.data.vertices), 3))
            np.add.at(suma, vi, c)
            c = suma / np.maximum(np.bincount(vi, minlength=len(H.data.vertices)), 1)[:, None]
        d = ((c[:, None, :] - EN_IMAGEN[None]) ** 2).sum(-1).min(1).mean()
        opciones.append((d, campo, c))
    _, campo, COL_MALLA = min(opciones, key=lambda o: o[0])
    informe["color_de_malla"] = campo

# escala, centrado y apoyado en el suelo (Z arriba en Blender)
V = verts_np(H.data)
mn, mx = V.min(0), V.max(0)
s = ALTURA / (mx[2] - mn[2])
centro = np.array([(mn[0] + mx[0]) / 2, (mn[1] + mx[1]) / 2, mn[2]])
V = (V - centro) * s
H.data.vertices.foreach_set("co", V.ravel())
H.data.update()
paso("limpiar", t)

# ---------------------------------------------------------------- 2. encajar la cámara de la imagen de partida
t = time.time()
img = bpy.data.images.load(cfg["imagen"])
w, h = img.size
px = np.empty(w * h * 4, dtype=np.float32)
img.pixels.foreach_get(px)
IMG = px.reshape(h, w, 4)[::-1, :, :3].astype(np.float64)  # fila 0 = arriba
fondo = np.median(np.concatenate([IMG[:8].reshape(-1, 3), IMG[-8:].reshape(-1, 3), IMG[:, :8].reshape(-1, 3), IMG[:, -8:].reshape(-1, 3)]), 0)
mascara = np.linalg.norm(IMG - fondo, axis=2) > 0.06
ys, xs = np.nonzero(mascara)
m_box = np.array([xs.min(), ys.min(), xs.max(), ys.max()], dtype=np.float64)
R = 128
esc_m = R / max(w, h)
mask_r = np.zeros((R, R), bool)
mask_r[(ys * esc_m).astype(int).clip(0, R - 1), (xs * esc_m).astype(int).clip(0, R - 1)] = True


def ejes(yaw, elev):
    y, e = math.radians(yaw), math.radians(elev)
    cam = np.array([math.sin(y) * math.cos(e), -math.cos(y) * math.cos(e), math.sin(e)])  # yaw 0 = cámara en -Y (frente)
    f = -cam
    r = np.cross(f, [0, 0, 1.0])
    r /= np.linalg.norm(r)
    u = np.cross(r, f)
    return r, u, f


def proyectar(V, yaw, elev):
    r, u, f = ejes(yaw, elev)
    X, Y, cerca = V @ r, V @ u, -(V @ f)
    p_box = np.array([X.min(), Y.min(), X.max(), Y.max()])
    sc = max(m_box[2] - m_box[0], m_box[3] - m_box[1]) / max(p_box[2] - p_box[0], p_box[3] - p_box[1])
    ix = (X - (p_box[0] + p_box[2]) / 2) * sc + (m_box[0] + m_box[2]) / 2
    iy = -(Y - (p_box[1] + p_box[3]) / 2) * sc + (m_box[1] + m_box[3]) / 2
    return ix, iy, cerca


def iou(V, yaw, elev):
    ix, iy, _ = proyectar(V, yaw, elev)
    sil = np.zeros((R, R), bool)
    sil[(iy * esc_m).astype(int).clip(0, R - 1), (ix * esc_m).astype(int).clip(0, R - 1)] = True
    sil = sil | np.roll(sil, 1, 0) | np.roll(sil, -1, 0) | np.roll(sil, 1, 1) | np.roll(sil, -1, 1)
    return (sil & mask_r).sum() / (sil | mask_r).sum()


V = verts_np(H.data)
Vm = V[np.random.default_rng(0).choice(len(V), min(len(V), 60_000), replace=False)]
# elevación solo positiva: la imagen se ve desde algo arriba y así se evita la confusión frente/espalda
mejor = max(((iou(Vm, y, e), y, e) for y in range(0, 360, 10) for e in range(5, 50, 10)))
_, y0, e0 = mejor
mejor = max(((iou(Vm, y, e), y, e) for y in range(y0 - 8, y0 + 9, 2) for e in range(max(0, e0 - 8), e0 + 9, 2)))
informe["encaje_camara"] = {"iou": round(float(mejor[0]), 3), "yaw": mejor[1], "elev": mejor[2]}
paso("encajar_camara", t)

# ---------------------------------------------------------------- 3. zonas vistas en la imagen
t = time.time()
ix, iy, cerca = proyectar(V, mejor[1], mejor[2])
ZR = 256
zx, zy = (ix * ZR / w).astype(int).clip(0, ZR - 1), (iy * ZR / h).astype(int).clip(0, ZR - 1)
zbuf = np.full((ZR, ZR), -np.inf)
np.maximum.at(zbuf, (zy, zx), cerca)
zb = zbuf.copy()  # tolerar vecinos para no perder vértices en los bordes de píxel
for dy in (-1, 0, 1):
    for dx in (-1, 0, 1):
        zb = np.maximum(zb, np.roll(np.roll(zbuf, dy, 0), dx, 1))
visible = cerca >= zb[zy, zx] - 0.03 * ALTURA
col = IMG[iy.astype(int).clip(0, h - 1), ix.astype(int).clip(0, w - 1)]
zona = np.argmin(((col[:, None, :] - EN_IMAGEN[None]) ** 2).sum(-1), axis=1)
zona[~visible] = -1
if COL_MALLA is not None:  # el color propio de la malla cubre también lo que no se ve en la imagen
    zona = np.argmin(((COL_MALLA[:, None, :] - EN_IMAGEN[None]) ** 2).sum(-1), axis=1)
    visible[:] = True
informe["vertices_vistos_pct"] = round(100 * float(visible.mean()), 1)
paso("zonas_vistas", t)

# ---------------------------------------------------------------- 4. plano de simetría y mirar al frente (-Y en Blender = -Z en Roblox)
# Las mascotas son simétricas: se busca el plano vertical que mejor refleja la malla sobre sí misma.
# El frente es la dirección dentro de ese plano que mira hacia la cámara de la imagen: las imágenes de partida
# son siempre de tres cuartos de frente (lo fija el prompt base). Los ojos no sirven: las rayas oscuras se confunden con ellos.
t = time.time()
c0 = V.mean(0)
P = V[np.random.default_rng(1).choice(len(V), min(len(V), 4000), replace=False)] - c0
arbol_p = kdtree.KDTree(len(P))
for i, p in enumerate(P):
    arbol_p.insert(Vector(p), i)
arbol_p.balance()


def error_espejo(theta):
    n = np.array([math.cos(theta), math.sin(theta), 0.0])
    Q = P - 2 * (P @ n)[:, None] * n
    return sum(arbol_p.find(Vector(q))[2] for q in Q[::4]) / len(Q[::4])


# Un cuerpo redondo (el búho) también es casi simétrico de delante a atrás. Entre los dos mejores planos se elige
# el que más casa los colores vistos con su reflejo (los dos ojos, las dos mejillas...).
errores = {g: error_espejo(math.radians(g)) for g in range(0, 180, 3)}
g1 = min(errores, key=errores.get)
g2 = min((g for g in errores if min(abs(g - g1), 180 - abs(g - g1)) >= 30), key=errores.get)
idx_v = np.nonzero(zona >= 0)[0]
arbol_v = kdtree.KDTree(len(idx_v))
for i in idx_v:
    arbol_v.insert(Vector(V[i]), int(i))
arbol_v.balance()


def coincidencias(g):
    n = np.array([math.cos(math.radians(g)), math.sin(math.radians(g)), 0.0])
    muestra = idx_v[:: max(1, len(idx_v) // 6000)]
    Q = V[muestra] - 2 * ((V[muestra] - c0) @ n)[:, None] * n
    total = 0
    for i, q in zip(muestra, Q):
        _, j, d = arbol_v.find(Vector(q))
        total += int(d < 0.02 * ALTURA and zona[j] == zona[i])
    return total


candidatos = [g for g in (g1, g2) if errores[g] <= 2 * errores[g1]]
grados = max(candidatos, key=coincidencias)
grados = min(np.arange(grados - 3, grados + 3.01, 0.5), key=lambda g: error_espejo(math.radians(g)))
theta = math.radians(grados)
frente = np.array([-math.sin(theta), math.cos(theta), 0.0])  # dentro del plano de simetría
hacia_camara = -ejes(mejor[1], mejor[2])[2]
if frente @ hacia_camara < 0:
    frente = -frente
if ficha.get("girar_180"):  # la ficha manda cuando el encaje con la imagen se equivoca (cuerpos redondos)
    frente = -frente
phi = -math.pi / 2 - math.atan2(frente[1], frente[0])
c, s_ = math.cos(phi), math.sin(phi)
rot = np.array([[c, -s_, 0], [s_, c, 0], [0, 0, 1]])
V = (V - [c0[0], c0[1], 0]) @ rot.T  # el plano de simetría queda en x = 0
V[:, 1] -= (V[:, 1].min() + V[:, 1].max()) / 2
H.data.vertices.foreach_set("co", V.ravel())
H.data.update()
informe["simetria"] = {"planos_probados": {g1: coincidencias(g1), g2: coincidencias(g2)}, "error_espejo_rel": round(error_espejo(theta) / ALTURA, 4), "giro_grados": round(math.degrees(phi), 1)}
paso("orientar", t)

# ---------------------------------------------------------------- 5. completar zonas: espejo, vecinos por la superficie y suavizado
t = time.time()
N = np.empty(len(V) * 3)
H.data.vertices.foreach_get("normal", N)
N = N.reshape(-1, 3)
idx_vis = np.nonzero(zona >= 0)[0]
arbol = kdtree.KDTree(len(idx_vis))
for i in idx_vis:
    arbol.insert(Vector(V[i]), int(i))
arbol.balance()
umbral = 0.02 * ALTURA
espejadas = 0
for i in np.nonzero(zona < 0)[0]:
    p = V[i]
    _, j, d = arbol.find(Vector((-p[0], p[1], p[2])))
    if d < umbral:
        zona[i] = zona[j]
        espejadas += 1
informe["vertices_por_espejo_pct"] = round(100 * espejadas / len(V), 1)
# lo que sigue sin zona (barriga, espalda...): vecino con zona más cercano cuya normal apunte igual,
# para no copiar a través de partes finas (orejas, cola)
conocidos = np.nonzero(zona >= 0)[0]
arbol = kdtree.KDTree(len(conocidos))
for i in conocidos:
    arbol.insert(Vector(V[i]), int(i))
arbol.balance()
for i in np.nonzero(zona < 0)[0]:
    vecinos = arbol.find_n(Vector(V[i]), 16)
    elegido = next((j for (_, j, _) in vecinos if N[j] @ N[i] > 0.3), vecinos[0][1])
    zona[i] = zona[elegido]
# suavizado: mayoría entre los vecinos más cercanos (quita motas sueltas)
todos = kdtree.KDTree(len(V))
for i, p in enumerate(V):
    todos.insert(Vector(p), i)
todos.balance()
for _ in range(2):
    nueva = zona.copy()
    for i, p in enumerate(V):
        vec = [zona[j] for (_, j, _) in todos.find_n(Vector(p), 12)]
        nueva[i] = np.bincount(vec, minlength=len(ZONAS)).argmax()
    zona = nueva
# limpieza: islas pequeñas de una zona (brillos y sombras de la imagen) y manchas de ojos lejos de la cara
E = np.empty(len(H.data.edges) * 2, dtype=np.int64)
H.data.edges.foreach_get("vertices", E)
E = E.reshape(-1, 2)


def componentes(m):
    lab = np.where(m, np.arange(len(m)), len(m))
    e = E[m[E[:, 0]] & m[E[:, 1]]]
    while True:
        mn = np.minimum(lab[e[:, 0]], lab[e[:, 1]])
        nueva = lab.copy()
        np.minimum.at(nueva, e[:, 0], mn)
        np.minimum.at(nueva, e[:, 1], mn)
        nueva = np.where(m, nueva[np.minimum(nueva, len(m) - 1)], len(m))
        if np.array_equal(nueva, lab):
            return lab
        lab = nueva


islas = 0
for k in range(len(ZONAS)):
    m = zona == k
    if not m.any():
        continue
    lab = componentes(m)
    ids, cnt = np.unique(lab[m], return_counts=True)
    for i_, c_ in zip(ids, cnt):
        sel = lab == i_
        if k == I_OJOS:
            quitar = V[sel].mean(0)[1] > V[:, 1].min() + 0.4 * (V[:, 1].max() - V[:, 1].min())  # lejos del frente
        else:
            quitar = c_ < 0.0015 * len(V)  # solo motas: las rayas y el antifaz son islas legítimas
        if quitar:
            zona[sel] = -1
            islas += 1
informe["islas_limpiadas"] = islas
while (zona < 0).any():
    votos = np.zeros((len(V), len(ZONAS)))
    for a_, b_ in ((0, 1), (1, 0)):
        ok = (zona[E[:, a_]] < 0) & (zona[E[:, b_]] >= 0)
        np.add.at(votos, (E[ok, a_], zona[E[ok, b_]]), 1)
    llenar = (zona < 0) & (votos.sum(1) > 0)
    if not llenar.any():
        zona[zona < 0] = 0
        break
    zona[llenar] = votos[llenar].argmax(1)


def aplicar_reglas(V, N):
    """Zonas pintadas con reglas de la ficha (en studs: x lado, -y frente, z arriba desde el suelo).
    Empieza todo en la primera zona y cada regla pinta encima de las anteriores."""
    z = np.zeros(len(V), dtype=np.int64)
    for r in ficha["regla"]:
        k = ZONAS.index(r["zona"])
        for sx in ([1, -1] if r.get("espejo") else [1]):
            if r["tipo"] == "elipsoide":
                c = np.array(r["centro"], dtype=np.float64) * [sx, 1, 1]
                m = (((V - c) / np.array(r["radios"])) ** 2).sum(1) <= 1
            elif r["tipo"] == "rayas":  # bandas alternas a lo largo de un tramo (cola)
                a = np.array(r["desde"], dtype=np.float64) * [sx, 1, 1]
                d = np.array(r["hasta"], dtype=np.float64) * [sx, 1, 1] - a
                tt = ((V - a) @ d) / (d @ d)
                dist = np.linalg.norm(V - a - tt[:, None] * d, axis=1)
                m = (tt >= 0) & (tt <= 1) & (dist <= r["radio"]) & ((tt * r["n"]) % 1 < r.get("ancho", 0.5))
            else:
                raise ValueError(f"regla desconocida: {r['tipo']}")
            if r.get("solo_frente"):  # solo la cara que mira hacia delante (no la parte de atrás de una oreja)
                m &= N[:, 1] < -0.2
            z[m] = k
    return z


if ficha.get("regla"):
    zona = aplicar_reglas(V, N)
    informe["pintado"] = "reglas de la ficha"
informe["zonas_pct"] = {z: round(100 * float((zona == k).mean()), 1) for k, z in enumerate(ZONAS)}

# color por cara (no por vértice): sin mezclas en los bordes entre zonas, que al ajustar a la paleta
# se comían las zonas oscuras (rayas finas)
LV = np.empty(len(H.data.loops), dtype=np.int64)
H.data.loops.foreach_get("vertex_index", LV)
LS = np.empty(len(H.data.polygons), dtype=np.int64)
H.data.polygons.foreach_get("loop_start", LS)
LT = np.empty(len(H.data.polygons), dtype=np.int64)
H.data.polygons.foreach_get("loop_total", LT)
z0, z1, z2 = zona[LV[LS]], zona[LV[LS + 1]], zona[LV[LS + np.minimum(2, LT - 1)]]
zc = np.where(z1 == z2, z1, z0)  # mayoría de los tres primeros vértices
lin = srgb_a_lineal(BASE[np.repeat(zc, LT)])
rgba = np.concatenate([lin, np.ones((len(lin), 1))], 1).astype(np.float32)
attr = H.data.color_attributes.new("zona", "FLOAT_COLOR", "CORNER")
attr.data.foreach_set("color", rgba.ravel())
paso("zonas", t)

if cfg.get("guardar_alta"):  # malla alta ya orientada, para ajustar las reglas a la vista en un Blender abierto
    seleccionar([H], H)
    bpy.ops.export_scene.gltf(filepath=f"{OUT}/alta.glb", use_selection=True, export_format="GLB", export_materials="NONE", export_yup=True)

# ---------------------------------------------------------------- 6. versión ligera + UV
t = time.time()
seleccionar([H], H)
bpy.ops.object.duplicate()
L = bpy.context.view_layer.objects.active
L.name = cfg["mascota"]
L.data.color_attributes.remove(L.data.color_attributes["zona"])
tri_alta = sum(len(p.vertices) - 2 for p in L.data.polygons)
mod = L.modifiers.new("dec", "DECIMATE")
mod.ratio = min(1.0, TRIS / tri_alta)
bpy.ops.object.modifier_apply(modifier=mod.name)
mod = L.modifiers.new("tri", "TRIANGULATE")
bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.ops.object.shade_smooth()
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
bpy.ops.object.mode_set(mode="OBJECT")
uv_l = np.empty(len(L.data.loops) * 2)
L.data.uv_layers.active.data.foreach_get("uv", uv_l)
L.data.uv_layers.active.data.foreach_set("uv", uv_l * 0.92)  # franja libre arriba y a la derecha


def uv_zona(k):  # celdas de color liso en la franja libre, una por zona; arriba del todo, el brillo blanco
    return (0.965, 0.03 + 0.06 * k)


UV_BRILLO = (0.965, 0.95)
VL = verts_np(L.data)  # la reducción mueve vértices: volver a apoyarlo en el suelo
VL[:, 2] -= VL[:, 2].min()
L.data.vertices.foreach_set("co", VL.ravel())
L.data.update()
informe["triangulos_final"] = len(L.data.polygons)
paso("reducir_uv", t)

# ---------------------------------------------------------------- 7. hornear color (zonas) y relieve
t = time.time()
esc = bpy.context.scene
esc.render.engine = "CYCLES"
try:
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = "CUDA"
    prefs.get_devices()
    for dev in prefs.devices:
        dev.use = True
    esc.cycles.device = "GPU"
except Exception as e:
    print("Cycles en CPU:", e)
esc.cycles.samples = 1

mat_h = bpy.data.materials.new("zona")
mat_h.use_nodes = True
nt = mat_h.node_tree
for n in list(nt.nodes):
    nt.nodes.remove(n)
a = nt.nodes.new("ShaderNodeAttribute")
a.attribute_name = "zona"
em = nt.nodes.new("ShaderNodeEmission")
salida_h = nt.nodes.new("ShaderNodeOutputMaterial")
nt.links.new(a.outputs["Color"], em.inputs["Color"])
nt.links.new(em.outputs["Emission"], salida_h.inputs["Surface"])
H.data.materials.clear()
H.data.materials.append(mat_h)


def imagen_nueva(nombre, no_color=False):
    im = bpy.data.images.new(nombre, RES_TEX, RES_TEX, alpha=False, float_buffer=False)
    if no_color:
        im.colorspace_settings.name = "Non-Color"
    return im


mat_l = bpy.data.materials.new("hornear")
mat_l.use_nodes = True
nodo_img = mat_l.node_tree.nodes.new("ShaderNodeTexImage")
mat_l.node_tree.nodes.active = nodo_img
L.data.materials.clear()
L.data.materials.append(mat_l)
seleccionar([H, L], L)
extr = 0.04 * ALTURA

im_color = imagen_nueva("color")
nodo_img.image = im_color
bpy.ops.object.bake(type="EMIT", use_selected_to_active=True, cage_extrusion=extr, margin=8)
im_normal = imagen_nueva("normal", no_color=True)
nodo_img.image = im_normal
bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", use_selected_to_active=True, cage_extrusion=extr, margin=8)
if ficha.get("regla"):
    # Con reglas, la zona se decide píxel a píxel (bordes lisos) y no por triángulo (bordes en zigzag):
    # se hornea la posición y la normal de la malla alta que cae en cada píxel y se aplican las reglas ahí.
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    mas = nt.nodes.new("ShaderNodeVectorMath")
    mas.operation = "ADD"
    mas.inputs[1].default_value = (10.0, 10.0, 10.0)  # todo positivo; 0 = píxel sin hornear
    nt.links.new(mas.outputs["Vector"], em.inputs["Color"])
    hornos = {}
    for salida_geo in ("Position", "Normal"):
        nt.links.new(geo.outputs[salida_geo], mas.inputs[0])
        im = bpy.data.images.new(salida_geo, RES_TEX, RES_TEX, alpha=False, float_buffer=True)
        im.colorspace_settings.name = "Non-Color"
        nodo_img.image = im
        bpy.ops.object.bake(type="EMIT", use_selected_to_active=True, cage_extrusion=extr, margin=0)
        px_ = np.empty(RES_TEX * RES_TEX * 4, dtype=np.float32)
        im.pixels.foreach_get(px_)
        hornos[salida_geo] = px_.reshape(-1, 4)[:, :3].astype(np.float64)
paso("hornear", t)

# ---------------------------------------------------------------- 7b. ojos (y nariz) como piezas de verdad
# Cada mancha de la zona de ojos se cubre con una pieza redonda y su brillo, con color liso de la franja libre.
t = time.time()
piezas_ojo = []  # (centro, normal, radio, zona, brillo)
if ficha.get("pieza"):
    # piezas puestas por la ficha: se lanza un rayo desde delante hasta la superficie en (x, z)
    bm_h = bmesh.new()
    bm_h.from_mesh(H.data)
    arbol_h = BVHTree.FromBMesh(bm_h)
    for p in ficha["pieza"]:
        for sx in ([1, -1] if p.get("espejo") else [1]):
            x, z = p["en"]
            golpe, normal, _, _ = arbol_h.ray_cast(Vector((sx * x, -10.0, z)), Vector((0, 1, 0)))
            if golpe is None:
                print("pieza sin superficie:", p, flush=True)
                continue
            piezas_ojo.append((np.array(golpe), np.array(normal.normalized()), p["radio"], ZONAS.index(p["zona"]), p.get("brillo", False)))
    bm_h.free()
elif I_OJOS is not None:
    VH = verts_np(H.data)
    NH = np.empty(len(VH) * 3)
    H.data.vertices.foreach_get("normal", NH)
    NH = NH.reshape(-1, 3)
    m = zona == I_OJOS
    if m.any():
        lab = componentes(m)
        ids, cnt = np.unique(lab[m], return_counts=True)
        for i_, c_ in zip(ids, cnt):
            if c_ < 0.0002 * len(VH):
                continue
            sel = lab == i_
            c = VH[sel].mean(0)
            n = NH[sel].mean(0)
            n /= np.linalg.norm(n)
            r = 1.5 * math.sqrt(((VH[sel] - c) ** 2).sum(1).mean())
            piezas_ojo.append((c, n, r, I_OJOS, True))
bm_l = bmesh.new()
bm_l.from_mesh(L.data)
uv_bm = bm_l.loops.layers.uv.active


def esfera(c, n, radios, uvc, res):
    ey = Vector(-n)
    ez = Vector((0, 0, 1)) - ey * ey.z
    ez = ez.normalized() if ez.length > 1e-3 else Vector((0, -1, 0))
    ex = ey.cross(ez)
    M = Matrix((ex, ey, ez)).transposed()
    tmp = bmesh.new()
    bmesh.ops.create_uvsphere(tmp, u_segments=res[0], v_segments=res[1], radius=1.0)
    for v in tmp.verts:
        v.co = Vector(c) + M @ Vector((v.co.x * radios[0], v.co.y * radios[1], v.co.z * radios[2]))
    me_t = bpy.data.meshes.new("t")
    tmp.to_mesh(me_t)
    tmp.free()
    antes = len(bm_l.faces)
    bm_l.from_mesh(me_t)
    bpy.data.meshes.remove(me_t)
    bm_l.faces.ensure_lookup_table()
    for f in bm_l.faces[antes:]:
        f.smooth = True
        for l in f.loops:
            l[uv_bm].uv = uvc


for c, n, r, k, brillo in piezas_ojo:
    nv = Vector(n)
    esfera(Vector(c) + nv * 0.15 * r, n, (r, 0.6 * r, r), uv_zona(k), (12, 8))
    if not brillo:
        continue
    arriba = (Vector((0, 0, 1)) - nv * nv.z).normalized()
    lado = nv.cross(arriba)
    esfera(Vector(c) + nv * 0.62 * r + arriba * 0.4 * r + lado * 0.3 * r, n, (0.28 * r, 0.15 * r, 0.28 * r), UV_BRILLO, (8, 5))
bm_l.to_mesh(L.data)
bm_l.free()
informe["ojos_piezas"] = len(piezas_ojo)
informe["triangulos_final"] = sum(len(p.vertices) - 2 for p in L.data.polygons)
# relieve plano en la franja de los ojos
npx = np.empty(RES_TEX * RES_TEX * 4, dtype=np.float32)
im_normal.pixels.foreach_get(npx)
npx = npx.reshape(RES_TEX, RES_TEX, 4)
franja = int(0.93 * RES_TEX)
npx[franja:, :, :3] = (0.5, 0.5, 1.0)
npx[:, franja:, :3] = (0.5, 0.5, 1.0)
im_normal.pixels.foreach_set(npx.ravel())
paso("ojos", t)

# ---------------------------------------------------------------- 8. colores exactos de la paleta + mutaciones
t = time.time()
pix = np.empty(RES_TEX * RES_TEX * 4, dtype=np.float32)
im_color.pixels.foreach_get(pix)
pix = pix.reshape(-1, 4)
lab = np.argmin(((pix[:, None, :3] - BASE[None]) ** 2).sum(-1), axis=1)
lab[pix[:, :3].sum(1) == 0] = 0  # fondo sin hornear: color del cuerpo, para que de lejos no salgan bordes negros
if ficha.get("regla"):
    cubierto = hornos["Position"].sum(1) > 0
    lab = aplicar_reglas(hornos["Position"] - 10, hornos["Normal"] - 10)
    lab[~cubierto] = 0
    # el margen de 8 px alrededor de cada isla: copiar la zona del píxel cubierto más cercano (evita costuras)
    lab2 = lab.reshape(RES_TEX, RES_TEX)
    cub2 = cubierto.reshape(RES_TEX, RES_TEX)
    for _ in range(8):
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            vecino = np.roll(np.roll(lab2, dy, 0), dx, 1)
            vcub = np.roll(np.roll(cub2, dy, 0), dx, 1)
            nuevo = ~cub2 & vcub
            lab2[nuevo] = vecino[nuevo]
            cub2 = cub2 | nuevo
    lab = lab2.ravel()
yy, xx = np.divmod(np.arange(RES_TEX * RES_TEX), RES_TEX)
uu, vv = (xx + 0.5) / RES_TEX, (yy + 0.5) / RES_TEX
for k in range(len(ZONAS)):
    lab[(uu > 0.93) & (vv >= 0.06 * k) & (vv < 0.06 * (k + 1))] = k
BLANCO_PX = (uu > 0.93) & (vv > 0.9)


def guardar(nombre, colores, ruta):
    im = bpy.data.images.new(nombre, RES_TEX, RES_TEX, alpha=False)
    p = np.concatenate([colores[lab], np.ones((len(lab), 1))], 1).astype(np.float32)
    p[BLANCO_PX, :3] = 1.0
    im.pixels.foreach_set(p.ravel())
    im.filepath_raw = ruta
    im.file_format = "PNG"
    im.save()
    return im


texturas = {"base": guardar("color_base", BASE, f"{OUT}/color_base.png")}
for m in ficha.get("mutaciones", {}):
    texturas[m] = guardar(f"color_{m}", colores_mutacion(m), f"{OUT}/color_{m}.png")
im_normal.filepath_raw = f"{OUT}/normal.png"
im_normal.file_format = "PNG"
im_normal.save()
usados = {tuple(np.round(c, 3)) for c in np.unique(BASE[lab], axis=0)}
informe["solo_colores_de_paleta"] = usados <= {tuple(np.round(hex_rgb(v), 3)) for v in PALETA.values()}
paso("paleta_mutaciones", t)

# ---------------------------------------------------------------- 9. exportar
t = time.time()
seleccionar([L], L)
L.data.materials.clear()
bpy.ops.wm.obj_export(filepath=f"{OUT}/{cfg['mascota']}.obj", export_selected_objects=True, export_materials=False,
                      export_uv=True, export_normals=True, forward_axis="NEGATIVE_Z", up_axis="Y", apply_modifiers=True)
# Open Cloud solo acepta modelos en FBX/glTF/GLB (no OBJ): el GLB es el que se sube a Roblox.
bpy.ops.export_scene.gltf(filepath=f"{OUT}/{cfg['mascota']}.glb", use_selection=True, export_format="GLB",
                          export_materials="NONE", export_yup=True)
paso("exportar", t)

# ---------------------------------------------------------------- 10. comprobaciones
bm = bmesh.new()
bm.from_mesh(L.data)
VL = verts_np(L.data)
informe["comprobaciones"] = {
    "triangulos_ok": informe["triangulos_final"] <= TRIS * 1.05,
    "altura": round(float(VL[:, 2].max() - VL[:, 2].min()), 3),
    "apoyado_en_suelo": abs(float(VL[:, 2].min())) < 1e-3,
    "aristas_abiertas": sum(1 for e in bm.edges if e.is_boundary),
    "aristas_no_manifold": sum(1 for e in bm.edges if not e.is_manifold),
    "solo_colores_de_paleta": informe["solo_colores_de_paleta"],
}
bm.free()

# ---------------------------------------------------------------- 11. vistas para la revisión
t = time.time()
bpy.data.objects.remove(H, do_unlink=True)
esc.cycles.samples = 24
esc.cycles.use_denoising = False
esc.render.resolution_x = esc.render.resolution_y = 384
esc.render.film_transparent = False
mundo = bpy.data.worlds.new("mundo")
mundo.use_nodes = True
fondo_n = next(n for n in mundo.node_tree.nodes if n.type == "BACKGROUND")
fondo_n.inputs["Color"].default_value = (0.82, 0.83, 0.85, 1)
fondo_n.inputs["Strength"].default_value = 0.9
esc.world = mundo
for nombre, rot, energia in [("sol", (math.radians(50), 0, math.radians(30)), 3.0), ("relleno", (math.radians(60), 0, math.radians(200)), 1.0)]:
    luz = bpy.data.objects.new(nombre, bpy.data.lights.new(nombre, "SUN"))
    luz.data.energy = energia
    luz.rotation_euler = rot
    esc.collection.objects.link(luz)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = ALTURA * 1.6
esc.collection.objects.link(cam)
esc.camera = cam


def material_vista(tex, con_normal):
    mt = bpy.data.materials.new("vista")
    mt.use_nodes = True
    n = mt.node_tree
    bsdf = next(x for x in n.nodes if x.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = 0.75
    ti = n.nodes.new("ShaderNodeTexImage")
    ti.image = tex
    n.links.new(ti.outputs["Color"], bsdf.inputs["Base Color"])
    if con_normal:
        tn = n.nodes.new("ShaderNodeTexImage")
        tn.image = im_normal
        nm = n.nodes.new("ShaderNodeNormalMap")
        n.links.new(tn.outputs["Color"], nm.inputs["Color"])
        n.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    L.data.materials.clear()
    L.data.materials.append(mt)


def foto(yaw, elev, ruta):
    r, u, f = ejes(yaw, elev)
    objetivo = Vector((0, 0, ALTURA / 2))
    cam.location = objetivo - Vector(f) * ALTURA * 4
    cam.rotation_euler = (objetivo - cam.location).to_track_quat("-Z", "Y").to_euler()
    esc.render.filepath = ruta
    bpy.ops.render.render(write_still=True)


VISTAS = {"frente": (0, 5), "derecha": (90, 5), "atras": (180, 5), "izquierda": (270, 5), "arriba": (0, 89), "tres_cuartos": (-35, 20)}
material_vista(texturas["base"], False)
for v, (yy, ee) in VISTAS.items():
    foto(yy, ee, f"{OUT}/vista_{v}.png")
material_vista(texturas["base"], True)
foto(-35, 20, f"{OUT}/vista_con_normal.png")
for m in ficha.get("mutaciones", {}):
    material_vista(texturas[m], True)
    foto(-35, 20, f"{OUT}/vista_mutacion_{m}.png")
paso("vistas", t)

informe["segundos_total"] = round(time.time() - T0, 1)
json.dump(informe, open(f"{OUT}/informe.json", "w"), indent=2, ensure_ascii=False)
print("INFORME", json.dumps(informe, ensure_ascii=False), flush=True)
