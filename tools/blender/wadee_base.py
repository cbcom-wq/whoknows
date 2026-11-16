# The Wadees of WADIS: Blender's Human Base Meshes (CC0, realistic female and male bodies)
# posed arms-down and slimmed, with eyes, brows, lips, hair, clothes and jewellery built in code.
# Writes wadee_<a|b|c|m|n>.glb (and, with "render", Blender test shots). See README.md here.
#   blender -b --factory-startup --disable-autoexec --python wadee_base.py -- <bundle.blend> <out dir> [render]
import bpy, bmesh, math, sys, os, random
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wkit import *  # noqa

ARGS = sys.argv[sys.argv.index("--") + 1:]
BUNDLE, OUT = ARGS[0], ARGS[1]
RENDER = "render" in ARGS
os.makedirs(OUT, exist_ok=True)
H = 1.745          # every body is first scaled to this height; the variant scale comes after
MULTIRES = 2       # level of the base's sculpt kept before decimating
BODY_TRIS = 40000

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)
SRC = {"f": "GEO-body_female_realistic", "m": "GEO-body_male_realistic"}
with bpy.data.libraries.load(BUNDLE, link=False) as (src, dst):
    dst.objects = [n for k in SRC.values() for n in (k, k + ".eye.L", k + ".eye.R")]
for o in dst.objects:
    bpy.context.scene.collection.objects.link(o)
    o.hide_render = True


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def baked_mesh(o, level=None):
    if level is not None:
        for m in o.modifiers:
            if m.type == "MULTIRES":
                m.levels = level
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
    me.transform(o.matrix_world)
    return me


def base_for(sex):
    """The base body (posed, at height H, centred) and its two eye meshes, as new meshes."""
    name = SRC[sex]
    body = bpy.data.objects[name]
    me = baked_mesh(body, MULTIRES)
    eyes = [baked_mesh(bpy.data.objects[name + e]) for e in (".eye.L", ".eye.R")]
    zs = [v.co.z for v in me.vertices]
    xs = [v.co.x for v in me.vertices]
    z0, z1 = min(zs), max(zs)
    cx = (min(xs) + max(xs)) / 2
    k = H / (z1 - z0)
    T = Matrix.Diagonal((k, k, k, 1)) @ Matrix.Translation((-cx, 0, -z0))
    for m in [me] + eyes:
        m.transform(T)
    return me, eyes


def pose_arms_down(me, down_deg=8.0):
    """Lowers the A-pose arms about each shoulder. The arm is what lies past a plane through the
    armpit, leaning out between the torso's side and the arm's underside. Returns the arm weight per vertex."""
    co = [v.co.copy() for v in me.vertices]
    w_all = [0.0] * len(co)
    for s in (-1, 1):
        side = [p for p in co if 0.05 < s * p.x < 0.6]
        armpit = None
        z = 0.80 * H
        while z > 0.6 * H and armpit is None:
            xs = sorted(s * p.x for p in side if abs(p.z - z) < 0.003)
            gaps = [(xs[i + 1] - xs[i], xs[i], xs[i + 1]) for i in range(len(xs) - 1)]
            big = [g for g in gaps if g[0] > 0.012]
            if big:
                g = min(big, key=lambda g: g[1])
                ys = [p.y for p in side if abs(p.z - z) < 0.003 and g[1] - 0.02 < s * p.x < g[2] + 0.02]
                armpit = Vector((s * (g[1] + g[2]) / 2, sum(ys) / len(ys), z))
            z -= 0.004
        hand = [p for p in co if s * p.x > 0.36 and p.z > 0.6]
        tip = sum(hand, Vector()) / len(hand)
        pivot = Vector((armpit.x + s * 0.012, armpit.y, armpit.z + 0.055))
        d = (tip - pivot).normalized()
        target = Vector((s * math.sin(math.radians(down_deg)), 0.03, -math.cos(math.radians(down_deg)))).normalized()
        axis = d.cross(target).normalized()
        ang = d.angle(target)
        n = Vector((s * 0.92, 0, 0.38)).normalized()
        print("WADEE armpit", s, tuple(round(c, 3) for c in armpit), "arm angle %.1f" % math.degrees(ang))
        for i, p in enumerate(co):
            if s * p.x <= 0:
                continue
            w = smoothstep(-0.012, 0.03, (p - armpit).dot(n)) * smoothstep(-0.06, 0.0, (p - pivot).dot(d))
            if w <= 0:
                continue
            me.vertices[i].co = pivot + Matrix.Rotation(ang * w, 3, axis) @ (p - pivot)
            w_all[i] = w
    me.update()
    return w_all


def push_out(o, tree, margin, only=None):
    for v in o.data.vertices:
        if only is not None and not only(v.co):
            continue
        loc, n, _, _ = tree.find_nearest(v.co)
        if loc is None:
            continue
        if (v.co - loc).dot(n) < margin:
            v.co = loc + n * margin
    o.data.update()


def extents_at(tree, z, cy=0.0):
    ex = {}
    for a, key in ((0, "+x"), (math.pi, "-x"), (-math.pi / 2, "front"), (math.pi / 2, "back")):
        d = Vector((math.cos(a), math.sin(a), 0))
        loc, n, _, _ = tree.ray_cast(Vector((0, cy, z)) + d * 0.6, -d)
        ex[key] = loc
    return ex


def build(tag, ox, sex, skin_hex, hair_hex, scale, outfit, seed):
    male = sex == "m"
    M = 1.0 if male else 0.0
    rnd = random.Random(seed)
    coll = bpy.data.collections.new("wadee_" + tag)
    bpy.context.scene.collection.children.link(coll)
    skin = mat("skin_" + tag, skin_hex, 0.55)
    lips_m = mat("lips_" + tag, "#86463d" if not male else "#6f3d33", 0.45)
    hair = mat("hair_" + tag, hair_hex, 0.55)
    cloth = {k: mat(k, v, 0.9) for k, v in
             (("cream", "#e4d3b6"), ("rust", "#8e4a2b"), ("teal", "#3d8787"), ("leather", "#5e3f2b"))}
    bronze = mat("bronze", "#b5803e", 0.35, 0.8)
    turq = mat("turquoise", "#3fb3a6", 0.3)
    sclera = mat("eye_white", "#ece6dc", 0.3)
    iris = mat("iris", "#4a2c18", 0.2)
    pupil = mat("pupil", "#100a07", 0.15)
    lash = mat("lash", "#140d09", 0.6)
    brow = mat("brow_" + tag, hair_hex, 0.8)

    me, eye_meshes = base_for(sex)
    w_arm = pose_arms_down(me, 12.0 if male else 9.0)
    # slender: a touch narrower; the women a fuller bust
    for v in me.vertices:
        v.co.x *= 0.97
        v.co.y *= 0.97
    eyes_c = []
    for em in eye_meshes:
        for v in em.vertices:
            v.co.x *= 0.97
            v.co.y *= 0.97
        c = sum((v.co for v in em.vertices), Vector()) / len(em.vertices)
        r = sum((v.co - c).length for v in em.vertices) / len(em.vertices)
        eyes_c.append((c, r, em))
    eye_z = eyes_c[0][0].z
    if not male:
        for s in (-1, 1):
            chest = [v.co for v in me.vertices if 0.70 * H < v.co.z < 0.76 * H and 0.03 < s * v.co.x < 0.12]
            front = min(chest, key=lambda p: p.y)
            for v in me.vertices:
                d = (v.co - front).length
                if d < 0.095 and v.co.y < front.y + 0.08:
                    f = (1 - (d / 0.095) ** 2) ** 2
                    v.co += Vector((s * 0.25, -1.0, 0.15)).normalized() * 0.013 * f
        me.update()

    body = bpy.data.objects.new("body_" + tag, me)
    coll.objects.link(body)
    me.materials.append(skin)
    me.materials.append(lips_m)
    # the lips: faces round the mouth's slit, found from the face's profile down the middle
    tb_hi = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())
    prof = []
    for k in range(80):
        z = eye_z - 0.03 - 0.07 * k / 79
        loc, n, _, _ = tb_hi.ray_cast(Vector((0, -1, z)), Vector((0, 1, 0)))
        if loc:
            prof.append((z, loc.y))
    nose_z, nose_y = min(prof, key=lambda q: q[1])
    # the slit is the sharpest crease below the nose (the nose's base and the chin's are broad)
    best = None
    for i in range(4, len(prof) - 4):
        z, y = prof[i]
        if not nose_z - 0.06 < z < nose_z - 0.025:
            continue
        crease = y - (prof[i - 4][1] + prof[i + 4][1]) / 2
        if best is None or crease > best[0]:
            best = (crease, z)
    slit_z = best[1]
    lip_front = min(q[1] for q in prof if slit_z - 0.012 < q[0] < slit_z + 0.012)
    for p in me.polygons:
        c = p.center
        dz = (c.z - slit_z) / (0.011 if c.z > slit_z else 0.013)
        if abs(dz) < 1 and c.y < lip_front + 0.014 and abs(c.x) < 0.025 * math.sqrt(max(0.0, 1 - dz * dz)) + 0.002:
            p.material_index = 1
    for p in me.polygons:
        p.use_smooth = True
    have = len(me.polygons) * 2
    d = body.modifiers.new("d", "DECIMATE")
    d.ratio = BODY_TRIS / have

    bake(body)
    tb = bvh(body)

    # the torso alone, for clothes to wrap: the body without its arms and head
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    kill = [bm.verts[i] for i, w in enumerate(w_arm) if w > 0.25]
    kill += [v for v in bm.verts if v.co.z > eye_z - 0.11 and v not in kill]
    bmesh.ops.delete(bm, geom=list(set(kill)), context="VERTS")
    tme = bpy.data.meshes.new("torso_" + tag)
    bm.to_mesh(tme)
    bm.free()
    torso_t = bpy.data.objects.new("torso_target_" + tag, tme)
    coll.objects.link(torso_t)
    tt = bvh(torso_t)
    parts = [body]

    # ---- eyes: the base's eyeballs, coloured by where they look; a lash line; brows
    for c, r, em in eyes_c:
        em.materials.append(sclera)
        em.materials.append(iris)
        em.materials.append(pupil)
        for p in em.polygons:
            a = (p.center - c).normalized().angle(Vector((0, -1, 0)))
            p.material_index = 2 if a < math.radians(13) else (1 if a < math.radians(31) else 0)
            p.use_smooth = True
        eo = bpy.data.objects.new("eye_" + tag, em)
        coll.objects.link(eo)
        parts.append(eo)
    bk, bbr = bmesh.new(), bmesh.new()
    for c, r, em in eyes_c:
        s = 1 if c.x > 0 else -1
        f = Vector((s * 0.12, -1, 0)).normalized()
        rv = Vector((0, 0, 1)).cross(f).normalized()
        uv = f.cross(rv)
        pts = []
        for k in range(11):
            ph = math.radians(-62 + 124 * k / 10)
            e = math.radians(20)
            dd = (f * math.cos(e) * math.cos(ph) + rv * math.cos(e) * math.sin(ph) + uv * math.sin(e)).normalized()
            t = k / 10
            rr = 0.0009 + 0.0007 * (1 - abs(2 * t - 1))
            pts.append((c + dd * (r + 0.0028), rr, rr * 0.8))
        tip_i = -1 if s > 0 else 0
        tip = pts[tip_i][0] + rv * 0.0045 + uv * 0.0022
        if s > 0:
            pts.append((tip, 0.0006, 0.0005))
        else:
            pts.insert(0, (tip, 0.0006, 0.0005))
        if not male:
            tube(bk, pts, segs=6)
        bpts = []
        for kx, kz in ((-0.013, 0.019), (-0.002, 0.024), (0.010, 0.025), (0.020, 0.020)):
            q, qn = hit_front(tb, c.x + s * kx, c.z + kz - 0.003 * M)
            if q is None:
                continue
            w = (0.0024 if kx < 0.0 else 0.0017) * (1.8 if male else 1.0)
            bpts.append((q + qn * 0.0018, w, w * 0.45))
        if len(bpts) >= 2:
            tube(bbr, bpts, segs=8)
    if not male:
        parts.append(obj_from(bk, "lash_" + tag, lash, coll))
    parts.append(obj_from(bbr, "brows_" + tag, brow, coll))

    # ---- hair: a cap fitted to the skull, the mane and locks, pushed clear of the body
    head = [v.co for v in me.vertices if v.co.z > eye_z + 0.005]
    hx = max(abs(p.x) for p in head)
    hy0, hy1 = min(p.y for p in head), max(p.y for p in head)
    htop = max(p.z for p in head)
    cy, cz = (hy0 + hy1) / 2 + 0.006, eye_z + 0.03
    rx, ry, rz = hx + 0.008, (hy1 - hy0) / 2 + 0.008, htop - cz + 0.009
    bm = bmesh.new()
    vs = ellipsoid(bm, (0, cy, cz), (rx, ry, rz), segs=28, rings=18)
    kill = [v for v in vs if (v.co.y < cy - 0.45 * ry and v.co.z < cz + 0.49 * rz) or v.co.z < cz - 0.98 * rz
            or (v.co.y < cy + 0.05 * ry and v.co.z < cz - 0.42 * rz)]
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.006)
    sh = extents_at(tt, 0.80 * H)
    shoulder_back = sh["back"].y if sh["back"] else 0.09
    end_base, end_side = (1.36, 0.05) if male else (1.03, 0.11)

    def mane_point(phi, t, zend, push=0.0, wave_ph=0.0):
        top = Vector((math.sin(phi) * rx * 0.83, cy + math.cos(phi) * ry * 0.85, cz + 0.65 * rz))
        bot = Vector((math.sin(phi) * (0.165 + .01 * M), shoulder_back + 0.02 + math.cos(phi) * 0.07, zend))
        ey = 1 - (1 - t) ** 3
        ex = 0.3 * t + 0.7 * (1 - (1 - t) ** 2)
        q = Vector((top.x + (bot.x - top.x) * ex, top.y + (bot.y - top.y) * ey, top.z + (bot.z - top.z) * t))
        dd = Vector((math.sin(phi), math.cos(phi), 0))
        tg = Vector((math.cos(phi), -math.sin(phi), 0))
        q += dd * (0.010 * math.sin(13 * phi + 1.0) * (0.3 + t) + push)
        q += tg * (0.016 * math.sin(t * math.pi * 5 + phi * 3 + wave_ph) * t)
        return q
    cols, rows = 41, 18
    ends = [end_base + end_side * abs(math.sin(math.radians(-86 + 172 * k / (cols - 1)))) ** 1.5
            + rnd.uniform(-0.03, 0.03) + (0.05 if k % 2 else 0.0) for k in range(cols)]
    grid = []
    for j in range(rows):
        t = j / (rows - 1)
        grid.append([bm.verts.new(mane_point(math.radians(-86 + 172 * k / (cols - 1)), t, ends[k]))
                     for k in range(cols)])
    mane_faces = []
    for j in range(rows - 1):
        for k in range(cols - 1):
            mane_faces.append(bm.faces.new((grid[j][k], grid[j][k + 1], grid[j + 1][k + 1], grid[j + 1][k])))
    bmesh.ops.solidify(bm, geom=mane_faces, thickness=0.010)
    for i in range(10 if male else 16):
        phi = math.radians(rnd.uniform(-80, 80))
        zend = end_base - 0.02 + end_side * abs(math.sin(phi)) ** 1.5 + rnd.uniform(-0.02, 0.05)
        tang = Vector((math.cos(phi), -math.sin(phi), 0))
        ph = rnd.uniform(0, 6.28)
        rings = [(mane_point(phi, 0.04 + 0.96 * k / 13, zend, 0.011, ph), 0.022 * (1 - 0.6 * (k / 13)) + 0.004,
                  (0.022 * (1 - 0.6 * (k / 13)) + 0.004) * 0.4) for k in range(14)]
        tube(bm, rings, segs=8, ref=tang)
    if False:
        for s in (-1, 1):
            path = [Vector((s * rx * 0.60, cy - ry * 0.55, cz + rz * 0.55)), Vector((s * rx * 0.82, cy - ry * 0.62, cz + rz * 0.30)),
                    Vector((s * rx * 0.98, cy - ry * 0.66, cz - rz * 0.10)), Vector((s * (rx + 0.008), cy - ry * 0.68, cz - rz * 0.55)),
                    Vector((s * (rx + 0.018), cy - ry * 0.70, cz - rz * 1.10)), Vector((s * (rx + 0.03), cy - ry * 0.72, cz - rz * 1.75)),
                    Vector((s * (rx + 0.038), cy - ry * 0.74, cz - rz * 2.35))]
            rings = []
            for k, q in enumerate(path):
                t = k / (len(path) - 1)
                q = q + Vector((s * math.sin(t * math.pi * 4) * 0.007 * t, 0, 0))
                w = 0.015 * (1 - 0.4 * t) + 0.004
                rings.append((q, w, w * 0.6))
            tube(bm, rings, segs=8, ref=(0, 1, 0))
    hair_o = obj_from(bm, "hair_" + tag, hair, coll)
    push_out(hair_o, tb, 0.006)
    parts.append(hair_o)

    def ring_on(bm_, c, axis, radius, r):
        s_, f_ = frame(Vector(axis))
        tube(bm_, [(Vector(c) + s_ * radius * math.cos(a) + f_ * radius * math.sin(a), r, r)
                   for a in [2 * math.pi * k / 20 for k in range(20)]], segs=8, loop=True)

    arm_vs = [(i, me.vertices[i].co.copy()) for i, w in enumerate(w_arm) if w > 0.9]
    # (indices refer to the pre-decimate mesh; we kept copies of positions)

    def arm_at(s, z):
        sl = [p for i, p in arm_vs if s * p.x > 0 and abs(p.z - z) < 0.01]
        if not sl:
            return None
        c = sum(sl, Vector()) / len(sl)
        ds = sorted(Vector((p.x - c.x, p.y - c.y, 0)).length for p in sl)
        cap = ds[len(ds) // 2] * 1.35
        prof_ = []
        for k in range(20):
            a = 2 * math.pi * k / 20
            dv = Vector((math.cos(a), math.sin(a), 0))
            best_ = 0.0
            for p in sl:
                q = Vector((p.x - c.x, p.y - c.y, 0))
                if q.length < 1e-6 or q.length > cap or q.normalized().dot(dv) < math.cos(math.radians(18)):
                    continue
                best_ = max(best_, q.dot(dv))
            prof_.append(best_ or ds[len(ds) // 2])
        return c, prof_

    def hug_ring(bm_, c, prof_, gap, r, ztilt=0.0):
        pts_ = []
        for k, d_ in enumerate(prof_):
            a = 2 * math.pi * k / len(prof_)
            pts_.append((Vector((c.x + math.cos(a) * (d_ + gap), c.y + math.sin(a) * (d_ + gap), c.z)), r, r))
        tube(bm_, pts_, segs=8, loop=True)

    top_c, skirt_c, trim_c = outfit
    bb, bt = bmesh.new(), bmesh.new()

    def fit_rings(rings):
        dense = []
        for (c0, a0, b0), (c1, a1, b1) in zip(rings, rings[1:]):
            n_ = max(1, int(abs(c0[2] - c1[2]) / 0.025))
            for k in range(n_):
                t = k / n_
                dense.append((tuple(c0[i] + (c1[i] - c0[i]) * t for i in range(3)), a0 + (a1 - a0) * t, b0 + (b1 - b0) * t))
        dense.append(rings[-1])
        out = []
        for c, rx_, ry_ in dense:
            ex = extents_at(tt, c[2], c[1])
            if all(ex.values()):
                fx = max(ex["+x"].x, -ex["-x"].x) + 0.016
                fy = (ex["back"].y - ex["front"].y) / 2 + 0.016
                cyy = (ex["back"].y + ex["front"].y) / 2
                out.append(((c[0], cyy, c[2]), max(rx_, fx), max(ry_, fy)))
            else:
                out.append((c, rx_, ry_))
        # never narrower going down
        for i in range(1, len(out)):
            c, a, b = out[i]
            out[i] = (c, max(a, out[i - 1][1] * 0.98), max(b, out[i - 1][2] * 0.98))
        return out

    if male:
        loop_pts = []
        for k in range(14):
            t = k / 13
            x, z = -0.150 + 0.285 * t, 1.43 - 0.41 * t
            loop_pts.append(radialn(tt, -math.pi / 2 + math.asin(max(-1, min(1, x / 0.19))), z, 0.008))
        for k in range(14):
            t = k / 13
            x, z = 0.135 - 0.285 * t, 1.02 + 0.41 * t
            loop_pts.append(radialn(tt, math.pi / 2 - math.asin(max(-1, min(1, x / 0.19))), z, 0.008))
        bm = bmesh.new()
        tube(bm, [(q, 0.003, 0.036) for q, nn in loop_pts], segs=8, loop=True, ref=lambda i: loop_pts[i][1])
        parts.append(obj_from(bm, "chest_sash_" + tag, cloth[top_c], coll))
        skirt_rings = fit_rings([((0, 0.0, 0.995), 0.152, 0.110), ((0, 0.004, 0.930), 0.166, 0.122),
                                 ((0, 0.006, 0.860), 0.174, 0.126), ((0, 0.006, 0.700), 0.186, 0.138),
                                 ((0, 0.006, 0.520), 0.198, 0.150), ((0, 0.006, 0.420), 0.204, 0.155),
                                 ((0, 0.006, 0.400), 0.205, 0.156)])
    else:
        bm = bmesh.new()
        segs, R = 64, 9
        grid = []
        for j in range(R):
            t = j / (R - 1)
            row = []
            for k in range(segs):
                a = 2 * math.pi * k / segs
                fw = max(0.0, -math.sin(a)) ** 3
                bwt = max(0.0, math.sin(a)) ** 2
                zb, zt = 1.172, 1.322 - 0.045 * fw - 0.05 * bwt
                row.append(bm.verts.new(radial(tt, a, zb + (zt - zb) * t, 0.008)))
            grid.append(row)
        for j in range(R - 1):
            for k in range(segs):
                bm.faces.new((grid[j][k], grid[j][(k + 1) % segs], grid[j + 1][(k + 1) % segs], grid[j + 1][k]))
        top = obj_from(bm, "top_" + tag, cloth[top_c], coll)
        sm = top.modifiers.new("sm", "SMOOTH")
        sm.factor = 0.6
        sm.iterations = 3
        bake(top)
        push_out(top, tt, 0.006)
        so = top.modifiers.new("so", "SOLIDIFY")
        so.thickness = 0.004
        bake(top)
        bm = bmesh.new()
        for s in (-1, 1):
            pts = [near(tt, q, 0.008)[0] for q in ((s * .090, -.11, 1.300), (s * .078, -.078, 1.365),
                                                   (s * .062, -.045, 1.420), (s * .050, -.005, 1.462),
                                                   (s * .030, .040, 1.470), (s * .004, .058, 1.468))]
            tube(bm, [(q, 0.0075, 0.0025) for q in pts], segs=8)
        pts = [radial(tt, a, 1.174, 0.012) for a in [2 * math.pi * k / 48 for k in range(48)]]
        tube(bm, [(q, 0.007, 0.004) for q in pts], segs=8, loop=True)
        parts += [top, obj_from(bm, "trim_" + tag, cloth[trim_c], coll)]
        skirt_rings = fit_rings([((0, 0.0, 0.990), 0.156, 0.110), ((0, 0.006, 0.930), 0.184, 0.134),
                                 ((0, 0.008, 0.860), 0.192, 0.142), ((0, 0.008, 0.700), 0.200, 0.160),
                                 ((0, 0.008, 0.500), 0.220, 0.180), ((0, 0.010, 0.300), 0.242, 0.200),
                                 ((0, 0.012, 0.100), 0.262, 0.218), ((0, 0.012, 0.075), 0.264, 0.220)])

    def folds(t, a):
        return 1 + 0.055 * (t ** 1.3) * math.sin(11 * a + 0.6) + 0.02 * t * math.sin(5 * a + 2.0)
    bms = bmesh.new()
    tube(bms, skirt_rings, segs=44, caps=False, fn=folds)
    skirt = obj_from(bms, "skirt_" + tag, cloth[skirt_c], coll)
    push_out(skirt, tt, 0.008)
    so = skirt.modifiers.new("so", "SOLIDIFY")
    so.thickness = 0.005
    bake(skirt)
    ts = bvh(skirt)
    parts.append(skirt)

    belt_z = skirt_rings[0][0][2] - 0.015
    pts = [near(ts, (0.3 * math.cos(a), 0.3 * math.sin(a), belt_z), 0.007)[0]
           for a in [2 * math.pi * k / 36 for k in range(36)]]
    tube(bb, [(q, 0.011, 0.009) for q in pts], segs=8, loop=True)
    for k in range(5 if male else 11):
        a = math.radians(-150 + 120 * k / (4 if male else 10))
        q, nn = near(ts, (0.3 * math.cos(a), 0.3 * math.sin(a), belt_z - 0.028), 0.006)
        tube(bb, [(q - nn * 0.0012, 0.011, 0.011), (q + nn * 0.0012, 0.011, 0.011)], segs=12)
    for a in (-90, -62, -118):
        q, nn = near(ts, (0.3 * math.cos(math.radians(a)), 0.3 * math.sin(math.radians(a)), belt_z), 0.016)
        ellipsoid(bt, q, (0.009, 0.009, 0.009), segs=10, rings=6)
    bsash = {trim_c: bmesh.new(), top_c: bmesh.new()}
    hang = (0.40, 0.34) if male else (0.56, 0.48)
    for a, c, length in ((-48, trim_c, hang[0]), (-60, top_c, hang[1])):
        rings = []
        for k in range(10):
            z = belt_z - 0.02 - length * k / 9
            ar = math.radians(a + 4 * k / 9)
            q, nn = near(ts, (0.4 * math.cos(ar), 0.4 * math.sin(ar), z), 0.009)
            rings.append((q, 0.022, 0.0025))
        tube(bsash[c], rings, segs=8, ref=Vector((-math.sin(math.radians(a)), math.cos(math.radians(a)), 0)))
    for c, b_ in bsash.items():
        parts.append(obj_from(b_, "sash_%s_%s" % (c, tag), cloth[c], coll))

    bleather = bmesh.new()
    for s in (-1, 1):
        up = arm_at(s, 0.68 * H)
        if up:
            hug_ring(bb, up[0], up[1], 0.004, 0.005)
        for zz in ((0.51 * H,) if male else (0.515 * H, 0.505 * H)):
            wr = arm_at(s, zz)
            if not wr:
                continue
            if male:
                for dz in (-0.012, -0.004, 0.004, 0.012):
                    hug_ring(bleather, wr[0] + Vector((0, 0, dz)), wr[1], 0.005, 0.005)
            else:
                hug_ring(bb, wr[0], wr[1], 0.005, 0.0045)
        if s > 0 or not male:
            lobe = [v.co for v in me.vertices if eye_z - 0.055 < v.co.z < eye_z - 0.03 and -0.03 < v.co.y < 0.03]
            if lobe:
                lp = max(lobe, key=lambda p: s * p.x)
                tube(bb, [(lp + Vector((s * 0.002, 0, -0.008)), .010, .010), (lp + Vector((s * 0.006, 0, -0.008)), .010, .010)],
                     segs=12)
                ellipsoid(bt, lp + Vector((s * 0.005, 0, -0.033)), (.004, .005, .009), segs=8, rings=6)
    pts = []
    for k in range(28):
        a = 2 * math.pi * k / 28
        fw = max(0.0, -math.sin(a)) ** 2
        pts.append(radial(tb, a, 1.452 - 0.055 * fw, 0.004))
    tube(bb, [(q, 0.0032, 0.0032) for q in pts], segs=6, loop=True)
    q, nn = hit_front(tt, 0.0, 1.372 if not male else 1.385)
    if q is not None:
        ellipsoid(bt, q + nn * 0.006, (0.011, 0.005, 0.015), segs=12, rings=8)
    parts += [obj_from(bb, "bronze_" + tag, bronze, coll), obj_from(bt, "turquoise_" + tag, turq, coll)]
    for s in (-1, 1):
        foot = [v.co for v in me.vertices if v.co.z < 0.03 and s * v.co.x > 0]
        if not foot:
            continue
        fx = sum(p.x for p in foot) / len(foot)
        fy0, fy1 = min(p.y for p in foot), max(p.y for p in foot)
        fw = (max(p.x for p in foot) - min(p.x for p in foot)) / 2 + 0.006
        fw -= 0.004
        tube(bleather, [((fx, fy1 + 0.003, 0.003), fw * 0.75, 0.003), ((fx, fy1 - 0.04, 0.003), fw * 0.9, 0.003),
                        ((fx, (fy0 + fy1) / 2, 0.003), fw, 0.003), ((fx, fy0 + 0.01, 0.003), fw * 0.95, 0.003),
                        ((fx, fy0 - 0.002, 0.003), fw * 0.6, 0.003)], segs=12)
        ank = [v.co for v in me.vertices if abs(v.co.z - 0.075) < 0.006 and s * v.co.x > 0]
        if ank:
            ac = sum(ank, Vector()) / len(ank)
            ar = sum(Vector((p.x - ac.x, p.y - ac.y, 0)).length for p in ank) / len(ank)
            ring_on(bleather, ac, (0, 0, 1), ar + 0.004, 0.004)
    parts.append(obj_from(bleather, "leather_" + tag, cloth["leather"], coll))

    bpy.data.objects.remove(torso_t)
    root = bpy.data.objects.new("wadee_" + tag, None)
    coll.objects.link(root)
    for o in parts:
        o.parent = root
    root.scale = (scale, scale, scale)
    root.location = (ox, 0, 0)
    tris = sum(sum(len(pg.vertices) - 2 for pg in o.data.polygons) for o in parts)
    print("WADEE %s tris %d (slit z %.3f, eye z %.3f)" % (tag, tris, slit_z, eye_z))
    return root, parts


VARIANTS = [
    ("a", -1.9, "f", "#8d5b3c", "#2a1a12", 1.00, ("cream", "rust", "teal"), 1),
    ("b", -0.95, "f", "#6b432c", "#17100c", 1.03, ("cream", "teal", "rust"), 2),
    ("c", 0.0, "f", "#a8714c", "#4e2e1a", 0.97, ("rust", "cream", "teal"), 3),
    ("m", 0.95, "m", "#7a4c32", "#1e140e", 1.055, ("cream", "rust", "teal"), 4),
    ("n", 1.9, "m", "#9a6644", "#3a2416", 1.04, ("teal", "cream", "rust"), 5),
]
built = [build(*v) for v in VARIANTS]
for o in list(bpy.data.objects):
    if o.name in [n for k in SRC.values() for n in (k, k + ".eye.L", k + ".eye.R")]:
        bpy.data.objects.remove(o)

for (root, parts), v in zip(built, VARIANTS):
    loc = root.location.copy()
    root.location = (0, 0, 0)
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for o in parts:
        o.select_set(True)
    path = os.path.join(OUT, "wadee_%s.glb" % v[0])
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True)
    root.location = loc
    print("WADEE wrote", path)

if RENDER:
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    world = bpy.data.worlds.new("w")
    sc.world = world
    bg = world.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = srgb("#a9c4d8")
    bg.inputs[1].default_value = 0.9
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 4.0
    sun.color = (1.0, 0.88, 0.72)
    so = bpy.data.objects.new("sun", sun)
    sc.collection.objects.link(so)
    so.rotation_euler = (math.radians(90 - 29), 0, math.radians(-25))
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=20)
    obj_from(bm, "ground", mat("sand", "#c99a68", 1.0), sc.collection)
    cam_d = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam

    def shot(name, loc, target, lens=35, res=(1200, 900)):
        sc.render.resolution_x, sc.render.resolution_y = res
        cam_d.lens = lens
        cam.location = loc
        cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(OUT, "blender_%s.png" % name)
        bpy.ops.render.render(write_still=True)
        print("WADEE render", sc.render.filepath)

    shot("group", (0, -5.4, 1.6), (0, 0, 0.95), 30, (1600, 900))
    shot("face_b", (-0.95, -0.62, 1.64 * 1.03), (-0.95, 0, 1.635 * 1.03), 50, (900, 900))
    shot("face_c_3q", (0.30, -0.55, 1.61), (0.0, 0, 1.60 * 0.97), 50, (900, 900))
    shot("face_m", (0.95, -0.66, 1.64 * 1.055), (0.95, 0, 1.635 * 1.055), 50, (900, 900))
    shot("men_3q", (2.9, -2.6, 1.6), (1.4, 0, 1.05), 40, (900, 1200))
