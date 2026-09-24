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

## The windows are portals: the canopy SubViewport renders the outside from
## wherever the viewer is, and glass shows it by screen position. The same
## parser defect that drops a HUD property would silently blank every window.
## These read the values back at runtime.

## The canopy camera stands where the viewer would be if the interior were
## inside the hull: the viewer's pose relative to the interior, carried onto
## the hull, with the same field of view.
func test_canopy_portal_carries_the_viewer_onto_the_hull():
	var portal: CanopyPortal = _root.get_node_or_null("Ship/CanopyPortal")
	assert_not_null(portal, "CanopyPortal survived the parse")
	var viewer: Camera3D = _root.get_node("Ship/Interior/Avatar/Head/Camera3D")
	viewer.fov = 71.0
	portal.sync(viewer)
	var hull: Node3D = _root.get_node("Ship/Exterior")
	var interior: Node3D = _root.get_node("Ship/Interior")
	var expected := hull.global_transform * interior.global_transform.affine_inverse() * viewer.global_transform
	var cam: Camera3D = _root.get_node("Ship/Canopy/CanopyCam")
	assert_almost_eq(cam.global_position, expected.origin, Vector3.ONE * 0.001)
	assert_true(cam.global_basis.is_equal_approx(expected.basis), "and faces the same way")
	assert_almost_eq(cam.fov, 71.0, 0.001)

func test_the_old_eye_point_remote_is_gone():
	assert_null(_root.get_node_or_null("Ship/Exterior/CanopyRemote"),
		"the portal moves the canopy camera now; a RemoteTransform3D would fight it")

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

## Glass samples the canopy view at its own screen position, so that view is
## exactly the size of the screen.
func test_canopy_view_matches_the_screen():
	var portal: CanopyPortal = _root.get_node("Ship/CanopyPortal")
	portal.sync(_root.get_node("Ship/Interior/Avatar/Head/Camera3D"))
	var viewport: SubViewport = _root.get_node("Ship/Canopy")
	assert_eq(viewport.size, Vector2i(_root.get_viewport().get_visible_rect().size))

func test_interact_prompt_label_is_present():
	assert_not_null(_root.get_node_or_null("Prompt/Label"), "prompt label survived the parse")

func test_windows_show_the_canopy_view():
	var builder: InteriorBuilder = _root.get_node("Ship/Interior/InteriorBuilder")
	var mat := builder.canopy_material as ShaderMaterial
	assert_not_null(mat, "canopy material is a ShaderMaterial")
	assert_eq(mat.shader, InteriorMaterials.CANOPY_SHADER)
	assert_true(mat.get_shader_parameter(&"canopy_view") is ViewportTexture, "fed by the canopy SubViewport")

## Cockpit pod spec §4: the starter shuttle's helm looks out through a pod,
## so its windshield gets the pod and shoulders instead of a rounded nose.
func test_the_bridge_has_a_cockpit_pod_and_no_nose():
	assert_eq(_root.find_children("CockpitPod", "Node3D", true, false).size(), 1)
	assert_eq(_root.find_children("NoseShell*", "MeshInstance3D", true, false).size(), 0)

func test_old_ceiling_fluorescents_are_gone():
	for i in [1, 2, 3]:
		assert_null(_root.get_node_or_null("Ship/Interior/CeilingLight%d" % i))

## The interior's dim warm mood is on the interior camera alone, so the chase
## view and the canopy feed keep the world's look.
func test_interior_camera_carries_the_interior_mood():
	var cam: Camera3D = _root.get_node("Ship/Interior/Avatar/Head/Camera3D")
	var env := cam.environment
	assert_not_null(env)
	assert_eq(env.resource_path, "res://data/environments/ship_interior.tres")
	assert_true(env.glow_enabled, "bloom is what turns the thin lit strips into light")
	assert_false(env.ssao_enabled, "stylized and cheap: no SSAO")
	assert_eq(env.tonemap_mode, Environment.TONE_MAPPER_FILMIC)
	assert_eq(env.ambient_light_source, Environment.AMBIENT_SOURCE_COLOR)
	assert_almost_eq(env.ambient_light_energy, 0.45, 0.001)

func test_chase_camera_keeps_the_world_look():
	var cam: Camera3D = _root.get_node("Ship/Exterior/ChaseCamera")
	assert_null(cam.environment)

## The interactable seat and the captain's chair the dressing draws come from
## the same frame, so the picture and the thing you sit in cannot drift apart.
func test_pilot_seat_sits_at_the_chairs_frame():
	var builder: InteriorBuilder = _root.get_node("Ship/Interior/InteriorBuilder")
	var seat: Node3D = _root.get_node("Ship/Interior/PilotSeat")
	var frame := InteriorDressing.fixture_frame(builder.layout(), Vector3i(0, 0, -3))
	assert_true(seat.transform.is_equal_approx(frame), "PilotSeat at the chair's fixture frame")
	var canopy_plane := ShipGrid.cell_center(Vector3i(0, 0, -3)).z - ShipGrid.CELL_SIZE * 0.5
	assert_almost_eq(seat.position.z, canopy_plane - InteriorProps.POD_SEAT_DEPTH, 0.001, "out in the pod")

func test_the_seated_eye_is_the_chairs():
	var eye: Node3D = _root.get_node("Ship/Interior/PilotSeat/Eye")
	assert_almost_eq(eye.position, InteriorProps.SEATED_EYE, Vector3.ONE * 0.001,
		"the headrest is built just behind this eye")

func test_the_cabin_has_a_sliding_door_for_every_room():
	var doors := _root.find_children("*", "Node3D", true, false).filter(func(n): return n is SlidingDoor)
	assert_eq(doors.size(), 5)

## Hands and items (docs/superpowers/specs/2026-09-23-hands-and-items-design.md
## §7, §10): what you let go of lands aboard, and the reticle follows the view.
func test_released_items_go_back_aboard_the_ship():
	var avatar: Avatar = _root.get_node("Ship/Interior/Avatar")
	var ship: Ship = _root.get_node("Ship")
	assert_eq(avatar.grasp.world_root, ship.items)

func test_the_reticle_shows_on_foot():
	var reticle := _root.get_node_or_null("Prompt/Reticle")
	assert_not_null(reticle)
	assert_true(reticle is Reticle)
	assert_true(reticle.visible)

func test_third_person_hides_the_reticle_and_refuses_use():
	var director: CameraDirector = _root.get_node("Ship/CameraDirector")
	var avatar: Avatar = _root.get_node("Ship/Interior/Avatar")
	director.cycle_view()
	assert_false(_root.get_node("Prompt/Reticle").visible)
	assert_false(avatar.grasp.first_person)
	director.cycle_view()
	assert_true(_root.get_node("Prompt/Reticle").visible)
	assert_true(avatar.grasp.first_person)

func test_sitting_down_hides_the_reticle_at_once():
	var director: CameraDirector = _root.get_node("Ship/CameraDirector")
	director.sit(_root.get_node("Ship/Interior/PilotSeat"))
	assert_false(_root.get_node("Prompt/Reticle").visible)

func test_a_stow_prompt_wins_over_the_interact_prompt():
	var interactor: Interactor = _root.get_node("Ship/Interior/Avatar/Head/Interactor")
	var avatar: Avatar = _root.get_node("Ship/Interior/Avatar")
	var label: Label = _root.get_node("Prompt/Label")
	interactor.prompt_changed.emit("[F] Take the controls")
	avatar.grasp.prompt_changed.emit(Grasp.STOW_PROMPT)
	assert_eq(label.text, Grasp.STOW_PROMPT)
	avatar.grasp.prompt_changed.emit("")
	assert_eq(label.text, "[F] Take the controls")

func test_third_person_hides_the_hands():
	var director: CameraDirector = _root.get_node("Ship/CameraDirector")
	var avatar: Avatar = _root.get_node("Ship/Interior/Avatar")
	assert_true(avatar.hands.shown)
	director.cycle_view()
	assert_false(avatar.hands.shown)

func test_sitting_down_hides_the_hands():
	var director: CameraDirector = _root.get_node("Ship/CameraDirector")
	var avatar: Avatar = _root.get_node("Ship/Interior/Avatar")
	director.sit(_root.get_node("Ship/Interior/PilotSeat"))
	assert_false(avatar.hands.shown)
