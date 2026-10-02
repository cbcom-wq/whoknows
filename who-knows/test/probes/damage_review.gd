extends SceneTree

# Damage on the real starter, for the owner (docs/superpowers/specs/
# 2026-09-29-health-and-damage-design.md §4.5 as amended 2026-10-02, §9):
# the hull before and after a heavy impact on the port side -- intact,
# scorched, charred and knocked off in one picture -- then the cabin at eye
# height (1.6 m) after it: the helm, the corridor and a wrecked wall. Run it
# WITHOUT --headless so it renders:
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

## A heavy impact on the port side: the further to port and forward, the
## harder each block is hit, from nothing on the starboard side to two and a
## half times its hp at the port bow.
func _impact() -> Dictionary:
	var lo := INF
	var hi := -INF
	for coord: Vector3i in _ship.grid.coords():
		lo = minf(lo, coord.x)
		hi = maxf(hi, coord.x)
	var hits := {}
	for coord: Vector3i in _ship.grid.coords():
		var port := 1.0 - (coord.x - lo) / maxf(hi - lo, 1.0)
		var bow := clampf(0.5 - coord.z * 0.08, 0.0, 1.0)
		var share := clampf(port * 2.4 + bow * 0.6 - 0.6, 0.0, 2.5)
		var def := _ship.catalog.get_def(_ship.grid.get_block(coord).block_id)
		if share > 0.0 and def != null:
			hits[coord] = def.hp * share
	return hits

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

	var before := _ship.grid.size()
	var removed := _ship.take_damage_many(_impact())
	print("impact  %d blocks before, %d knocked off, now %s" % [before, removed.size(), _count()])
	await _frames(4)
	await _hull_shots("hit")

	# Inside, at eye height, after the same impact.
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
	await _shot("cabin_bridge", 12)
	# The corridor, from the bridge, looking aft.
	_eye(cam, Vector3i(0, 0, -1), Vector3(0, 0, -0.5), Vector3i(0, 0, 2), Vector3(0, 1.0, 0))
	await _shot("cabin_corridor", 12)
	# A wrecked port wall, close: the char, and its sparks.
	var wall_cell := Vector3i.ZERO
	var wall_dir := Vector3i(-1, 0, 0)
	for c: Vector3i in walk:
		var w := _ship.grid.get_block(c + wall_dir)
		if w != null and BlockDamage.stage_of(w, _ship.catalog.get_def(w.block_id)) == BlockDamage.Stage.WRECKED \
				and _ship.interior_builder.layout().zone_at(c) == &"common":
			wall_cell = c
			break
	_eye(cam, wall_cell, Vector3(0.6, 0, 0.9), wall_cell, Vector3(-1.0, 1.2, -0.3))
	await _shot("cabin_wall", 12)
	await _shot("cabin_wall_sparks", 20)
	quit(0)
