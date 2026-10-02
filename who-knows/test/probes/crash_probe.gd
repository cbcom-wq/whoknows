extends SceneTree

# Crashes in the real starter (docs/superpowers/specs/
# 2026-09-29-health-and-damage-design.md §5.2, §11.2): the ship driven into a
# big still body at 3, 5 and 8 m/s, and what broke; then the cost of knocking
# three blocks off at once. Headless is fine:
#
#   godot --headless --path who-knows --script res://test/probes/crash_probe.gd
#
# Prints one line per speed, and the rebuild time.

const SPEEDS := [3.0, 5.0, 8.0]

func _initialize() -> void:
	_run.call_deferred()

func _scene() -> Node:
	var scene: Node = load("res://scenes/flight_test.tscn").instantiate()
	scene.save_enabled = false
	root.add_child(scene)
	return scene

func _physics(n: int) -> void:
	for i in n:
		await physics_frame

## A wall of solid rock across the ship's nose, `ahead` metres forward.
func _wall(scene: Node, ship: Ship, ahead: float) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = AsteroidBody.LAYER
	wall.collision_mask = 0
	var box := BoxShape3D.new()
	box.size = Vector3(40, 40, 2)
	var shape := CollisionShape3D.new()
	shape.shape = box
	wall.add_child(shape)
	scene.add_child(wall)
	var front := -INF
	for coord: Vector3i in ship.grid.coords():
		front = maxf(front, -ShipGrid.cell_center(coord).z)
	wall.global_transform = ship.exterior.global_transform * Transform3D(Basis.IDENTITY,
		Vector3(0, 0, -(front + ShipGrid.CELL_SIZE * 0.5 + ahead + 1.0)))
	return wall

func _run() -> void:
	for speed: float in SPEEDS:
		var scene := _scene()
		await _physics(5)
		var ship: Ship = scene.get_node("Ship")
		ship.flight_computer.set_physics_process(false)
		_wall(scene, ship, 2.0)
		await _physics(2)
		var lost := []
		ship.blocks_lost.connect(func(coords: Array[Vector3i]) -> void: lost.append_array(coords))
		ship.exterior.linear_velocity = -ship.exterior.global_basis.z * speed
		ship.exterior.angular_velocity = Vector3.ZERO
		await _physics(90)
		var staged := {}
		var hurt := 0
		for coord: Vector3i in ship.grid.coords():
			var inst := ship.grid.get_block(coord)
			if inst.damage > 0.0:
				hurt += 1
				var stage: String = BlockDamage.Stage.keys()[BlockDamage.stage_of(inst, ship.catalog.get_def(inst.block_id))]
				staged[stage] = staged.get(stage, 0) + 1
		print("crash %.0f m/s: %d blocks hurt %s, %d knocked off, hull %d%%, crippled '%s'" % [
			speed, hurt, staged, lost.size(), roundi(ship.hull_whole() * 100.0), ship.stats.crippled_reason])
		scene.queue_free()
		await _physics(3)

	var scene := _scene()
	await _physics(5)
	var ship: Ship = scene.get_node("Ship")
	var outer: Array[Vector3i] = []
	for coord: Vector3i in ship.grid.coords():
		if not ship.inner_cells.has(coord) and not ship.grid.has_block(coord + Vector3i(1, 0, 0)):
			outer.append(coord)
		if outer.size() == 3:
			break
	var hits := {}
	for c in outer:
		hits[c] = 100_000.0
	var t0 := Time.get_ticks_usec()
	var removed := ship.take_damage_many(hits)
	var took := (Time.get_ticks_usec() - t0) / 1000.0
	print("three blocks off at once: %d removed, %.1f ms (one rebuild)" % [removed.size(), took])
	t0 = Time.get_ticks_usec()
	ship._rebuild_everything()
	print("one full rebuild alone: %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	quit(0)
