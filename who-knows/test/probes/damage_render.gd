extends SceneTree

# Damage in the real starter, for the owner (docs/superpowers/specs/
# 2026-09-29-health-and-damage-design.md §9, §11.2): an interior wall
# damaged beside a wrecked one at eye height (1.6 m), and the hull outside
# with a damaged, a wrecked and a knocked-off block, then the burst. Run it
# WITHOUT --headless so it renders:
#
#   godot --path who-knows --resolution 1280x720 --script res://test/probes/damage_render.gd -- <abs out dir>
#
# Writes damage_inside, damage_inside_intact, damage_outside and
# damage_burst.png.

var _out := ""
var _ship: Ship
var _cam: Camera3D

func _initialize() -> void:
	_out = OS.get_cmdline_user_args()[0]
	var scene: Node = load("res://scenes/flight_test.tscn").instantiate()
	# Never the owner's saved game (saving spec §9): a windowed run would load and overwrite it.
	scene.save_enabled = false
	root.add_child(scene)
	_run.call_deferred(scene)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shot(name: String, settle := 8) -> void:
	await _frames(settle)
	var file := "%s/damage_%s.png" % [_out, name]
	root.get_viewport().get_texture().get_image().save_png(file)
	print("render  %s" % file)

func _hp(coord: Vector3i) -> float:
	return float(_ship.catalog.get_def(_ship.grid.get_block(coord).block_id).hp)

## Two walkable cells side by side along z, each with a hull wall on +x or -x.
func _wall_pair() -> Array:
	var walk: Array = _ship.interior_builder.walkable_coords()
	for c: Vector3i in walk:
		for side in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0)]:
			var next := c + Vector3i(0, 0, 1)
			if not walk.has(next):
				continue
			var a := _ship.grid.get_block(c + side)
			var b := _ship.grid.get_block(next + side)
			if a != null and b != null and a.block_id == &"hull" and b.block_id == &"hull":
				return [c, next, side]
	return []

func _run(scene: Node) -> void:
	await _frames(5)
	_ship = scene.get_node("Ship")
	_ship.exterior.freeze = true
	var avatar: Avatar = _ship.get_node("Interior/Avatar")
	var acam: Camera3D = avatar.camera
	_cam = Camera3D.new()
	_cam.environment = acam.environment
	_cam.cull_mask = acam.cull_mask
	_cam.fov = acam.fov
	_cam.near = 0.05
	_ship.interior.add_child(_cam)
	_cam.make_current()

	# 1. Inside: a wall at eye height, intact, then one cell damaged and the next wrecked.
	var pair := _wall_pair()
	if pair.is_empty():
		push_error("no pair of hull walls side by side")
		quit(1)
		return
	var c: Vector3i = pair[0]
	var next: Vector3i = pair[1]
	var side: Vector3i = pair[2]
	print("walls behind %s and %s toward %s" % [c, next, side])
	var eye := DeckPaths.floor_point(c) + Vector3(0, 1.6, 0.5) - Vector3(side) * 0.8
	var target := (DeckPaths.floor_point(c) + DeckPaths.floor_point(next)) * 0.5 + Vector3(side) * 1.0 + Vector3(0, 1.1, 0)
	_cam.global_transform = _ship.interior.global_transform * Transform3D(Basis.IDENTITY, eye)
	_cam.look_at(_ship.interior.global_transform * target, Vector3.UP)
	avatar.place(_ship.interior.global_transform * Transform3D(Basis.IDENTITY, DeckPaths.floor_point(c) - Vector3(side) * 0.8 + Vector3(0, 0, -3)))
	await _shot("inside_intact")
	_ship.take_damage(c + side, _hp(c + side) * 0.6)
	_ship.take_damage(next + side, _hp(next + side) * 1.1)
	await _frames(3)
	await _shot("inside")

	# 2. Outside, through the chase camera: three blocks in a row on top.
	var face := Vector3i(0, 1, 0)
	var flank: Array[Vector3i] = []
	var top := -99
	for coord: Vector3i in _ship.grid.coords():
		top = maxi(top, coord.y)
	for coord: Vector3i in _ship.grid.coords():
		if coord.y != top:
			continue
		var row: Array[Vector3i] = [coord, coord + Vector3i(0, 0, 1), coord + Vector3i(0, 0, 2)]
		var ok := true
		for cell in row:
			if not _ship.grid.has_block(cell) or _ship.grid.has_block(cell + face) \
					or BlockDamage.KEEP.has(_ship.grid.get_block(cell).block_id):
				ok = false
		if ok:
			flank = row
			break
	if flank.is_empty():
		push_error("no three blocks in a row on top")
		quit(1)
		return
	print("top row %s: %s" % [flank, flank.map(func(c): return _ship.grid.get_block(c).block_id)])
	var chase: Camera3D = _ship.get_node("Exterior/ChaseCamera")
	var outer := Camera3D.new()
	outer.environment = chase.environment
	outer.cull_mask = chase.cull_mask
	outer.attributes = chase.attributes
	outer.fov = 50.0
	outer.near = 0.05
	outer.far = 30000.0
	_ship.exterior.add_child(outer)
	var mid := ShipGrid.cell_center(flank[1])
	outer.position = mid + Vector3(5.0, 7.0, 7.0)
	outer.look_at(_ship.exterior.to_global(mid), _ship.exterior.global_basis.y)
	outer.make_current()
	_ship.take_damage(flank[0], _hp(flank[0]) * 0.6)
	_ship.take_damage(flank[1], _hp(flank[1]) * 1.1)
	await _shot("outside")
	_ship.take_damage(flank[2], _hp(flank[2]) * 2.0)
	await _shot("burst", 12)
	await _shot("hole", 150)
	quit(0)
