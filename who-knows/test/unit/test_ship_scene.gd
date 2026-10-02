extends GutTest

## The ship as a scene of its own (docs/superpowers/specs/
## 2026-10-02-many-ships-design.md §3): everything one ship needs to be flown,
## and nothing of yours. Read back at runtime: a `#` in a .tscn drops
## properties without a word (CLAUDE.md).

const SHIP := "res://scenes/ship.tscn"
const FLIGHT := "res://scenes/flight_test.tscn"

## A ship on its own, under a Node3D that stands in for the outside.
func _ship(slot := 3) -> Ship:
	var holder := Node3D.new()
	add_child_autofree(holder)
	var ship: Ship = load(SHIP).instantiate()
	ship.interior_slot = slot
	holder.add_child(ship)
	return ship

func test_the_ship_scene_holds_a_whole_ship():
	var ship := _ship()
	for path in ["Exterior", "Exterior/ExteriorBuilder", "Exterior/ChaseCamera", "FlightComputer",
			"PilotControls", "MotionCoupling", "CanopyPortal", "Canopy", "Canopy/CanopyCam",
			"Canopy/CanopyOverlay/CockpitMarker", "Canopy/CanopyOverlay/HeadingCockpitMarker",
			"Interior", "Interior/InteriorBuilder", "Interior/PilotSeat", "Interior/PilotSeat/Eye"]:
		assert_not_null(ship.get_node_or_null(path), "%s present" % path)
	assert_null(ship.get_node_or_null("CameraDirector"), "the director is the game's, not the ship's")
	assert_null(ship.get_node_or_null("Interior/Avatar"), "and so are you")

func test_every_exported_path_survived_the_parse():
	var ship := _ship()
	var portal := ship.get_node("CanopyPortal")
	for pair in [[ship.flight_computer, "hull_path"], [ship.pilot, "flight_computer_path"],
			[ship.pilot, "hull_path"], [ship.pilot, "interior_path"], [ship.motion, "hull_path"],
			[ship.motion, "interior_path"], [ship.motion, "interior_builder_path"],
			[ship.exterior_builder, "body_path"], [portal, "viewport_path"], [portal, "camera_path"],
			[portal, "hull_path"], [portal, "interior_path"]]:
		var node: Node = pair[0]
		var path: NodePath = node.get(pair[1])
		assert_ne(path, NodePath(""), "%s.%s was not dropped" % [node.name, pair[1]])
		assert_not_null(node.get_node_or_null(path), "%s.%s resolves" % [node.name, pair[1]])
	assert_almost_eq(ship.seat.get_node("Eye").position, Vector3(0, 1.35, 0.45), Vector3.ONE * 0.001)
	assert_eq(ship.seat.collision_layer, 2)
	assert_eq(ship.chase_camera.cull_mask, 5)
	assert_eq(ship.canopy_camera.cull_mask, 1)
	assert_eq((ship.get_node("Canopy") as SubViewport).render_target_update_mode, SubViewport.UPDATE_ALWAYS)

func test_each_ship_draws_its_own_canopy_view():
	var a := _ship(3)
	var b := _ship(4)
	var mat_a := a.interior_builder.canopy_material as ShaderMaterial
	var mat_b := b.interior_builder.canopy_material as ShaderMaterial
	assert_not_null(mat_a, "a canopy material")
	assert_ne(mat_a, mat_b, "one each")
	assert_eq(mat_a.get_shader_parameter(&"canopy_view"), (a.get_node("Canopy") as SubViewport).get_texture())
	assert_eq(mat_b.get_shader_parameter(&"canopy_view"), (b.get_node("Canopy") as SubViewport).get_texture())

func test_the_starter_is_an_instance_of_it():
	var root: Node = load(FLIGHT).instantiate()
	add_child_autofree(root)
	var ship: Ship = root.get_node("Ship")
	assert_eq(ship.scene_file_path, SHIP)
	var director := root.get_node_or_null("CameraDirector") as CameraDirector
	assert_not_null(director, "the director at the root")
	assert_true(root.get_node_or_null("Ship/Interior/Avatar") is Avatar, "you start aboard it")
	assert_eq(ship.outside, root.get_node("Outside"))
	assert_same(ship.seat.director, director, "its seat was handed the director")
	assert_same(ship.pilot.director, director, "and so were its controls")
