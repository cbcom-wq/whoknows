extends GutTest

## Airlock spec §3.1: an airlock's outer hatch is its one horizontal face onto
## an empty cell. None, or more than one, and the airlock is inert.

var _grid: ShipGrid
var _cat: BlockCatalog

func before_each():
	_grid = ShipGrid.new()
	_cat = BlockCatalog.new()
	for id in [&"hull"]:
		_cat.register(_def(id, BlockDefinition.Occupancy.SOLID))
	for id in [&"deck", &"airlock", &"bunk_room"]:
		_cat.register(_def(id, BlockDefinition.Occupancy.DECK))

func _def(id: StringName, occ: BlockDefinition.Occupancy) -> BlockDefinition:
	var d := BlockDefinition.new()
	d.id = id
	d.occupancy = occ
	return d

func _put(coord: Vector3i, id: StringName) -> void:
	var i := BlockInstance.new()
	i.block_id = id
	_grid.set_block(coord, i)

func test_one_face_onto_open_space_is_the_hatch():
	_put(Vector3i(0, 0, 0), &"airlock")
	_put(Vector3i(0, 0, -1), &"deck")
	_put(Vector3i(1, 0, 0), &"hull")
	_put(Vector3i(-1, 0, 0), &"hull")
	assert_eq(AirlockSite.hatch_normal(_grid, Vector3i.ZERO), Vector3i(0, 0, 1))

func test_floor_and_ceiling_never_count():
	_put(Vector3i(0, 0, 0), &"airlock")
	_put(Vector3i(0, 0, -1), &"deck")
	_put(Vector3i(1, 0, 0), &"hull")
	_put(Vector3i(-1, 0, 0), &"hull")
	assert_false(_grid.has_block(Vector3i(0, 1, 0)), "open above and below")
	assert_eq(AirlockSite.hatch_normal(_grid, Vector3i.ZERO), Vector3i(0, 0, 1))

func test_no_face_onto_open_space_is_inert():
	_put(Vector3i(0, 0, 0), &"airlock")
	for n in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		_put(n, &"hull")
	assert_eq(AirlockSite.hatch_normal(_grid, Vector3i.ZERO), Vector3i.ZERO)

func test_two_faces_onto_open_space_is_inert():
	_put(Vector3i(0, 0, 0), &"airlock")
	_put(Vector3i(0, 0, -1), &"deck")
	_put(Vector3i(1, 0, 0), &"hull")
	assert_eq(AirlockSite.hatch_normal(_grid, Vector3i.ZERO), Vector3i.ZERO)

func test_only_airlocks_have_hatches():
	_put(Vector3i(0, 0, 0), &"deck")
	assert_eq(AirlockSite.hatch_normal(_grid, Vector3i.ZERO), Vector3i.ZERO)

## The inner hatch goes straight through, opposite the outer one, when it can:
## the shape both builders and the layout agree on.
func test_the_door_is_straight_through_when_it_can_be():
	_put(Vector3i(0, 0, 0), &"airlock")
	_put(Vector3i(0, 0, -1), &"deck")
	_put(Vector3i(1, 0, 0), &"deck")
	_put(Vector3i(-1, 0, 0), &"hull")
	assert_eq(AirlockSite.hatch_normal(_grid, Vector3i.ZERO), Vector3i(0, 0, 1))
	assert_eq(AirlockSite.door_normal(_grid, _cat, Vector3i.ZERO), Vector3i(0, 0, -1))

func test_otherwise_the_door_opens_onto_a_side():
	_put(Vector3i(0, 0, 0), &"airlock")
	_put(Vector3i(0, 0, -1), &"hull")
	_put(Vector3i(1, 0, 0), &"deck")
	_put(Vector3i(-1, 0, 0), &"hull")
	assert_eq(AirlockSite.door_normal(_grid, _cat, Vector3i.ZERO), Vector3i(1, 0, 0))

func test_the_door_prefers_open_deck_to_a_room():
	_put(Vector3i(0, 0, 0), &"airlock")
	_put(Vector3i(0, 0, -1), &"bunk_room")
	_put(Vector3i(1, 0, 0), &"deck")
	_put(Vector3i(-1, 0, 0), &"hull")
	assert_eq(AirlockSite.door_normal(_grid, _cat, Vector3i.ZERO), Vector3i(1, 0, 0))

func test_an_airlock_with_nowhere_to_open_onto_has_no_door():
	_put(Vector3i(0, 0, 0), &"airlock")
	for n in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, -1)]:
		_put(n, &"hull")
	assert_eq(AirlockSite.door_normal(_grid, _cat, Vector3i.ZERO), Vector3i.ZERO)
