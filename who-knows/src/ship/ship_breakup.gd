class_name ShipBreakup
extends Node

## A destroyed ship breaking apart (docs/superpowers/specs/
## 2026-10-24-hostile-ships-design.md §8.2): its blocks go as a handful of
## large chunks and many small ones, flung out from the core with a spin and
## carrying the hull's velocity, with a burst of sparks and a puff of gas. A
## chunk is a loose body of chunky bevelled blocks in the hull's plate colour,
## scorched or charred (ExteriorBuilder.stage_colour); it touches rocks and
## nothing else, never another chunk, and shrinks away over its last SHRINK
## seconds of a life between LIFE's.
##
## The floating origin (CLAUDE.md): this is a plain Node under Outside, so it
## never moves; each chunk under it is in Universe.EXTERIOR_SPACE, and so is
## the gas, which drifts at the hull's velocity with its puffs in its own
## frame. The sparks are DamageShow's bursts, world-space, holding the shift
## for their two seconds.

## Every chunk is in this group, for tests and the probe.
const CHUNKS := &"breakup_chunks"
## How many large chunks the ship is cut into, and how many single blocks fly
## off on their own.
const LARGE := Vector2i(6, 10)
const SMALL := Vector2i(20, 30)
## m/s out from the core, and rad/s of spin: large chunks heave off slowly,
## small ones fly.
const SPEED_LARGE := Vector2(5.0, 12.0)
const SPEED_SMALL := Vector2(10.0, 25.0)
const SPIN_LARGE := Vector2(0.15, 0.6)
const SPIN_SMALL := Vector2(0.8, 3.0)
## How far off the line from the core a chunk may fly, as a share of it.
const SCATTER := 0.35
## Seconds a chunk lasts, at random between these; it shrinks over the last
## SHRINK of them.
const LIFE := Vector2(20.0, 60.0)
const SHRINK := 2.0
## Each block of a chunk: a little under a cell, chamfered; kg per block.
const BLOCK := ShipGrid.CELL_SIZE * 0.96
const BEVEL := 0.2
const BLOCK_KG := 400.0
## The share of blocks only scorched; the rest are charred.
const SCORCHED := 0.35
## The gas: a puff of PUFFS from the core, out at PUFF_SPEED m/s, PUFF_SIZE m
## across growing PUFF_GROW times over PUFF_LIFE s, at most PUFF_PEAK opaque.
const PUFFS := 18
const PUFF_LIFE := 2.0
const PUFF_SPEED := Vector2(3.0, 8.0)
const PUFF_SIZE := Vector2(1.5, 3.0)
const PUFF_GROW := 4.0
const PUFF_PEAK := 0.45

static var _puff_mesh: Mesh
static var _puff_ramp: GradientTexture1D

## Each chunk: {body, look, life}.
var _chunks: Array[Dictionary] = []
var _gas: GPUParticles3D
var _gas_velocity := Vector3.ZERO
var _age := 0.0

## `ship` breaks apart under `outside`, and its hull is gone from view.
static func go(ship: Ship, outside: Node3D) -> void:
	var b := ShipBreakup.new()
	b.name = "ShipBreakup"
	outside.add_child(b, true)
	b._break(ship)

## The ship's blocks as LARGE large chunks -- a flood-fill of the grid from
## seeds spread through it -- then SMALL single blocks off its outside, first.
## Seeded by `rng`, so a ship breaks the same way every time. {large, small}:
## each a list of chunks, each a list of cells; a large chunk's seed first.
static func clusters(grid: ShipGrid, rng: RandomNumberGenerator) -> Dictionary:
	var cells: Array = grid.coords()
	cells.sort()
	var out := {"large": [], "small": []}
	if cells.is_empty():
		return out
	var large_n := rng.randi_range(LARGE.x, LARGE.y)
	var small_n := rng.randi_range(SMALL.x, SMALL.y)
	large_n = mini(large_n, cells.size())
	small_n = mini(small_n, cells.size() - large_n)
	# The small ones: blocks with a face onto space, at random.
	var outer: Array = []
	for c: Vector3i in cells:
		for n in ShipGrid.FACE_OFFSETS:
			if not grid.has_block(c + n):
				outer.append(c)
				break
	_shuffle(outer, rng)
	var left := {}
	for c: Vector3i in cells:
		left[c] = true
	var small: Array[Array] = []
	for c: Vector3i in outer:
		if small.size() >= small_n:
			break
		small.append([c])
		left.erase(c)
	# The large ones' seeds: each the farthest of a few picks from those before.
	var pool: Array = left.keys()
	var seeds: Array[Vector3i] = []
	while seeds.size() < large_n and not pool.is_empty():
		var best: Vector3i = pool[rng.randi() % pool.size()]
		var best_d := -1.0
		if not seeds.is_empty():
			for i in 6:
				var pick: Vector3i = pool[rng.randi() % pool.size()]
				var d := INF
				for s in seeds:
					d = minf(d, Vector3(pick - s).length_squared())
				if d > best_d:
					best = pick
					best_d = d
		seeds.append(best)
		pool.erase(best)
	var groups: Array[Array] = []
	var fronts: Array[Array] = []
	for s in seeds:
		groups.append([s])
		fronts.append([s])
		left.erase(s)
	# Each grows a ring at a time, in turn, until nothing is left to reach.
	var grew := true
	while grew and not left.is_empty():
		grew = false
		for i in groups.size():
			var next: Array = []
			for c: Vector3i in fronts[i]:
				for n in ShipGrid.FACE_OFFSETS:
					if left.has(c + n):
						left.erase(c + n)
						groups[i].append(c + n)
						next.append(c + n)
			fronts[i] = next
			grew = grew or not next.is_empty()
	# Blocks no seed reaches (an island of the grid) go with the nearest.
	for c: Vector3i in left:
		var best_i := 0
		var best_d := INF
		for i in seeds.size():
			var d := Vector3(c - seeds[i]).length_squared()
			if d < best_d:
				best_i = i
				best_d = d
		groups[best_i].append(c)
	out["large"] = groups
	out["small"] = small
	return out

static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t

func _break(ship: Ship) -> void:
	var hull := ship.exterior
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(ship.name))
	var parts := clusters(ship.grid, rng)
	var core := CoreBlast.core_of(ship)
	for group: Array in parts["large"]:
		_chunk(group, hull, core, rng, false)
	for group: Array in parts["small"]:
		_chunk(group, hull, core, rng, true)
	# Sparks from the core, and from where the large chunks part.
	var bursts: Array[Vector3i] = [Vector3i((hull.to_local(core) / ShipGrid.CELL_SIZE).round())]
	for group: Array in parts["large"]:
		if bursts.size() < DamageShow.MAX_BURSTS:
			bursts.append(group[0])
	ship.damage_show.lost(bursts)
	_puff(core, hull.linear_velocity)
	hull.visible = false
	if _chunks.is_empty():
		queue_free()

## A chunk of `cells`, out of `hull`, flung from `core`.
func _chunk(cells: Array, hull: RigidBody3D, core: Vector3, rng: RandomNumberGenerator, small: bool) -> void:
	var centre := Vector3.ZERO
	var lo := Vector3.ONE * INF
	var hi := -Vector3.ONE * INF
	for c: Vector3i in cells:
		var p := ShipGrid.cell_center(c)
		centre += p
		lo = lo.min(p)
		hi = hi.max(p)
	centre /= cells.size()
	var kit := InteriorKit.new(null)
	for c: Vector3i in cells:
		var stage := BlockDamage.Stage.DAMAGED if rng.randf() < SCORCHED else BlockDamage.Stage.WRECKED
		kit.bevel_box(InteriorKit.Batch.SOLID, InteriorKit.at(ShipGrid.cell_center(c) - centre),
			Vector3.ONE * BLOCK, BEVEL, InteriorKit.solid(HullPalette.PLATE * ExteriorBuilder.stage_colour(stage)))
	var body := RigidBody3D.new()
	body.name = "Chunk"
	body.collision_layer = 0
	body.collision_mask = AsteroidBody.LAYER
	body.gravity_scale = 0.0
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.mass = BLOCK_KG * cells.size()
	body.set_meta(&"cells", cells.size())
	var look := MeshInstance3D.new()
	look.name = "Look"
	look.mesh = kit.mesh(InteriorKit.Batch.SOLID)
	look.material_override = HullMaterials.trim()
	look.layers = 1
	if small:
		look.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(look)
	var box := BoxShape3D.new()
	box.size = hi - lo + Vector3.ONE * ShipGrid.CELL_SIZE
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = (lo + hi) * 0.5 - centre
	body.add_child(shape)
	add_child(body)
	body.add_to_group(Universe.EXTERIOR_SPACE)
	body.add_to_group(CHUNKS)
	body.global_transform = Transform3D(hull.global_basis, hull.to_global(centre))
	var at := body.global_position
	var out := at - core
	out = out.normalized() if out.length() > 0.5 else _random_dir(rng)
	out = (out + _random_dir(rng) * SCATTER).normalized()
	var speed := rng.randf_range(SPEED_SMALL.x, SPEED_SMALL.y) if small \
		else rng.randf_range(SPEED_LARGE.x, SPEED_LARGE.y)
	var spin := rng.randf_range(SPIN_SMALL.x, SPIN_SMALL.y) if small \
		else rng.randf_range(SPIN_LARGE.x, SPIN_LARGE.y)
	body.linear_velocity = hull.linear_velocity + hull.angular_velocity.cross(at - hull.global_position) + out * speed
	body.angular_velocity = hull.angular_velocity + _random_dir(rng) * spin
	_chunks.append({"body": body, "look": look, "life": rng.randf_range(LIFE.x, LIFE.y)})

static func _random_dir(rng: RandomNumberGenerator) -> Vector3:
	var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
	return v.normalized() if v.length() > 0.01 else Vector3.UP

## The gas from the core: one puff of chunky vapour, as the hull vents (style
## guide §3.4), drifting on at the hull's `velocity`.
func _puff(at: Vector3, velocity: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.name = "Gas"
	p.amount = PUFFS
	p.lifetime = PUFF_LIFE
	p.one_shot = true
	p.explosiveness = 0.85
	p.randomness = 0.3
	p.local_coords = true
	p.layers = 1
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.draw_pass_1 = _puff_look()
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 180.0
	m.gravity = Vector3.ZERO
	m.initial_velocity_min = PUFF_SPEED.x
	m.initial_velocity_max = PUFF_SPEED.y
	m.damping_min = 1.0
	m.damping_max = 2.0
	m.scale_min = PUFF_SIZE.x
	m.scale_max = PUFF_SIZE.y
	m.scale_curve = Puffs.grow(1.0, PUFF_GROW)
	m.color_ramp = _ramp()
	m.angle_min = 0.0
	m.angle_max = 360.0
	p.process_material = m
	p.visibility_aabb = AABB(Vector3.ONE * -40.0, Vector3.ONE * 80.0)
	add_child(p)
	p.add_to_group(Universe.EXTERIOR_SPACE)
	p.global_position = at
	p.restart()
	_gas = p
	_gas_velocity = velocity

func _process(delta: float) -> void:
	tick(delta)

## `delta` seconds on: the gas drifts, then goes; each chunk shrinks over its
## last SHRINK seconds and goes at the end of its life; this goes with the last.
func tick(delta: float) -> void:
	_age += delta
	if is_instance_valid(_gas):
		if _age >= PUFF_LIFE + 0.5:
			_gas.queue_free()
			_gas = null
		else:
			_gas.global_position += _gas_velocity * delta
	var keep: Array[Dictionary] = []
	for c in _chunks:
		var body: RigidBody3D = c["body"]
		if not is_instance_valid(body):
			continue
		var to_go: float = c["life"] - _age
		if to_go <= 0.0:
			body.queue_free()
			continue
		if to_go < SHRINK:
			(c["look"] as MeshInstance3D).scale = Vector3.ONE * maxf(to_go / SHRINK, 0.01)
		keep.append(c)
	_chunks = keep
	if _chunks.is_empty():
		queue_free()

## The shared puff, flat lit, in the vent gas colour.
static func _puff_look() -> Mesh:
	if _puff_mesh == null:
		var m := Puffs.mesh(true)
		(m.material as StandardMaterial3D).albedo_color = SpacePalette.VENT_GAS
		_puff_mesh = m
	return _puff_mesh

## Fades in, holds, fades out; untinted, so the puff's own colour shows.
static func _ramp() -> GradientTexture1D:
	if _puff_ramp == null:
		var clear := SpacePalette.UNTINTED
		clear.a = 0.0
		var thick := SpacePalette.UNTINTED
		thick.a = PUFF_PEAK
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.15, 0.55, 1.0])
		g.colors = PackedColorArray([clear, thick, thick, clear])
		_puff_ramp = GradientTexture1D.new()
		_puff_ramp.gradient = g
	return _puff_ramp
