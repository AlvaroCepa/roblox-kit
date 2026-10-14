# roblox-kit (skill modelos-3d).
# Vista previa EN DIRECTO (Blender abierto, vía MCP) de las reglas de color y piezas de una ficha,
# sobre la malla alta ya orientada (alta.glb que deja procesar.py con "guardar_alta").
# Mismas reglas que procesar.py (aplicar_reglas y piezas); aquí solo se pinta para mirar y ajustar.
import math, tomllib
import bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix


def hex_rgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.float64) / 255.0


def lineal(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def pintar(obj, ruta_ficha, ruta_estilo, mutacion=None):
    ficha = tomllib.load(open(ruta_ficha, "rb"))
    paleta = tomllib.load(open(ruta_estilo, "rb"))["paleta"]
    zonas = list(ficha["zonas"])
    cambios = ficha.get("mutaciones", {}).get(mutacion, {}) if mutacion else {}
    color = np.array([hex_rgb(paleta[cambios.get(z, ficha["zonas"][z]["color"])]) for z in zonas])

    me = obj.data
    V = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", V)
    V = V.reshape(-1, 3)
    N = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("normal", N)
    N = N.reshape(-1, 3)

    zona = np.zeros(len(V), dtype=np.int64)
    for r in ficha.get("regla", []):
        k = zonas.index(r["zona"])
        for sx in ([1, -1] if r.get("espejo") else [1]):
            if r["tipo"] == "elipsoide":
                c = np.array(r["centro"], dtype=np.float64) * [sx, 1, 1]
                m = (((V - c) / np.array(r["radios"])) ** 2).sum(1) <= 1
            elif r["tipo"] == "rayas":
                a = np.array(r["desde"], dtype=np.float64) * [sx, 1, 1]
                d = np.array(r["hasta"], dtype=np.float64) * [sx, 1, 1] - a
                tt = ((V - a) @ d) / (d @ d)
                dist = np.linalg.norm(V - a - tt[:, None] * d, axis=1)
                m = (tt >= 0) & (tt <= 1) & (dist <= r["radio"]) & ((tt * r["n"]) % 1 < r.get("ancho", 0.5))
            if r.get("solo_frente"):
                m &= N[:, 1] < -0.2
            zona[m] = k

    # color por cara, como en procesar.py
    LV = np.empty(len(me.loops), dtype=np.int64)
    me.loops.foreach_get("vertex_index", LV)
    LS = np.empty(len(me.polygons), dtype=np.int64)
    me.polygons.foreach_get("loop_start", LS)
    LT = np.empty(len(me.polygons), dtype=np.int64)
    me.polygons.foreach_get("loop_total", LT)
    z0, z1, z2 = zona[LV[LS]], zona[LV[LS + 1]], zona[LV[LS + np.minimum(2, LT - 1)]]
    zc = np.where(z1 == z2, z1, z0)
    rgba = np.concatenate([lineal(color[np.repeat(zc, LT)]), np.ones((len(LV), 1))], 1).astype(np.float32)
    if "vista" in me.color_attributes:
        me.color_attributes.remove(me.color_attributes["vista"])
    attr = me.color_attributes.new("vista", "FLOAT_COLOR", "CORNER")
    attr.data.foreach_set("color", rgba.ravel())
    me.color_attributes.active_color = attr

    # piezas (ojos, nariz...): rayo desde delante en (x, z)
    col = bpy.data.collections.get("piezas") or bpy.data.collections.new("piezas")
    if col.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(col)
    for o in list(col.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for p in ficha.get("pieza", []):
        for sx in ([1, -1] if p.get("espejo") else [1]):
            x, z = p["en"]
            ok, golpe, normal, _ = obj.ray_cast(Vector((sx * x, -10.0, z)), Vector((0, 1, 0)))
            if not ok:
                continue
            r = p["radio"]
            esfera(col, golpe + normal * 0.15 * r, normal, (r, 0.6 * r, r), color[zonas.index(p["zona"])])
            if p.get("brillo"):
                arriba = (Vector((0, 0, 1)) - normal * normal.z).normalized()
                lado = normal.cross(arriba)
                esfera(col, golpe + normal * 0.62 * r + arriba * 0.4 * r + lado * 0.3 * r, normal,
                       (0.28 * r, 0.15 * r, 0.28 * r), np.ones(3))
    return {z: round(100 * float((zona == k).mean()), 1) for k, z in enumerate(zonas)}


def esfera(col, c, n, radios, rgb):
    ey = -n
    ez = Vector((0, 0, 1)) - ey * ey.z
    ez = ez.normalized() if ez.length > 1e-3 else Vector((0, -1, 0))
    ex = ey.cross(ez)
    M = Matrix((ex, ey, ez)).transposed()
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=1.0)
    for v in bm.verts:
        v.co = c + M @ Vector((v.co.x * radios[0], v.co.y * radios[1], v.co.z * radios[2]))
    me = bpy.data.meshes.new("pieza")
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    a = me.color_attributes.new("vista", "FLOAT_COLOR", "CORNER")
    rgba = np.tile(np.append(lineal(rgb), 1.0), (len(me.loops), 1)).astype(np.float32)
    a.data.foreach_set("color", rgba.ravel())
    o = bpy.data.objects.new("pieza", me)
    col.objects.link(o)
