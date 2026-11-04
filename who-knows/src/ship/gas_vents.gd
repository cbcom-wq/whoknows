class_name GasVents
extends Node3D

## Gas venting from a badly hurt hull (docs/superpowers/specs/
## 2026-10-24-hostile-ships-design.md §7): a section under VENT_BELOW vents
## from a few of its most exposed blocks, more vents and thicker puffs as it
## falls, and a vent stops once its section is mended past half. Chunky puffs
## like the airlock's steam (style guide §3.4): built-in particles, the shared
## low-poly puff, flat lit, in SpacePalette.VENT_GAS, foggy never a whiteout.
##
## The floating origin (CLAUDE.md): the puffs are in the emitter's own frame,
## on the hull, so they ride it through a shift and never hold one -- a
## venting ship would otherwise hold the shift for as long as it vents.

const VENT_BELOW := 0.5
const MOST_PER_SECTION := 4
const PUFFS := 12
const LIFETIME := 1.6
## How fast a puff leaves the hull, m/s, at strength 0 and 1.
const SPEED := Vector2(0.8, 2.4)
## The share of PUFFS out at strength 0; all of them at 1.
const THINNEST := 0.35
## A puff grows from GROW_FROM to between these times its size over its life,
## at strength 0 and 1.
const GROW_FROM := 0.4
const GROW_TO := Vector2(1.4, 2.6)
## How opaque a puff is at its thickest.
const PEAK := 0.5
const SPREAD := 25.0
## The hull's own layer and the world's, as DamageShow's sparks.
const LAYERS := ExteriorBuilder.OWN_HULL_LAYER | 1

## coord -> {emitter, normal, strength}
var _vents: Dictionary = {}
static var _puff: Mesh
static var _ramp: GradientTexture1D

## The vents `damage` calls for on `grid` now: for each section under
## VENT_BELOW, from 1 just under it to MOST_PER_SECTION at nothing, of its
## most exposed blocks still there with a face onto space. Each is {coord,
## normal (the face it vents from, in hull axes), strength 0..1 (how far its
## section is below VENT_BELOW)}. A centre-line block vents once.
static func vents(damage: ShipDamage, grid: ShipGrid) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lost := damage.lost()
	var centre := Vector3.ZERO
	for coord: Vector3i in damage.sections_of:
		centre += Vector3(coord)
	if not damage.sections_of.is_empty():
		centre /= damage.sections_of.size()
	var taken := {}
	for id in ShipDamage.SECTIONS:
		var h := damage.health(id)
		if h >= VENT_BELOW:
			continue
		var strength := clampf((VENT_BELOW - h) / VENT_BELOW, 0.0, 1.0)
		var want := roundi(lerpf(1.0, MOST_PER_SECTION, strength))
		var open := {}
		for coord: Vector3i in damage.sections_of:
			if taken.has(coord) or not (damage.sections_of[coord] as Array).has(id):
				continue
			if not grid.has_block(coord) or lost.has(coord):
				continue
			var face: Variant = _outward_face(grid, lost, coord, centre)
			if face != null:
				open[coord] = face
		var order: Array = open.keys()
		order.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			var ea: float = damage.exposure[a]
			var eb: float = damage.exposure[b]
			return ea > eb if ea != eb else ShipDamage._key(a) < ShipDamage._key(b))
		for i in mini(want, order.size()):
			var coord: Vector3i = order[i]
			taken[coord] = true
			out.append({"coord": coord, "normal": open[coord], "strength": strength})
	return out

## Of the block's faces onto space (nothing there, or a piece lost), the one
## facing most away from `centre`, or null when it has none.
static func _outward_face(grid: ShipGrid, lost: Dictionary, coord: Vector3i, centre: Vector3) -> Variant:
	var away := Vector3(coord) - centre
	var best: Variant = null
	var best_dot := -INF
	for n in ShipGrid.FACE_OFFSETS:
		if grid.has_block(coord + n) and not lost.has(coord + n):
			continue
		var d := away.dot(Vector3(n))
		if d > best_dot:
			best_dot = d
			best = n
	return best

## Makes or retunes one emitter per vent in `list` (vents()), and stops any
## no longer in it.
func sync(list: Array[Dictionary]) -> void:
	var keep := {}
	for vent in list:
		var coord: Vector3i = vent["coord"]
		var normal: Vector3i = vent["normal"]
		keep[coord] = true
		var e: Dictionary = _vents.get(coord, {})
		if not e.is_empty() and e["normal"] != normal:
			_stop(coord)
			e = {}
		if e.is_empty():
			e = {"emitter": _emitter(coord, normal), "normal": normal, "strength": -1.0}
			_vents[coord] = e
		if e["strength"] != vent["strength"]:
			e["strength"] = vent["strength"]
			_tune(e["emitter"], e["strength"])
	for coord: Vector3i in _vents.keys():
		if not keep.has(coord):
			_stop(coord)

## The vents' emitters, for tests and probes.
func emitters() -> Array[GPUParticles3D]:
	var out: Array[GPUParticles3D] = []
	for e: Dictionary in _vents.values():
		out.append(e["emitter"])
	return out

func _stop(coord: Vector3i) -> void:
	var emitter: GPUParticles3D = _vents[coord]["emitter"]
	_vents.erase(coord)
	if is_instance_valid(emitter):
		emitter.queue_free()

func _emitter(coord: Vector3i, normal: Vector3i) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Vent"
	p.amount = PUFFS
	p.lifetime = LIFETIME
	p.randomness = 0.3
	p.local_coords = true
	p.layers = LAYERS
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.draw_pass_1 = _mesh()
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 0, -1)
	m.spread = SPREAD
	m.gravity = Vector3.ZERO
	m.damping_min = 0.6
	m.damping_max = 1.2
	m.scale_min = 0.7
	m.scale_max = 1.0
	m.color_ramp = _fade()
	m.angle_min = 0.0
	m.angle_max = 360.0
	p.process_material = m
	p.visibility_aabb = AABB(Vector3(-5, -5, -8), Vector3(10, 10, 10))
	var out := Vector3(normal)
	var up := Vector3.UP if absf(out.dot(Vector3.UP)) < 0.9 else Vector3.BACK
	p.transform = Transform3D(Basis.looking_at(out, up),
		ShipGrid.cell_center(coord) + out * ShipGrid.CELL_SIZE * 0.5)
	add_child(p)
	p.emitting = true
	return p

## More puffs, faster and bigger, the stronger the vent.
static func _tune(p: GPUParticles3D, strength: float) -> void:
	p.amount_ratio = lerpf(THINNEST, 1.0, strength)
	var m := p.process_material as ParticleProcessMaterial
	var speed := lerpf(SPEED.x, SPEED.y, strength)
	m.initial_velocity_min = speed * 0.7
	m.initial_velocity_max = speed
	m.scale_curve = Puffs.grow(GROW_FROM, lerpf(GROW_TO.x, GROW_TO.y, strength))

## The shared puff, flat lit, in the vent gas colour.
static func _mesh() -> Mesh:
	if _puff == null:
		var m := Puffs.mesh(true)
		(m.material as StandardMaterial3D).albedo_color = SpacePalette.VENT_GAS
		_puff = m
	return _puff

## Fades in, holds, fades out; untinted, so the puff's own colour shows.
static func _fade() -> GradientTexture1D:
	if _ramp == null:
		var clear := SpacePalette.UNTINTED
		clear.a = 0.0
		var thick := SpacePalette.UNTINTED
		thick.a = PEAK
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.15, 0.55, 1.0])
		g.colors = PackedColorArray([clear, thick, thick, clear])
		_ramp = GradientTexture1D.new()
		_ramp.gradient = g
	return _ramp
