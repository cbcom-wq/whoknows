extends GutTest

## Airlock spec §3.1: an airlock's outer hatch is its one horizontal face onto
## an empty cell. None, or more than one, and the airlock is inert.

var _grid: ShipGrid

func before_each():
	_grid = ShipGrid.new()

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
