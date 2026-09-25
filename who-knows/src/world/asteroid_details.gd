class_name AsteroidDetails
extends RefCounted

## Which big rocks are drawn and solid in detail
## (docs/superpowers/specs/2026-09-24-asteroids-design.md §18): those within
## NEAR of an anchor -- the hull, or you on a spacewalk -- until they are FAR
## away. Each is built on a worker thread; while it stands in, its picture is
## hidden. Distances are to the rock's bounds.

const NEAR := 4000.0
const FAR := 4500.0

var stream: AsteroidStream
var holder: Node3D
## id -> AsteroidDetail
var live := {}

var _jobs := {}

class _Job:
	var rock: AsteroidRock
	var world_seed: int
	var data: RockDetail
	var task := -1
	var done := false

	## On a worker thread.
	func run() -> void:
		data = RockDetail.build(rock, world_seed)

func _init(p_stream: AsteroidStream, p_holder: Node3D) -> void:
	stream = p_stream
	holder = p_holder

## Starts details for big rocks coming near, puts finished ones in, and sends
## far ones back to pictures.
func step() -> void:
	var near := _near()
	for id: Vector4i in near:
		if not live.has(id) and not _jobs.has(id) and float(near[id][1]) < NEAR:
			var job := _Job.new()
			job.rock = near[id][0]
			job.world_seed = stream.seed
			job.task = WorkerThreadPool.add_task(job.run)
			_jobs[id] = job
	for id: Vector4i in _jobs.keys():
		var job: _Job = _jobs[id]
		if not job.done:
			if not WorkerThreadPool.is_task_completed(job.task):
				continue
			WorkerThreadPool.wait_for_task_completion(job.task)
			job.done = true
		_jobs.erase(id)
		if near.has(id) and stream.is_loaded(AsteroidRecipe.Tier.GIANT, job.rock.cell):
			_put(job.rock, job.data)
	for id: Vector4i in live.keys():
		var detail: AsteroidDetail = live[id]
		if not near.has(id) or not stream.is_loaded(AsteroidRecipe.Tier.GIANT, detail.rock.cell):
			_take(id)

## Waits for every build in flight.
func finish() -> void:
	for job: _Job in _jobs.values():
		if not job.done:
			WorkerThreadPool.wait_for_task_completion(job.task)
			job.done = true

## Big rocks within FAR of an anchor: id -> [rock, distance to its bounds].
func _near() -> Dictionary:
	var out := {}
	if stream.universe == null:
		return out
	var tier := AsteroidRecipe.Tier.GIANT
	var widest := AsteroidRecipe.BOUND * AsteroidRecipe.D_MAX[tier] * AsteroidRecipe.STRETCH_MAX
	for node in stream.get_tree().get_nodes_in_group(AsteroidStream.SPACE_ANCHOR):
		var anchor := node as Node3D
		if anchor == null or not anchor.is_inside_tree():
			continue
		var at := anchor.global_position
		var box := AABB(at, Vector3.ZERO).grow(FAR + widest)
		for cell in stream.cells_in(tier, box):
			var corner := stream.cell_origin(tier, cell)
			for rock in stream.loaded_rocks(tier, cell):
				var d := (corner + rock.local).distance_to(at) - rock.radius
				var id := rock.id()
				if d < FAR and (not out.has(id) or d < float(out[id][1])):
					out[id] = [rock, d]
	return out

func _put(rock: AsteroidRock, data: RockDetail) -> void:
	var detail := AsteroidDetail.new()
	detail.setup(rock, data, stream.rock_material(AsteroidRecipe.Tier.GIANT, SpacePalette.UNTINTED))
	# Placed before it enters the tree, so the physics server has it where it
	# is from the start (the holder never moves: its frame is engine space).
	detail.transform = stream.rock_pose(rock)
	holder.add_child(detail)
	stream.hide_rock(rock)
	live[rock.id()] = detail

func _take(id: Vector4i) -> void:
	var detail: AsteroidDetail = live[id]
	live.erase(id)
	stream.show_rock(detail.rock)
	detail.free()
