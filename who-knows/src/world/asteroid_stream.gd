class_name AsteroidStream
extends Node3D

## Keeps the rocks around you loaded, drawn and touchable
## (docs/superpowers/specs/2026-09-24-asteroids-design.md §6, §7). Cells load
## well beyond where their rocks fade in, on worker threads; loaded rocks are
## drawn as batched pictures, a block of cells at a time; the few near the path
## of the hull or a spacewalker become sleeping bodies (AsteroidBubble).
##
## This node and its two holders never move. Every block and body under them
## is a member of Universe.EXTERIOR_SPACE, moved by the shift itself.

## Bodies that touch rocks: the hull, and you on a spacewalk.
const SPACE_ANCHOR := &"space_anchor"
## Meta on an anchor: how far it reaches from its origin, metres.
const ANCHOR_RADIUS := &"anchor_radius"

## Per tier: whole within FADE_START, gone beyond FADE_END; loaded within
## LOAD, unloaded beyond UNLOAD.
const FADE_START: Array[float] = [450.0, 3000.0, 15000.0]
const FADE_END: Array[float] = [600.0, 4000.0, 20000.0]
const LOAD: Array[float] = [900.0, 5000.0, 25000.0]
const UNLOAD: Array[float] = [1100.0, 5500.0, 30000.0]
## Boost: every tier loads at least a second ahead of it.
const TOP_SPEED := 300.0
## Icosphere subdivisions per tier.
const DETAIL: Array[int] = [0, 1, 2]
const APPLY_BUDGET_USEC := 2000
const MAX_JOBS := 48
const _NO_SLOT := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)

@export var seed: int = 1337

var universe: Universe
var recipe: AsteroidRecipe
var bubble: AsteroidBubble
## Cells finished after their rocks could already have been seen. Stays 0.
var late_cells := 0

var _pictures: Node3D
var _started := false
var _start_point: UniversePoint
var _cells: Array[Dictionary] = [{}, {}, {}]
var _wanted: Array[Dictionary] = [{}, {}, {}]
var _blocks: Array[Dictionary] = [{}, {}, {}]
var _block_cells: Array[Dictionary] = [{}, {}, {}]
var _dirty: Array[Dictionary] = [{}, {}, {}]
var _queue: Array = []
var _queued := {}
var _jobs := {}
var _focus_cell: Array = [null, null, null]
var _materials := {}

class _Cell:
	var rocks: Array[AsteroidRock]
	## Per shape: instance data relative to the block's corner, and the ids in
	## the same order.
	var packed: Array[PackedFloat32Array]
	var ids: Array
	## Rocks whose picture is hidden: a body stands in for it, or took it away.
	var hidden := {}

class _Block:
	var node: Node3D
	var instances: Array[MultiMeshInstance3D] = [null, null, null]
	## What each MultiMesh was given, kept here too: without a renderer the
	## engine hands no instance data back, and this is the same data.
	var buffers: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()]
	## id -> Vector2i(shape, slot)
	var slots := {}

class _Job:
	var tier: int
	var cell: Vector3i
	var world_seed: int
	var start: UniversePoint
	var task := -1
	var done := false
	var rocks: Array[AsteroidRock]
	var packed: Array[PackedFloat32Array]
	var ids: Array

	## On a worker thread: the cell's rocks, packed for its block.
	func run() -> void:
		rocks = AsteroidRecipe.new(world_seed, start).cell_rocks(tier, cell)
		var offset := AsteroidStream.offset_in_block(tier, cell)
		var p0 := PackedFloat32Array()
		var p1 := PackedFloat32Array()
		var p2 := PackedFloat32Array()
		var i0: Array[Vector4i] = []
		var i1: Array[Vector4i] = []
		var i2: Array[Vector4i] = []
		for rock in rocks:
			var t := Transform3D(rock.basis(), offset + rock.local)
			match rock.shape:
				RockMesh.Shape.BOULDER:
					p0 = AsteroidStream.pack(p0, t, rock.colour)
					i0.append(rock.id())
				RockMesh.Shape.SHARD:
					p1 = AsteroidStream.pack(p1, t, rock.colour)
					i1.append(rock.id())
				_:
					p2 = AsteroidStream.pack(p2, t, rock.colour)
					i2.append(rock.id())
		packed = [p0, p1, p2]
		ids = [i0, i1, i2]

func _ready() -> void:
	_pictures = Node3D.new()
	_pictures.name = "Pictures"
	add_child(_pictures)
	var bodies := Node3D.new()
	bodies.name = "Bodies"
	add_child(bodies)
	bubble = AsteroidBubble.new(self, bodies)

## Starts streaming around `u`'s focus, keeping `start_point`'s bubble clear
## (or none). Everything wanted now is loaded and drawn before this returns.
func start(u: Universe, start_point: UniversePoint = null) -> void:
	universe = u
	_start_point = start_point
	recipe = AsteroidRecipe.new(seed, start_point)
	_started = true
	update(0.0, true)

func _exit_tree() -> void:
	finish_jobs()
	if bubble != null:
		bubble.clear()

func _process(delta: float) -> void:
	if _started:
		update(delta)

func _physics_process(delta: float) -> void:
	if _started:
		bubble.step(delta)

## One streaming step: what is wanted, what finished, what to redraw.
## `all_now` does all of it at once and waits (the first load, and tests).
func update(_delta: float, all_now := false) -> void:
	var focus := _focus_point()
	if focus == null:
		return
	for tier in AsteroidRecipe.TIERS:
		var fc := AsteroidRecipe.cell_of(tier, focus)
		if all_now or _focus_cell[tier] == null or _focus_cell[tier] != fc:
			_focus_cell[tier] = fc
			_rewant(tier, focus)
	_submit(all_now)
	if all_now:
		finish_jobs()
	_collect(focus, all_now)
	_rebuild_dirty(focus, all_now)

## Waits for every job in flight.
func finish_jobs() -> void:
	for job: _Job in _jobs.values():
		if not job.done:
			WorkerThreadPool.wait_for_task_completion(job.task)
			job.done = true

func is_loaded(tier: int, cell: Vector3i) -> bool:
	return _cells[tier].has(cell)

func loaded_rocks(tier: int, cell: Vector3i) -> Array[AsteroidRock]:
	var c: _Cell = _cells[tier].get(cell)
	return c.rocks if c != null else [] as Array[AsteroidRock]

func loaded_count(tier: int) -> int:
	return _cells[tier].size()

## The loaded rocks of `tier` in cells overlapping an engine-space box.
func rocks_in(tier: int, box: AABB) -> Array[AsteroidRock]:
	var lo := AsteroidRecipe.cell_of(tier, universe.to_universe(box.position))
	var hi := AsteroidRecipe.cell_of(tier, universe.to_universe(box.end))
	var out: Array[AsteroidRock] = []
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				var c: _Cell = _cells[tier].get(Vector3i(x, y, z))
				if c != null:
					out.append_array(c.rocks)
	return out

## Where a rock sits, in engine space: rotation and position, no scale.
func rock_pose(rock: AsteroidRock) -> Transform3D:
	return Transform3D(rock.turn, universe.to_engine(AsteroidRecipe.cell_corner(rock.tier, rock.cell)) + rock.local)

## Where its picture is drawn, in engine space, scale included.
func picture_transform(rock: AsteroidRock) -> Transform3D:
	var block: _Block = _blocks[rock.tier].get(block_of(rock.cell))
	if block == null or not block.slots.has(rock.id()):
		return _NO_SLOT
	var slot: Vector2i = block.slots[rock.id()]
	return block.node.global_transform * unpack(block.buffers[slot.x], slot.y)

## Hides a rock's picture: a body stands in for it.
func hide_rock(rock: AsteroidRock) -> void:
	var c: _Cell = _cells[rock.tier].get(rock.cell)
	if c != null:
		c.hidden[rock.id()] = true
	_set_slot(rock.tier, rock.id(), _NO_SLOT)

## Shows a rock's picture again, just where it was.
func show_rock(rock: AsteroidRock) -> void:
	var c: _Cell = _cells[rock.tier].get(rock.cell)
	if c == null:
		return
	c.hidden.erase(rock.id())
	_set_slot(rock.tier, rock.id(), Transform3D(rock.basis(), offset_in_block(rock.tier, rock.cell) + rock.local))

func is_hidden(rock: AsteroidRock) -> bool:
	var c: _Cell = _cells[rock.tier].get(rock.cell)
	return c != null and c.hidden.has(rock.id())

## A rock material: vertex colour times `colour` (white for the pictures,
## whose instance colour tints them), fading out by the tier's distances.
func rock_material(tier: int, colour: Color) -> StandardMaterial3D:
	var key := "%d:%s" % [tier, colour.to_html()]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.albedo_color = colour
		m.roughness = 1.0
		# Reversed (min beyond max): whole within FADE_START, gone past FADE_END.
		m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
		m.distance_fade_min_distance = FADE_END[tier]
		m.distance_fade_max_distance = FADE_START[tier]
		_materials[key] = m
	return _materials[key]

## Appends one instance to a MultiMesh buffer: the transform's rows, then the
## colour.
static func pack(buf: PackedFloat32Array, t: Transform3D, c: Color) -> PackedFloat32Array:
	buf.append_array(PackedFloat32Array([
		t.basis.x.x, t.basis.y.x, t.basis.z.x, t.origin.x,
		t.basis.x.y, t.basis.y.y, t.basis.z.y, t.origin.y,
		t.basis.x.z, t.basis.y.z, t.basis.z.z, t.origin.z,
		c.r, c.g, c.b, c.a]))
	return buf

## Instance `slot`'s transform in a MultiMesh buffer.
static func unpack(buf: PackedFloat32Array, slot: int) -> Transform3D:
	var i := slot * 16
	return Transform3D(Vector3(buf[i], buf[i + 4], buf[i + 8]), Vector3(buf[i + 1], buf[i + 5], buf[i + 9]),
		Vector3(buf[i + 2], buf[i + 6], buf[i + 10]), Vector3(buf[i + 3], buf[i + 7], buf[i + 11]))

## The block (the next tier's cell) a cell is drawn in.
static func block_of(cell: Vector3i) -> Vector3i:
	return Vector3i(AsteroidRecipe.floor_div(cell.x, AsteroidRecipe.NEST),
		AsteroidRecipe.floor_div(cell.y, AsteroidRecipe.NEST), AsteroidRecipe.floor_div(cell.z, AsteroidRecipe.NEST))

## A cell's corner from its block's corner, metres.
static func offset_in_block(tier: int, cell: Vector3i) -> Vector3:
	return Vector3(cell - block_of(cell) * AsteroidRecipe.NEST) * AsteroidRecipe.CELL[tier]

static func velocity_of(node: Node) -> Vector3:
	if node is RigidBody3D:
		return (node as RigidBody3D).linear_velocity
	if node is CharacterBody3D:
		return (node as CharacterBody3D).velocity
	return Vector3.ZERO

## How far `p` (from a box's lowest corner) is from the box [0, size]^3.
static func box_distance(p: Vector3, size: float) -> float:
	return Vector3(maxf(0.0, maxf(-p.x, p.x - size)), maxf(0.0, maxf(-p.y, p.y - size)),
		maxf(0.0, maxf(-p.z, p.z - size))).length()

func _focus_point() -> UniversePoint:
	if universe == null or not is_instance_valid(universe.focus):
		return null
	return universe.to_universe(universe.focus.global_position)

func _key(tier: int, cell: Vector3i) -> Vector4i:
	return Vector4i(cell.x, cell.y, cell.z, tier)

func _rewant(tier: int, focus: UniversePoint) -> void:
	var size := float(AsteroidRecipe.CELL[tier])
	var fc: Vector3i = _focus_cell[tier]
	var inside := focus.minus(AsteroidRecipe.cell_corner(tier, fc))
	var n := ceili(LOAD[tier] / size)
	var wanted := {}
	for x in range(-n, n + 1):
		for y in range(-n, n + 1):
			for z in range(-n, n + 1):
				var d := Vector3i(x, y, z)
				if box_distance(inside - Vector3(d) * size, size) <= LOAD[tier]:
					wanted[fc + d] = true
	_wanted[tier] = wanted
	for c: Vector3i in _cells[tier].keys():
		if not wanted.has(c) and box_distance(inside - Vector3(c - fc) * size, size) > UNLOAD[tier]:
			_unload(tier, c)
	var velocity := velocity_of(universe.focus)
	var ahead := velocity.normalized() if velocity.length() > 1.0 else Vector3.ZERO
	_queue = _queue.filter(func(q: Array) -> bool:
		var keep: bool = q[1] != tier or wanted.has(q[2])
		if not keep:
			_queued.erase(_key(q[1], q[2]))
		return keep)
	for c: Vector3i in wanted:
		var key := _key(tier, c)
		if _cells[tier].has(c) or _jobs.has(key) or _queued.has(key):
			continue
		var centre := Vector3(c - fc) * size + Vector3.ONE * size * 0.5 - inside
		_queue.append([centre.length() - 0.5 * maxf(0.0, centre.dot(ahead)), tier, c])
		_queued[key] = true
	_queue.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])

func _submit(all_now: bool) -> void:
	while not _queue.is_empty() and (all_now or _jobs.size() < MAX_JOBS):
		var q: Array = _queue.pop_front()
		var key := _key(q[1], q[2])
		_queued.erase(key)
		var job := _Job.new()
		job.tier = q[1]
		job.cell = q[2]
		job.world_seed = seed
		job.start = _start_point
		job.task = WorkerThreadPool.add_task(job.run)
		_jobs[key] = job

func _collect(focus: UniversePoint, all_now: bool) -> void:
	for key: Vector4i in _jobs.keys():
		var job: _Job = _jobs[key]
		if not job.done:
			if not WorkerThreadPool.is_task_completed(job.task):
				continue
			WorkerThreadPool.wait_for_task_completion(job.task)
			job.done = true
		_jobs.erase(key)
		if not _wanted[job.tier].has(job.cell):
			continue
		var cell := _Cell.new()
		cell.rocks = job.rocks
		cell.packed = job.packed
		cell.ids = job.ids
		_cells[job.tier][job.cell] = cell
		var b := block_of(job.cell)
		if not _block_cells[job.tier].has(b):
			_block_cells[job.tier][b] = {}
		_block_cells[job.tier][b][job.cell] = true
		_dirty[job.tier][b] = true
		if not all_now and not cell.rocks.is_empty():
			var size := float(AsteroidRecipe.CELL[job.tier])
			if box_distance(focus.minus(AsteroidRecipe.cell_corner(job.tier, job.cell)), size) < FADE_END[job.tier]:
				late_cells += 1

func _unload(tier: int, c: Vector3i) -> void:
	_cells[tier].erase(c)
	var b := block_of(c)
	if _block_cells[tier].has(b):
		_block_cells[tier][b].erase(c)
	_dirty[tier][b] = true
	bubble.cell_unloaded(tier, c)

func _rebuild_dirty(focus: UniversePoint, all_now: bool) -> void:
	var order := []
	for tier in AsteroidRecipe.TIERS:
		var size := float(AsteroidRecipe.CELL[tier] * AsteroidRecipe.NEST)
		for b: Vector3i in _dirty[tier]:
			var corner := UniversePoint.at(b.x * int(size), b.y * int(size), b.z * int(size))
			order.append([box_distance(focus.minus(corner), size), tier, b])
	order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var began := Time.get_ticks_usec()
	for o in order:
		if not all_now and Time.get_ticks_usec() - began > APPLY_BUDGET_USEC:
			return
		_dirty[o[1]].erase(o[2])
		_rebuild(o[1], o[2])

func _rebuild(tier: int, b: Vector3i) -> void:
	var cells: Dictionary = _block_cells[tier].get(b, {})
	var block: _Block = _blocks[tier].get(b)
	var buffers: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()]
	var counts := [0, 0, 0]
	var slots := {}
	for c: Vector3i in cells:
		var cell: _Cell = _cells[tier][c]
		for s in 3:
			var ids: Array = cell.ids[s]
			for k in ids.size():
				slots[ids[k]] = Vector2i(s, counts[s] + k)
			var buf := buffers[s]
			buf.append_array(cell.packed[s])
			buffers[s] = buf
			counts[s] += ids.size()
	if counts[0] + counts[1] + counts[2] == 0:
		if block != null:
			block.node.free()
			_blocks[tier].erase(b)
		if cells.is_empty():
			_block_cells[tier].erase(b)
		return
	if block == null:
		block = _Block.new()
		block.node = Node3D.new()
		block.node.name = "Block_%d_%d_%d_%d" % [tier, b.x, b.y, b.z]
		_pictures.add_child(block.node)
		var edge := AsteroidRecipe.CELL[tier] * AsteroidRecipe.NEST
		block.node.global_position = universe.to_engine(UniversePoint.at(b.x * edge, b.y * edge, b.z * edge))
		block.node.add_to_group(Universe.EXTERIOR_SPACE)
		_blocks[tier][b] = block
	for s in 3:
		var inst := block.instances[s]
		if counts[s] == 0:
			if inst != null:
				inst.free()
				block.instances[s] = null
			continue
		if inst == null:
			inst = MultiMeshInstance3D.new()
			inst.layers = 1
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if tier == AsteroidRecipe.Tier.GIANT \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			inst.material_override = rock_material(tier, SpacePalette.UNTINTED)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = RockMesh.mesh(s, DETAIL[tier])
			inst.multimesh = mm
			block.node.add_child(inst)
			block.instances[s] = inst
		inst.multimesh.instance_count = counts[s]
		inst.multimesh.buffer = buffers[s]
	block.buffers = buffers
	block.slots = slots
	for c: Vector3i in cells:
		for id: Vector4i in (_cells[tier][c] as _Cell).hidden:
			_set_slot(tier, id, _NO_SLOT)

func _set_slot(tier: int, id: Vector4i, t: Transform3D) -> void:
	var block: _Block = _blocks[tier].get(block_of(Vector3i(id.x, id.y, id.z)))
	if block == null or not block.slots.has(id):
		return
	var slot: Vector2i = block.slots[id]
	block.instances[slot.x].multimesh.set_instance_transform(slot.y, t)
	var buf := block.buffers[slot.x]
	var row := PackedFloat32Array(AsteroidStream.pack(PackedFloat32Array(), t, SpacePalette.UNTINTED))
	for k in 12:
		buf[slot.y * 16 + k] = row[k]
	block.buffers[slot.x] = buf
