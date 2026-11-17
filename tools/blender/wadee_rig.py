# The Wadees' skeletons and motions. Reads the models wadee_base.py wrote, puts a skeleton in
# each (bones placed from the body's own shape, named as Godot's humanoid profile), weights the
# skin to it, lets clothes, hair and jewellery follow the skin under them, copies motions from
# Quaternius's Universal Animation Libraries 1 and 2 (CC0) onto it, and joins every part into one
# mesh with one material whose colours are slots of a 16 x 1 palette (SLOTS), so the game draws a
# Wadee in one call and colours each person from WadeePalette. Writes wadee_<tag>.glb with the
# clips, and sunstaff.glb (the Sunguard's staff).
#   blender -b --factory-startup --disable-autoexec --python wadee_rig.py -- <UAL1 glb> <UAL2 glb> <in dir> <out dir> [render] [a m ...]
import bpy, math, sys, os
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wkit import srgb, mat, tube, ellipsoid, obj_from  # noqa
import bmesh

ARGS = sys.argv[sys.argv.index("--") + 1:]
UAL, UAL2, IN, OUT = ARGS[0], ARGS[1], ARGS[2], ARGS[3]
RENDER = "render" in ARGS
TAGS = [a for a in ARGS[4:] if len(a) == 1] or ["a", "b", "c", "m", "n", "q", "s", "t"]
os.makedirs(OUT, exist_ok=True)
FPS = 24  # the library's clips import at the scene's rate; they go out at the same one

# The clips each Wadee gets, by the libraries' names (kept, so a clip can be traced back). Godot
# drops "_Loop" and loops those; the game loops the others it holds (WadeeLook).
CLIPS1 = ["Idle_Loop", "Idle_Talking_Loop", "Walk_Loop", "Walk_Formal_Loop", "Jog_Fwd_Loop", "Sprint_Loop",
          "Sitting_Enter", "Sitting_Idle_Loop", "Sitting_Exit", "Sitting_Talking_Loop", "Fixing_Kneeling",
          "Interact", "PickUp_Table", "Hit_Chest", "Hit_Head", "Death01", "Roll", "Spell_Simple_Shoot",
          "Spell_Simple_Idle_Loop", "Crouch_Idle_Loop", "Crouch_Fwd_Loop"]
CLIPS2 = ["Farm_Watering", "Farm_Harvest", "Farm_PlantSeed", "Walk_Carry_Loop", "Consume",
          "Idle_FoldArms_Loop", "Yes", "Hit_Knockback"]

# Ours (Godot's humanoid profile), library 1's, the parent.
BONES = [("Root", "root", None), ("Hips", "DEF-hips", "Root"), ("Spine", "DEF-spine.001", "Hips"),
         ("Chest", "DEF-spine.002", "Spine"), ("UpperChest", "DEF-spine.003", "Chest"),
         ("Neck", "DEF-neck", "UpperChest"), ("Head", "DEF-head", "Neck")]
for side, sfx in (("Left", ".L"), ("Right", ".R")):
    BONES += [(side + "Shoulder", "DEF-shoulder" + sfx, "UpperChest"),
              (side + "UpperArm", "DEF-upper_arm" + sfx, side + "Shoulder"),
              (side + "LowerArm", "DEF-forearm" + sfx, side + "UpperArm"),
              (side + "Hand", "DEF-hand" + sfx, side + "LowerArm"),
              (side + "UpperLeg", "DEF-thigh" + sfx, "Hips"),
              (side + "LowerLeg", "DEF-shin" + sfx, side + "UpperLeg"),
              (side + "Foot", "DEF-foot" + sfx, side + "LowerLeg"),
              (side + "Toes", "DEF-toe" + sfx, side + "Foot")]
NAMES1 = {n: s_ for n, s_, _ in BONES}
# Library 2's bones are named as Unreal's mannequin.
NAMES2 = {"Root": "root", "Hips": "pelvis", "Spine": "spine_01", "Chest": "spine_02", "UpperChest": "spine_03",
          "Neck": "neck_01", "Head": "Head"}
for side, sfx in (("Left", "_l"), ("Right", "_r")):
    for ours, theirs in (("Shoulder", "clavicle"), ("UpperArm", "upperarm"), ("LowerArm", "lowerarm"),
                         ("Hand", "hand"), ("UpperLeg", "thigh"), ("LowerLeg", "calf"), ("Foot", "foot"),
                         ("Toes", "ball")):
        NAMES2[side + ours] = theirs + sfx
ARM_BONES = {s + b for s in ("Left", "Right") for b in ("UpperArm", "LowerArm", "Hand")}
LEG_BONES = {s + b for s in ("Left", "Right") for b in ("UpperLeg", "LowerLeg")}
HAIR_BONES = {"Head", "Neck", "UpperChest", "Chest"}

# The palette: a Wadee's material is one 16 x 1 texture, and each part's UVs point at its slot's
# texel. Material names from wadee_base.py (before any "_<tag>") give the slot.
SLOTS = ["skin", "lips", "hair", "brow", "eye_white", "iris", "pupil", "lash", "cloth1", "cloth2", "cloth3",
         "leather", "bronze", "turquoise", "sunglass", "cape"]

sc = bpy.context.scene
sc.render.fps = FPS
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)


def import_glb(path, merge=False):
    """merge: join the vertices glTF splits along material edges, so the lips stay part of the face."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path, merge_vertices=merge)
    return [o for o in bpy.data.objects if o not in before]


def use_action(obj, act):
    if obj.animation_data is None:
        obj.animation_data_create()
    obj.animation_data.action = act
    if act is not None and hasattr(obj.animation_data, "action_slot") and len(getattr(act, "slots", [])):
        obj.animation_data.action_slot = act.slots[0]


class Source:
    """A motion library: its rest (world matrices by our bone names), its height, and every clip
    it has of `clips`, sampled once (world matrices by our names, per frame)."""

    def __init__(self, path, names, clips):
        objs = import_glb(path)
        arm = next(o for o in objs if o.type == "ARMATURE")
        mesh = next(o for o in objs if o.type == "MESH" and o.name.startswith("Mannequin"))
        for o in objs:
            o.hide_render = True
        self.arm, self.names = arm, names
        SW = arm.matrix_world.copy()
        rest = {n: SW @ arm.data.bones[t].matrix_local for n, t in names.items()}
        # facing -y as ours; a library facing +y is turned about z
        if (rest["LeftToes"].translation - rest["LeftFoot"].translation).y > 0:
            SW = Matrix.Rotation(math.pi, 4, "Z") @ SW
            rest = {n: SW @ arm.data.bones[t].matrix_local for n, t in names.items()}
            print("WADEE %s faces +y: turned" % os.path.basename(path))
        self.SW = SW
        self.rest = rest
        self.H = max((mesh.matrix_world @ v.co).z for v in mesh.data.vertices)
        self.hips0 = rest["Hips"].translation.copy()
        self.samples = {}
        for clip in clips:
            act = bpy.data.actions.get(clip)
            if act is None:
                print("WADEE clip %s: not in %s, skipped" % (clip, os.path.basename(path)))
                continue
            use_action(arm, act)
            f0, f1 = act.frame_range
            frames = [f0 + i for i in range(int(f1 - f0) + 1)]
            if f1 - frames[-1] > 1e-3:
                frames.append(f1)
            rows = []
            for f in frames:
                sc.frame_set(int(f), subframe=f - int(f))
                rows.append((f - f0, {n: (SW @ arm.pose.bones[t].matrix).copy() for n, t in names.items()}))
            self.samples[clip] = rows
            speeds = []
            for side in ("Left", "Right"):
                ys = [(t, r[side + "Toes"].translation) for t, r in rows]
                zmin = min(p.z for _, p in ys)
                for (t0, p0), (t1, p1) in zip(ys, ys[1:]):
                    if p0.z < zmin + 0.01 and p1.z < zmin + 0.01 and t1 > t0:
                        speeds.append((p1.y - p0.y) / ((t1 - t0) / FPS))
            speeds.sort()
            pace = speeds[len(speeds) // 2] if speeds else 0.0
            print("WADEE clip %-24s %5.2f s  planted foot %.2f m/s (library body %.2f m, hips %.3f)" % (
                clip, (f1 - f0) / FPS, pace, self.H, self.hips0.z))
        use_action(arm, None)


SRC1 = Source(UAL, NAMES1, CLIPS1)
SRC2 = Source(UAL2, NAMES2, CLIPS2)
SOURCES = [SRC1, SRC2]
H_SRC = SRC1.H


def bbox_mid(ps):
    return Vector(((min(p.x for p in ps) + max(p.x for p in ps)) / 2, (min(p.y for p in ps) + max(p.y for p in ps)) / 2,
                   (min(p.z for p in ps) + max(p.z for p in ps)) / 2))


def landmarks(vs):
    """Joint places on a Wadee body (arms down, facing -y), in metres. Heights of the trunk and legs
    follow the library body's proportions; sideways and front-back they come from slices of the body."""
    Hs = max(p.z for p in vs)
    kw = Hs / 1.745

    def sl(z, tol, keep):
        return [p for p in vs if abs(p.z - z) < tol and keep(p)]

    def ratio(name):
        return SRC1.rest[name].translation.z / H_SRC

    J = {}
    # trunk: the middle of each slice, a little toward the back
    for name, back in (("Hips", 0.1), ("Spine", 0.1), ("Chest", 0.1), ("UpperChest", 0.1), ("Neck", 0.0), ("Head", 0.0)):
        z = ratio(name) * Hs
        half = 0.07 * kw if name in ("Neck", "Head") else 0.15 * kw
        ps = sl(z, 0.008 * kw, lambda p: abs(p.x) < half)
        y0, y1 = min(p.y for p in ps), max(p.y for p in ps)
        J[name] = Vector((0.0, (y0 + y1) / 2 + back * (y1 - y0), z))
    J["HeadTop"] = Vector((0.0, J["Head"].y, Hs * 0.97))
    for side, s in (("Left", 1), ("Right", -1)):
        # legs: slices of one leg, clear of the hands
        def leg(z):
            return bbox_mid(sl(z, 0.008 * kw, lambda p: 0.0 < s * p.x < 0.19 * kw))
        hip = leg(0.43 * Hs)
        J[side + "UpperLeg"] = Vector((hip.x, hip.y, ratio("LeftUpperLeg") * Hs))
        J[side + "LowerLeg"] = leg(ratio("LeftLowerLeg") * Hs)
        J[side + "Foot"] = leg(ratio("LeftFoot") * Hs)
        foot = [p for p in vs if p.z < 0.035 * kw and s * p.x > 0]
        yf, yb = min(p.y for p in foot), max(p.y for p in foot)
        ball_y = yb + 0.72 * (yf - yb)
        ball = [p for p in foot if abs(p.y - ball_y) < 0.01 * kw]
        J[side + "Toes"] = Vector(((min(p.x for p in ball) + max(p.x for p in ball)) / 2, ball_y, 0.022 * kw))
        J[side + "ToesTip"] = Vector((J[side + "Toes"].x, yf, 0.015 * kw))
        # arms: the shoulder joint sits inside the deltoid; the hand is what hangs out past the hips
        zj = ratio("LeftUpperArm") * Hs
        top = sl(zj, 0.01 * kw, lambda p: s * p.x > 0)
        outer = max(s * p.x for p in top)
        hand = [p for p in vs if s * p.x > 0.2 * kw and 0.28 * Hs < p.z < 0.6 * Hs]
        tip = min(hand, key=lambda p: p.z)
        joint = Vector((s * (outer - 0.045 * kw), 0.0, zj))
        # the outer half of the upper arm, below the armpit, gives its middle front to back
        upper = [p for p in vs if zj - 0.16 * kw < p.z < zj - 0.10 * kw and s * p.x > outer - 0.05 * kw]
        joint.y = bbox_mid(upper).y

        def arm_slice(z):
            t = (joint.z - z) / (joint.z - tip.z)
            c = joint.lerp(tip, t)
            return [p for p in vs if abs(p.z - z) < 0.006 * kw and abs(p.x - c.x) < 0.055 * kw and abs(p.y - c.y) < 0.07 * kw]
        best = None
        z = tip.z + 0.13 * kw
        while z < tip.z + 0.25 * kw:
            ps = arm_slice(z)
            if len(ps) > 6:
                w = max(max(p.x for p in ps) - min(p.x for p in ps), max(p.y for p in ps) - min(p.y for p in ps))
                if best is None or w < best[0]:
                    best = (w, bbox_mid(ps))
            z += 0.005 * kw
        wrist = best[1]
        ez = joint.z + 0.56 * (wrist.z - joint.z)
        es = arm_slice(ez)
        elbow = bbox_mid(es) if len(es) > 6 else joint.lerp(wrist, 0.56)
        J[side + "UpperArm"], J[side + "LowerArm"], J[side + "Hand"] = joint, elbow, wrist
        J[side + "HandTip"] = wrist.lerp(tip, 0.55)
        uc = J["UpperChest"]
        neck_base = sl(ratio("LeftShoulder") * Hs, 0.008 * kw, lambda p: abs(p.x) < 0.06 * kw)
        y0 = min(p.y for p in neck_base)
        J[side + "Shoulder"] = Vector((s * 0.02 * kw, y0 + 0.35 * (uc.y - y0) * 2, ratio("LeftShoulder") * Hs))
    return J, Hs


def tail_of(name, J):
    kids = [n for n, _, p in BONES if p == name]
    if name == "Root":
        return Vector((0, 0.1, 0))
    if name == "Head":
        return J["HeadTop"]
    if name.endswith("Hand"):
        return J[name + "Tip"]
    if name.endswith("Toes"):
        return J[name + "Tip"]
    if name == "UpperChest":
        return J["Neck"]
    if name == "Hips":
        return J["Spine"]
    return J[kids[0]]


def slot_of(name):
    base = name.split(".")[0]
    for k, slot in enumerate(SLOTS):
        if base == slot or base.startswith(slot + "_"):
            return k
    raise ValueError("WADEE no palette slot for material %s" % name)


def rig(tag):
    objs = import_glb(os.path.join(IN, "wadee_%s.glb" % tag), merge=True)
    for o in objs:
        if o.type == "MESH":
            mw = o.matrix_world.copy()
            o.parent = None
            o.data.transform(mw)
            o.matrix_world = Matrix.Identity(4)
    parts = [o for o in objs if o.type == "MESH"]
    for o in objs:
        if o.type == "EMPTY":
            bpy.data.objects.remove(o)
    body = next(o for o in parts if o.name.startswith("body_"))
    vs = [v.co.copy() for v in body.data.vertices]
    J, Hs = landmarks(vs)
    print("WADEE %s height %.3f  shoulder %s elbow %s wrist %s knee %s" % (
        tag, Hs, tuple(round(c, 3) for c in J["LeftUpperArm"]), tuple(round(c, 3) for c in J["LeftLowerArm"]),
        tuple(round(c, 3) for c in J["LeftHand"]), tuple(round(c, 3) for c in J["LeftLowerLeg"])))

    ad = bpy.data.armatures.new("skeleton_" + tag)
    arm = bpy.data.objects.new("wadee_" + tag, ad)
    sc.collection.objects.link(arm)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, _, parent in BONES:
        eb = ad.edit_bones.new(name)
        eb.head = J[name] if name != "Root" else Vector()
        eb.tail = tail_of(name, J)
        if parent:
            eb.parent = ad.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    ad.bones["Root"].use_deform = False

    # the skin: Blender's heat weights
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    names = {g.index: g.name for g in body.vertex_groups}
    bw = [{names[g.group]: g.weight for g in v.groups if g.weight > 1e-4} for v in body.data.vertices]
    bare = [i for i, w in enumerate(bw) if not w]
    print("WADEE %s skin: %d of %d vertices unweighted" % (tag, len(bare), len(bw)))
    if bare:
        # heat weighting can miss a small island: give each such vertex its nearest weighted one's
        from mathutils.kdtree import KDTree
        kd = KDTree(len(bw) - len(bare))
        for i, w in enumerate(bw):
            if w:
                kd.insert(vs[i], i)
        kd.balance()
        for i in bare:
            _, j, _ = kd.find(vs[i])
            bw[i] = dict(bw[j])
            for g, x in bw[i].items():
                body.vertex_groups[g].add([i], x, "REPLACE")

    # everything else follows the skin under it, with a rule per kind of part. Clothes, hair and
    # anything that is not a ring round an arm take the skin of the body without its arms: a hand
    # hangs beside the belt and the skirt, and must not drag them.
    polys = [tuple(p.vertices) for p in body.data.polygons]
    arm_w = [sum(x for g, x in w.items() if g in ARM_BONES) for w in bw]
    trunk_polys = [p for p in polys if max(arm_w[i] for i in p) < 0.5]
    trees = {"all": (BVHTree.FromPolygons(vs, polys), polys),
             "trunk": (BVHTree.FromPolygons(vs, trunk_polys), trunk_polys)}
    arm_segs = [(J[s + a], J[s + b]) for s in ("Left", "Right")
                for a, b in (("UpperArm", "LowerArm"), ("LowerArm", "Hand"), ("Hand", "HandTip"))]

    def skin_at(p, which):
        tree, pl = trees[which]
        loc, _, fi, _ = tree.find_nearest(p)
        w, tot = {}, 0.0
        for vi in pl[fi]:
            k = 1.0 / max(1e-4, (vs[vi] - loc).length)
            tot += k
            for g, x in bw[vi].items():
                w[g] = w.get(g, 0.0) + x * k
        return {g: x / tot for g, x in w.items()}

    def seg_dist(p, a, b):
        ab = b - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / max(1e-9, ab.length_squared)))
        return (p - (a + ab * t)).length

    def islands(me):
        root = list(range(len(me.vertices)))

        def find(i):
            while root[i] != i:
                root[i] = root[root[i]]
                i = root[i]
            return i
        for e in me.edges:
            a, b = find(e.vertices[0]), find(e.vertices[1])
            if a != b:
                root[a] = b
        return [find(i) for i in range(len(me.vertices))]

    def smooth(me, wl, iters):
        nb = [[] for _ in me.vertices]
        for e in me.edges:
            a, b = e.vertices
            nb[a].append(b)
            nb[b].append(a)
        for _ in range(iters):
            new = []
            for i, w in enumerate(wl):
                if not nb[i]:
                    new.append(w)
                    continue
                acc = {g: x * 0.5 for g, x in w.items()}
                k = 0.5 / len(nb[i])
                for j in nb[i]:
                    for g, x in wl[j].items():
                        acc[g] = acc.get(g, 0.0) + x * k
                new.append(acc)
            wl = new
        return wl

    for o in parts:
        if o is body:
            continue
        kind = o.name.split("_")[0]
        me = o.data
        if kind in ("eye", "lash", "brows"):
            wl = [{"Head": 1.0} for _ in me.vertices]
        elif kind == "hair":
            wl = [{g: x for g, x in skin_at(v.co, "trunk").items() if g in HAIR_BONES} or {"Head": 1.0}
                  for v in me.vertices]
            wl = smooth(me, wl, 4)
        elif kind in ("top", "trim", "chest", "sash", "skirt", "cape", "clasp"):
            wl = []
            for v in me.vertices:
                w = skin_at(v.co, "trunk")
                legs = sum(x for g, x in w.items() if g in LEG_BONES)
                if legs:
                    w = {g: (x * 0.6 if g in LEG_BONES else x) for g, x in w.items()}
                    w["Hips"] = w.get("Hips", 0.0) + legs * 0.4
                wl.append(w)
            # smoothed along the cloth, so it stretches between the legs instead of tearing
            wl = smooth(me, wl, 40 if kind == "cape" else 30 if kind == "skirt" else 8)
        else:
            # jewellery and leather: a ring round an arm (its middle on the arm's bone) follows the
            # arm; a coin, a bead, a belt or a sandal follows the trunk and legs
            isl = islands(me)
            members = {}
            for v in me.vertices:
                members.setdefault(isl[v.index], []).append(v.co)
            on_arm = {r: min(seg_dist(sum(ps, Vector()) / len(ps), a, b) for a, b in arm_segs) < 0.035
                      for r, ps in members.items()}
            wl = [skin_at(v.co, "all" if on_arm[isl[v.index]] else "trunk") for v in me.vertices]
        vg = {}
        for v, w in zip(me.vertices, wl):
            w = {g: x for g, x in w.items() if x > 0.01}
            tot = sum(w.values())
            for g, x in w.items():
                vg.setdefault(g, []).append((v.index, x / tot))
        for g, lst in vg.items():
            grp = o.vertex_groups.new(name=g)
            for i, x in lst:
                grp.add([i], x, "REPLACE")
        m = o.modifiers.new("skeleton", "ARMATURE")
        m.object = arm
        o.parent = arm

    # the motions: each bone turns in the world as the library's bone does, measured from a pose of
    # the library's body matched to ours (its arms brought down to where ours hang)
    TB = {n: ad.bones[n].matrix_local.copy() for n, _, _ in BONES}

    def matched(src):
        ref = {}
        for name, _, parent in BONES:
            rest_s = src.rest[name].to_3x3().normalized()
            if parent:
                cur = ref[parent] @ src.rest[parent].to_3x3().normalized().inverted() @ rest_s
            else:
                cur = rest_s
            swing = cur.col[1].rotation_difference(TB[name].col[1].xyz.normalized()).to_matrix()
            ref[name] = swing @ cur
        corr = {n: ref[n].inverted() @ TB[n].to_3x3().normalized() for n, _, _ in BONES}
        return corr, TB["Hips"].translation.z / src.hips0.z
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    acts = []
    for src in SOURCES:
        C, lift = matched(src)
        for clip, rows in src.samples.items():
            act = bpy.data.actions.new("%s_%s" % (clip, tag))
            use_action(arm, act)
            last = {}
            for t, row in rows:
                M = {}
                for name, _, parent in BONES:
                    B = TB[name]
                    pb = arm.pose.bones[name]
                    if parent is None:
                        M[name] = B
                        continue
                    chain = M[parent] @ TB[parent].inverted() @ B
                    R = row[name].to_3x3().normalized() @ C[name]
                    pos = B.translation + (row[name].translation - src.hips0) * lift if name == "Hips" else chain.translation
                    M[name] = Matrix.Translation(pos) @ R.to_4x4()
                    basis = chain.inverted() @ M[name]
                    q = basis.to_quaternion()
                    if name in last:
                        q.make_compatible(last[name])
                    last[name] = q
                    pb.rotation_quaternion = q
                    pb.keyframe_insert("rotation_quaternion", frame=t, group=name)
                    if name == "Hips":
                        pb.location = basis.translation
                        pb.keyframe_insert("location", frame=t, group=name)
            acts.append((clip, act))
    use_action(arm, None)
    for clip, act in acts:
        tr = arm.animation_data.nla_tracks.new()
        tr.name = clip
        st = tr.strips.new(clip, 0, act)
        if hasattr(st, "action_slot") and len(getattr(act, "slots", [])):
            st.action_slot = act.slots[0]
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)

    # one mesh, one material: each part's faces point at their material's slot of the palette
    image = bpy.data.images.new("palette_" + tag, len(SLOTS), 1, alpha=True)
    px = [0.0] * (4 * len(SLOTS))
    for o in parts:
        for m in o.data.materials:
            k = slot_of(m.name)
            node = m.node_tree.nodes.get("Principled BSDF") if m.node_tree else None
            if node is not None:
                px[4 * k:4 * k + 4] = list(node.inputs["Base Color"].default_value)
    image.pixels = px
    image.pack()
    pal = bpy.data.materials.new("wadee_palette")
    pal.use_nodes = True
    bsdf = pal.node_tree.nodes.get("Principled BSDF")
    tex = pal.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Closest"
    pal.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.65
    for o in parts:
        me = o.data
        slots = [slot_of(m.name) if m else 0 for m in me.materials]
        while me.uv_layers:
            me.uv_layers.remove(me.uv_layers[0])
        uv = me.uv_layers.new(name="UVMap")
        for poly in me.polygons:
            u = (slots[poly.material_index] + 0.5) / len(SLOTS)
            for li in poly.loop_indices:
                uv.data[li].uv = (u, 0.5)
            poly.material_index = 0
        me.materials.clear()
        me.materials.append(pal)
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    body.name = "wadee_mesh_" + tag
    parts = [body]
    print("WADEE %s one mesh: %d triangles, %d groups" % (
        tag, sum(len(pg.vertices) - 2 for pg in body.data.polygons), len(body.vertex_groups)))

    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    for o in parts:
        o.select_set(True)
    path = os.path.join(OUT, "wadee_%s.glb" % tag)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=False,
                              export_animations=True, export_animation_mode="NLA_TRACKS", export_skins=True)
    print("WADEE wrote", path, "lift %.3f" % lift)
    return arm, parts, acts


rigged = [rig(t) for t in TAGS]


def sunstaff():
    """The Sunguard's sunstaff, 1.5 m: a bronze shaft along +z (Godot's +y), its grip at the origin,
    a sunglass orb in a bronze cage at the top. Writes sunstaff.glb."""
    coll = bpy.data.collections.new("sunstaff")
    sc.collection.children.link(coll)
    bronze = mat("staff_bronze", "#b5803e", 0.35, 0.8)
    glass = mat("sunglass", "#ffc94a", 0.2)
    node = glass.node_tree.nodes.get("Principled BSDF")
    node.inputs["Emission Color"].default_value = srgb("#ffb627")
    node.inputs["Emission Strength"].default_value = 3.0
    bb, bg = bmesh.new(), bmesh.new()
    tube(bb, [((0, 0, -0.50), 0.016, 0.016), ((0, 0, -0.46), 0.013, 0.013), ((0, 0, 0.80), 0.012, 0.012),
              ((0, 0, 0.90), 0.016, 0.016), ((0, 0, 0.93), 0.022, 0.022)], segs=12)
    for z in (-0.06, 0.0, 0.06, 0.62, 0.66):
        tube(bb, [((0, 0, z - 0.008), 0.016, 0.016), ((0, 0, z + 0.008), 0.016, 0.016)], segs=12)
    for k in range(4):
        a = math.pi / 2 * k + math.pi / 4
        rib = [((math.cos(a) * r, math.sin(a) * r, z), 0.005, 0.005)
               for r, z in ((0.020, 0.93), (0.050, 0.98), (0.058, 1.03), (0.045, 1.08), (0.010, 1.11))]
        tube(bb, rib, segs=6)
    ellipsoid(bg, (0, 0, 1.03), (0.040, 0.040, 0.052), segs=16, rings=10)
    parts = [obj_from(bb, "staff_bronze", bronze, coll), obj_from(bg, "staff_glass", glass, coll)]
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    path = os.path.join(OUT, "sunstaff.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True)
    print("WADEE wrote", path)


sunstaff()

if RENDER:
    import numpy as np
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
    gme = bpy.data.meshes.new("ground")
    bm.to_mesh(gme)
    g = bpy.data.objects.new("ground", gme)
    gme.materials.append(mat("sand", "#c99a68", 1.0))
    sc.collection.objects.link(g)
    cam_d = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam

    def shot(path, loc, target, lens, res):
        sc.render.resolution_x, sc.render.resolution_y = res
        cam_d.lens = lens
        cam.location = loc
        cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)

    def strip(name, paths):
        """One frame per row, the first at the top."""
        imgs = [bpy.data.images.load(p) for p in paths]
        w, h = imgs[0].size
        arr = [np.array(i.pixels[:]).reshape(h, w, 4) for i in imgs]
        out = np.concatenate(arr[::-1], axis=0)
        im = bpy.data.images.new(name, w, h * len(arr))
        im.pixels = out.ravel()
        im.filepath_raw = os.path.join(OUT, name + ".png")
        im.file_format = "PNG"
        im.save()
        for p in paths:
            os.remove(p)
        print("WADEE render", im.filepath_raw)

    # all in a row a metre apart, seen from the front; "side" turns each to show its profile.
    # One sheet per clip, one row per moment of its cycle.
    span = len(rigged) * 1.0 + 0.6
    for i, (arm, parts, acts) in enumerate(rigged):
        arm.location = (i * 1.0 - (len(rigged) - 1) * 0.5, 0, 0)
        arm.animation_data.use_nla = False
    for clip, n, view in (("Walk_Loop", 4, "side"), ("Farm_Watering", 3, "side"), ("Farm_Harvest", 3, "side"),
                          ("Sitting_Idle_Loop", 2, "side"), ("Fixing_Kneeling", 3, "side"), ("Consume", 3, "front"),
                          ("Idle_FoldArms_Loop", 2, "front"), ("Walk_Carry_Loop", 3, "side"), ("Yes", 2, "front"),
                          ("Spell_Simple_Shoot", 3, "front"), ("Death01", 3, "side")):
        paths = []
        for k in range(n):
            for arm, parts, acts in rigged:
                arm.rotation_euler = (0, 0, math.radians(90) if view == "side" else 0)
                act = dict(acts).get(clip)
                if act is None:
                    continue
                use_action(arm, act)
                f0, f1 = act.frame_range
            sc.frame_set(int(f0 + (f1 - f0) * k / n))
            p = os.path.join(OUT, "_tmp_%s_%d.png" % (clip, k))
            dist = span / 2 / math.tan(math.atan(18 / 35))
            shot(p, (0, -dist, 1.0), (0, 0, 0.95), 35, (1400, int(1400 * 2.3 / span)))
            paths.append(p)
        strip("blender_%s" % clip.lower(), paths)
