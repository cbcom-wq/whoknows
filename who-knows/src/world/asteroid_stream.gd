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
const FADE_START: Array[float] = [450.0, 3000.0, 20000.0]
const FADE_END: Array[float] = [600.0, 4000.0, 25000.0]
const LOAD: Array[float] = [900.0, 5000.0, 30000.0]
const UNLOAD: Array[float] = [1100.0, 5500.0, 35000.0]
## How far a camera outside must see: past the farthest fade.
const VIEW_FAR := 30000.0
## How far the sun's shadows reach: far enough that craters, ledges and
## boulders on a big rock throw shadows as you come in (§18).
const SHADOW_REACH := 2000.0
## Boost: every tier loads at least a second ahead of it.
const TOP_SPEED := 300.0
## Icosphere subdivisions per tier.
const DETAIL: Array[int] = [0, 1, 2]
const APPLY_BUDGET_USEC := 2000
const MAX_JOBS := 48
## A cell's diagonal, in cell edges.
const _DIAG := 1.7320508
## The wanted set is redone whenever you have moved this much of a cell since
## it was last worked out: so you never get more than that closer to a cell
## before it is asked for.
const REWANT_EVERY := 0.25
const _NO_SLOT := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)

@export var seed: int = 1337

var universe: Universe
var recipe: AsteroidRecipe
var bubble: AsteroidBubble
## Big rocks within reach, in detail (§18).
var details: AsteroidDetails
## Cells finished after their rocks could already have been seen. Stays 0.
var late_cells := 0
var late_by_tier: Array[int] = [0, 0, 0]

var _pictures: Node3D
var _started := false
var _start_point: UniversePoint
var _cells: Array[Dictionary] = [{}, {}, {}]
var _wanted: Array[Dictionary] = [{}, {}, {}]
var _blocks: Array[Dictionary] = [{}, {}, {}]
var _block_cells: Array[Dictionary] = [{}, {}, {}]
var _dirty: Array[Dictionary] = [{}, {}, {}]
## Per tier: cells to load, nearest first, and how far submission has got.
var _queues: Array = [[], [], []]
var _heads: Array[int] = [0, 0, 0]
var _jobs := {}
var _focus_cell: Array = [null, null, null]
## Per tier: the focus from its cell's lowest corner, metres.
var _inside: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
## Per tier: the wanted-cell pass running on a worker, or null, and where
## the focus was when the last one began.
var _rewants: Array = [null, null, null]
var _rewant_from: Array = [null, null, null]
var _materials := {}
## Per tier: every cell offset that could be within LOAD of a focus anywhere in
## its cell, nearest first, with its distance. Built once, shared.
static var _offsets: Array = []

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
	## cell -> Vector3i: where its rocks start in each shape's buffer.
	var starts := {}

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

## The wanted-cell pass for one tier, on a worker: which cells are within
## LOAD of the focus, which of them to load (nearest and ahead of you first),
## and which loaded ones have gone past UNLOAD. Works on copies only.
class _Rewant:
	var tier: int
	var fc: Vector3i
	var inside: Vector3
	var ahead: Vector3
	## Snapshots: loaded cells, and cells already being made.
	var loaded: Dictionary
	var busy: Dictionary
	var task := -1
	var done := false
	var wanted := {}
	var queue: Array[Vector3i] = []
	var unload: Array[Vector3i] = []

	func run() -> void:
		var size := float(AsteroidRecipe.CELL[tier])
		var load_to: float = AsteroidStream.LOAD[tier]
		# Nearer than this, a cell is within LOAD wherever the focus is in its cell.
		var sure := load_to - AsteroidStream._DIAG * size
		var fresh := []
		for o: Array in AsteroidStream._offsets[tier]:
			var d: Vector3i = o[1]
			var rel := Vector3(d) * size
			if o[0] > sure and AsteroidStream.box_distance(inside - rel, size) > load_to:
				continue
			var c := fc + d
			wanted[c] = true
			if not loaded.has(c) and not busy.has(c):
				var centre := rel + Vector3.ONE * size * 0.5 - inside
				fresh.append([centre.length() - 0.5 * maxf(0.0, centre.dot(ahead)), c])
		fresh.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		for f in fresh:
			queue.append(f[1])
		for c: Vector3i in loaded:
			if not wanted.has(c) and AsteroidStream.box_distance(inside - Vector3(c - fc) * size, size) > AsteroidStream.UNLOAD[tier]:
				unload.append(c)

func _ready() -> void:
	_pictures = Node3D.new()
	_pictures.name = "Pictures"
	add_child(_pictures)
	var bodies := Node3D.new()
	bodies.name = "Bodies"
	add_child(bodies)
	bubble = AsteroidBubble.new(self, bodies)
	var near := Node3D.new()
	near.name = "Details"
	add_child(near)
	details = AsteroidDetails.new(self, near)
	# Everything the detail builders read on workers, built here first.
	RockMesh.warm()

## Starts streaming around `u`'s focus, keeping `start_point`'s bubble clear
## (or none). Everything wanted now is loaded and drawn before this returns.
func start(u: Universe, start_point: UniversePoint = null) -> void:
	universe = u
	_start_point = start_point
	recipe = AsteroidRecipe.new(seed, start_point)
	_started = true
	update(0.0, true)
	# The big rock you start by is in detail before the first frame.
	details.step()
	details.finish()
	details.step()

func _exit_tree() -> void:
	finish_jobs()
	if details != null:
		details.finish()
	if bubble != null:
		bubble.clear()

func _process(delta: float) -> void:
	if _started:
		update(delta)
		details.step()

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
		_inside[tier] = focus.minus(AsteroidRecipe.cell_corner(tier, fc))
		var moved := INF if _rewant_from[tier] == null else focus.minus(_rewant_from[tier]).length()
		if all_now or _focus_cell[tier] != fc or moved > AsteroidRecipe.CELL[tier] * REWANT_EVERY:
			_focus_cell[tier] = fc
			_rewant_from[tier] = focus
			_rewant(tier, all_now)
		_take_rewant(tier)
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
	for r: _Rewant in _rewants:
		if r != null and not r.done:
			WorkerThreadPool.wait_for_task_completion(r.task)
			r.done = true

func is_loaded(tier: int, cell: Vector3i) -> bool:
	return _cells[tier].has(cell)

func loaded_rocks(tier: int, cell: Vector3i) -> Array[AsteroidRock]:
	var c: _Cell = _cells[tier].get(cell)
	return c.rocks if c != null else [] as Array[AsteroidRock]

func loaded_count(tier: int) -> int:
	return _cells[tier].size()

## The loaded cells of `tier` overlapping an engine-space box.
func cells_in(tier: int, box: AABB) -> Array[Vector3i]:
	var lo := AsteroidRecipe.cell_of(tier, universe.to_universe(box.position))
	var hi := AsteroidRecipe.cell_of(tier, universe.to_universe(box.end))
	var out: Array[Vector3i] = []
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				var c := Vector3i(x, y, z)
				if _cells[tier].has(c):
					out.append(c)
	return out

## A cell's lowest corner, in engine space.
func cell_origin(tier: int, cell: Vector3i) -> Vector3:
	return universe.to_engine(AsteroidRecipe.cell_corner(tier, cell))

## Where a rock sits, in engine space: rotation and position, no scale.
func rock_pose(rock: AsteroidRock) -> Transform3D:
	return Transform3D(rock.turn, cell_origin(rock.tier, rock.cell) + rock.local)

## Where its picture is drawn, in engine space, scale included.
func picture_transform(rock: AsteroidRock) -> Transform3D:
	var slot := _slot(rock.tier, rock.id())
	if slot.x < 0:
		return _NO_SLOT
	var block: _Block = _blocks[rock.tier][block_of(rock.cell)]
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

## Starts the wanted-cell pass for `tier` on a worker (at once, with `now`).
## A pass already running is left to finish and then superseded.
func _rewant(tier: int, now := false) -> void:
	_offsets_for(tier)
	var r := _Rewant.new()
	r.tier = tier
	r.fc = _focus_cell[tier]
	r.inside = _inside[tier]
	var v := velocity_of(universe.focus)
	r.ahead = v.normalized() if v.length() > 1.0 else Vector3.ZERO
	r.loaded = _cells[tier].duplicate()
	var busy := {}
	for key: Vector4i in _jobs:
		if key.w == tier:
			busy[Vector3i(key.x, key.y, key.z)] = true
	r.busy = busy
	var running: _Rewant = _rewants[tier]
	if running != null and not running.done:
		WorkerThreadPool.wait_for_task_completion(running.task)
		running.done = true
	if now:
		r.run()
		r.done = true
	else:
		r.task = WorkerThreadPool.add_task(r.run)
	_rewants[tier] = r

## Applies a finished wanted-cell pass.
func _take_rewant(tier: int) -> void:
	var r: _Rewant = _rewants[tier]
	if r == null:
		return
	if not r.done:
		if not WorkerThreadPool.is_task_completed(r.task):
			return
		WorkerThreadPool.wait_for_task_completion(r.task)
		r.done = true
	_rewants[tier] = null
	_wanted[tier] = r.wanted
	_queues[tier] = r.queue
	_heads[tier] = 0
	for c in r.unload:
		if _cells[tier].has(c) and not r.wanted.has(c):
			_unload(tier, c)

static func _offsets_for(tier: int) -> Array:
	if _offsets.is_empty():
		for t in AsteroidRecipe.TIERS:
			var size := float(AsteroidRecipe.CELL[t])
			var n := ceili(LOAD[t] / size) + 1
			var list := []
			for x in range(-n, n + 1):
				for y in range(-n, n + 1):
					for z in range(-n, n + 1):
						var d := Vector3i(x, y, z)
						var far := Vector3(d).length() * size
						if far - _DIAG * size <= LOAD[t]:
							list.append([far, d])
			list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
			_offsets.append(list)
	return _offsets[tier]

## Hands cells to workers: next, whichever tier's nearest waiting cell is
## closest to coming into sight.
func _submit(all_now: bool) -> void:
	var v := velocity_of(universe.focus)
	var ahead := v.normalized() if v.length() > 1.0 else Vector3.ZERO
	while all_now or _jobs.size() < MAX_JOBS:
		var best_tier := -1
		var best := INF
		for tier in AsteroidRecipe.TIERS:
			var q: Array = _queues[tier]
			while _heads[tier] < q.size() and (_cells[tier].has(q[_heads[tier]]) or _jobs.has(_key(tier, q[_heads[tier]]))):
				_heads[tier] += 1
			if _heads[tier] >= q.size():
				continue
			var size := float(AsteroidRecipe.CELL[tier])
			var c: Vector3i = q[_heads[tier]]
			var urgency := box_distance(_inside[tier] - Vector3(c - _focus_cell[tier]) * size, size) - FADE_END[tier]
			var centre := Vector3(c - _focus_cell[tier]) * size + Vector3.ONE * size * 0.5 - _inside[tier]
			urgency -= 0.5 * maxf(0.0, centre.dot(ahead))
			if urgency < best:
				best = urgency
				best_tier = tier
		if best_tier < 0:
			return
		var cell: Vector3i = _queues[best_tier][_heads[best_tier]]
		_heads[best_tier] += 1
		var job := _Job.new()
		job.tier = best_tier
		job.cell = cell
		job.world_seed = seed
		job.start = _start_point
		job.task = WorkerThreadPool.add_task(job.run)
		_jobs[_key(best_tier, cell)] = job

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
				late_by_tier[job.tier] += 1

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
	var starts := {}
	for c: Vector3i in cells:
		var cell: _Cell = _cells[tier][c]
		starts[c] = Vector3i(counts[0], counts[1], counts[2])
		for s in 3:
			var buf := buffers[s]
			buf.append_array(cell.packed[s])
			buffers[s] = buf
			counts[s] += (cell.ids[s] as Array).size()
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
	block.starts = starts
	for c: Vector3i in cells:
		for id: Vector4i in (_cells[tier][c] as _Cell).hidden:
			_set_slot(tier, id, _NO_SLOT)

func _set_slot(tier: int, id: Vector4i, t: Transform3D) -> void:
	var slot := _slot(tier, id)
	if slot.x < 0:
		return
	var block: _Block = _blocks[tier][block_of(Vector3i(id.x, id.y, id.z))]
	block.instances[slot.x].multimesh.set_instance_transform(slot.y, t)
	var buf := block.buffers[slot.x]
	var row := AsteroidStream.pack(PackedFloat32Array(), t, SpacePalette.UNTINTED)
	for k in 12:
		buf[slot.y * 16 + k] = row[k]
	block.buffers[slot.x] = buf

## Where a rock is in its block's buffers: (shape, slot), or (-1, -1) while
## its cell is not drawn yet.
func _slot(tier: int, id: Vector4i) -> Vector2i:
	var at := Vector3i(id.x, id.y, id.z)
	var block: _Block = _blocks[tier].get(block_of(at))
	var cell: _Cell = _cells[tier].get(at)
	if block == null or cell == null or not block.starts.has(at):
		return Vector2i(-1, -1)
	var start: Vector3i = block.starts[at]
	for s in 3:
		var k := (cell.ids[s] as Array).find(id)
		if k >= 0:
			return Vector2i(s, start[s] + k)
	return Vector2i(-1, -1)
