extends GutTest

## The airlock on a world (docs/superpowers/specs/2026-11-03-desert-world-design.md):
## the room panel will not open onto ground until the ship is down.

const DT := 1.0 / 60.0

class OnWorld extends WorldGravity:
	func on_world_at(_p: Vector3) -> bool:
		return true
	func at(_p: Vector3) -> Vector3:
		return Vector3.ZERO
	func up_at(_p: Vector3) -> Vector3:
		return Vector3.UP
	func altitude_at(_p: Vector3) -> float:
		return INF

var _root: Node
var _ship: Ship
var _airlock: Airlock
var _avatar: Avatar

func test_warp_beats_everything():
	assert_eq(Airlock.refusal_order(true, "Not landed", true), "Not during a warp")

func test_world_refusal_beats_charge():
	assert_eq(Airlock.refusal_order(false, "Uneven ground · tilt 31°", true), "Uneven ground · tilt 31°")

func test_open_space_still_asks_for_charge():
	assert_eq(Airlock.refusal_order(false, "", true), "Charge suit first")

func test_nothing_to_refuse():
	assert_eq(Airlock.refusal_order(false, "", false), "")

func test_base_never_refuses_for_ground():
	var home := GridHome.new()
	assert_eq(home.outside_refusal(), "")
	assert_false(home.on_world())
	home.free()

# --- in the real scene -------------------------------------------------------

func _build() -> void:
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_airlock = _ship.airlocks.get(Vector3i(0, 0, 3))
	_avatar = _root.get_node("Ship/Interior/Avatar")
	_avatar.suit_cell.charge = 0.0
	_airlock.set_physics_process(false)
	_ship.flight_computer.gravity = OnWorld.new()
	_airlock.room.corridor_panel.interact(null)
	_step(AirlockCycle.OPEN_TIME + 0.1)
	_avatar.position = _airlock.room.room_frame.origin
	_step(DT)

func _step(seconds: float) -> void:
	for i in int(round(seconds / DT)):
		_airlock.tick(DT)

func test_flying_over_a_world_refuses():
	_build()
	assert_true(_ship.on_world())
	assert_eq(_airlock.prompt(&"room"), "Not landed")
	assert_eq(_airlock.room.room_panel.readout_text(), "PRESSURE 101 kPa\nNOT LANDED")
	_airlock.room.room_panel.interact(null)
	_step(5.0)
	assert_eq(_airlock.cycle.stage, AirlockCycle.Stage.IDLE)
	assert_eq(_airlock.room.outer_hatch.open_amount, 0.0)

func test_landed_on_a_world_needs_no_charge():
	_build()
	_ship.landing.restore_landed()
	_step(DT)
	assert_eq(_airlock.world_refusal(), "")
	assert_false(_airlock.must_charge())
	assert_eq(_airlock.prompt(&"room"), _airlock.cycle.prompt(&"room"))
	assert_eq(_airlock.prompt(&"room"), "Depressurize")

func test_a_rock_outside_the_hatch_blocks_it():
	_build()
	_ship.landing.restore_landed()
	var body := StaticBody3D.new()
	body.collision_layer = BodyProxy.LAYER
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE
	shape.shape = box
	body.add_child(shape)
	_root.add_child(body)
	var hatch := _airlock.alcove.outer_hatch.global_transform
	body.global_position = hatch * Vector3(0, InteriorProps.HATCH_HEIGHT * 0.5, -1.5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(_airlock.world_refusal(), "Hatch blocked")
	assert_eq(_airlock.prompt(&"room"), "Hatch blocked")

func test_open_space_costs_no_query_and_still_asks_for_charge():
	_build()
	_ship.flight_computer.gravity = null
	assert_false(_ship.on_world())
	assert_eq(_airlock.world_refusal(), "")
	assert_eq(_airlock.prompt(&"room"), "Charge suit first")
