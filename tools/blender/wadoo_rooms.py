"""The Wadees' rooms (docs/superpowers/specs/2026-11-16-wadoo-design.md §8, §10).

Builds the queen's hall, the furnishings that stand inside the brick shell
`house_b` of the oasis (data/places/oasis.json), and writes it as a GLB:

  blender -b --factory-startup --python wadoo_rooms.py -- <out dir> [render]

The game puts it in the shell's frame (WadooRooms): its origin is the middle of
the shell's floor, y up, the door's side toward -z. Here everything is written in
those Godot coordinates and turned into Blender's (x, -z, y) by G().

Materials are named by what they are (stone, wood, bronze, sunglass, ...): the
game paints each from WadeePalette, so the colours set here are only for a
preview render. Empties carry the rest: lamp_<n> where a sunglass lamp's light
sits, col_<name> a solid box (its scale the half size), seat where the queen's
throne seat is, sit where she stands to sit down on it, stand where she
stands to receive you.
"""

import math
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

# The shell's inside (BrickShell: house_b is 7.5 x 5.6 x 6.0, walls 0.45).
IN_X = 3.3
IN_Z = 2.55
CEIL = 4.94
DOOR_W = 1.1
# The windows (BrickShell.openings_for(house_b)): front ones either side of the
# door, one in the west wall, one over the door. Nothing hangs over them.
WEST_WINDOW_Z = (-0.18, 0.52)

# The dais at the back, and its step.
DAIS = (2.2, 1.25, 0.3)        # half width, front edge z, height
STEP = (1.2, 1.0, 0.15)
SEAT_H = 0.45                  # the throne's seat over the dais
THRONE_Z = 2.05

PREVIEW = {
    "stone": (0.79, 0.72, 0.60), "stone_dark": (0.62, 0.55, 0.45), "wood": (0.35, 0.23, 0.14),
    "bronze": (0.71, 0.50, 0.24), "sunglass": (1.0, 0.79, 0.29), "royal": (0.35, 0.16, 0.29),
    "teal": (0.18, 0.42, 0.43), "rust": (0.56, 0.29, 0.17), "cream": (0.89, 0.83, 0.71),
    "saffron": (0.82, 0.64, 0.29), "turquoise": (0.25, 0.70, 0.65), "water": (0.25, 0.46, 0.39),
    "map_sand": (0.85, 0.73, 0.54), "map_dune": (0.66, 0.50, 0.35), "map_red": (0.65, 0.16, 0.13),
    "clay": (0.66, 0.40, 0.25),
}


def G(x, y, z):
    """A Godot point (x, y up, z toward the back) in Blender's space."""
    return Vector((x, -z, y))


def mat(name):
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        c = PREVIEW[name]
        bsdf.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1.0)
        bsdf.inputs["Roughness"].default_value = 0.35 if name in ("bronze", "water", "sunglass") else 0.85
        if name == "bronze":
            bsdf.inputs["Metallic"].default_value = 0.8
        if name == "sunglass":
            bsdf.inputs["Emission Color"].default_value = (c[0], c[1], c[2], 1.0)
            bsdf.inputs["Emission Strength"].default_value = 4.0
    return m


PARTS = []


def _obj(name, bm, material, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat(material))
    for p in ob.data.polygons:
        p.use_smooth = smooth
    PARTS.append(ob)
    return ob


def _bevel(ob, width, segments=3):
    mod = ob.modifiers.new("bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.harden_normals = False
    return ob


def box(name, centre, size, material, bevel=0.03, segments=3, turn=0.0):
    """A box `size` (Godot x, y, z) with its middle at Godot `centre`, rounded."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    m = Matrix.Translation(G(*centre)) @ Matrix.Rotation(turn, 4, "Z") @ Matrix.Diagonal((size[0], size[2], size[1], 1.0))
    bm.transform(m)
    ob = _obj(name, bm, material)
    if bevel > 0.0:
        _bevel(ob, bevel, segments)
    return ob


def lathe(name, profile, centre, material, steps=32, smooth=True):
    """Turns `profile` [(radius, height), ...] about Godot y at `centre`."""
    bm = bmesh.new()
    verts = [bm.verts.new((r, 0.0, h)) for r, h in profile]
    edges = [bm.edges.new((verts[i], verts[i + 1])) for i in range(len(verts) - 1)]
    bmesh.ops.spin(bm, geom=verts + edges, cent=(0, 0, 0), axis=(0, 0, 1), angle=math.tau, steps=steps,
                   use_merge=True)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.transform(Matrix.Translation(G(*centre)))
    return _obj(name, bm, material, smooth)


def sphere(name, centre, radius, material, subdivisions=3, squash=1.0):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=radius)
    bm.transform(Matrix.Translation(G(*centre)) @ Matrix.Diagonal((1.0, 1.0, squash, 1.0)))
    return _obj(name, bm, material)


def rod(name, a, b, radius, material, sides=12):
    """A round rod from Godot point `a` to `b`."""
    pa, pb = G(*a), G(*b)
    d = pb - pa
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=sides, radius1=radius, radius2=radius, depth=d.length)
    rot = d.to_track_quat("Z", "Y").to_matrix().to_4x4()
    bm.transform(Matrix.Translation((pa + pb) * 0.5) @ rot)
    return _obj(name, bm, material)


def cloth(name, centre, width, height, facing, stripes, folds=4, depth=0.03, rows=24, cols=16):
    """A hanging cloth: its middle at Godot `centre`, `width` x `height`, its face
    toward Godot direction `facing` (a unit x or z), gently folded. `stripes` is
    [(material, from share, to share)] down its height; the rest is the first."""
    bm = bmesh.new()
    face_dir = G(*facing)
    across = Vector((0, 0, 1)).cross(face_dir).normalized()
    up = Vector((0, 0, 1))
    grid = []
    for j in range(rows + 1):
        row = []
        v = j / rows
        for i in range(cols + 1):
            u = i / cols
            fold = math.sin(u * folds * math.tau) * depth * (0.6 + 0.4 * v)
            p = G(*centre) + across * ((u - 0.5) * width) + up * ((0.5 - v) * height) + face_dir * fold
            row.append(bm.verts.new(p))
        grid.append(row)
    names = [s[0] for s in stripes]
    me_mats = []
    for n in names:
        if n not in me_mats:
            me_mats.append(n)
    for j in range(rows):
        v = (j + 0.5) / rows
        which = 0
        for k, (n, a, b) in enumerate(stripes):
            if a <= v <= b:
                which = me_mats.index(n)
        for i in range(cols):
            f = bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
            f.material_index = which
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        if f.normal.dot(face_dir) < 0:
            f.normal_flip()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    for n in me_mats:
        ob.data.materials.append(mat(n))
    for p in ob.data.polygons:
        p.use_smooth = True
    sol = ob.modifiers.new("thick", "SOLIDIFY")
    sol.thickness = 0.012
    PARTS.append(ob)
    return ob


def empty(name, at, half=None):
    ob = bpy.data.objects.new(name, None)
    ob.location = G(*at)
    if half is not None:
        ob.scale = (half[0], half[2], half[1])
    bpy.context.collection.objects.link(ob)
    return ob


def solid(name, centre, size):
    empty("col_%s" % name, centre, (size[0] * 0.5, size[1] * 0.5, size[2] * 0.5))


def walked(name, centre, size):
    """A box you stand on (the dais, its step): solid to you, walked by the Wadees."""
    empty("floor_%s" % name, centre, (size[0] * 0.5, size[1] * 0.5, size[2] * 0.5))


# --- the pieces -----------------------------------------------------------------

def dais():
    w, front, h = DAIS
    depth = IN_Z - front
    box("dais", (0.0, h * 0.5, front + depth * 0.5), (w * 2.0, h, depth + 0.02), "stone", bevel=0.06)
    walked("dais", (0.0, h * 0.5, front + depth * 0.5), (w * 2.0, h, depth))
    sw, sfront, sh = STEP
    box("step", (0.0, sh * 0.5, sfront + (front - sfront) * 0.5 + 0.03), (sw * 2.0, sh, front - sfront + 0.06), "stone",
        bevel=0.05)
    walked("step", (0.0, sh * 0.5, sfront + (front - sfront) * 0.5), (sw * 2.0, sh, front - sfront))
    # a band of bronze along the dais's lip
    box("dais_lip", (0.0, h - 0.03, front - 0.005), (w * 2.0 - 0.1, 0.035, 0.02), "bronze", bevel=0.008, segments=2)
    # a teal cloth over the dais behind the throne
    box("dais_cloth", (0.0, h + 0.006, front + depth * 0.55), (w * 1.5, 0.012, depth * 0.7), "teal", bevel=0.004,
        segments=1)


def throne():
    y0 = DAIS[2]
    z = THRONE_Z
    seat_w = 0.78
    seat_d = 0.58
    # the seat: a wooden box with a cushion
    box("throne_seat", (0.0, y0 + SEAT_H - 0.09, z), (seat_w, 0.14, seat_d), "wood", bevel=0.03)
    box("throne_cushion", (0.0, y0 + SEAT_H + 0.02, z - 0.02), (seat_w - 0.1, 0.09, seat_d - 0.08), "royal", bevel=0.04,
        segments=4)
    # legs, and a low plinth under them
    box("throne_plinth", (0.0, y0 + 0.05, z + 0.02), (seat_w + 0.16, 0.1, seat_d + 0.16), "wood", bevel=0.03)
    for sx in (-1, 1):
        for sz in (-1, 1):
            box("throne_leg", (sx * (seat_w * 0.5 - 0.06), y0 + 0.1 + (SEAT_H - 0.25) * 0.5, z + sz * (seat_d * 0.5 - 0.06)),
                (0.08, SEAT_H - 0.25, 0.08), "wood", bevel=0.015)
    # the arms, capped in bronze
    for sx in (-1, 1):
        x = sx * (seat_w * 0.5 + 0.02)
        box("throne_arm", (x, y0 + SEAT_H + 0.2, z - 0.02), (0.09, 0.07, seat_d + 0.02), "wood", bevel=0.025)
        box("throne_armpost", (x, y0 + SEAT_H + 0.08, z - seat_d * 0.5 + 0.05), (0.07, 0.22, 0.07), "wood", bevel=0.02)
        sphere("throne_armcap", (x, y0 + SEAT_H + 0.25, z - seat_d * 0.5 + 0.03), 0.055, "bronze", 2)
    # the high back: a wooden frame round a teal panel, arched over with bronze
    back_z = z + seat_d * 0.5 - 0.04
    back_h = 1.75
    for sx in (-1, 1):
        box("throne_post", (sx * (seat_w * 0.5 - 0.02), y0 + SEAT_H + back_h * 0.5 - 0.1, back_z), (0.1, back_h, 0.1), "wood",
            bevel=0.025)
        sphere("throne_finial", (sx * (seat_w * 0.5 - 0.02), y0 + SEAT_H + back_h - 0.1 + 0.06, back_z), 0.065, "bronze", 2)
    box("throne_panel", (0.0, y0 + SEAT_H + back_h * 0.45, back_z + 0.01), (seat_w - 0.12, back_h * 0.82, 0.04), "teal",
        bevel=0.012)
    box("throne_rail", (0.0, y0 + SEAT_H + back_h - 0.16, back_z), (seat_w - 0.04, 0.09, 0.08), "wood", bevel=0.02)
    # an arch of bronze over the back, and the queen's sunglass in it
    arch = []
    for k in range(13):
        a = math.pi * k / 12
        arch.append((math.cos(a) * 0.36, y0 + SEAT_H + back_h - 0.1 + math.sin(a) * 0.36))
    for k in range(12):
        rod("throne_arch", (arch[k][0], arch[k][1], back_z), (arch[k + 1][0], arch[k + 1][1], back_z), 0.025, "bronze", 8)
    sphere("throne_sun", (0.0, y0 + SEAT_H + back_h + 0.08, back_z), 0.12, "sunglass", 3)
    for k in range(9):
        a = math.pi * (k + 0.5) / 9
        c = Vector((0.0, y0 + SEAT_H + back_h + 0.08))
        rod("throne_ray", (math.cos(a) * 0.15, c.y + math.sin(a) * 0.15, back_z),
            (math.cos(a) * 0.27, c.y + math.sin(a) * 0.27, back_z), 0.012, "bronze", 6)
    # turquoise studs down the posts
    for sx in (-1, 1):
        for k in range(4):
            sphere("throne_stud", (sx * (seat_w * 0.5 - 0.02), y0 + SEAT_H + 0.35 + k * 0.33, back_z - 0.055), 0.022,
                   "turquoise", 1)
    solid("throne", (0.0, y0 + 0.6, z + 0.04), (seat_w + 0.2, 1.2, seat_d + 0.2))
    empty("seat", (0.0, y0, z - seat_d * 0.5 + 0.05))
    empty("stand", (0.0, y0, DAIS[1] + 0.35))
    # where she stands before sitting: a sitter's feet 0.38 m before the seat's middle (WadooSite.SIT_OUT)
    empty("sit", (0.0, y0, z - 0.38))


def basin():
    cz = -0.45
    lathe("basin", [(0.0, 0.0), (0.42, 0.0), (0.46, 0.04), (0.44, 0.12), (0.5, 0.36), (0.62, 0.44), (0.64, 0.5),
                    (0.58, 0.52), (0.54, 0.47), (0.0, 0.42)], (0.0, 0.0, cz), "stone", 40)
    lathe("basin_water", [(0.0, 0.0), (0.545, 0.0)], (0.0, 0.445, cz), "water", 40, smooth=False)
    lathe("basin_ring", [(0.47, 0.0), (0.52, 0.0), (0.52, 0.03), (0.47, 0.03)], (0.0, 0.2, cz), "turquoise", 40)
    solid("basin", (0.0, 0.26, cz), (1.28, 0.52, 1.28))


def rug():
    z0, z1 = -IN_Z + 0.35, STEP[1] - 0.04
    length = z1 - z0
    mid = (z0 + z1) * 0.5
    box("rug", (0.0, 0.008, mid), (1.3, 0.016, length), "rust", bevel=0.006, segments=1)
    box("rug_field", (0.0, 0.018, mid), (1.0, 0.012, length - 0.3), "teal", bevel=0.004, segments=1)
    for sx in (-1, 1):
        box("rug_band", (sx * 0.56, 0.02, mid), (0.05, 0.012, length - 0.1), "cream", bevel=0.003, segments=1)
    # cream diamonds down the middle
    for k in range(6):
        z = z0 + 0.4 + k * (length - 0.8) / 5
        box("rug_diamond", (0.0, 0.026, z), (0.22, 0.01, 0.22), "saffron", bevel=0.003, segments=1, turn=math.pi / 4)


def lamp(name, x, z, n):
    tall = 1.5
    lathe(name + "_foot", [(0.0, 0.0), (0.2, 0.0), (0.21, 0.03), (0.16, 0.06), (0.06, 0.1), (0.0, 0.1)], (x, 0.0, z),
          "bronze", 24)
    rod(name + "_stem", (x, 0.08, z), (x, tall - 0.08, z), 0.025, "bronze")
    for k in range(3):
        y = 0.45 + k * 0.38
        lathe(name + "_knot", [(0.0, -0.03), (0.045, -0.02), (0.05, 0.0), (0.045, 0.02), (0.0, 0.03)], (x, y, z), "bronze",
              16)
    lathe(name + "_cup", [(0.0, 0.0), (0.03, 0.0), (0.12, 0.06), (0.17, 0.14), (0.16, 0.15), (0.11, 0.08), (0.0, 0.06)],
          (x, tall - 0.1, z), "bronze", 24)
    sphere(name + "_glass", (x, tall + 0.08, z), 0.11, "sunglass", 3, squash=1.1)
    empty("lamp_%d" % n, (x, tall + 0.1, z))
    solid(name, (x, tall * 0.5, z), (0.42, tall, 0.42))


def banner(name, x, y, z, facing, width, height, pattern):
    stripes = {
        "rust": [("rust", 0.0, 1.0), ("cream", 0.1, 0.14), ("teal", 0.42, 0.58), ("cream", 0.86, 0.9),
                 ("saffron", 0.94, 1.0)],
        "teal": [("teal", 0.0, 1.0), ("cream", 0.08, 0.12), ("rust", 0.3, 0.34), ("saffron", 0.48, 0.52),
                 ("rust", 0.66, 0.7), ("cream", 0.88, 0.92), ("bronze", 0.96, 1.0)],
        "royal": [("royal", 0.0, 1.0), ("saffron", 0.12, 0.16), ("cream", 0.5, 0.53), ("saffron", 0.84, 0.88)],
    }[pattern]
    cloth(name, (x, y, z), width, height, facing, stripes, folds=3, depth=0.025)
    # the rod it hangs from, with bronze ends
    across = Vector((facing[2], 0.0, -facing[0]))
    a = (x - across.x * (width * 0.5 + 0.08), y + height * 0.5 + 0.03, z - across.z * (width * 0.5 + 0.08))
    b = (x + across.x * (width * 0.5 + 0.08), y + height * 0.5 + 0.03, z + across.z * (width * 0.5 + 0.08))
    rod(name + "_rod", a, b, 0.022, "wood", 10)
    sphere(name + "_end", a, 0.04, "bronze", 1)
    sphere(name + "_end", b, 0.04, "bronze", 1)
    # tassels along its foot
    for k in range(5):
        u = (k + 0.5) / 5 - 0.5
        p = (x + across.x * u * width * 0.9 + facing[0] * 0.02, y - height * 0.5 - 0.06, z + across.z * u * width * 0.9 +
             facing[2] * 0.02)
        rod(name + "_tassel", (p[0], p[1] + 0.07, p[2]), p, 0.012, "saffron", 6)


def staff_rack():
    x = -IN_X + 0.22
    z = -1.55
    for dz in (-0.55, 0.55):
        box("rack_post", (x, 0.85, z + dz), (0.09, 1.7, 0.09), "wood", bevel=0.02)
    for y in (0.25, 1.35):
        box("rack_bar", (x + 0.04, y, z), (0.07, 0.07, 1.3), "wood", bevel=0.02)
    box("rack_foot", (x, 0.04, z), (0.32, 0.08, 1.3), "wood", bevel=0.02)
    # three sunstaffs standing in it, leaning on the wall
    for k, dz in enumerate((-0.35, 0.0, 0.35)):
        bx, bz = x + 0.06, z + dz
        rod("staff", (bx, 0.08, bz), (bx - 0.05, 1.55, bz), 0.02, "bronze", 10)
        lathe("staff_cage", [(0.0, -0.02), (0.06, 0.02), (0.075, 0.1), (0.05, 0.17), (0.0, 0.2)], (bx - 0.05, 1.55, bz),
              "bronze", 12)
        sphere("staff_sun", (bx - 0.05, 1.66, bz), 0.05, "sunglass", 2)
    solid("rack", (x + 0.05, 0.85, z), (0.36, 1.7, 1.3))


def woven_map():
    """The dunes on a cloth on the east wall: sand, darker dune ridges, the
    oasis's ring wall and pool, the breach, and the beast's path stitched in red
    from the deep dunes to the breach."""
    x = IN_X - 0.03
    cz, cy = 0.2, 1.75
    w, h = 2.3, 1.45
    face = (-1.0, 0.0, 0.0)
    cloth("map_cloth", (x, cy, cz), w, h, face, [("map_sand", 0.0, 1.0), ("rust", 0.0, 0.035), ("rust", 0.965, 1.0)],
          folds=2, depth=0.012, rows=12, cols=18)
    rod("map_rod", (x - 0.04, cy + h * 0.5 + 0.03, cz - w * 0.5 - 0.1), (x - 0.04, cy + h * 0.5 + 0.03, cz + w * 0.5 + 0.1),
        0.022, "wood", 10)

    def on(u, v, out=0.022):
        # a point on the cloth: u across (0 left to 1 right as you face it), v up
        return (x - out, cy + (v - 0.5) * h, cz + (0.5 - u) * w)

    # dune ridges: long waving lines of a darker sand
    for r in range(7):
        v0 = 0.12 + r * 0.12
        pts = [on(u / 20.0, v0 + 0.035 * math.sin(u / 20.0 * 9.0 + r * 1.7)) for u in range(21)]
        for k in range(20):
            if 0.25 < k / 20.0 < 0.55 and 0.3 < v0 < 0.7:
                continue  # the village sits here
            rod("map_dune", pts[k], pts[k + 1], 0.009, "map_dune", 5)
    # the village: a ring wall of cream thread round a teal pool
    c = (0.4, 0.5)
    ring = [on(c[0] + 0.1 * math.cos(a) * h / w * 1.4, c[1] + 0.14 * math.sin(a)) for a in
            [math.tau * k / 24 for k in range(25)]]
    for k in range(24):
        if k in (0, 23):
            continue  # the breach, east
        rod("map_wall", ring[k], ring[k + 1], 0.012, "cream", 5)
    lathe("map_pool", [(0.0, 0.0), (0.06, 0.0), (0.065, 0.006), (0.0, 0.008)], (x - 0.022, cy, cz + (0.5 - c[0]) * w), "teal",
          20)
    # the beast's path: red stitches from the deep dunes (top right) to the breach
    path = []
    for k in range(40):
        t = k / 39.0
        u = 0.93 - t * 0.43 + 0.05 * math.sin(t * 7.0)
        v = 0.88 - t * 0.38 + 0.04 * math.cos(t * 5.0)
        path.append(on(u, v, 0.026))
    for k in range(0, 39, 2):
        rod("map_path", path[k], path[k + 1], 0.011, "map_red", 6)
    # where it came up: a red mark like a burst
    end = path[0]
    for k in range(6):
        a = math.tau * k / 6
        rod("map_burst", end, (end[0], end[1] + 0.05 * math.sin(a), end[2] + 0.05 * math.cos(a)), 0.009, "map_red", 5)


def beams():
    for k in range(5):
        z = -IN_Z + 0.55 + k * (2.0 * IN_Z - 1.1) / 4
        rod("beam", (-IN_X - 0.05, CEIL - 0.13, z), (IN_X + 0.05, CEIL - 0.13, z), 0.11, "wood", 8)


def jars():
    for k, (x, z, s) in enumerate([(2.85, -2.1, 1.0), (2.5, -2.2, 0.8), (-2.85, 2.1, 0.9), (2.85, 2.05, 1.05)]):
        prof = [(0.0, 0.0), (0.12, 0.0), (0.2, 0.12), (0.22, 0.3), (0.16, 0.5), (0.09, 0.58), (0.1, 0.64),
                (0.075, 0.64), (0.0, 0.6)]
        lathe("jar", [(r * s, y * s) for r, y in prof], (x, 0.0, z), "clay", 24)
        lathe("jar_band", [(0.214 * s, 0.26 * s), (0.224 * s, 0.27 * s), (0.224 * s, 0.31 * s), (0.214 * s, 0.32 * s)],
              (x, 0.0, z), "turquoise" if k % 2 == 0 else "rust", 24)
        solid("jar_%d" % k, (x, 0.32 * s, z), (0.46 * s, 0.64 * s, 0.46 * s))


def cushions():
    for sx in (-1, 1):
        x = sx * 1.45
        box("cushion", (x, DAIS[2] + 0.07, 2.0), (0.6, 0.14, 0.6), "saffron" if sx < 0 else "rust", bevel=0.06,
            segments=4)
        box("cushion_top", (x, DAIS[2] + 0.17, 2.0), (0.45, 0.08, 0.45), "cream", bevel=0.035, segments=4)


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    dais()
    throne()
    basin()
    rug()
    lamp("lamp_a", -1.65, 1.0, 0)
    lamp("lamp_b", 1.65, 1.0, 1)
    lamp("lamp_c", -1.9, -1.7, 2)
    lamp("lamp_d", 1.9, -1.7, 3)
    # back wall, either side of the throne; west wall, clear of its window
    banner("banner_back_w", -1.75, 2.55, IN_Z - 0.04, (0.0, 0.0, -1.0), 0.85, 2.6, "rust")
    banner("banner_back_e", 1.75, 2.55, IN_Z - 0.04, (0.0, 0.0, -1.0), 0.85, 2.6, "rust")
    banner("banner_west", -IN_X + 0.04, 2.4, 1.55, (1.0, 0.0, 0.0), 0.8, 2.3, "teal")
    banner("banner_east", IN_X - 0.04, 2.4, -1.75, (-1.0, 0.0, 0.0), 0.75, 2.2, "royal")
    staff_rack()
    woven_map()
    beams()
    jars()
    cushions()


def join_by_material():
    """One object, one surface per material: few draw calls in the game."""
    for ob in PARTS:
        bpy.context.view_layer.objects.active = ob
        for mod in list(ob.modifiers):
            ob.select_set(True)
            bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in PARTS:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = PARTS[0]
    bpy.ops.object.join()
    hall = bpy.context.view_layer.objects.active
    hall.name = "Hall"
    hall.data.name = "Hall"
    return hall


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = argv[0] if argv else "."
    build()
    hall = join_by_material()
    tris = sum(len(p.vertices) - 2 for p in hall.data.polygons)
    print("HALL triangles %d, materials %d" % (tris, len(hall.data.materials)))
    bpy.ops.export_scene.gltf(filepath="%s/hall.glb" % out, export_format="GLB", export_yup=True,
                              export_apply=True, use_selection=False)
    if "render" in argv:
        render(out)


def render(out):
    scene = bpy.context.scene
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    cam.location = G(0.0, 1.6, -2.4)
    cam.rotation_euler = (math.radians(84), 0.0, math.radians(180))
    cam.data.lens = 18
    scene.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    scene.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(50), 0.0, math.radians(30))
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.6, 0.55, 0.5, 1.0)
    scene.world = world
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.color_type = "MATERIAL"
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.filepath = "%s/blender_hall.png" % out
    bpy.ops.render.render(write_still=True)


main()
