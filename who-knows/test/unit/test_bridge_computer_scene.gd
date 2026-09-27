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
	assert_eq(c.cell, Vector3i(-1, 0, -1))
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

## Spec §3.2: you start beside it, and can reach its buttons from there.
func test_its_buttons_are_within_reach_of_where_you_start():
	var avatar: Avatar = _root.get_node("Ship/Interior/Avatar")
	var eye := avatar.global_position + Vector3(0, 1.6, 0)
	for button in ShipComputer.BUTTONS:
		var panel: ReadoutPanel = _computer().panels[button]
		assert_lt(eye.distance_to(panel.global_position), 2.5, "%s within the Interactor's 2.5 m" % button)

## Spec §7.1: the status page's miniature shares the hull's own MultiMeshes.
func test_the_miniature_is_the_hull_s_own_meshes():
	var c := _computer()
	_status(c)
	c._process(0.016)
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
	c._process(0.016)
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
	after._process(0.016)
	for mm in old_meshes:
		assert_false(after.holo.miniature_meshes().has(mm), "the miniature takes the new hull's meshes")
