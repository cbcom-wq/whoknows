extends GutTest

## Guards the flight scene's HUD wiring against the Godot 4.5.1 text-scene
## parser defect described in CLAUDE.md, where a '#' comment adjacent to a
## node or property line silently drops that property -- or the whole next
## node -- with no error output at all. Checking for load warnings does not
## catch it. Reading the values back at runtime does.

var _root: Node

func before_each():
	var scene: PackedScene = load("res://scenes/flight_test.tscn")
	assert_not_null(scene, "flight_test.tscn loads")
	_root = scene.instantiate()
	add_child_autofree(_root)

func test_hud_root_survived_the_parse():
	var hud := _root.get_node_or_null("HudRoot")
	assert_not_null(hud, "HudRoot node present")
	assert_true(hud is HudRoot, "and carries its script")

func test_hud_root_screen_path_survived_the_parse():
	var hud: HudRoot = _root.get_node_or_null("HudRoot")
	assert_ne(hud.screen_path, NodePath(""), "screen_path was not dropped")
	assert_not_null(hud.get_node_or_null(hud.screen_path), "and still resolves")

func test_band_holds_both_panels():
	assert_not_null(
		_root.get_node_or_null("HudRoot/Screen/Band/Row/VelocityPanel"),
		"velocity panel present"
	)
	assert_not_null(
		_root.get_node_or_null("HudRoot/Screen/Band/Row/AttitudePanel"),
		"attitude panel present"
	)

func test_band_carries_its_chrome_script():
	# Without HudBand the readouts float over the scene with no lit surface
	# behind them, which is the layout that was explicitly not chosen.
	var band := _root.get_node_or_null("HudRoot/Screen/Band")
	assert_not_null(band, "band present")
	assert_true(band is HudBand, "band carries its script")

func test_chase_marker_camera_path_survived_the_parse():
	var marker: VelocityMarker = _root.get_node_or_null("HudRoot/Screen/ChaseMarker")
	assert_not_null(marker, "chase marker present")
	assert_ne(marker.camera_path, NodePath(""), "camera_path was not dropped")

func test_cockpit_marker_lives_inside_the_canopy_viewport():
	# It has to be in the SubViewport: only the camera that rendered the view
	# can project onto it correctly. See design doc §6.
	var marker: VelocityMarker = _root.get_node_or_null(
		"Ship/Canopy/CanopyOverlay/CockpitMarker"
	)
	assert_not_null(marker, "cockpit marker present, inside Ship/Canopy")
	assert_ne(marker.camera_path, NodePath(""), "camera_path was not dropped")

func test_camera_director_exports_survived_the_parse():
	# This scene's other exported NodePaths are re-verified here because the
	# same edit touches the same file.
	var director: CameraDirector = _root.get_node_or_null("Ship/CameraDirector")
	assert_not_null(director, "CameraDirector present")
	assert_ne(director.chase_camera_path, NodePath(""), "chase_camera_path intact")
	assert_ne(director.flight_computer_path, NodePath(""), "flight_computer_path intact")

func test_camera_director_announces_piloting_changes():
	var director: CameraDirector = _root.get_node_or_null("Ship/CameraDirector")
	assert_has_signal(director, "piloting_changed")
