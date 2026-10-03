extends SceneTree

# Crashes in the real starter (docs/superpowers/specs/
# 2026-09-29-health-and-damage-design.md §5.2, §11.2): the ship driven into a
# big still body at 3, 5 and 8 m/s, and what each section and component took;
# then the cost of a whole section's pieces going at once. Headless is fine:
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
		var sections := []
		for id in ShipDamage.SECTIONS:
			if ship.damage.health(id) < 1.0:
				sections.append("%s %d%%" % [id, roundi(ship.damage.health(id) * 100.0)])
		var comps := []
		for comp: StringName in ship.damage.component_damage:
			if ship.damage.component_damage[comp] > 0.0:
				comps.append("%s %d%%" % [comp, roundi(ship.damage.component_health(comp) * 100.0)])
		print("crash %.0f m/s: sections %s, components %s, %d pieces off, hull %d%%, crippled '%s'" % [
			speed, sections, comps, lost.size(), roundi(ship.hull_whole() * 100.0), ship.stats.crippled_reason])
		scene.queue_free()
		await _physics(3)

	var scene := _scene()
	await _physics(5)
	var ship: Ship = scene.get_node("Ship")
	var t0 := Time.get_ticks_usec()
	ship.damage.section_damage[&"port_stern"] = ship.damage.section_hp[&"port_stern"]
	var removed := ship._apply_view()
	var took := (Time.get_ticks_usec() - t0) / 1000.0
	print("a section to nothing at once: %d pieces off, %.1f ms (one rebuild)" % [removed.size(), took])
	t0 = Time.get_ticks_usec()
	ship._rebuild_everything()
	print("one full rebuild alone: %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	quit(0)
