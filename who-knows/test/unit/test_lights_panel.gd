extends GutTest

## Ship exterior spec §7.3: a two-button lights panel on the starboard
## shoulder wall, beside its window, reachable standing.

var _root: Node
var _ship: Ship

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	_root.save_enabled = false
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")

func _panel() -> LightsPanel:
	var panels := _ship.interior_builder.lights_panels()
	assert_eq(panels.size(), 1)
	return panels[0]

func test_it_is_on_the_starboard_shoulder():
	assert_eq(_panel().cell, Vector3i(1, 0, -3))

func test_its_buttons_switch_the_ship_s_lights():
	var p := _panel()
	var flood: ReadoutPanel = p.buttons[&"flood"]
	assert_eq(flood.prompt_text(), "Floods on")
	assert_eq(flood.button_state(), &"", "unlit while off")
	flood.interact(null)
	assert_true(_ship.lights.floods)
	assert_eq(flood.button_state(), &"go", "lit SIGNAL_GO while on")
	assert_eq(flood.prompt_text(), "Floods off")
	_ship.lights.toggle(&"forward")
	assert_eq(p.buttons[&"forward"].button_state(), &"go", "the helm's keys show on the panel too")

func test_it_is_within_reach_standing_beside_the_desk():
	# In front of the desk, in the shoulder's own cell: the wall is 1 m off and
	# the panel is above the desk's side, not behind it.
	var eye: Vector3 = _ship.interior.global_transform * Vector3(2.0, InteriorBuilder.floor_y(Vector3i(1, 0, -3)) + 1.6, -6.0)
	for group in [&"flood", &"forward"]:
		var button: ReadoutPanel = _panel().buttons[group]
		assert_lt(eye.distance_to(button.global_position), 2.5, "within the Interactor's reach")

func test_a_rebuild_binds_the_new_panel():
	_ship._rebuild_everything()
	var p := _panel()
	p.buttons[&"forward"].interact(null)
	assert_true(_ship.lights.forward)

func test_the_switch_has_a_sound():
	assert_true(Synth.NAMES.has(&"light_switch"))
	assert_gt(Synth.build(&"light_switch").get_length(), 0.0)
