extends GutTest

## Boarding a base (habitat modules spec §5.5, §11.3): in through its airlock
## it is where you are; your ship may sleep; the suit's home is the nearer of
## a ship or a base; and a blackout inside wakes you there, at its cost.

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
		return &"rock:boarding"

var _root: Node
var _ship: Ship
var _avatar: Avatar
var _base: Base

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_avatar = _root.get_node("Ship/Interior/Avatar")
	var at := _ship.exterior.global_position + Vector3(0, -40, 60)
	var r := Planting.fit(Ground.new(at.y), ModuleCatalog.get_def(ModuleCatalog.HUB), at, Vector3.FORWARD, 0)
	_base = _root.bases.plant(ModuleCatalog.HUB, r, Ground.new(at.y))
	_base.tick_unfold(HabitatValues.UNFOLD + 0.1)

func _step_in() -> void:
	_avatar.move_aboard(_base.interior, _base.wake_spots()[0])
	_base.airlock_crossed.emit(_avatar, false)

func test_in_through_its_airlock_you_are_in_the_base():
	_step_in()
	assert_same(_root.home, _base)
	assert_same(_root.aboard, _ship, "your ship is still yours")
	assert_true(_base.own, "its interior shows")
	assert_false(_ship.own, "the ship's does not")
	assert_same(_avatar.grasp.world_root, _base.items, "what you put down stays in the base")
	assert_same(_root.get_node("Universe").focus, _base.exterior)

func test_your_ship_may_sleep_while_you_are_in_a_base():
	_step_in()
	assert_null(_root.fleet.aboard.call(), "the fleet holds no ship awake for you")
	assert_same(_root.bases.inside.call(), _base, "the base you are in never sleeps")

func test_boarding_the_ship_again_puts_you_back_aboard():
	_step_in()
	_root.board(_ship, true)
	assert_same(_root.home, _ship)
	assert_true(_ship.own)
	assert_false(_base.own)
	assert_same(_root.fleet.aboard.call(), _ship)

## Your ship is still `aboard` while you are in a base, so walking back in
## through its airlock is no board of the ship you are already aboard.
func test_in_through_your_own_ship_s_airlock_from_a_base_you_are_aboard_again():
	_step_in()
	_avatar.move_aboard(_ship.interior, _ship.wake_spots()[0])
	_ship.airlock_crossed.emit(_avatar, false)
	assert_same(_root.home, _ship)
	assert_true(_ship.own)
	assert_false(_base.own)
	assert_same(_avatar.grasp.world_root, _ship.items)

func test_the_suit_s_home_is_the_nearer_of_a_ship_or_a_base():
	var lock: Airlock = _base.airlocks.values()[0]
	var near_base := _base.exterior.global_transform * (lock.alcove.outer_frame * Vector3(0, 0.3, -6.0))
	_avatar.enter_suit(_base.outside, Transform3D(Basis.IDENTITY, near_base), Vector3.ZERO, _ship.exterior)
	_root.suit_tie.check()
	assert_same(_root.home, _base)
	assert_same(_avatar.hull, _base.exterior, "relative speed is to the base: zero")
	assert_same(_avatar.beacon_source.get_object(), lock, "home is its airlock")

func test_the_other_marker_points_at_the_other_kind_of_home():
	var lock: Airlock = _base.airlocks.values()[0]
	var near_base := _base.exterior.global_transform * (lock.alcove.outer_frame * Vector3(0, 0.3, -6.0))
	_avatar.enter_suit(_base.outside, Transform3D(Basis.IDENTITY, near_base), Vector3.ZERO, _ship.exterior)
	_root.suit_tie.check()
	var t := _avatar.build_telemetry()
	assert_true(t.has_other_beacon)
	assert_eq(t.other_label, "SHIP")

## The debug keys reason from where you are (the final review): in a base,
## with your ship asleep far off, F7 never moves it, F8 refuses, and F6
## spawns ahead of the base, not of your ship's stale engine place.
func test_in_a_base_with_your_ship_asleep_the_debug_keys_reason_from_the_base():
	_step_in()
	_ship.exterior.global_position += Vector3(25000, 0, 0)
	_root.fleet.check_sleep()
	assert_true(_root.fleet.sleeping(_ship), "your ship, 25 km off, asleep")
	var held: UniversePoint = _root.fleet.place_of(_ship)
	assert_false(_root.hop(1), "F7 refuses")
	assert_eq(_root.hop_index, -1, "and hopped nowhere")
	assert_lt(_root.fleet.place_of(_ship).minus(held).length(), 0.001, "your ship stays parked")
	assert_false(_root.board_nearest(), "F8 refuses")
	assert_eq(_root.warp_panel.toast_label.text, "IN A BASE")
	var view := _base.exterior.global_transform
	var expected: Variant = SpawnSpot.find(view, [] as Array[Vector3], Callable(_root, "_rock_near"))
	assert_not_null(expected, "somewhere clear ahead of the base")
	var said: String = _root.spawn_from_library(ShipLibrary.STARTER)
	assert_string_starts_with(said, "SPAWNED")
	var ships: Array[Ship] = _root.fleet.ships()
	var spawned := ships[ships.size() - 1]
	WarpArrival.of(spawned.exterior)._physics_process(WarpArrival.DURATION + 0.01)
	assert_almost_eq(spawned.exterior.global_position, (expected as Transform3D).origin, Vector3.ONE * 0.01,
		"ahead of the base")

func test_blacking_out_in_a_base_wakes_you_there_at_the_base_s_cost():
	_step_in()
	_base.quantum.store.credit(120, &"test")
	var ship_before := _ship.quantum.store.amount
	var paid: int = _avatar.rescue_cost.call(50)
	assert_eq(paid, 50)
	assert_eq(_base.quantum.store.amount, 70, "the base pays")
	assert_eq(_ship.quantum.store.amount, ship_before, "never the ship")
	_root._rescue(_avatar)
	assert_eq(_avatar.get_parent(), _base.interior, "you wake in the base")
