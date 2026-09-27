class_name SkitterLook
extends Node3D

## The skitter as you see it (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §13.4, §22.5): a plated, domed back of
## big flat facets in its rock's colour leaning toward violet, with two
## lavender patches from grazing crystal, a squat head, two pale eyes, and six
## two-segment legs set by a tripod gait. Flat-shaded, no texture, colours from
## SpacePalette only; it fades in with distance as the rocks do. Silent.

const HIPS: Array[Vector3] = [Vector3(-0.2, 0.14, -0.2), Vector3(0.2, 0.14, -0.2), Vector3(-0.22, 0.14, 0.0),
	Vector3(0.22, 0.14, 0.0), Vector3(-0.2, 0.14, 0.2), Vector3(0.2, 0.14, 0.2)]
const FEET: Array[Vector3] = [Vector3(-0.36, 0.0, -0.3), Vector3(0.36, 0.0, -0.3), Vector3(-0.4, 0.0, 0.0),
	Vector3(0.4, 0.0, 0.0), Vector3(-0.36, 0.0, 0.3), Vector3(0.36, 0.0, 0.3)]
## Short, stubby legs: a squat grazer, not a spider.
const THIGH := 0.15
const SHIN := 0.17
const LEG_THICKNESS := 0.055
const FLATTEN := 0.04
const REST_DROP := 0.08
const EASE := 10.0
const PUFF_TIME := 0.6
## Farther than this from the camera, metres, its legs are posed every
## FAR_EVERY frames.
const LEGS_DETAILED := 100.0
const FAR_EVERY := 6

var action: StringName = &""
var gait: LeggedGait
var fade := Vector2(250, 300)
var _shell: Node3D
var _head: Node3D
var _segments: Array[MeshInstance3D] = []
var _body_material: StandardMaterial3D
var _leg_material: StandardMaterial3D
var _bob := 0.0
var _frame := 0
var _skipped := 0.0

## Builds it in `colour` (its rock's), with `variety` picking which facet
## carries the lavender.
func build(variety: float, colour: Color, p_fade: Vector2) -> void:
	fade = p_fade
	_body_material = _material(SpacePalette.UNTINTED, true)
	_leg_material = _material(SpacePalette.scree(colour), false)
	_shell = Node3D.new()
	_shell.name = "Shell"
	add_child(_shell)
	var shell := MeshInstance3D.new()
	shell.name = "Back"
	shell.mesh = back_mesh(colour, variety)
	shell.material_override = _body_material
	_shell.add_child(shell)
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 0.17, -0.36)
	_shell.add_child(_head)
	var head := MeshInstance3D.new()
	head.name = "Face"
	head.mesh = head_mesh(colour)
	head.material_override = _body_material
	_head.add_child(head)
	var leg := BoxMesh.new()
	leg.size = Vector3(LEG_THICKNESS, LEG_THICKNESS, 1.0)
	for i in HIPS.size() * 2:
		var seg := MeshInstance3D.new()
		seg.name = "Leg%d" % i
		seg.mesh = leg
		seg.material_override = _leg_material
		add_child(seg)
		_segments.append(seg)
	gait = LeggedGait.new(FEET)
	_pose_legs(_resting_feet())

func _material(albedo: Color, vertex: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = vertex
	m.albedo_color = albedo
	m.roughness = 1.0
	if fade.y > 0.0:
		# Reversed (min beyond max): whole within fade.x, gone past fade.y.
		m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
		m.distance_fade_min_distance = fade.y
		m.distance_fade_max_distance = fade.x
	return m

## What it is doing: &"freeze" flattens it and stills its legs; &"graze" bobs
## its head; &"rest" lowers it and folds its legs; &"puff" is a jet of gas.
func act(p_action: StringName) -> void:
	if p_action == &"puff":
		puff()
		return
	action = p_action

func _process(delta: float) -> void:
	var npc := get_parent() as Npc
	if npc == null:
		return
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var far := cam.global_position.distance_to(global_position) if cam != null else INF
	# Past its fade nobody can see it; far off, its legs are a few pixels and
	# can be posed now and then.
	if fade.y > 0.0 and far > fade.y:
		return
	_skipped += delta
	_frame += 1
	if far > LEGS_DETAILED and _frame % FAR_EVERY != 0:
		return
	var drifting := npc.active is ZeroGDrift
	var speed := npc.velocity.length()
	var near := far < LeggedGait.NEAR
	pose(_skipped, speed, drifting, npc.get_world_3d().direct_space_state if near else null, [npc.get_rid()])
	_skipped = 0.0

## Moves its parts for `delta` seconds at `speed`.
func pose(delta: float, speed: float, drifting: bool, space: PhysicsDirectSpaceState3D, exclude: Array[RID]) -> void:
	var low := -FLATTEN if action == &"freeze" else (-REST_DROP if action == &"rest" else 0.0)
	_shell.position.y = lerpf(_shell.position.y, low, minf(EASE * delta, 1.0))
	_bob = _bob + delta * 9.0 if action == &"graze" else 0.0
	_head.rotation.x = sin(_bob) * 0.3 - (0.15 if action == &"graze" else 0.0)
	var feet: Array[Vector3]
	if drifting:
		feet = _tucked()
	elif action == &"freeze" or action == &"rest":
		feet = _resting_feet()
	else:
		var world := gait.update(global_transform, speed, delta, space, exclude, AsteroidBody.LAYER)
		feet = []
		var to_local := global_transform.affine_inverse()
		for f in world:
			feet.append(to_local * f)
	_pose_legs(feet)

func _resting_feet() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for f in FEET:
		out.append(f * Vector3(0.9, 1.0, 0.9) if action == &"rest" else f)
	return out

func _tucked() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in FEET.size():
		out.append(HIPS[i] * Vector3(1.3, 0.0, 1.1) + Vector3(0, 0.02, 0))
	return out

## Bends each two-segment leg from its hip to its foot (body frame), the knee
## up and out.
func _pose_legs(feet: Array[Vector3]) -> void:
	for i in HIPS.size():
		var hip := HIPS[i] + Vector3(0, _shell.position.y, 0)
		# A foot left behind by a bolting body is drawn at the end of its reach:
		# legs never stretch.
		var foot := feet[i]
		var reach := (THIGH + SHIN) * 0.97
		if hip.distance_to(foot) > reach:
			foot = hip + (foot - hip).normalized() * reach
		var knee := knee_for(hip, foot, THIGH, SHIN)
		_segment(_segments[i * 2], hip, knee)
		_segment(_segments[i * 2 + 1], knee, foot)

## Where the knee goes for a leg from `hip` to `foot`: bent up, in the plane
## through both and the body's up.
static func knee_for(hip: Vector3, foot: Vector3, a: float, b: float) -> Vector3:
	var to := foot - hip
	var d := clampf(to.length(), 0.01, a + b - 0.001)
	var dir := to.normalized()
	var out := Vector3(dir.x, 0.0, dir.z)
	var bend := (Vector3.UP - dir * dir.dot(Vector3.UP)) + out * 0.3
	bend = (bend - dir * bend.dot(dir)).normalized()
	var cos_a := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	return hip + dir * a * cos_a + bend * a * sqrt(1.0 - cos_a * cos_a)

func _segment(seg: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var along := to - from
	var length := along.length()
	if length < 0.001:
		return
	var up := Vector3.UP if absf(along.normalized().y) < 0.95 else Vector3.RIGHT
	var basis := Basis.looking_at(along, up)
	seg.transform = Transform3D(basis.scaled_local(Vector3(1, 1, length)), (from + to) * 0.5)

## A small jet of gas, from its rear, gone in a moment.
func puff() -> void:
	if not is_inside_tree():
		return
	var p := MeshInstance3D.new()
	p.name = "Puff"
	p.mesh = Puffs.mesh(false)
	p.position = Vector3(0, 0.2, 0.45)
	p.scale = Vector3.ONE * 0.15
	add_child(p)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(p, "scale", Vector3.ONE * 0.5, PUFF_TIME)
	t.tween_property(p, "transparency", 1.0, PUFF_TIME)
	t.chain().tween_callback(p.queue_free)

## The back: a low dome of big facets in the rock's colour leaning violet,
## each facet one of three shades, two of them lavender, and a darker
## underside. Built at 0.85 m long; NpcLooks scales it to the species.
static func back_mesh(colour: Color, variety: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var low: Array[Vector3] = []
	var high: Array[Vector3] = []
	for i in 6:
		var a := TAU * float(i) / 6.0 + PI / 6.0
		low.append(Vector3(sin(a) * 0.24, 0.12, cos(a) * 0.38))
		high.append(Vector3(sin(a) * 0.15, 0.3, cos(a) * 0.25))
	var apex := Vector3(0, 0.37, 0.02)
	var patch := int(variety * 6.0) % 6
	var back := SpacePalette.skitter(colour)
	for i in 6:
		var j := (i + 1) % 6
		var shade := SpacePalette.shade(back, i % SpacePalette.SHADES.size())
		_tri(st, low[i], low[j], high[j], shade)
		_tri(st, low[i], high[j], high[i], shade)
		var crystal := i == patch or i == (patch + 3) % 6
		_tri(st, high[i], high[j], apex, SpacePalette.CRYSTAL if crystal else SpacePalette.shade(back, (i + 1) % 3))
		_tri(st, low[j], low[i], Vector3(0, 0.1, 0), SpacePalette.scree(colour))
	return st.commit()

## A squat head: a wedge in the underside's shade, with two pale eyes.
static func head_mesh(colour: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dark := SpacePalette.shade(colour, 0)
	_box(st, Vector3(0, 0, 0), Vector3(0.2, 0.11, 0.14), dark)
	for side in [-1.0, 1.0]:
		_box(st, Vector3(side * 0.055, 0.025, -0.075), Vector3(0.035, 0.03, 0.02), SpacePalette.SKITTER_EYE)
	return st.commit()

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	# Godot's front faces wind clockwise seen from the front.
	var n := (c - a).cross(b - a).normalized()
	if n.dot((a + b + c) / 3.0 - Vector3(0, 0.15, 0)) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	for p in [a, b, c]:
		st.set_color(colour)
		st.set_normal(n)
		st.add_vertex(p)

static func _box(st: SurfaceTool, centre: Vector3, size: Vector3, colour: Color) -> void:
	var h := size * 0.5
	var c: Array[Vector3] = []
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				c.append(centre + Vector3(x * h.x, y * h.y, z * h.z))
	var faces := [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
	for f in faces:
		var a: Vector3 = c[f[0]]
		var b: Vector3 = c[f[1]]
		var cc: Vector3 = c[f[2]]
		var d: Vector3 = c[f[3]]
		var n := (cc - a).cross(b - a).normalized()
		if n.dot((a + cc) * 0.5 - centre) < 0.0:
			n = -n
			for p in [a, d, cc, a, cc, b]:
				st.set_color(colour)
				st.set_normal(n)
				st.add_vertex(p)
		else:
			for p in [a, b, cc, a, cc, d]:
				st.set_color(colour)
				st.set_normal(n)
				st.add_vertex(p)
