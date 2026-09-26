class_name QuantumShow
extends Node3D

## The quantum machine's show (docs/superpowers/specs/
## 2026-09-24-quantum-energy-design.md §7.5): violet sparkles in the bay
## while it converts or makes, a bead of light running along the conduit to
## the core, a short warm flash at the bay, and the item shrinking to a point
## or swelling out of one. It only shows what it is told -- the plant drives
## it from the machine's cues -- and keeps no clock but the bead's and the
## flash's.
##
## Built from the kit, engine particles and plain materials: no new shader
## (style guide §2.5). The item's shrink and swell are by scale, as
## ImpactFlash's are, so no shared material is ever modified.
##
## Knows nothing about ships, like AirlockShow: it takes the bay's frame, the
## conduit's path and a render layer, all in its parent's space.

const SPARKLES := 24
const SPARKLE_LIFETIME := 0.8
## The sparkles start anywhere within this of the bay's centre.
const SPARKLE_SPREAD := 0.2
const SPARKLE_SIZE := Vector2(0.035, 0.065)
## How bright the sparkles' violet is, above the unshaded 1.0, so the
## interior camera's glow blooms them like the glow batch.
const SPARKLE_ENERGY := 1.8
## Sparkles nearer the camera than this fade away, so one drifting past your
## face never fills the screen.
const SPARKLE_FADE := Vector2(0.08, 0.3)
## The bead: a chunky glowing gem -- two bevelled cubes, one turned in the
## other -- well proud of the conduit it runs along.
const BEAD_SIZE := 0.13
const BEAD_ENERGY := 2.4
## The flash (spec §7.5): a warm light at the bay's mouth, fading from this
## energy over FLASH_TIME.
const FLASH_ENERGY := 0.6
const FLASH_TIME := 0.2
const FLASH_RANGE := 1.8
const FLASH_OUT := 0.35
## Where shrinking ends and swelling starts: a point, never zero, so the
## item's basis stays invertible.
const POINT := 0.001

var _sparkles: GPUParticles3D
var _bead: Node3D
var _flash: OmniLight3D
var _path := PackedVector3Array()
var _bead_time := 0.0
var _bead_left := 0.0
var _flash_left := 0.0

## Builds the show: the sparkles at `bay_frame` (origin at the bay's centre,
## +y up), the bead on `conduit_path` (from the machine to the core), both in
## the parent's space, on render layer `layer`. Call once, before it enters
## the tree.
func setup(bay_frame: Transform3D, conduit_path: PackedVector3Array, layer: int) -> void:
	name = "QuantumShow"
	_path = conduit_path
	_sparkles = GPUParticles3D.new()
	_sparkles.name = "Sparkles"
	_sparkles.amount = SPARKLES
	_sparkles.lifetime = SPARKLE_LIFETIME
	_sparkles.draw_pass_1 = _sparkle_mesh()
	_sparkles.process_material = _sparkle_process()
	_sparkles.layers = layer
	_sparkles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sparkles.emitting = false
	_sparkles.visibility_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	_sparkles.transform = bay_frame
	add_child(_sparkles)

	_bead = Node3D.new()
	_bead.name = "Bead"
	_bead.visible = false
	add_child(_bead)
	var kit := InteriorKit.new(_bead)
	kit.layer = layer
	kit.light_mask = layer
	kit.bevel_box(InteriorKit.Batch.GLOW, Transform3D.IDENTITY, Vector3.ONE * BEAD_SIZE, BEAD_SIZE * 0.3,
		InteriorKit.lit(InteriorPalette.QUANTUM, BEAD_ENERGY))
	kit.bevel_box(InteriorKit.Batch.GLOW, Transform3D(Basis(Vector3(1, 1, 0).normalized(), PI * 0.25), Vector3.ZERO),
		Vector3.ONE * BEAD_SIZE * 0.85, BEAD_SIZE * 0.25, InteriorKit.lit(InteriorPalette.QUANTUM, BEAD_ENERGY))
	kit.commit()

	_flash = OmniLight3D.new()
	_flash.name = "Flash"
	_flash.light_color = InteriorPalette.LIGHT_WARM
	_flash.light_energy = 0.0
	_flash.omni_range = FLASH_RANGE
	_flash.light_cull_mask = layer
	_flash.shadow_enabled = false
	_flash.visible = false
	_flash.position = bay_frame * Vector3(0, 0, FLASH_OUT)
	add_child(_flash)

## Sparkles in the bay, on or off.
func sparkle(on: bool) -> void:
	if _sparkles.emitting != on:
		_sparkles.emitting = on

func is_sparkling() -> bool:
	return _sparkles.emitting

## Sends the bead from the machine along the conduit to its far end over
## `duration` seconds.
func run_bead(duration: float) -> void:
	if _path.size() < 2:
		return
	_bead_time = maxf(duration, 0.001)
	_bead_left = _bead_time
	_bead.position = _path[0]
	_bead.visible = true

func bead_running() -> bool:
	return _bead.visible

## Where the bead is now, in the parent's space.
func bead_position() -> Vector3:
	return _bead.position

## A short warm flash at the bay's mouth.
func flash() -> void:
	_flash_left = FLASH_TIME
	_flash.light_energy = FLASH_ENERGY
	_flash.visible = true

func flashing() -> bool:
	return _flash.visible

## Shows `item` `t` of the way (0..1) from whole to a point, by scale.
static func shrink(item: Item, t: float) -> void:
	var u := clampf(t, 0.0, 1.0)
	_scale_look(item, maxf(1.0 - u * u, POINT))

## Shows `item` `t` of the way (0..1) from a point to whole, by scale.
static func swell(item: Item, t: float) -> void:
	var u := clampf(t, 0.0, 1.0)
	_scale_look(item, maxf(1.0 - (1.0 - u) * (1.0 - u), POINT))

## Scales everything the item shows -- its look, and whatever its use hangs
## on it (a datapad's screen) -- about the item's centre. Never its collider,
## and never the body itself, whose scale physics does not keep.
static func _scale_look(item: Item, k: float) -> void:
	for child in item.get_children():
		if child is Node3D and not child is CollisionShape3D:
			(child as Node3D).scale = Vector3.ONE * k

## The point `u` (0..1) of the way along the path, by length.
func point_along(u: float) -> Vector3:
	if _path.is_empty():
		return Vector3.ZERO
	var total := 0.0
	for i in range(1, _path.size()):
		total += _path[i - 1].distance_to(_path[i])
	var want := clampf(u, 0.0, 1.0) * total
	for i in range(1, _path.size()):
		var leg := _path[i - 1].distance_to(_path[i])
		if want <= leg and leg > 0.0:
			return _path[i - 1].lerp(_path[i], want / leg)
		want -= leg
	return _path[_path.size() - 1]

func _process(delta: float) -> void:
	if _bead.visible:
		_bead_left -= delta
		if _bead_left <= 0.0:
			_bead.visible = false
		else:
			var u := 1.0 - _bead_left / _bead_time
			_bead.position = point_along(u * u * (3.0 - 2.0 * u))
	if _flash.visible:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_flash.visible = false
			_flash.light_energy = 0.0
		else:
			_flash.light_energy = FLASH_ENERGY * _flash_left / FLASH_TIME

## A chunky low-poly puff in violet, unshaded and bright enough to bloom,
## fading out near the camera: Puffs' shape in the machine's colour.
static func _sparkle_mesh() -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = Puffs.SEGMENTS
	m.rings = Puffs.RINGS
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	material.distance_fade_min_distance = SPARKLE_FADE.x
	material.distance_fade_max_distance = SPARKLE_FADE.y
	m.material = material
	return m

## Sparkles drifting gently up out of the bay, shrinking and fading as they
## go, in QUANTUM raised past 1.0 for the bloom.
static func _sparkle_process() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = SPARKLE_SPREAD
	m.direction = Vector3(0, 1, 0)
	m.spread = 60.0
	m.initial_velocity_min = 0.05
	m.initial_velocity_max = 0.25
	m.gravity = Vector3.ZERO
	m.damping_min = 0.1
	m.damping_max = 0.3
	m.scale_min = SPARKLE_SIZE.x
	m.scale_max = SPARKLE_SIZE.y
	m.scale_curve = Puffs.grow(1.0, 0.35)
	m.angle_min = 0.0
	m.angle_max = 360.0
	var glow := InteriorPalette.QUANTUM.srgb_to_linear() * SPARKLE_ENERGY
	var clear := glow
	clear.a = 0.0
	var bright := glow
	bright.a = 1.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.6, 1.0])
	g.colors = PackedColorArray([clear, bright, bright, clear])
	var ramp := GradientTexture1D.new()
	ramp.gradient = g
	ramp.use_hdr = true
	m.color_ramp = ramp
	return m
