extends GutTest

## The bridge computer in the real flight scene (bridge computer spec §3.2,
## §7, §10): the starter's table, bound to its ship, surviving a rebuild.

var _root: Node
var _ship: Ship

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")

func _computer() -> ShipComputer:
	var all := _ship.interior_builder.computers()
	assert_eq(all.size(), 1, "the starter has one table")
	return all[0]

func _status(c: ShipComputer) -> void:
	for i in c.pages.size():
		if c.pages[i] is StatusPage:
			c.page_index = i

func test_the_starter_has_one_table_bound_to_its_ship():
	var c := _computer()
	assert_eq(c.cell, Vector3i(-1, 0, -3))
	assert_eq(c.ctx.sensors, _ship.sensors)
	assert_eq(c.ctx.store, _ship.quantum.store)
	assert_eq(c.ctx.stats, _ship.stats)
	assert_eq(c.ctx.hull, _ship.exterior)
	assert_eq(c.ctx.exterior_builder, _ship.exterior_builder)

func test_its_buttons_are_interactables_on_the_interior_layer():
	for button in ShipComputer.BUTTONS:
		var panel: ReadoutPanel = _computer().panels[button]
		assert_true(panel.is_in_group("interactable"))
		assert_eq(panel.collision_layer, InteriorKit.LAYER)

## Spec §3.2: you can reach its buttons from where you stand to use it.
func test_its_buttons_are_within_reach_of_its_operator_s_spot():
	var spot := DeckPaths.floor_point(Vector3i(-1, 0, -2))
	var eye := _ship.interior.global_transform * (spot + Vector3(0, 1.6, 0))
	for button in ShipComputer.BUTTONS:
		var panel: ReadoutPanel = _computer().panels[button]
		assert_lt(eye.distance_to(panel.global_position), 2.5, "%s within the Interactor's 2.5 m" % button)

## Being in reach is not enough: the Interactor's ray, looking at a button from
## where its operator stands, must land on that button and not on the table.
func test_looking_at_a_button_from_its_operator_s_spot_finds_the_button():
	await wait_physics_frames(2)
	var spot := DeckPaths.floor_point(Vector3i(-1, 0, -2))
	var eye := _ship.interior.global_transform * (spot + Vector3(0, 1.6, 0))
	var space := _ship.interior.get_world_3d().direct_space_state
	for button in ShipComputer.BUTTONS:
		var panel: ReadoutPanel = _computer().panels[button]
		var query := PhysicsRayQueryParameters3D.create(eye, panel.global_position, Interactor.MASK)
		query.collide_with_areas = true
		var hit := space.intersect_ray(query)
		assert_eq(hit.get("collider"), panel, "looking at %s finds it, not %s" % [button, hit.get("collider")])

## Spec §7.1: the status page's miniature shares the hull's own MultiMeshes.
func test_the_miniature_is_the_hull_s_own_meshes():
	var c := _computer()
	_status(c)
	c.update(0.016)
	var shared := c.holo.miniature_meshes()
	assert_gt(shared.size(), 0)
	assert_eq(shared.size(), _ship.exterior_builder.multimeshes().size())
	for mm in _ship.exterior_builder.multimeshes():
		assert_true(shared.has(mm), "shared, not copied")

func test_the_status_page_reads_the_ship():
	var c := _computer()
	_status(c)
	c.panels[&"page"].last_actor = null
	c.ctx.operator = _root.get_node("Ship/Interior/Avatar")
	c.update(0.016)
	var lines := c.screen_text().split("\n")
	assert_eq(lines[0], "STATUS")
	assert_eq(lines[1], "QE 600 / 1200")
	assert_eq(lines[2], "POWER 36.0 / 31.3 MW")
	assert_eq(lines[3], "SUIT 0%", "the suit starts empty")

func test_a_rebuild_makes_a_new_table_bound_again_with_its_state():
	var before := _computer()
	var last := before.pages.size() - 1
	before.page_index = last
	var old_meshes := _ship.exterior_builder.multimeshes()
	_ship._rebuild_everything()
	assert_false(is_instance_valid(before), "the dressing freed it")
	var after := _computer()
	assert_eq(after.page_index, last, "its page survived")
	assert_eq(after.ctx.stats, _ship.stats, "and it is bound again")
	after.update(0.016)
	for mm in old_meshes:
		assert_false(after.holo.miniature_meshes().has(mm), "the miniature takes the new hull's meshes")

func test_the_table_opens_on_the_map_and_page_reaches_the_status():
	var c := _computer()
	assert_true(c.page() is MapPage)
	assert_true(c.screen_text().begins_with("MAP · 10 KM"))
	c.press(&"page")
	assert_true(c.page() is StatusPage)
	c.press(&"page")
	assert_true(c.page() is MapPage, "and round again")

func test_the_map_s_range_survives_a_rebuild():
	var c := _computer()
	c.press(&"range")
	_ship._rebuild_everything()
	var after := _computer()
	assert_eq((after.pages[0] as MapPage).range_index, 2)

## The start is 700 m off a big rock, so at 10 km there is always one to pick.
func test_the_start_s_big_rock_is_on_the_map():
	var c := _computer()
	var map := c.pages[0] as MapPage
	map.reselect(c.ctx)
	assert_ne(map.selected, &"", "the nearest is selected")
	var rocks := map.targets(c.ctx).filter(func(t: Contact) -> bool: return t.kind == &"rock")
	assert_gt(rocks.size(), 0, "the start's big rock is on the map")
	c.update(0.016)
	assert_gt(c.holo.mark_count(&"ball"), 0, "and in the holo")
	assert_true(c.holo.bracket_shown())

## Nobody at the table, nothing redrawn: the 30 km map places hundreds of
## marks. The scene's camera starts at the avatar's eye, facing the helm.
func test_it_redraws_only_while_someone_can_see_it():
	var c := _computer()
	var cam := _root.get_viewport().get_camera_3d()
	assert_not_null(cam)
	cam.global_position = c.holo.global_position + Vector3(0, 0.2, 1.5)
	cam.look_at(c.holo.global_position)
	assert_true(c._seen(), "looking at it")
	cam.look_at(c.holo.global_position + Vector3(0, 0, 6))
	assert_false(c._seen(), "looking away")

## Spec §8: the course marker is mounted once per view.
func test_the_course_marker_is_mounted_per_view():
	var overlay := _root.get_node("Ship/Canopy/CanopyOverlay").get_children().filter(
		func(n): return n is CourseMarker)
	var screen := _root.get_node("HudRoot/Screen").get_children().filter(
		func(n): return n is CourseMarker)
	assert_eq(overlay.size(), 1, "the cockpit's")
	assert_eq(screen.size(), 2, "the chase camera's and the spacewalk's")
	for m in overlay + screen:
		assert_eq((m as CourseMarker).sensors, _ship.sensors)
	assert_not_null(_root.course_chime, "and a chime for arriving")

## The start is 700 m off a big rock, so at 10 km there is always one to pick.
func test_setting_a_course_at_the_table_reaches_the_ship_s_sensors():
	var c := _computer()
	var map := c.pages[0] as MapPage
	map.reselect(c.ctx)
	while map.selected_contact(c.ctx).kind != &"rock":
		c.press(&"next")
	var rock := map.selected
	c.press(&"big")
	assert_eq(_ship.sensors.course, rock)
	assert_eq(c.panels[&"big"].button_state(), &"cycling", "amber: pressing again clears it")
	assert_eq(c.prompt(&"big"), "Clear course")
	c.press(&"big")
	assert_eq(_ship.sensors.course, &"")

## Spec §6.2: a course to the big rock you start by arrives at once -- you
## are within a kilometre of its surface -- and the table says so.
func test_a_course_to_where_you_are_arrives_and_the_table_says_so():
	var c := _computer()
	var map := c.pages[0] as MapPage
	map.reselect(c.ctx)
	while map.selected_contact(c.ctx).kind != &"rock":
		c.press(&"next")
	var rock := map.selected_contact(c.ctx)
	var off := rock.point.minus(_ship.sensors.focus_point()).length() - rock.radius
	assert_lt(off, ShipSensors.ARRIVE_ROCK, "the start's rock is close")
	watch_signals(_ship.sensors)
	c.press(&"big")
	_ship.sensors.check_course()
	assert_signal_emitted(_ship.sensors, "course_arrived")
	assert_eq(_ship.sensors.course, &"")
	c.update(0.016)
	assert_eq(c.screen_text().split("\n")[2], "ARRIVED")
