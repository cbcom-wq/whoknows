# Helpers shared by the Wadee spike builders (from wadee_build.py).
import bpy, bmesh, math
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c) + (1.0,)


MATS = {}


def mat(name, hexcol, rough=0.8, metal=0.0):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = srgb(hexcol)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    MATS[name] = m
    return m


def frame(T, ref=None):
    T = T.normalized()
    ref = Vector((1, 0, 0)) if ref is None else Vector(ref)
    if abs(T.dot(ref.normalized())) > 0.95:
        ref = Vector((0, 0, 1)) if abs(T.z) < 0.9 else Vector((0, 1, 0))
    side = (ref - T * T.dot(ref)).normalized()
    front = T.cross(side).normalized()
    return side, front


def tube(bm, rings, segs=16, caps=True, loop=False, fn=None, ref=None):
    n = len(rings)
    allr = []
    for i, (c, rx, ry) in enumerate(rings):
        c = Vector(c)
        if loop:
            T = Vector(rings[(i + 1) % n][0]) - Vector(rings[i - 1][0])
        else:
            T = Vector(rings[min(i + 1, n - 1)][0]) - Vector(rings[max(i - 1, 0)][0])
        s, f = frame(T, ref(i) if callable(ref) else ref)
        ring = []
        for k in range(segs):
            a = 2 * math.pi * k / segs
            m = fn(i / (n - 1) if n > 1 else 0.0, a) if fn else 1.0
            ring.append(bm.verts.new(c + s * (rx * m * math.cos(a)) + f * (ry * m * math.sin(a))))
        allr.append(ring)
    for i in (range(n) if loop else range(n - 1)):
        a, b = allr[i], allr[(i + 1) % n]
        for k in range(segs):
            bm.faces.new((a[k], a[(k + 1) % segs], b[(k + 1) % segs], b[k]))
    if caps and not loop:
        for ring, rev in ((allr[0], True), (allr[-1], False)):
            c0 = sum((v.co for v in ring), Vector()) / segs
            if len(rings) > 1:
                out = (c0 - (sum((v.co for v in allr[1 if rev else -2]), Vector()) / segs)).normalized()
                c0 = c0 + out * min(rings[0 if rev else -1][1], rings[0 if rev else -1][2]) * 0.8
            c = bm.verts.new(c0)
            for k in range(segs):
                vs = (c, ring[k], ring[(k + 1) % segs])
                bm.faces.new(vs[::-1] if rev else vs)
    return allr


def ellipsoid(bm, c, r, segs=16, rings=10, rot=None):
    ret = bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
    M = Matrix.Translation(Vector(c)) @ (rot.to_4x4() if rot is not None else Matrix.Identity(4)) \
        @ Matrix.Diagonal((r[0], r[1], r[2], 1.0))
    bmesh.ops.transform(bm, matrix=M, verts=ret["verts"])
    return ret["verts"]


def obj_from(bm, name, material, coll, smooth=True):
    me = bpy.data.meshes.new(name)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    coll.objects.link(o)
    me.materials.append(material)
    for p in me.polygons:
        p.use_smooth = smooth
    return o


def bake(o):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
    o.modifiers.clear()
    o.data = me
    for p in me.polygons:
        p.use_smooth = True


def remesh(o, voxel=0.0045, smooth_iters=4, tris=None):
    m = o.modifiers.new("r", "REMESH")
    m.mode = "VOXEL"
    m.voxel_size = voxel
    bake(o)
    if smooth_iters:
        s = o.modifiers.new("s", "SMOOTH")
        s.factor = 0.5
        s.iterations = smooth_iters
        bake(o)
    if tris:
        have = sum(len(p.vertices) - 2 for p in o.data.polygons)
        if have > tris:
            d = o.modifiers.new("d", "DECIMATE")
            d.ratio = tris / have
            bake(o)


def bvh(o):
    dg = bpy.context.evaluated_depsgraph_get()
    return BVHTree.FromObject(o, dg)


def hit_front(tree, x, z, from_y=-1.0):
    loc, n, _, _ = tree.ray_cast(Vector((x, from_y, z)), Vector((0, 1, 0)))
    return loc, n


def near(tree, p, off):
    loc, n, _, _ = tree.find_nearest(Vector(p))
    return loc + n * off, n


def radial(tree, a, z, off, cy=-0.005):
    d = Vector((math.cos(a), math.sin(a), 0))
    o = Vector((0, cy, z)) + d * 0.5
    loc, n, _, _ = tree.ray_cast(o, -d)
    if loc is None:
        loc, n, _, _ = tree.find_nearest(Vector((0, cy, z)) + d * 0.15)
    return loc + d * off


def radialn(tree, a, z, off, cy=-0.005):
    d = Vector((math.cos(a), math.sin(a), 0))
    o = Vector((0, cy, z)) + d * 0.5
    loc, n, _, _ = tree.ray_cast(o, -d)
    if loc is None:
        loc, n, _, _ = tree.find_nearest(Vector((0, cy, z)) + d * 0.15)
    return loc + n * off, n


def rot_to(normal, up=Vector((0, 0, 1))):
    y = normal.normalized()
    x = up.cross(y)
    if x.length < 1e-4:
        x = Vector((1, 0, 0))
    x.normalize()
    z = x.cross(y).normalized()
    return Matrix((x, y, z)).transposed()


