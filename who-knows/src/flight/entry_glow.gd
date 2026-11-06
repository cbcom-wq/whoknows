class_name EntryGlow
extends Node3D

## The glow at a fast entry's bow and the buffet in its cabin (desert-world
## spec §6.5, call 6): no heat damage, and never stronger than a light hit.
##
## A dome of added light, pole along the hull's velocity, scaled to the cell
## box across that direction and set just ahead of the box along it. Its colour
## climbs from SpacePalette.ENTRY_LOW to ENTRY_HIGH with the heat, its vertex
## alpha fades the rim. While hot, it also emits `buffet` on a fixed beat, no
## stronger than a light bolt's felt hit.
##
## The floating origin (CLAUDE.md): a child of the hull, which is in
## Universe.EXTERIOR_SPACE; it remembers no engine position.

const GLOW_ALPHA := 0.55
const CAP_SEGMENTS := 24
const CAP_RINGS := 6
const CAP_MARGIN := 0.6
const BUFFET_EVERY := 0.12
const SEED := 0xE7
const SHOW_ABOVE := 0.01

signal buffet(strength: float, from: Vector3)

var _flight: FlightComputer
var _hull: RigidBody3D
var _cap: MeshInstance3D
var _material: StandardMaterial3D
var _box := AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
var _rng := RandomNumberGenerator.new()
var _since := 0.0
## The last heading seen, kept for a moment when the velocity is all but nil.
var _dir := Vector3.FORWARD

## A unit dome bulging to -Z; vertex alpha is cos^2 of the angle from its pole
## (0, 0, -1): 1 at the pole, 0 at the rim.
static func cap_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for r in CAP_RINGS + 1:
		var theta := (PI / 2.0) * float(r) / float(CAP_RINGS)
		var a := cos(theta) * cos(theta)
		for s in CAP_SEGMENTS:
			var phi := TAU * float(s) / float(CAP_SEGMENTS)
			verts.append(Vector3(sin(theta) * cos(phi), sin(theta) * sin(phi), -cos(theta)))
			var tint := SpacePalette.UNTINTED
			tint.a = a
			cols.append(tint)
	for r in CAP_RINGS:
		for s in CAP_SEGMENTS:
			var n := (s + 1) % CAP_SEGMENTS
			var a0 := r * CAP_SEGMENTS + s
			var a1 := r * CAP_SEGMENTS + n
			var b0 := (r + 1) * CAP_SEGMENTS + s
			var b1 := (r + 1) * CAP_SEGMENTS + n
			idx.append_array([a0, b0, a1, a1, b0, b1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## The hardest the buffet ever gets: a light hit's strength.
static func buffet_most() -> float:
	return HitFeel.strength(WeaponValues.spec(WeaponValues.LIGHT)["damage"])

func setup(flight: FlightComputer, hull: RigidBody3D) -> void:
	_flight = flight
	_hull = hull
	_rng.seed = SEED
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.vertex_color_use_as_albedo = true
	_cap = MeshInstance3D.new()
	_cap.name = "Cap"
	_cap.mesh = cap_mesh()
	_cap.material_override = _material
	_cap.layers = 1
	_cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cap.visible = false
	add_child(_cap)

func fit(box: AABB) -> void:
	_box = box

func _physics_process(delta: float) -> void:
	if _flight == null or _hull == null:
		return
	var h := _flight.entry_heat()
	var v := _hull.global_transform.basis.inverse() * _hull.linear_velocity
	if h <= SHOW_ABOVE:
		_cap.visible = false
		_since = 0.0
		return
	if v.length() > 0.01:
		_dir = v.normalized()
	var dir := _dir
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	var back := -dir
	var x := up.cross(back).normalized()
	var y := back.cross(x)
	var half := _box.size / 2.0
	var along := absf(dir.x) * half.x + absf(dir.y) * half.y + absf(dir.z) * half.z
	# The box's reach across the direction, on each of the cap's own axes.
	var across_x := absf(x.x) * half.x + absf(x.y) * half.y + absf(x.z) * half.z
	var across_y := absf(y.x) * half.x + absf(y.y) * half.y + absf(y.z) * half.z
	var basis := Basis(x * across_x, y * across_y, back * (along + CAP_MARGIN))
	_cap.transform = Transform3D(basis, _box.get_center() + dir * (along + CAP_MARGIN))
	var c := SpacePalette.ENTRY_LOW.lerp(SpacePalette.ENTRY_HIGH, h)
	c.a = GLOW_ALPHA * h
	_material.albedo_color = c
	_cap.visible = true
	_since += delta
	if _since >= BUFFET_EVERY:
		_since = 0.0
		var from := Vector3(_rng.randfn(), _rng.randfn(), _rng.randfn())
		from = from.normalized() if from.length() > 0.001 else Vector3.UP
		buffet.emit(buffet_most() * h, from)
