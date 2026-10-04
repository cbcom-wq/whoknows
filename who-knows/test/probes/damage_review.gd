extends SceneTree

# Damage on the real starter, for the owner (docs/superpowers/specs/
# 2026-10-03-ship-damage-sections-design.md §4, §5, §9): the hull with the port
# sections at 70%, 35% and 0% (scorched from the edges in, then pieces off),
# and the cabin at eye height (1.6 m) with HULL at 60%, 35% and 15%: the helm,
# the corridor and a wall. Run it WITHOUT --headless so it renders:
#
#   godot --path who-knows --resolution 1280x720 --script res://test/probes/damage_review.gd -- <abs out dir>
#
# Outside, a soft light rides with the camera, as in ship_probe.gd: an unlit
# hull renders near-black and says nothing.

var _out := ""
var _ship: Ship

func _initialize() -> void:
	_out = OS.get_cmdline_user_args()[0]
	var scene: Node = load("res://scenes/flight_test.tscn").instantiate()
	# Never the owner's saved game (saving spec §9).
	scene.save_enabled = false
	root.add_child(scene)
	_run.call_deferred(scene)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shot(name: String, settle := 8) -> void:
	await _frames(settle)
	var file := "%s/review_%s.png" % [_out, name]
	root.get_viewport().get_texture().get_image().save_png(file)
	print("render  %s" % file)

const VIEWS := {
	"bow_port": Vector3(-14, 6, -18), "port": Vector3(-22, 3, 2), "above": Vector3(-6, 24, 4),
}

func _hull_shots(tag: String) -> void:
	var cam := Camera3D.new()
	cam.cull_mask = 1 | ExteriorBuilder.OWN_HULL_LAYER
	cam.far = 5000.0
	_ship.exterior.add_child(cam)
	var light := DirectionalLight3D.new()
	light.light_cull_mask = 1 | ExteriorBuilder.OWN_HULL_LAYER
	light.light_energy = 1.4
	light.shadow_enabled = false
	light.rotation_degrees = Vector3(-22, 28, 0)
	cam.add_child(light)
	for view: String in VIEWS:
		var at: Vector3 = VIEWS[view]
		var up := Vector3.UP if absf(at.normalized().y) < 0.9 else Vector3.FORWARD
		cam.transform = Transform3D(Basis.looking_at(-at, up), at)
		cam.current = true
		await _shot("%s_%s" % [tag, view])
	cam.current = false
	cam.queue_free()

## The port sections at `port`, the starboard ones at `starboard` (health).
func _sections(port: float, starboard: float) -> void:
	for id in ShipDamage.SECTIONS:
		var h := port if String(id).begins_with("port") else starboard
		_ship.damage.section_damage[id] = _ship.damage.section_hp[id] * (1.0 - h)
	_ship._apply_view()

func _count() -> Dictionary:
	var out := {}
	for coord: Vector3i in _ship.grid.coords():
		var inst := _ship.grid.get_block(coord)
		var stage: String = BlockDamage.Stage.keys()[BlockDamage.stage_of(inst, _ship.catalog.get_def(inst.block_id))]
		out[stage] = out.get(stage, 0) + 1
	return out

func _eye(cam: Camera3D, cell: Vector3i, offset: Vector3, look_cell: Vector3i, look_offset: Vector3) -> void:
	var eye := DeckPaths.floor_point(cell) + offset + Vector3(0, 1.6, 0)
	var at := DeckPaths.floor_point(look_cell) + look_offset
	cam.global_transform = _ship.interior.global_transform * Transform3D(Basis.IDENTITY, eye)
	cam.look_at(_ship.interior.global_transform * at, Vector3.UP)

func _run(scene: Node) -> void:
	await _frames(5)
	_ship = scene.get_node("Ship")
	_ship.exterior.freeze = true
	_ship.flight_computer.set_physics_process(false)
	await _hull_shots("intact")

	for h in [0.7, 0.35, 0.0]:
		_sections(h, 1.0)
		print("port at %d%%: %d pieces off, now %s" % [roundi(h * 100.0), _ship.damage.lost().size(), _count()])
		await _frames(4)
		await _hull_shots("port%d" % roundi(h * 100.0))

	# Inside, at eye height, at each cabin level.
	var avatar: Avatar = _ship.get_node("Interior/Avatar")
	var acam: Camera3D = avatar.camera
	var cam := Camera3D.new()
	cam.environment = acam.environment
	cam.cull_mask = acam.cull_mask
	cam.fov = acam.fov
	cam.near = 0.05
	_ship.interior.add_child(cam)
	cam.make_current()
	var walk: Array = _ship.interior_builder.walkable_coords()
	# The bridge, from just behind the helm, looking forward at the glass.
	var helm := Vector3i.ZERO
	var front := 99
	for c: Vector3i in walk:
		if c.z < front:
			front = c.z
			helm = c
	var behind := helm + Vector3i(0, 0, 2)
	_eye(cam, behind, Vector3.ZERO, helm + Vector3i(0, 0, -1), Vector3(0, 1.1, 0))
	avatar.place(_ship.interior.global_transform * Transform3D(Basis.IDENTITY, DeckPaths.floor_point(behind) + Vector3(0, 0, 3)))
	for hull in [0.6, 0.35, 0.15]:
		_sections(hull, hull)
		await _frames(4)
		var tag := "hull%d" % roundi(hull * 100.0)
		_eye(cam, behind, Vector3.ZERO, helm + Vector3i(0, 0, -1), Vector3(0, 1.1, 0))
		await _shot("cabin_bridge_" + tag, 12)
		_eye(cam, Vector3i(0, 0, -1), Vector3(0, 0, -0.5), Vector3i(0, 0, 2), Vector3(0, 1.0, 0))
		await _shot("cabin_corridor_" + tag, 12)
	_sections(1.0, 1.0)
	# The bridge computer, intact, glitching and dark, from its operator's spot.
	var table: ShipComputer = _ship.interior_builder.computers()[0]
	var spot := table.cell + InteriorLayout.facing(_ship.grid.get_block(table.cell).orientation)
	_eye(cam, spot, Vector3.ZERO, table.cell, Vector3(0, 1.0, 0))
	for share in [0.0, 0.6, 1.0]:
		_ship.damage.component_damage[&"computer"] = _ship.damage.component_hp[&"computer"] * share
		_ship._apply_view()
		await _frames(4)
		# A stage seen from inside rebuilds the cabin, tables and all.
		table = _ship.interior_builder.computers()[0]
		if share == 0.6:
			table._glitch_in = 0.0
			table._glitch(0.01)
		await _shot("computer_%d" % roundi((1.0 - share) * 100.0), 2)
	_ship.damage.component_damage[&"computer"] = 0.0
	# The helm, seated, with the cockpit damaged and wrecked: the canopy cracks.
	var director: Node = _ship.get_parent().get_node("CameraDirector")
	_ship.seat.interact(avatar)
	await director.transition_finished
	for share in [0.6, 1.0]:
		_ship.damage.component_damage[&"cockpit"] = _ship.damage.component_hp[&"cockpit"] * share
		_ship._apply_view()
		await _shot("seated_cockpit_%d" % roundi((1.0 - share) * 100.0), 12)
	quit(0)
