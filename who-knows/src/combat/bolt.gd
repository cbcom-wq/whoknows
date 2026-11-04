class_name Bolt
extends Node3D

## What every bolt does (hands-and-items spec §9.2, §9.3; ship weapons spec
## §6.1). Not a physics body: each tick it casts a ray from where it is to
## where it will be, so it cannot pass through a 0.1 m wall at any speed. Where
## it lands it pushes whatever is loose, tells anything that listens
## (receive_hit), flashes, and is done. `outside`, it hits what is out there
## and moves with the floating origin (CLAUDE.md). PlasmaBolt and PhaserBolt
## set the numbers and the look.

signal struck(point: Vector3, collider: Object)

var direction := Vector3.FORWARD
## The shooter's velocity, carried by the bolt (world, m/s): a turret's bolts
## leave with their ship's motion. Zero for the pistol.
var carrier := Vector3.ZERO
var speed := 45.0
var lifetime := 1.5
## Newton-seconds given to whatever it hits.
var push := 6.0
## hp it takes from what it hits.
var damage := 10.0
var kind: StringName = &"plasma"
var ray_mask := 0
## Its impact flash's size against a pistol bolt's.
var flash_scale := 1.0
## Its impact flash's brightness against a pistol bolt's.
var flash_bright := 1.0
var exclude: Array[RID] = []
var source: Node = null
var age := 0.0
## Set before it enters the tree.
var outside := false
## Metres flown, for a trail.
var travelled := 0.0

var _spent := false

func launch(from: Vector3, dir: Vector3) -> void:
	direction = dir.normalized()
	var along := carrier + direction * speed
	along = along.normalized() if along.length_squared() > 1e-9 else direction
	var up := Vector3.UP if absf(along.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	global_transform = Transform3D(Basis.looking_at(along, up), from)

func is_spent() -> bool:
	return _spent

func _physics_process(delta: float) -> void:
	if _spent:
		_after(delta)
		return
	age += delta
	if age >= lifetime:
		_spent = true
		_done()
		return
	var from := global_position
	var step := (carrier + direction * speed) * delta
	var query := PhysicsRayQueryParameters3D.create(from, from + step, ray_mask, exclude)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		global_position = from + step
		travelled += step.length()
	else:
		travelled += from.distance_to(result["position"])
		impact(result)

## Lands: a push, the hook, a flash, and done.
func impact(result: Dictionary) -> void:
	if _spent:
		return
	_spent = true
	# The firing ship may have been removed while this flew; a freed object
	# passed to a typed parameter aborts the impact.
	if not is_instance_valid(source):
		source = null
	var point: Vector3 = result["position"]
	var normal: Vector3 = result["normal"]
	var collider: Object = result.get("collider")
	var body := collider as RigidBody3D
	if body != null and not body.freeze:
		body.apply_impulse(direction * push, point - body.global_position)
		body.sleeping = false
	var hit := Hit.make(point, normal, direction, direction * push, source)
	hit.damage = damage
	hit.kind = kind
	hit.shape = int(result.get("shape", -1))
	Hit.deliver(collider, hit)
	_tell_npcs(point, collider)
	ImpactFlash.spawn(get_parent(), point, normal, ImpactFlash.Kind.IMPACT, outside, flash_scale,
		flash_bright)
	struck.emit(point, collider)
	_done()

## Spent: freed here; a pooled bolt goes back to its pool.
func _done() -> void:
	queue_free()

## Each tick once spent, until it is gone: a trail fading.
func _after(_delta: float) -> void:
	pass

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
