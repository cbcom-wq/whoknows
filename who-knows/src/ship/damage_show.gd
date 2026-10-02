class_name DamageShow
extends Node3D

## What damage looks like on the hull, beyond its colour (docs/superpowers/
## specs/2026-09-29-health-and-damage-design.md §9): a damaged block spits a
## few sparks now and then, and a block knocked off goes in a burst of sparks
## and a few charred chunks. Inside, a damaged or wrecked wall spits sparks
## into the cabin (as amended 2026-10-02: the inside changes style, never
## shape).
##
## The floating origin (CLAUDE.md): the spits are in their emitter's own frame,
## on the hull or in the interior, so they move with it and never hold the
## shift -- a spit every second or two from every damaged block would hold it
## for good. Only the burst is world-space, under Outside, and holds it for
## its two seconds. Chunks are loose bodies outside, in
## Universe.EXTERIOR_SPACE, gone in CHUNK_LIFE.

const SPARKS := 6
const SPARK_LIFE := 0.3
## Seconds between a damaged block's spits, at random between these.
const SPIT_EVERY := Vector2(0.8, 2.5)
const BURST_SPARKS := 32
const BURST_LIFE := 2.0
const CHUNKS := Vector2i(3, 5)
const CHUNK_LIFE := 2.0
const CHUNK_SPEED := 2.5
## At most this many cells of one loss burst: a big piece breaking off is a
## few bursts, not a hundred.
const MAX_BURSTS := 4

## Where the ship's outside things go (Ship.outside).
var outside: Node3D
## The hull, for its velocity and frame.
var hull: RigidBody3D
## Render layers the sparks draw on: the hull's own.
var layer := ExteriorBuilder.OWN_HULL_LAYER
## The interior, and where a block's damage shows in it: inside_face(coord)
## returns an interior-local point on the cabin side of its wall, or null.
var interior: Node3D
var inside_face: Callable

## coord -> {emitter, next}
var _spitting: Dictionary = {}
## coord -> {emitter, next}: walls spitting into the cabin.
var _inside: Dictionary = {}
var _rng := RandomNumberGenerator.new()
static var _spark_mesh: Mesh
static var _chunk_mesh: Mesh

func setup(p_hull: RigidBody3D, p_outside: Node3D, p_interior: Node3D = null,
		p_inside_face := Callable()) -> void:
	hull = p_hull
	outside = p_outside
	interior = p_interior
	inside_face = p_inside_face

## Every damaged block spits; nothing else does. After a rebuild or a load.
func sync(grid: ShipGrid, catalog: BlockCatalog) -> void:
	for coord: Vector3i in _spitting.keys() + _inside.keys():
		_stop(coord)
	for coord: Vector3i in grid.coords():
		var inst := grid.get_block(coord)
		stage(grid, coord, BlockDamage.stage_of(inst, catalog.get_def(inst.block_id)))

## The block at `coord` is at `stage` now.
## Outside, a damaged block spits from its face onto space; inside, a damaged
## or wrecked one spits from its wall into the cabin.
func stage(grid: ShipGrid, coord: Vector3i, stage: int) -> void:
	var outside_spits := stage == BlockDamage.Stage.DAMAGED
	var inside_spits := stage == BlockDamage.Stage.DAMAGED or stage == BlockDamage.Stage.WRECKED
	if not outside_spits:
		_drop(_spitting, coord)
	elif not _spitting.has(coord):
		var at: Variant = _outer_face(grid, coord)
		if at != null:
			_spitting[coord] = _spit(self, at, layer | 1, coord)
	if not inside_spits or interior == null or not inside_face.is_valid():
		_drop(_inside, coord)
	elif not _inside.has(coord):
		var at: Variant = inside_face.call(coord)
		if at != null:
			_inside[coord] = _spit(interior, at, InteriorKit.LAYER, coord)

func _spit(parent: Node3D, at: Vector3, layers: int, coord: Vector3i) -> Dictionary:
	var emitter := _emitter(SPARKS, SPARK_LIFE, 3.5, true)
	emitter.layers = layers
	emitter.position = at
	parent.add_child(emitter)
	_rng.seed = hash(coord)
	return {"emitter": emitter, "next": _rng.randf_range(0.0, SPIT_EVERY.y)}

## Blocks at `coords` are gone: a burst and chunks at each of the first few.
func lost(coords: Array[Vector3i]) -> void:
	if outside == null or hull == null or not hull.is_inside_tree():
		return
	for i in mini(coords.size(), MAX_BURSTS):
		var at := hull.to_global(ShipGrid.cell_center(coords[i]))
		_burst(at)
		_chunks(at)

## How many cells spit now, outside and into the cabin, for tests.
func spitting() -> int:
	return _spitting.size()

func spitting_inside() -> int:
	return _inside.size()

func _process(delta: float) -> void:
	for spits: Dictionary in [_spitting, _inside]:
		for coord: Vector3i in spits:
			var e: Dictionary = spits[coord]
			e["next"] -= delta
			if e["next"] <= 0.0:
				e["next"] = _rng.randf_range(SPIT_EVERY.x, SPIT_EVERY.y)
				var emitter: GPUParticles3D = e["emitter"]
				if is_instance_valid(emitter):
					emitter.restart()

func _stop(coord: Vector3i) -> void:
	_drop(_spitting, coord)
	_drop(_inside, coord)

static func _drop(spits: Dictionary, coord: Vector3i) -> void:
	if not spits.has(coord):
		return
	var emitter: GPUParticles3D = spits[coord]["emitter"]
	spits.erase(coord)
	if is_instance_valid(emitter):
		emitter.queue_free()

## The middle of one of the block's faces onto open space, in the hull's
## frame, or null when it has none.
func _outer_face(grid: ShipGrid, coord: Vector3i) -> Variant:
	for n in ShipGrid.FACE_OFFSETS:
		if not grid.has_block(coord + n):
			return ShipGrid.cell_center(coord) + Vector3(n) * ShipGrid.CELL_SIZE * 0.5
	return null

func _burst(at: Vector3) -> void:
	var emitter := _emitter(BURST_SPARKS, BURST_LIFE, 4.0)
	outside.add_child(emitter)
	emitter.global_position = at
	emitter.restart()
	_free_after(emitter, BURST_LIFE + 0.5)

func _chunks(at: Vector3) -> void:
	_rng.randomize()
	for i in _rng.randi_range(CHUNKS.x, CHUNKS.y):
		var chunk := RigidBody3D.new()
		chunk.name = "DamageChunk"
		chunk.collision_layer = 0
		chunk.collision_mask = 0
		chunk.gravity_scale = 0.0
		var look := MeshInstance3D.new()
		look.mesh = _chunk()
		look.layers = layer | 1
		look.scale = Vector3.ONE * _rng.randf_range(0.6, 1.4)
		chunk.add_child(look)
		outside.add_child(chunk)
		chunk.add_to_group(Universe.EXTERIOR_SPACE)
		var out := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
		chunk.global_position = at + out * 0.4
		chunk.linear_velocity = hull.linear_velocity + out * CHUNK_SPEED
		chunk.angular_velocity = out.cross(Vector3.UP) * 3.0
		_free_after(chunk, CHUNK_LIFE)

## Frees `node` after `seconds` with a timer of its own, so nothing outlives
## it holding a reference (leaving the tree drops its groups).
static func _free_after(node: Node, seconds: float) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = seconds
	timer.autostart = true
	timer.timeout.connect(node.queue_free)
	node.add_child(timer)

## A one-shot spray of sparks in world space, which holds the shift.
## A one-shot spray of sparks. In its own frame (`local`) it moves with its
## parent and never holds the shift; in world space, it does.
func _emitter(amount: int, life: float, speed: float, local := false) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Sparks"
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.9
	p.emitting = false
	p.local_coords = local
	p.layers = layer | 1
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.draw_pass_1 = _spark()
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 180.0
	m.initial_velocity_min = speed * 0.5
	m.initial_velocity_max = speed
	m.gravity = Vector3.ZERO
	m.damping_min = 1.0
	m.damping_max = 2.0
	m.scale_min = 0.5
	m.scale_max = 1.0
	p.process_material = m
	p.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	if not local:
		p.add_to_group(Universe.HOLDS_SHIFT)
	return p

static func _spark() -> Mesh:
	if _spark_mesh == null:
		var b := BoxMesh.new()
		b.size = Vector3(0.015, 0.015, 0.05)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = HullPalette.SPARK
		b.material = m
		_spark_mesh = b
	return _spark_mesh

static func _chunk() -> Mesh:
	if _chunk_mesh == null:
		var b := BoxMesh.new()
		b.size = Vector3(0.35, 0.2, 0.3)
		var m := StandardMaterial3D.new()
		m.albedo_color = HullPalette.CHAR
		m.roughness = 0.9
		b.material = m
		_chunk_mesh = b
	return _chunk_mesh
