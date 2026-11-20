"""The Wadees' rooms (docs/superpowers/specs/2026-11-16-wadoo-design.md §8, §10).

Builds the furnishings that stand inside three brick shells of the oasis
(data/places/oasis.json) and writes each as a GLB, <room>.glb:

  hall        the queen's hall, in `house_b`;
  home        a family's home, in `home_4` (stage 5);
  glassworks  the Glassworks, in `workshop` (stage 5).

  blender -b --factory-startup --python wadoo_rooms.py -- <out dir> [hall] [home] [glassworks] [render]

With no room named, the hall alone (as before stage 5).

The game puts it in the shell's frame (WadooRooms): its origin is the middle of
the shell's floor, y up, the door's side toward -z. Here everything is written in
those Godot coordinates and turned into Blender's (x, -z, y) by G().

Materials are named by what they are (stone, wood, bronze, sunglass, ...): the
game paints each from WadeePalette, so the colours set here are only for a
preview render. Empties carry the rest: lamp_<n> where a sunglass lamp's light
sits, col_<name> a solid box (its scale the half size), seat where the queen's
throne seat is, sit where she stands to sit down on it, stand where she
stands to receive you. In the home and the Glassworks, spot_<kind>_<n>_<action>
is where a Wadee stands to do <action> at a spot of <kind> (home, jar, hide or
glass: WadooSite reads them), and look_<kind>_<n> what they face there; kiln_<n>
is where the kiln's glow sits.
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
    "clay": (0.66, 0.40, 0.25), "glass": (0.62, 0.82, 0.78), "ember": (1.0, 0.54, 0.23),
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
        if name in ("sunglass", "ember"):
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


# --- shared by the home and the Glassworks ---------------------------------------

def spot(kind, n, action, at, look):
    """Where a Wadee stands to do `action` at spot `n` of `kind`, and what they face."""
    empty("spot_%s_%d_%s" % (kind, n, action), at)
    empty("look_%s_%d" % (kind, n), look)


def roof_beams(half_x, half_z, ceil, count):
    for k in range(count):
        z = -half_z + 0.5 + k * (2.0 * half_z - 1.0) / (count - 1)
        rod("beam", (-half_x - 0.05, ceil - 0.1, z), (half_x + 0.05, ceil - 0.1, z), 0.09, "wood", 8)


def pot(name, x, z, s, material="clay", band="turquoise", y=0.0):
    prof = [(0.0, 0.0), (0.1, 0.0), (0.17, 0.08), (0.19, 0.2), (0.14, 0.33), (0.08, 0.38), (0.09, 0.42),
            (0.065, 0.42), (0.0, 0.39)]
    lathe(name, [(r * s, h * s) for r, h in prof], (x, y, z), material, 20)
    lathe(name + "_band", [(0.185 * s, 0.17 * s), (0.195 * s, 0.18 * s), (0.195 * s, 0.22 * s), (0.185 * s, 0.23 * s)],
          (x, y, z), band, 20)


def bowl(name, x, y, z, r, material="clay"):
    lathe(name, [(0.0, 0.0), (r * 0.55, 0.0), (r, r * 0.55), (r * 0.92, r * 0.58), (r * 0.5, r * 0.12), (0.0, r * 0.1)],
          (x, y, z), material, 18)


def stool(name, x, z):
    """A round stool, its seat 0.45 high (the benches' height, BrickShell.BENCH_SEAT)."""
    lathe(name, [(0.0, 0.0), (0.15, 0.0), (0.16, 0.02), (0.1, 0.12), (0.09, 0.3), (0.16, 0.38), (0.19, 0.42),
                 (0.18, 0.45), (0.0, 0.45)], (x, 0.0, z), "wood", 20)
    lathe(name + "_pad", [(0.0, 0.0), (0.16, 0.0), (0.165, 0.02), (0.12, 0.04), (0.0, 0.045)], (x, 0.45, z), "rust", 20)
    solid(name, (x, 0.23, z), (0.4, 0.46, 0.4))


def small_lamp(name, x, y, z, n):
    """A sunglass ball in a bronze cup on a short foot, standing on something."""
    lathe(name + "_foot", [(0.0, 0.0), (0.07, 0.0), (0.075, 0.015), (0.03, 0.05), (0.025, 0.12), (0.0, 0.12)],
          (x, y, z), "bronze", 16)
    lathe(name + "_cup", [(0.0, 0.0), (0.02, 0.0), (0.07, 0.04), (0.09, 0.08), (0.085, 0.09), (0.0, 0.05)],
          (x, y + 0.11, z), "bronze", 16)
    sphere(name + "_glass", (x, y + 0.22, z), 0.07, "sunglass", 3)
    empty("lamp_%d" % n, (x, y + 0.25, z))


def hanging_lamp(name, x, z, ceil, drop, n):
    y = ceil - 0.1 - drop
    for k in range(3):
        a = math.tau * k / 3
        rod(name + "_chain", (x, ceil - 0.12, z), (x + math.cos(a) * 0.1, y + 0.12, z + math.sin(a) * 0.1), 0.006,
            "bronze", 5)
    lathe(name + "_cup", [(0.0, 0.0), (0.03, 0.0), (0.1, 0.05), (0.13, 0.12), (0.12, 0.13), (0.0, 0.07)],
          (x, y, z), "bronze", 20)
    sphere(name + "_glass", (x, y + 0.08, z), 0.09, "sunglass", 3)
    empty("lamp_%d" % n, (x, y + 0.02, z))


# --- the home (home_4) ----------------------------------------------------------
# home_4 is 6.9 x 3.2 x 4.9 (BrickShell, walls 0.45): inside 6.0 x 4.0, its ceiling
# 2.53 up (3.2 less its parapet and roof slab). The door is in the middle of the
# front (-z), 1.1 wide; a window in the east wall at z -0.2, 0.7 wide, its sill
# 1.05 up. Four live here (WadooCast: Wenna, Jori, Sabi, Hami).
HOME_X = 3.0
HOME_Z = 2.0
HOME_CEIL = 2.53
HOME_TABLE = (-0.6, 0.15)


def bedroll(name, x0, x1, z0, z1, colours):
    """A sleeping mat on a low wooden frame, a folded blanket and a pillow at one end."""
    along_x = (x1 - x0) >= (z1 - z0)
    cx, cz = (x0 + x1) * 0.5, (z0 + z1) * 0.5
    w, d = x1 - x0, z1 - z0
    box(name + "_frame", (cx, 0.04, cz), (w, 0.08, d), "wood", bevel=0.02)
    box(name + "_mat", (cx, 0.11, cz), (w - 0.06, 0.07, d - 0.06), colours[0], bevel=0.03, segments=3)
    if along_x:
        box(name + "_blanket", (cx + w * 0.12, 0.165, cz), (w * 0.55, 0.05, d - 0.1), colours[1], bevel=0.02)
        box(name + "_stripe", (cx + w * 0.12, 0.192, cz), (w * 0.08, 0.012, d - 0.12), colours[2], bevel=0.004,
            segments=1)
        box(name + "_pillow", (x0 + 0.24, 0.19, cz), (0.32, 0.1, d - 0.22), "cream", bevel=0.045, segments=4)
    else:
        box(name + "_blanket", (cx, 0.165, cz - d * 0.12), (w - 0.1, 0.05, d * 0.55), colours[1], bevel=0.02)
        box(name + "_stripe", (cx, 0.192, cz - d * 0.12), (w - 0.12, 0.012, d * 0.08), colours[2], bevel=0.004,
            segments=1)
        box(name + "_pillow", (cx, 0.19, z1 - 0.24), (w - 0.22, 0.1, 0.32), "cream", bevel=0.045, segments=4)
    solid(name, (cx, 0.12, cz), (w, 0.24, d))


def home_table():
    x, z = HOME_TABLE
    box("table_top", (x, 0.57, z), (1.1, 0.06, 0.7), "wood", bevel=0.025)
    for sx in (-1, 1):
        box("table_foot", (x + sx * 0.4, 0.27, z), (0.12, 0.54, 0.5), "wood", bevel=0.02)
    box("table_runner", (x, 0.605, z), (1.15, 0.008, 0.22), "teal", bevel=0.003, segments=1)
    bowl("table_bowl", x + 0.25, 0.6, z - 0.05, 0.12)
    bowl("table_cup", x - 0.3, 0.6, z + 0.12, 0.05, "turquoise")
    bowl("table_cup", x - 0.15, 0.6, z - 0.17, 0.05, "clay")
    small_lamp("table_lamp", x - 0.05, 0.6, z + 0.12, 0)
    solid("table", (x, 0.3, z), (1.1, 0.6, 0.7))
    # two stools, at the west and east ends; each sitter stands 0.38 m before their
    # stool's middle, toward the table, and sits back onto it (WadooSite.SIT_OUT).
    # A third on the near side walled the west half of the room off from the door
    # in the walkers' grid, with the stools' margins: the front is a passage.
    for n, (sx, sz) in enumerate([(x - 1.0, z), (x + 1.0, z)]):
        stool("stool_%d" % n, sx, sz)
        d = Vector((x - sx, z - sz)).normalized()
        spot("home", n, "sit", (sx + d.x * 0.38, 0.0, sz + d.y * 0.38), (x + d.x * 2.0, 0.0, z + d.y * 2.0))
    lathe("rug", [(0.0, 0.0), (1.2, 0.0), (1.2, 0.012), (0.0, 0.012)], (x, 0.0, z), "rust", 48)
    lathe("rug_field", [(0.0, 0.0), (1.02, 0.0), (1.02, 0.016), (0.0, 0.016)], (x, 0.0, z), "saffron", 48)
    lathe("rug_ring", [(0.55, 0.0), (0.68, 0.0), (0.68, 0.02), (0.55, 0.02)], (x, 0.0, z), "teal", 48)


def loom():
    """An upright loom against the west wall, a cloth half woven on it."""
    x = -HOME_X + 0.22
    z0, z1 = -1.55, -0.25
    for zz in (z0, z1):
        box("loom_post", (x, 0.9, zz), (0.09, 1.8, 0.09), "wood", bevel=0.02)
        box("loom_foot", (x + 0.12, 0.04, zz), (0.4, 0.08, 0.1), "wood", bevel=0.02)
    for y in (0.28, 1.7):
        rod("loom_beam", (x + 0.04, y, z0 - 0.05), (x + 0.04, y, z1 + 0.05), 0.04, "wood", 10)
    # the warp: threads from beam to beam, and the woven part from the bottom up
    for k in range(17):
        zz = z0 + 0.1 + k * (z1 - z0 - 0.2) / 16
        rod("loom_warp", (x + 0.06, 0.95, zz), (x + 0.06, 1.68, zz), 0.004, "cream", 4)
    cloth("loom_cloth", (x + 0.07, 0.62, (z0 + z1) * 0.5), (z1 - z0) - 0.18, 0.66, (1.0, 0.0, 0.0),
          [("rust", 0.0, 1.0), ("cream", 0.1, 0.16), ("teal", 0.3, 0.45), ("saffron", 0.55, 0.6), ("teal", 0.72, 0.8),
           ("cream", 0.9, 0.95)], folds=0, depth=0.0, rows=12, cols=8)
    rod("loom_bar", (x + 0.12, 0.96, z0 + 0.02), (x + 0.12, 0.96, z1 - 0.02), 0.018, "wood", 8)
    # a shuttle and a basket of yarn at its foot
    box("loom_shuttle", (x + 0.14, 0.97, (z0 + z1) * 0.5 + 0.2), (0.04, 0.03, 0.3), "wood", bevel=0.01, segments=2)
    lathe("yarn_basket", [(0.0, 0.0), (0.16, 0.0), (0.2, 0.18), (0.19, 0.19), (0.0, 0.03)], (x + 0.55, 0.0, z0 - 0.1),
          "wood", 18)
    for c, dx, dz in [("teal", -0.05, 0.03), ("saffron", 0.06, -0.02), ("rust", 0.0, -0.08)]:
        sphere("yarn", (x + 0.55 + dx, 0.2, z0 - 0.1 + dz), 0.075, c, 2)
    solid("loom", (x + 0.05, 0.9, (z0 + z1) * 0.5), (0.45, 1.8, z1 - z0 + 0.2))
    spot("home", 2, "kneel", (x + 0.8, 0.0, (z0 + z1) * 0.5), (x - 0.5, 0.0, (z0 + z1) * 0.5))


def water_jar():
    """The family's water jar by the door, its lid and a dipper; water is poured in here."""
    x, z = 1.85, -1.35
    prof = [(0.0, 0.0), (0.2, 0.0), (0.33, 0.18), (0.37, 0.42), (0.3, 0.7), (0.17, 0.82), (0.19, 0.9), (0.15, 0.9),
            (0.0, 0.86)]
    lathe("big_jar", prof, (x, 0.0, z), "clay", 32)
    lathe("big_jar_band", [(0.368, 0.4), (0.378, 0.42), (0.375, 0.5), (0.36, 0.52)], (x, 0.0, z), "turquoise", 32)
    lathe("big_jar_band", [(0.34, 0.62), (0.35, 0.63), (0.335, 0.67), (0.32, 0.68)], (x, 0.0, z), "rust", 32)
    lathe("big_jar_lid", [(0.0, 0.0), (0.2, 0.0), (0.2, 0.025), (0.06, 0.05), (0.04, 0.09), (0.0, 0.1)],
          (x, 0.9, z), "wood", 24)
    rod("dipper", (x + 0.18, 0.92, z + 0.05), (x + 0.42, 1.05, z + 0.1), 0.012, "wood", 6)
    bowl("dipper_cup", x + 0.14, 0.88, z + 0.04, 0.06, "wood")
    box("jar_stand", (x, 0.03, z), (0.82, 0.06, 0.82), "stone", bevel=0.02)
    solid("big_jar", (x, 0.45, z), (0.8, 0.9, 0.8))
    spot("jar", 0, "interact", (x - 0.75, 0.0, z + 0.25), (x, 0.0, z))


def home_shelf():
    """A low shelf against the west wall, behind the stools: pots and bowls."""
    x = -HOME_X + 0.2
    z0, z1 = 0.05, 1.0
    zc = (z0 + z1) * 0.5
    for y in (0.02, 0.5, 0.98):
        box("shelf_board", (x, y + 0.02, zc), (0.36, 0.04, z1 - z0), "wood", bevel=0.012)
    for zz in (z0 + 0.03, z1 - 0.03):
        box("shelf_side", (x, 0.52, zz), (0.36, 1.04, 0.04), "wood", bevel=0.012)
    pot("shelf_pot", x, z0 + 0.2, 0.9, y=0.04)
    pot("shelf_pot", x, z1 - 0.22, 0.75, "clay", "rust", y=0.04)
    pot("shelf_pot", x, zc, 0.6, "clay", "saffron", y=0.52)
    for k in range(3):
        bowl("shelf_bowl", x, 1.02 + k * 0.035, z0 + 0.25, 0.11 - k * 0.012, "clay" if k != 1 else "teal")
    bowl("shelf_bowl", x, 0.54, z1 - 0.2, 0.09, "turquoise")
    pot("shelf_pot", x, z1 - 0.2, 0.45, "clay", "turquoise", y=1.0)
    solid("shelf", (x, 0.52, zc), (0.4, 1.04, z1 - z0 + 0.04))


def doorway_curtain():
    """A woven curtain on a rod over the door, gathered and tied back to its east side."""
    z = -HOME_Z + 0.05
    rod("curtain_rod", (-0.75, 2.12, z), (0.95, 2.12, z), 0.018, "wood", 8)
    sphere("curtain_end", (-0.75, 2.12, z), 0.035, "bronze", 1)
    sphere("curtain_end", (0.95, 2.12, z), 0.035, "bronze", 1)
    # gathered: a narrow, deeply folded cloth beside the jamb, pinched by a tie
    cloth("curtain", (0.78, 1.08, z + 0.03), 0.3, 2.06, (0.0, 0.0, 1.0),
          [("teal", 0.0, 1.0), ("saffron", 0.15, 0.2), ("rust", 0.48, 0.56), ("cream", 0.82, 0.86)],
          folds=5, depth=0.05, rows=20, cols=8)
    lathe("curtain_tie", [(0.13, -0.025), (0.15, 0.0), (0.13, 0.025)], (0.78, 1.0, z + 0.04), "bronze", 12)


def home():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # two bedrolls along the back wall, one along the east wall, and one rolled up
    bedroll("bed_a", -2.95, -1.05, 1.18, 1.95, ("cream", "teal", "saffron"))
    bedroll("bed_b", -0.95, 0.95, 1.18, 1.95, ("cream", "rust", "teal"))
    bedroll("bed_c", 2.18, 2.95, 0.15, 1.95, ("cream", "saffron", "rust"))
    rod("bed_rolled", (1.35, 0.13, 1.82), (2.0, 0.13, 1.82), 0.13, "teal", 16)
    box("bed_rolled_tie", (1.5, 0.13, 1.82), (0.04, 0.28, 0.28), "rust", bevel=0.02)
    box("bed_rolled_tie", (1.85, 0.13, 1.82), (0.04, 0.28, 0.28), "rust", bevel=0.02)
    solid("bed_rolled", (1.68, 0.13, 1.82), (0.7, 0.28, 0.3))
    # the family's hanging over the back bedrolls
    cloth("hanging", (-1.0, 1.55, HOME_Z - 0.04), 2.4, 1.05, (0.0, 0.0, -1.0),
          [("teal", 0.0, 1.0), ("cream", 0.08, 0.12), ("rust", 0.25, 0.4), ("saffron", 0.47, 0.53), ("rust", 0.6, 0.75),
           ("cream", 0.88, 0.92)], folds=3, depth=0.02, rows=12, cols=20)
    rod("hanging_rod", (-2.3, 2.1, HOME_Z - 0.06), (0.3, 2.1, HOME_Z - 0.06), 0.02, "wood", 8)
    home_table()
    loom()
    water_jar()
    home_shelf()
    # pots by the front wall, west of the door
    pot("floor_pot", -1.55, -1.72, 1.2)
    pot("floor_pot", -1.95, -1.75, 0.9, "clay", "rust")
    pot("floor_pot", -1.2, -1.78, 0.7, "clay", "saffron")
    solid("floor_pots", (-1.6, 0.25, -1.74), (1.1, 0.5, 0.45))
    doorway_curtain()
    hanging_lamp("hang_lamp", 1.2, 0.2, HOME_CEIL, 0.55, 1)
    roof_beams(HOME_X, HOME_Z, HOME_CEIL, 4)
    # tidying a bedroll; and where they huddle at the back if the town is in danger
    spot("home", 3, "kneel", (-1.95, 0.0, 0.88), (-1.95, 0.0, 1.6))
    spot("hide", 0, "cower", (-2.35, 0.0, 0.85), (0.0, 0.0, -2.4))
    spot("hide", 1, "cower", (0.1, 0.0, 0.92), (0.0, 0.0, -2.4))
    spot("hide", 2, "cower", (1.65, 0.0, 1.0), (0.0, 0.0, -2.4))


# --- the Glassworks (workshop) ----------------------------------------------------
# workshop is 10.8 x 3.4 x 6.4: inside 9.9 x 5.5, its ceiling 2.71 up. The door is in
# the front (-z) at x -1.25, 1.1 wide; a window in the front at x 1.76 and one in
# the east wall at z 0.11, each 0.7 wide, their sills 1.05 up.
GW_X = 4.95
GW_Z = 2.75
GW_CEIL = 2.71
KILN = (-3.7, 0.9)


def kiln():
    """A beehive kiln of clay on a stone ring, its mouth glowing to the east, a flue up
    through the roof; tongs and a bellows beside it."""
    x, z = KILN
    lathe("kiln_ring", [(0.0, 0.0), (0.98, 0.0), (1.0, 0.04), (0.98, 0.22), (0.92, 0.25), (0.0, 0.25)], (x, 0.0, z),
          "stone_dark", 32)
    lathe("kiln_dome", [(0.0, 0.0), (0.88, 0.0), (0.88, 0.35), (0.83, 0.7), (0.7, 1.02), (0.5, 1.28), (0.28, 1.43),
                        (0.2, 1.47), (0.0, 1.47)], (x, 0.22, z), "clay", 32)
    for y, r in ((0.55, 0.87), (1.05, 0.69)):
        lathe("kiln_band", [(r - 0.01, -0.03), (r + 0.025, -0.02), (r + 0.025, 0.02), (r - 0.01, 0.03)],
              (x, 0.22 + y, z), "rust", 32)
    # the mouth: a glowing arch set in the dome's east face, under a stone lintel
    sphere("kiln_mouth", (x + 0.82, 0.62, z), 0.3, "ember", 3, squash=1.25)
    box("kiln_lintel", (x + 0.86, 0.98, z), (0.18, 0.12, 0.72), "stone_dark", bevel=0.03)
    for sz in (-1, 1):
        box("kiln_jamb", (x + 0.86, 0.6, z + sz * 0.34), (0.18, 0.7, 0.1), "stone_dark", bevel=0.03)
    rod("kiln_flue", (x, 1.6, z), (x, GW_CEIL + 0.05, z), 0.17, "clay", 16)
    lathe("kiln_collar", [(0.17, 0.0), (0.24, 0.0), (0.24, 0.08), (0.17, 0.08)], (x, 1.62, z), "bronze", 16)
    empty("kiln_0", (x + 1.25, 0.65, z))
    solid("kiln", (x, 0.8, z), (2.0, 1.6, 2.0))
    # a bellows on the south side, its nozzle at the dome
    bx, bz = x + 0.55, z - 1.05
    box("bellows_board", (bx, 0.12, bz), (0.55, 0.04, 0.32), "wood", bevel=0.01, segments=2)
    box("bellows_leather", (bx, 0.2, bz), (0.5, 0.12, 0.3), "rust", bevel=0.05, segments=4)
    box("bellows_board", (bx, 0.28, bz), (0.55, 0.04, 0.32), "wood", bevel=0.01, segments=2)
    rod("bellows_nozzle", (bx - 0.25, 0.2, bz + 0.05), (x + 0.4, 0.32, z - 0.65), 0.03, "bronze", 8)
    rod("bellows_handle", (bx + 0.27, 0.28, bz), (bx + 0.55, 0.3, bz), 0.02, "wood", 6)
    solid("bellows", (bx, 0.16, bz), (0.6, 0.32, 0.36))
    # tongs hung on a peg beside the mouth
    for dz in (-0.03, 0.03):
        rod("tongs", (x + 0.98, 1.2, z + 0.62 + dz), (x + 1.02, 0.55, z + 0.6 + dz * 3), 0.012, "bronze", 6)
    spot("glass", 0, "interact", (x + 1.55, 0.0, z - 0.1), (x, 0.0, z))


def quench_trough():
    x, z = -3.85, -1.35
    box("trough", (x, 0.25, z), (1.3, 0.5, 0.55), "stone", bevel=0.04)
    box("trough_water", (x, 0.43, z), (1.12, 0.02, 0.37), "water", bevel=0.0)
    for k in range(3):
        rod("trough_rod", (x - 0.4 + k * 0.3, 0.45, z - 0.12), (x - 0.25 + k * 0.3, 0.75, z + 0.25), 0.012, "glass", 8)
    solid("trough", (x, 0.25, z), (1.3, 0.5, 0.55))


def workbench():
    """A low bench along the back wall, worked kneeling: rods, tongs, a blowpipe, and a
    sunstaff being made, its cage open and its head of sunglass waiting beside it."""
    x0, x1 = -1.15, 1.65
    z = GW_Z - 0.45
    xc = (x0 + x1) * 0.5
    box("bench_top", (xc, 0.42, z), (x1 - x0, 0.07, 0.8), "wood", bevel=0.025)
    for xx in (x0 + 0.15, xc, x1 - 0.15):
        box("bench_leg", (xx, 0.19, z), (0.1, 0.38, 0.66), "wood", bevel=0.02)
    box("bench_cloth", (xc - 0.5, 0.465, z - 0.05), (0.9, 0.01, 0.55), "cream", bevel=0.003, segments=1)
    # the staff in the making, along the bench
    rod("bench_staff", (xc - 0.85, 0.5, z - 0.1), (xc + 0.35, 0.5, z - 0.1), 0.02, "bronze", 10)
    lathe("bench_cage", [(0.0, -0.02), (0.06, 0.02), (0.075, 0.1), (0.05, 0.17), (0.0, 0.2)],
          (xc + 0.45, 0.5, z - 0.1), "bronze", 12)
    sphere("bench_sun", (xc + 0.75, 0.53, z - 0.15), 0.06, "sunglass", 2)
    # glass rods and a blowpipe
    for k in range(5):
        rod("bench_rod", (xc + 0.3 + k * 0.05, 0.47, z + 0.15), (xc + 0.9 + k * 0.05, 0.47, z + 0.22), 0.01, "glass", 6)
    rod("blowpipe", (x0 + 0.15, 0.48, z + 0.2), (x0 + 1.1, 0.48, z + 0.15), 0.014, "bronze", 8)
    sphere("blowpipe_glass", (x0 + 1.14, 0.49, z + 0.15), 0.05, "glass", 2)
    for dx in (-0.02, 0.02):
        rod("bench_tongs", (x1 - 0.5 + dx, 0.47, z - 0.25), (x1 - 0.15 + dx * 3, 0.47, z - 0.2), 0.01, "bronze", 6)
    bowl("bench_bowl", x1 - 0.35, 0.455, z + 0.15, 0.1, "clay")
    small_lamp("bench_lamp", x1 - 0.15, 0.455, z + 0.22, 0)
    solid("bench", (xc, 0.22, z), (x1 - x0, 0.46, 0.8))
    lathe("bench_mat", [(0.0, 0.0), (0.38, 0.0), (0.38, 0.015), (0.0, 0.015)], (xc, 0.0, z - 0.85), "rust", 24)
    spot("glass", 1, "kneel", (xc, 0.0, z - 0.85), (xc, 0.0, GW_Z))


def rod_rack():
    """A rack of glass rods cooling, east of the bench."""
    x, z = 2.85, GW_Z - 0.3
    for dx in (-0.7, 0.7):
        box("rack_post", (x + dx, 0.65, z), (0.08, 1.3, 0.08), "wood", bevel=0.02)
        box("rack_foot", (x + dx, 0.04, z - 0.1), (0.1, 0.08, 0.35), "wood", bevel=0.02)
    for k, y in enumerate((0.35, 0.65, 0.95, 1.25)):
        box("rack_bar", (x, y, z), (1.5, 0.05, 0.06), "wood", bevel=0.015)
        for r in range(9 if k < 3 else 5):
            rr = x - 0.6 + r * 0.15
            rod("rack_rod", (rr, y + 0.035, z - 0.18), (rr + 0.02, y + 0.035, z + 0.18), 0.011,
                "glass" if (r + k) % 4 else "turquoise", 6)
    solid("rack", (x, 0.65, z), (1.55, 1.3, 0.4))


def staff_wall():
    """Half-made sunstaffs leaning on the east wall: shafts, some caged, two with heads."""
    x = GW_X - 0.12
    for k in range(6):
        z = 1.2 + k * 0.24
        top = 1.45 + (k % 3) * 0.05
        rod("wall_staff", (x - 0.22, 0.02, z), (x, top, z), 0.018, "bronze" if k % 2 == 0 else "wood", 8)
        if k in (1, 3, 4):
            lathe("wall_cage", [(0.0, -0.02), (0.05, 0.02), (0.065, 0.09), (0.045, 0.15), (0.0, 0.17)],
                  (x, top, z), "bronze", 10)
        if k in (1, 4):
            sphere("wall_sun", (x, top + 0.09, z), 0.045, "sunglass", 2)
    rod("wall_peg_rail", (x + 0.06, 1.3, 1.05), (x + 0.06, 1.3, 2.55), 0.02, "wood", 6)
    solid("staffs", (x - 0.1, 0.8, 1.8), (0.3, 1.6, 1.5))


def sand_bins():
    """Three bins of sand for the glass, under the front window, with a scoop."""
    z = -GW_Z + 0.45
    for xx, sand in [(0.95, "map_sand"), (1.85, "cream"), (2.75, "map_dune")]:
        box("bin", (xx, 0.3, z), (0.82, 0.6, 0.7), "wood", bevel=0.025)
        box("bin_sand", (xx, 0.56, z), (0.7, 0.06, 0.58), sand, bevel=0.03, segments=3)
        sphere("bin_heap", (xx, 0.58, z), 0.25, sand, 2, squash=0.35)
    rod("scoop_handle", (1.85, 0.62, z - 0.05), (2.15, 0.85, z - 0.25), 0.015, "wood", 6)
    bowl("scoop", 1.8, 0.6, z - 0.02, 0.08, "bronze")
    solid("bins", (1.85, 0.3, z), (2.65, 0.6, 0.72))
    lathe("spilt_sand", [(0.0, 0.0), (0.6, 0.0), (0.0, 0.01)], (1.85, 0.0, z + 0.6), "map_sand", 20)
    spot("glass", 2, "lift", (1.85, 0.0, z + 0.85), (1.85, 0.0, -GW_Z))


def glass_shelves():
    """Shelves of finished glass west of the door: orbs, bottles and lamp glasses."""
    x0, x1 = -4.75, -2.55
    z = -GW_Z + 0.2
    xc = (x0 + x1) * 0.5
    for y in (0.02, 0.6, 1.18, 1.76):
        box("gshelf_board", (xc, y + 0.02, z), (x1 - x0, 0.04, 0.34), "wood", bevel=0.012)
    for xx in (x0 + 0.02, x1 - 0.02):
        box("gshelf_side", (xx, 0.9, z), (0.04, 1.8, 0.34), "wood", bevel=0.012)
    k = 0
    for y in (0.62, 1.2, 1.78):
        for i in range(6):
            xx = x0 + 0.22 + i * (x1 - x0 - 0.44) / 5
            m = ["glass", "sunglass", "turquoise", "glass", "teal", "glass"][(i + k) % 6]
            if (i + k) % 3 == 0:
                sphere("gshelf_orb", (xx, y + 0.1, z), 0.08, m, 2)
            else:
                lathe("gshelf_bottle", [(0.0, 0.0), (0.06, 0.0), (0.07, 0.08), (0.05, 0.16), (0.02, 0.2),
                                        (0.025, 0.24), (0.0, 0.24)], (xx, y + 0.04, z), m, 12)
            k += 1
    pot("gshelf_pot", xc, z, 0.9, "clay", "rust", y=0.04)
    solid("gshelf", (xc, 0.9, z), (x1 - x0, 1.8, 0.36))


def glassworks():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    kiln()
    quench_trough()
    workbench()
    rod_rack()
    staff_wall()
    sand_bins()
    glass_shelves()
    # a worn mat by the kiln, and lamps
    lathe("kiln_mat", [(0.0, 0.0), (0.55, 0.0), (0.55, 0.012), (0.0, 0.012)], (KILN[0] + 1.55, 0.0, KILN[1] - 0.1),
          "rust", 24)
    lamp("lamp_a", -1.85, GW_Z - 0.4, 1)
    lamp("lamp_b", 4.35, -1.55, 2)
    roof_beams(GW_X, GW_Z, GW_CEIL, 6)


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


def join_by_material(name="Hall"):
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
    hall.name = name
    hall.data.name = name
    return hall


ROOMS = {"hall": (build, "Hall"), "home": (home, "Home"), "glassworks": (glassworks, "Glassworks")}
# Where each room's preview render stands and looks: (eye (Godot), yaw deg).
VIEWS = {"hall": ((0.0, 1.6, -2.4), 180), "home": ((0.0, 1.6, -1.7), 180), "glassworks": ((-1.25, 1.6, -2.4), 200)}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = argv[0] if argv else "."
    rooms = [a for a in argv[1:] if a in ROOMS] or ["hall"]
    for room in rooms:
        PARTS.clear()
        make, name = ROOMS[room]
        make()
        joined = join_by_material(name)
        tris = sum(len(p.vertices) - 2 for p in joined.data.polygons)
        print("%s triangles %d, materials %d" % (room.upper(), tris, len(joined.data.materials)))
        bpy.ops.export_scene.gltf(filepath="%s/%s.glb" % (out, room), export_format="GLB", export_yup=True,
                                  export_apply=True, use_selection=False)
        if "render" in argv:
            render(out, room)


def render(out, room="hall"):
    scene = bpy.context.scene
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    eye, yaw = VIEWS[room]
    cam.location = G(*eye)
    cam.rotation_euler = (math.radians(84), 0.0, math.radians(yaw))
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
    scene.render.filepath = "%s/blender_%s.png" % (out, room)
    bpy.ops.render.render(write_still=True)


main()
