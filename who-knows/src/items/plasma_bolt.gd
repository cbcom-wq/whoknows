class_name PlasmaBolt
extends Node3D

## A plasma bolt (docs/superpowers/specs/2026-09-23-hands-and-items-design.md
## §9.2, §9.3). Not a physics body: each tick it casts a ray from where it is
## to where it will be, so it cannot pass through a 0.1 m wall at any speed.
## Where it lands it pushes whatever is loose, tells anything that listens
## (receive_hit), flashes, and is gone.

signal struck(point: Vector3, collider: Object)

const SPEED := 45.0
const LIFETIME := 1.5
## Newton-seconds given to whatever it hits.
const PUSH := 6.0
## interior_geometry | items.
const RAY_MASK := 2 | 32
const LENGTH := 0.4
const THICKNESS := 0.06
const LIGHT_ENERGY := 0.4
const LIGHT_RANGE := 2.5

static var _mesh: Mesh

var direction := Vector3.FORWARD
var exclude: Array[RID] = []
var source: Node = null
var age := 0.0

var _spent := false

func launch(from: Vector3, dir: Vector3) -> void:
	direction = dir.normalized()
	var up := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	global_transform = Transform3D(Basis.looking_at(direction, up), from)

func _ready() -> void:
	var body := MeshInstance3D.new()
	body.mesh = _shared_mesh()
	body.material_override = InteriorMaterials.glow()
	body.layers = InteriorKit.LAYER
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)
	var light := OmniLight3D.new()
	light.light_color = InteriorPalette.LIGHT_WARM
	light.light_energy = LIGHT_ENERGY
	light.omni_range = LIGHT_RANGE
	light.light_cull_mask = InteriorKit.LAYER
	light.shadow_enabled = false
	add_child(light)

func _physics_process(delta: float) -> void:
	if _spent:
		return
	age += delta
	if age >= LIFETIME:
		_spent = true
		queue_free()
		return
	var from := global_position
	var to := from + direction * SPEED * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, RAY_MASK, exclude)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		global_position = to
	else:
		impact(result)

## Lands: a push, the hook, a flash, and gone.
func impact(result: Dictionary) -> void:
	if _spent:
		return
	_spent = true
	var point: Vector3 = result["position"]
	var normal: Vector3 = result["normal"]
	var collider: Object = result.get("collider")
	var body := collider as RigidBody3D
	if body != null and not body.freeze:
		body.apply_impulse(direction * PUSH, point - body.global_position)
		body.sleeping = false
	if collider != null and collider.has_method(&"receive_hit"):
		collider.receive_hit(Hit.make(point, normal, direction, direction * PUSH, source))
	ImpactFlash.spawn(get_parent(), point, normal, ImpactFlash.Kind.IMPACT)
	struck.emit(point, collider)
	queue_free()

## A stretched glowing capsule along -z, shared by every bolt.
static func _shared_mesh() -> Mesh:
	if _mesh == null:
		var holder := Node3D.new()
		var kit := InteriorKit.new(holder)
		kit.bevel_box(InteriorKit.Batch.GLOW, Transform3D.IDENTITY, Vector3(THICKNESS, THICKNESS, LENGTH),
			THICKNESS * 0.4, InteriorKit.lit(InteriorPalette.PLASMA, 2.4))
		_mesh = kit.commit()[0].mesh
		holder.free()
	return _mesh
