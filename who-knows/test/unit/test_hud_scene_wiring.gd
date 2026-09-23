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

func test_hud_fade_in_matches_the_seat_transition_duration():
	# The bootstrap injects HudRoot.fade_in from CameraDirector.SIT_DURATION
	# so the band finishes fading exactly as the camera settles into the
	# seat. If a future retune changes one without the other, this fails.
	var hud: HudRoot = _root.get_node_or_null("HudRoot")
	assert_almost_eq(
		hud.fade_in, CameraDirector.SIT_DURATION, 0.001,
		"HUD fade-in matches the seat transition"
	)

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
	assert_true(
		marker.get_node_or_null(marker.camera_path) is Camera3D,
		"camera_path resolves to a real camera"
	)

func test_cockpit_marker_lives_inside_the_canopy_viewport():
	# It has to be in the SubViewport: only the camera that rendered the view
	# can project onto it correctly. See design doc §6.
	var marker: VelocityMarker = _root.get_node_or_null(
		"Ship/Canopy/CanopyOverlay/CockpitMarker"
	)
	assert_not_null(marker, "cockpit marker present, inside Ship/Canopy")
	assert_ne(marker.camera_path, NodePath(""), "camera_path was not dropped")
	assert_true(
		marker.get_node_or_null(marker.camera_path) is Camera3D,
		"camera_path resolves to a real camera"
	)

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

## The cockpit view is a SubViewport painted onto the canopy panes, so the
## same parser defect that drops a HUD property would silently turn the
## windshield back into a wall. These read the values back at runtime.

func test_canopy_camera_looks_out_from_the_pilots_eye():
	# Not from a point out ahead of the nose, which renders a view the pilot
	# is not standing at -- the ship appears to be flying from outside itself.
	# Interior and exterior are both grid space, so the eye's interior-local
	# position is exactly where the camera belongs on the hull.
	var remote: RemoteTransform3D = _root.get_node_or_null("Ship/Exterior/CanopyRemote")
	assert_not_null(remote, "CanopyRemote survived the parse")
	var ship: Ship = _root.get_node("Ship")
	var eye: Node3D = _root.get_node_or_null("Ship/Interior/PilotSeat/Eye")
	assert_almost_eq(
		remote.position, ship.interior.to_local(eye.global_position), Vector3.ONE * 0.001,
		"canopy camera sits at the pilot's eye"
	)

func test_canopy_camera_excludes_the_ships_own_hull():
	var cam: Camera3D = _root.get_node_or_null("Ship/Canopy/CanopyCam")
	assert_not_null(cam)
	assert_eq(cam.cull_mask & ExteriorBuilder.OWN_HULL_LAYER, 0,
		"own hull is excluded; the camera is inside it")

func test_chase_camera_still_sees_the_hull():
	var cam: Camera3D = _root.get_node_or_null("Ship/Exterior/ChaseCamera")
	assert_ne(cam.cull_mask & ExteriorBuilder.OWN_HULL_LAYER, 0)

func test_sunlight_reaches_the_hull_layer():
	var light: DirectionalLight3D = _root.get_node_or_null("DirectionalLight3D")
	assert_ne(light.light_cull_mask & ExteriorBuilder.OWN_HULL_LAYER, 0,
		"moving the hull to its own layer must not unlight it")

func test_canopy_viewport_matches_the_windshield_shape():
	# Three panes wide by one tall, so a 3:1 viewport keeps the view from
	# being stretched across the glass.
	var viewport: SubViewport = _root.get_node_or_null("Ship/Canopy")
	assert_almost_eq(float(viewport.size.x) / float(viewport.size.y), 3.0, 0.01)

func test_interact_prompt_label_is_present():
	assert_not_null(_root.get_node_or_null("Prompt/Label"), "prompt label survived the parse")
