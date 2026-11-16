extends "res://test/probes/oasis_render.gd"

## Five Wadees (assets/wadee/wadee_<a|b|c|m|n>.glb, made in Blender by
## tools/blender/wadee_base.py) stood by the pool at WADIS's oasis, rendered on foot with
## the eye 1.6 m over the ground. They are models only: no skeleton, no behaviour yet.
## Run WITHOUT --headless, from who-knows:
##
##   godot --path . --resolution 1280x720 --script res://test/probes/wadee_render.gd -- <abs out dir>

## Where each stands, [east, north] m in the oasis's layout, and the model.
const WADEES := [["a", [-11.4, 18.6]], ["b", [-10.0, 19.0]], ["c", [-8.6, 18.8]], ["m", [-7.1, 19.1]],
	["n", [-5.6, 18.6]]]
## Where they all face, [east, north] m.
const FACING := [-8.6, 24.0]
## [name, where you stand, what you look at, head pitch deg], [east, north] m.
const SPIKE_VIEWS := [
	["wadee_close", [-8.6, 24.4], [-8.6, 18.9], -6.0],
	["wadee_face_b", [-10.0, 20.6], [-10.0, 19.0], -1.0],
	["wadee_face_m", [-7.1, 20.75], [-7.1, 19.1], 1.0],
	["wadee_three_quarter", [-4.0, 22.5], [-8.6, 18.9], -6.0],
	["wadee_pool_behind", [-8.6, 28.0], [-8.6, 0.0], -3.0],
	["wadee_backs", [-8.6, 14.0], [-8.6, 24.0], -6.0],
	["wadee_far", [-8.6, 50.0], [-8.6, 0.0], 0.0],
]

func _run() -> void:
	await _frames(3)
	_fleet = _scene.get("fleet")
	_starter = _scene.get_node("Ship")
	_director = _scene.get_node("CameraDirector")
	_avatar = get_first_node_in_group(Avatar.GROUP)
	_universe = _scene.get_node("Universe")
	_gravity = _scene.get("world_gravity")
	_stars = _scene.get("star_system")
	_scene.set("reload", func() -> void: pass)
	print("gpu     %s" % RenderingServer.get_video_adapter_name())
	var system: SystemRecipe = _scene.get("system")
	_planet = system.body(WORLD_ID)
	for place in system.places():
		if place.id == PLACE_ID:
			_oasis = place
	_starter.flight_computer.assist_enabled = true
	await _sit(_starter)
	await _hide_the_card()
	await _warp_in()
	if not await _to_the_planet():
		print("wadee   no world")
		quit(1)
		return
	_terrain = WorldTerrain.new(_planet.recipe)
	_starter.flight_computer.assist_enabled = true
	_find_the_oasis()
	await _aboard()
	await _starter_on_the_pad()
	_director.stand_now()
	await _frames(3)
	if not await _out_through(_starter.airlocks.values()[0], "", "foot"):
		quit(1)
		return
	var places: PlaceField = _scene.get("places")
	var node := places.loaded(PLACE_ID)
	for w: Array in WADEES:
		var model: Node3D = (load("res://assets/wadee/wadee_%s.glb" % w[0]) as PackedScene).instantiate()
		var at := PlaceField.on_ground(_oasis, _terrain, float(w[1][0]), float(w[1][1]))
		var look := PlaceField.on_ground(_oasis, _terrain, float(FACING[0]), float(FACING[1]))
		var d := look - at
		model.transform = Transform3D(Basis(Vector3.UP, atan2(d.x, d.z)), at)
		node.add_child(model)
		print("wadee   %s at %s (ground) in %s" % [w[0], at, node.name])
	for v: Array in SPIKE_VIEWS:
		await _foot_look(v[0], v[1], v[2], deg_to_rad(float(v[3])))
	await _reading_for("on foot by the pool with five Wadees in view", 5.0)
	_let_go()
	for line in _readings:
		print("        %s" % line)
	quit(0)
