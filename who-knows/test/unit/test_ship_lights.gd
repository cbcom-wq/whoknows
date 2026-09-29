extends GutTest

## Ship exterior spec §6.2, §7.1: the lights' state, their spot lights and
## beams, low power, and the save.

var _lights: ShipLights
var _flood_lens: MeshInstance3D
var _forward_lens: MeshInstance3D
var _glow: ShaderMaterial

const MOUNTS := [
	{"group": &"flood", "position": Vector3(-4, -1, -6), "normal": Vector3.DOWN, "aim": Vector3(-0.3, -0.9, -0.3)},
	{"group": &"flood", "position": Vector3(4, -1, -6), "normal": Vector3.DOWN, "aim": Vector3(0.3, -0.9, -0.3)},
	{"group": &"forward", "position": Vector3(-4, 0, -6), "normal": Vector3.FORWARD, "aim": Vector3(0, -0.087, -0.996)},
]

func _lens() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.material_override = HullMaterials.glow_instance(0.0)
	add_child_autofree(mi)
	return mi

func before_each():
	_lights = ShipLights.new()
	add_child_autofree(_lights)
	_flood_lens = _lens()
	_forward_lens = _lens()
	_glow = HullMaterials.glow_instance(0.0)
	_bind()

func _bind() -> void:
	var mounts: Array = []
	for m in MOUNTS:
		var d: Dictionary = m.duplicate()
		d["aim"] = (d["aim"] as Vector3).normalized()
		mounts.append(d)
	_lights.bind(mounts, {&"flood": _flood_lens, &"forward": _forward_lens}, _glow)

func _energy(mi: MeshInstance3D) -> float:
	return (mi.material_override as ShaderMaterial).get_shader_parameter(&"energy")

func test_one_spot_light_per_mount_aimed_along_it():
	assert_eq(_lights.spots(&"flood").size(), 2)
	assert_eq(_lights.spots(&"forward").size(), 1)
	var spot: SpotLight3D = _lights.spots(&"forward")[0]
	assert_almost_eq(-spot.global_basis.z, MOUNTS[2]["aim"].normalized(), Vector3.ONE * 0.001, "a spot shines along -z")
	assert_eq(spot.light_cull_mask, 1 | ExteriorBuilder.OWN_HULL_LAYER, "never the interior")
	assert_true(spot.shadow_enabled, "the forward lights cast shadows")
	assert_false(_lights.spots(&"flood")[0].shadow_enabled)
	assert_almost_eq(spot.spot_angle, 11.0, 0.0001, "half the 22 deg cone")
	assert_almost_eq(spot.spot_range, 220.0, 0.0001)
	assert_eq(_lights.beam(&"forward").layers, ShipLights.BEAM_LAYER, "beams on the world's layer")

func test_everything_starts_off():
	assert_false(_lights.floods)
	assert_false(_lights.forward)
	for spot in _lights.spots(&"flood"):
		assert_false(spot.visible)
	assert_false(_lights.beam(&"flood").visible)
	assert_eq(_energy(_flood_lens), 0.0)
	assert_almost_eq(_glow.get_shader_parameter(&"energy"), HullMaterials.WINDOW_ENERGY, 0.0001, "the windows glow")

func test_toggling_a_group_lights_it_and_says_so():
	watch_signals(_lights)
	_lights.toggle(&"flood")
	assert_signal_emit_count(_lights, "changed", 1)
	assert_true(_lights.floods)
	assert_false(_lights.forward, "the groups are separate")
	for spot in _lights.spots(&"flood"):
		assert_true(spot.visible)
	assert_true(_lights.beam(&"flood").visible)
	assert_false(_lights.beam(&"forward").visible)
	assert_gt(_energy(_flood_lens), 0.0)
	assert_eq(_energy(_forward_lens), 0.0)
	_lights.set_group(&"flood", true)
	assert_signal_emit_count(_lights, "changed", 1, "no change, no signal")

func test_low_power_halves_the_lights_and_the_windows():
	_lights.set_group(&"forward", true)
	var full: float = _lights.spots(&"forward")[0].light_energy
	_lights.apply_power(true)
	assert_almost_eq(_lights.spots(&"forward")[0].light_energy, full * ShipLights.LOW_POWER_LEVEL, 0.0001)
	assert_almost_eq(_glow.get_shader_parameter(&"energy"), HullMaterials.WINDOW_ENERGY * ShipLights.LOW_POWER_LEVEL, 0.0001)
	assert_true(_lights.spots(&"forward")[0].visible, "the lights still work in low power")
	_lights.apply_power(false)
	assert_almost_eq(_lights.spots(&"forward")[0].light_energy, full, 0.0001)

func test_with_no_plant_the_lights_run_at_full_power():
	_lights.quantum = null
	_lights._process(0.016)
	assert_eq(_lights.exterior_level, 1.0)
	assert_eq(_lights.interior_level, 1.0)

func test_a_rebuild_keeps_the_lights_on():
	_lights.set_group(&"flood", true)
	var old: SpotLight3D = _lights.spots(&"flood")[0]
	_bind()
	assert_false(is_instance_valid(old), "the old lights are freed at once")
	assert_true(_lights.floods)
	for spot in _lights.spots(&"flood"):
		assert_true(spot.visible, "the new lights come on as the old were")

func test_the_save_round_trips():
	_lights.set_group(&"forward", true)
	var d := _lights.to_dict()
	assert_eq(d, {"floods": false, "forward": true})
	var other := ShipLights.new()
	add_child_autofree(other)
	other.from_dict(d)
	assert_true(other.forward)
	assert_false(other.floods)

func test_a_save_without_lights_loads_them_off():
	_lights.set_group(&"flood", true)
	_lights.from_dict({})
	assert_false(_lights.floods)
	assert_false(_lights.forward)

## The real ship: its lights live on the hull, bound after every rebuild.
func test_the_flight_scene_s_ship_has_its_lights_on_the_hull():
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	root.save_enabled = false
	add_child_autofree(root)
	var ship: Ship = root.get_node("Ship")
	assert_true(ship.lights is ShipLights)
	assert_eq(ship.lights.get_parent(), ship.exterior, "carried by the floating origin with the hull")
	assert_eq(ship.lights.spots(&"flood").size(), 5)
	assert_eq(ship.lights.spots(&"forward").size(), 2)
	assert_true(ship.to_dict(root.get_node("Universe")).has("lights"))
