class_name PhaserBolt
extends Bolt

## A turret's bolt (ship weapons spec §6): an elongated amber-gold streak
## carried at its ship's velocity, with a light trail behind it, always
## outside. Pooled (BoltPool): spent, its trail runs up to where it ended and
## it goes back to the pool, never freed. It is in Universe.EXTERIOR_SPACE
## from the moment it is made, flying or waiting.

## Outside, everything a turret can hit: exterior_hull | avatar | terrain |
## items | asteroids | npcs.
const RAY_MASK := 1 | 4 | BodyProxy.LAYER | Item.LAYER | AsteroidBody.LAYER | Npc.LAYER
const HEAD_ENERGY := 2.6
const TRAIL_ENERGY := 1.4
## The trail's thickness against the head's.
const TRAIL_THIN := 0.35
const LIGHT_ENERGY := 1.2

static var _head_mesh: Mesh
static var _trail_mesh: Mesh

var turret_kind := WeaponValues.LIGHT
var pool: BoltPool
var _head: MeshInstance3D
var _trail: MeshInstance3D
var _light: OmniLight3D
var _crack: AudioStreamPlayer3D
var _fading := 0.0
var _trail_end := 0.0

func _init() -> void:
	outside = true
	ray_mask = RAY_MASK
	kind = &"phaser"
	_spent = true

func _ready() -> void:
	add_to_group(Universe.EXTERIOR_SPACE)
	_head = _streak("Head", _shared(true))
	_trail = _streak("Trail", _shared(false))
	_light = OmniLight3D.new()
	_light.name = "Light"
	_light.light_color = SpacePalette.PHASER
	_light.light_energy = LIGHT_ENERGY
	_light.omni_range = WeaponValues.HEAVY_LIGHT_RANGE
	_light.light_cull_mask = PlasmaBolt.light_mask(true)
	_light.shadow_enabled = false
	_light.visible = false
	add_child(_light)
	_crack = AudioStreamPlayer3D.new()
	_crack.name = "Crack"
	_crack.bus = AudioBuses.SUIT
	_crack.max_distance = 200.0
	add_child(_crack)
	visible = false
	set_physics_process(false)

func _streak(streak_name: String, mesh: Mesh) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = streak_name
	m.mesh = mesh
	m.material_override = InteriorMaterials.glow()
	m.layers = Item.SPACE_LAYER
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m

## Readies it to fly from `from` along `dir` as a `p_kind` turret's bolt,
## carried at `p_carrier`, from `p_source`, through `p_exclude`.
func arm(p_kind: StringName, from: Vector3, dir: Vector3, p_carrier: Vector3, p_source: Node,
		p_exclude: Array[RID]) -> void:
	var s := WeaponValues.spec(p_kind)
	turret_kind = p_kind
	speed = s["speed"]
	lifetime = s["life"]
	damage = s["damage"]
	push = s["push"]
	flash_scale = s["flash"]
	carrier = p_carrier
	source = p_source
	exclude = p_exclude
	age = 0.0
	travelled = 0.0
	_fading = 0.0
	_spent = false
	launch(from, dir)
	var thick: float = s["thickness"]
	_head.scale = Vector3(thick, thick, s["length"])
	_head.visible = true
	_light.visible = p_kind == WeaponValues.HEAVY
	_draw_trail()
	visible = true
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	super(delta)
	if not _spent:
		_draw_trail()

## Where it lands, it stops: the trail runs up to that point.
func impact(result: Dictionary) -> void:
	if _spent:
		return
	global_position = result["position"]
	var crack := Synth.sound(&"phaser_crack")
	if crack != null and _crack != null and _crack.is_inside_tree():
		_crack.stream = crack
		_crack.play()
	super(result)

func _draw_trail() -> void:
	var length := minf(travelled, (carrier + direction * speed).length() * WeaponValues.TRAIL_TIME)
	var thick: float = WeaponValues.spec(turret_kind)["thickness"] * TRAIL_THIN
	_trail.scale = Vector3(thick, thick, maxf(length, 0.001))

func _done() -> void:
	_head.visible = false
	_light.visible = false
	_trail_end = _trail.scale.z
	_fading = 0.0

func _after(delta: float) -> void:
	_fading += delta
	var left := 1.0 - _fading / WeaponValues.TRAIL_TIME
	if left <= 0.0:
		_release()
		return
	var thick: float = WeaponValues.spec(turret_kind)["thickness"] * TRAIL_THIN * left
	_trail.scale = Vector3(thick, thick, maxf(_trail_end * left, 0.001))

func _release() -> void:
	set_physics_process(false)
	visible = false
	if pool != null:
		pool.release(self)
	else:
		queue_free()

## A unit streak from the node back along +z, 1 m long: the head brighter, the
## trail dimmer. Scaled per bolt, so one mesh serves every bolt and the shared
## glow material is never touched.
static func _shared(head: bool) -> Mesh:
	if head and _head_mesh != null:
		return _head_mesh
	if not head and _trail_mesh != null:
		return _trail_mesh
	var holder := Node3D.new()
	var kit := InteriorKit.new(holder)
	kit.bevel_box(InteriorKit.Batch.GLOW, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.5)), Vector3.ONE,
		0.3 if head else 0.45, InteriorKit.lit(SpacePalette.PHASER, HEAD_ENERGY if head else TRAIL_ENERGY))
	var mesh := kit.commit()[0].mesh
	holder.free()
	if head:
		_head_mesh = mesh
	else:
		_trail_mesh = mesh
	return mesh
