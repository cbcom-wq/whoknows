extends GutTest

## The quantum link (habitat modules spec §6.1, row 9): QE between your ship's
## store and the base's, both ways, without loss, within 1 km.

func test_it_moves_without_loss():
	var ship := QuantumStore.new(1200, 600)
	var base := QuantumStore.new(400, 0)
	assert_eq(QuantumLink.move(ship, base, 50), 50)
	assert_eq(ship.amount, 550)
	assert_eq(base.amount, 50)
	assert_eq(QuantumLink.move(base, ship, 50), 50)
	assert_eq(ship.amount, 600)

func test_it_respects_both_stores():
	var ship := QuantumStore.new(1200, 30)
	var base := QuantumStore.new(400, 390)
	assert_eq(QuantumLink.move(ship, base, 50), 10, "only room for 10")
	assert_eq(QuantumLink.move(base, ship, 1000), 400, "only 400 to give")

func test_its_reach_is_a_kilometre():
	assert_true(QuantumLink.in_reach(Vector3.ZERO, Vector3(999, 0, 0)))
	assert_false(QuantumLink.in_reach(Vector3.ZERO, Vector3(1001, 0, 0)))

class Ground extends PlantSurface:
	var y := 0.0
	func _init(p_y: float) -> void:
		y = p_y
	func cast(from: Vector3, dir: Vector3, reach: float) -> Dictionary:
		var to := from + dir * reach
		if from.y >= y and to.y <= y:
			return {"position": from.lerp(to, (from.y - y) / (from.y - to.y)), "normal": Vector3.UP}
		return {}
	func fixed() -> bool:
		return true
	func site_id() -> StringName:
		return &"rock:link"

func test_the_hub_s_panel_moves_qe_in_fifties_and_says_no_link_when_far():
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(root)
	var ship: Ship = root.get_node("Ship")
	var at := ship.exterior.global_position + Vector3(0, -40, 60)
	var r := Planting.fit(Ground.new(at.y), ModuleCatalog.get_def(ModuleCatalog.HUB), at, Vector3.FORWARD, 0)
	var base: Base = root.bases.plant(ModuleCatalog.HUB, r, Ground.new(at.y))
	base.tick_unfold(HabitatValues.UNFOLD + 0.1)
	var before := ship.quantum.store.amount
	assert_not_null(base.link)
	assert_eq(base.link.lines()[0], "SHIP %d · BASE 0" % before)
	base.link.press(&"to_base")
	assert_eq(base.quantum.store.amount, HabitatValues.LINK_STEP)
	assert_eq(ship.quantum.store.amount, before - HabitatValues.LINK_STEP)
	base.link.press(&"to_ship")
	assert_eq(ship.quantum.store.amount, before)
	ship.exterior.global_position += Vector3(5000, 0, 0)
	assert_eq(base.link.lines()[0], "NO LINK")

## Ground of its own: each hub founds a base, not joins the last.
class OwnGround extends Ground:
	var id := &"rock:link"
	func site_id() -> StringName:
		return id

## The panel stands on the deck beside the airlock, its back to the hub's
## front wall and its face to the room, however the hub was turned: the floor
## a step in front of it is the hub's, and it does not poke out of its cell.
func test_the_panel_faces_into_the_hub_however_it_is_turned():
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(root)
	var ship: Ship = root.get_node("Ship")
	var hub := ModuleCatalog.get_def(ModuleCatalog.HUB)
	for turns in 4:
		var at := ship.exterior.global_position + Vector3(turns * 60.0, -40, 60)
		var ground := OwnGround.new(at.y)
		ground.id = StringName("rock:link%d" % turns)
		var r := Planting.fit(ground, hub, at, Vector3.FORWARD, turns)
		var base: Base = root.bases.plant(ModuleCatalog.HUB, r, ground)
		base.tick_unfold(HabitatValues.UNFOLD + 0.1)
		var turn := Basis(Vector3.UP, PI * 0.5 * turns)
		var spot := ModuleDefinition.turn_cell(Vector3i(0, 0, 1), turns, hub.size)
		var p := base.link.position
		assert_almost_eq(base.link.basis.z, turn * Vector3.FORWARD, Vector3.ONE * 0.001,
			"turned %d: faces away from the front wall" % turns)
		var stand := p + base.link.basis.z * 1.2
		var walkable := base.interior_builder.walkable_coords()
		assert_has(walkable, _cell_of(stand), "turned %d: a step in front of it is the hub's floor" % turns)
		assert_eq(_cell_of(p - base.link.basis.z * LinkPanel.PEDESTAL.z * 0.5), spot,
			"turned %d: its back stays in its own cell" % turns)

static func _cell_of(p: Vector3) -> Vector3i:
	return Vector3i(roundi(p.x / ShipGrid.CELL_SIZE), roundi(p.y / ShipGrid.CELL_SIZE), roundi(p.z / ShipGrid.CELL_SIZE))
