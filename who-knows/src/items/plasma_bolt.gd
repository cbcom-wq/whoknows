class_name PlasmaBolt
extends Node3D

## A plasma bolt (docs/superpowers/specs/2026-09-23-hands-and-items-design.md
## §9.2, §9.3). Not a physics body: each tick it casts a ray from where it is
## to where it will be, so it cannot pass through a 0.1 m wall at any speed.
## Where it lands it pushes whatever is loose, tells anything that listens
## (receive_hit), flashes, and is gone. Fired on a spacewalk it is `outside`:
## drawn and lit for the world, it hits what is out there, and it moves with the
## floating origin (CLAUDE.md).

signal struck(point: Vector3, collider: Object)

const SPEED := 45.0
const LIFETIME := 1.5
## Newton-seconds given to whatever it hits.
const PUSH := 6.0
## hp a bolt takes from what it hits (health and damage spec §5.1).
const DAMAGE := 10.0
## interior_geometry | items.
const RAY_MASK := 2 | 32 | Npc.LAYER
## Outside: exterior_hull | terrain | items | asteroids | npcs -- Item.SPACE_MASK
## without the avatar.
const SPACE_RAY_MASK := 1 | BodyProxy.LAYER | 32 | AsteroidBody.LAYER | Npc.LAYER
## Chunky enough to read at the far end of a corridor: at 0.06 m thick it was
## a hairline by four metres.
const LENGTH := 0.5
const THICKNESS := 0.09
const LIGHT_ENERGY := 0.4
const LIGHT_RANGE := 2.5

static var _mesh: Mesh

var direction := Vector3.FORWARD
var exclude: Array[RID] = []
var source: Node = null
var age := 0.0
## Set before it enters the tree.
var outside := false

var _spent := false

func launch(from: Vector3, dir: Vector3) -> void:
	direction = dir.normalized()
	var up := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	global_transform = Transform3D(Basis.looking_at(direction, up), from)

## The rays it casts, for where it is.
static func mask(out: bool) -> int:
	return SPACE_RAY_MASK if out else RAY_MASK

## What draws it and what its light falls on: the interior's aboard, the
## world's outside (as the repair torch's sparks).
static func render_layer(out: bool) -> int:
	return Item.SPACE_LAYER if out else InteriorKit.LAYER

static func light_mask(out: bool) -> int:
	return (1 | ExteriorBuilder.OWN_HULL_LAYER) if out else InteriorKit.LAYER

func _ready() -> void:
	if outside:
		add_to_group(Universe.EXTERIOR_SPACE)
	var body := MeshInstance3D.new()
	body.mesh = _shared_mesh()
	body.material_override = InteriorMaterials.glow()
	body.layers = render_layer(outside)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)
	var light := OmniLight3D.new()
	light.light_color = InteriorPalette.LIGHT_WARM
	light.light_energy = LIGHT_ENERGY
	light.omni_range = LIGHT_RANGE
	light.light_cull_mask = light_mask(outside)
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
	var query := PhysicsRayQueryParameters3D.create(from, to, mask(outside), exclude)
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
	var hit := Hit.make(point, normal, direction, direction * PUSH, source)
	hit.damage = DAMAGE
	hit.kind = &"plasma"
	hit.shape = int(result.get("shape", -1))
	Hit.deliver(collider, hit)
	_tell_npcs(point, collider)
	ImpactFlash.spawn(get_parent(), point, normal, ImpactFlash.Kind.IMPACT, outside)
	struck.emit(point, collider)
	queue_free()

## What NPCs notice of a hit (NPC foundation spec §6.1): a crack they hear
## through air, and, on a rock, a jolt through the stone.
func _tell_npcs(point: Vector3, collider: Object) -> void:
	StimulusBus.send(self, Stimulus.make(Stimulus.SOUND, point, 1.0, 15.0, source))
	var rock: AsteroidRock = null
	if collider is AsteroidDetail:
		rock = (collider as AsteroidDetail).rock
	elif collider is AsteroidBody:
		rock = (collider as AsteroidBody).rock
	if rock != null:
		StimulusBus.send(self, Stimulus.make(Stimulus.VIBRATION, point, 0.8, 40.0, source, RockHerds.site_of(rock)))

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
