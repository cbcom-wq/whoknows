extends GutTest

## Walking on a world (docs/superpowers/specs/2026-11-03-desert-world-design.md
## §5.5; docs/superpowers/specs/2026-09-23-planetfall-design.md §11): the
## avatar's third mode, FIELD -- the world's gravity, up away from its centre,
## a jump and a lamp, the suit's thrusters off -- and PLATING pinned as it was.

const DT := 1.0 / 60.0

## A pull of the test's choosing, counting how often anything asks.
class FakeGravity extends WorldGravity:
	var pull := Vector3.ZERO
	var on := true
	var asked := 0
	func at(_p: Vector3) -> Vector3:
		asked += 1
		return pull
	func up_at(_p: Vector3) -> Vector3:
		asked += 1
		return -pull.normalized() if pull != Vector3.ZERO else Vector3.ZERO
	func on_world_at(_p: Vector3) -> bool:
		asked += 1
		return on
	func altitude_at(_p: Vector3) -> float:
		return INF

## The ship's side of a world (test_airlock_world.gd's): on one, and holding
## itself up for free, so the hull never moves.
class OnWorld extends WorldGravity:
	func on_world_at(_p: Vector3) -> bool:
		return true
	func at(_p: Vector3) -> Vector3:
		return Vector3.ZERO
	func up_at(_p: Vector3) -> Vector3:
		return Vector3.UP
	func altitude_at(_p: Vector3) -> float:
		return INF

static func _fake_gravity(pull: Vector3) -> FakeGravity:
	var g := FakeGravity.new()
	g.pull = pull
	return g

static func _action(action: StringName) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev

func after_each():
	for action in [&"move_forward", &"sprint"]:
		Input.action_release(action)
	AudioBuses.set_air(1.0)

# --- the rules, pure ---------------------------------------------------------

func test_field_basis_keeps_heading():
	var b := Basis(Vector3.UP, 0.7)
	var tilted_up := Vector3(0.1, 1.0, 0.0).normalized()
	var nb := Avatar.field_basis(b, tilted_up)
	assert_almost_eq(nb.y, tilted_up, Vector3.ONE * 1e-5)
	var fwd_before := Plane(Vector3.UP, 0).project(-b.z).normalized()
	var fwd_after := Plane(tilted_up, 0).project(-nb.z).normalized()
	assert_almost_eq(fwd_after, Plane(tilted_up, 0).project(fwd_before).normalized(), Vector3.ONE * 1e-4)

func test_field_basis_is_still_a_rotation():
	var nb := Avatar.field_basis(Basis(Vector3.UP, 0.7), Vector3(0.3, 1.0, -0.2).normalized())
	assert_almost_eq(nb.determinant(), 1.0, 1e-5)
	assert_true(nb.is_equal_approx(nb.orthonormalized()))

## Upright already: nothing turns.
func test_field_basis_leaves_an_upright_body_alone():
	var b := Basis(Vector3.UP, 1.2)
	assert_true(Avatar.field_basis(b, Vector3.UP).is_equal_approx(b))

## Looking straight along the new up, there is no heading to lay on the ground:
## the shortest arc still stands you on it.
func test_field_basis_with_forward_along_the_new_up_still_stands_you_up():
	var nb := Avatar.field_basis(Basis.IDENTITY, Vector3.FORWARD)
	assert_almost_eq(nb.y, Vector3.FORWARD, Vector3.ONE * 1e-5)
	assert_almost_eq(nb.determinant(), 1.0, 1e-5)

func test_field_velocity_walks_tangent_and_falls_along_up():
	var v := Avatar.field_velocity(Vector3(0, 0, 0), Vector3.UP, Vector3(0, 0, -1), 4.0, 30.0, Vector3(0, -5.0, 0), 0.1)
	assert_almost_eq(v, Vector3(0, -0.5, -3.0), Vector3.ONE * 1e-5)

## Falling is left alone by walking: only the part along the ground changes.
func test_field_velocity_leaves_the_fall_alone():
	var v := Avatar.field_velocity(Vector3(1, -2, 0), Vector3.UP, Vector3.ZERO, 4.0, 30.0, Vector3.ZERO, 0.01)
	assert_almost_eq(v, Vector3(0.7, -2, 0), Vector3.ONE * 1e-5)

# --- a lone avatar -------------------------------------------------------------

var _world: Node3D
var _avatar: Avatar

## An avatar standing at the origin of `_world`, which stands in for the world
## outside; what it lets go of aboard lands in a node of its own.
func _lone() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	_avatar = load("res://scenes/avatar.tscn").instantiate()
	_world.add_child(_avatar)
	var aboard := Node3D.new()
	aboard.name = "AboardItems"
	_world.add_child(aboard)
	_avatar.grasp.world_root = aboard

## Ground on the world's layer: a wide slab whose top is y = 0.
func _ground() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = BodyProxy.LAYER
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	var shape := CollisionShape3D.new()
	shape.shape = box
	body.add_child(shape)
	_world.add_child(body)
	body.global_position = Vector3(0, -0.5, 0)

func _field(at := Vector3.ZERO, pull := Vector3(0, -5, 0)) -> FakeGravity:
	var g := _fake_gravity(pull)
	_avatar.gravity = g
	_avatar.enter_field(_world, Transform3D(Basis.IDENTITY, at), Vector3.ZERO, null)
	return g

## Planetfall §11.1: aboard, gravity is the plating's alone, straight down -Y,
## and the world's is never asked, whatever it would say.
func test_plating_is_unchanged():
	_lone()
	_avatar.global_position = Vector3(0, 10, 0)
	var g := _fake_gravity(Vector3(5, 0, 0))   # would pull sideways if asked
	_avatar.gravity = g
	_avatar._physics_process(DT)
	assert_eq(_avatar.mode, Avatar.Mode.PLATING)
	assert_almost_eq(_avatar.velocity, Vector3(0, -9.8 / 60.0, 0), Vector3.ONE * 1e-6)
	assert_eq(g.asked, 0, "PLATING never asks the world")
	assert_eq(_avatar.up_direction, Vector3.UP)

## Ruling 3, the other half: a spacewalk feels no world's pull, however hard it
## would pull -- the world is never asked, and a tick leaves you drifting as you
## were.
func test_on_a_spacewalk_no_world_pulls():
	_lone()
	var g := _fake_gravity(Vector3(0, -50, 0))
	_avatar.gravity = g
	_avatar.enter_suit(_world, Transform3D.IDENTITY, Vector3(0.5, 0, 0), null)
	_avatar.suit_cell.charge = SuitCell.CAPACITY
	_avatar.suit_assist = false   # the assist's braking is not the world's
	_avatar._physics_process(DT)
	assert_eq(_avatar.mode, Avatar.Mode.SUIT)
	assert_eq(g.asked, 0, "SUIT never asks the world")
	assert_almost_eq(_avatar.velocity, Vector3(0.5, 0, 0), Vector3.ONE * 1e-6, "drifting as you were")

func test_out_onto_a_world_you_are_outside_on_your_feet():
	_lone()
	var root := _avatar.grasp.world_root
	_field(Vector3(0, 0.02, 0))
	assert_eq(_avatar.mode, Avatar.Mode.FIELD)
	assert_true(_avatar.is_outside())
	assert_true(_avatar.is_in_group(Universe.EXTERIOR_SPACE), "the floating origin moves you")
	assert_true(_avatar.is_in_group(AsteroidStream.SPACE_ANCHOR), "the ground goes solid round you")
	assert_eq(_avatar.motion_mode, CharacterBody3D.MOTION_MODE_GROUNDED)
	assert_eq(_avatar.collision_mask, Avatar.SUIT_MASK, "your hull, the ground, items, rocks, creatures")
	assert_false(_avatar.grasp.suspended, "hands work on the ground")
	assert_eq(_avatar.grasp.world_root, _world, "what you let go of lands outside")
	assert_ne(root, _world)
	assert_eq(_avatar.grasp.ray_mask, Grasp.OUTSIDE_RAY_MASK, "the hands' ray stops at hulls, ground and rocks")
	assert_null(_avatar.camera.environment, "the world's look")
	assert_eq(_avatar.up, Vector3.UP)
	assert_eq(_avatar.up_direction, Vector3.UP)

## Fix round 1: a thing let go against the ground lands on your side of it,
## never 0.3 m inside -- the hands' ray stops at the ground outside.
func test_on_a_world_a_drop_against_the_ground_lands_on_your_side():
	_lone()
	_field()
	_avatar.set_physics_process(false)
	var eye := _avatar.grasp.aim()
	var forward := -eye.basis.z
	var wall := StaticBody3D.new()
	wall.collision_layer = BodyProxy.LAYER
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.1)
	var shape := CollisionShape3D.new()
	shape.shape = box
	wall.add_child(shape)
	_world.add_child(wall)
	wall.global_transform = Transform3D(eye.basis, eye.origin + forward * 0.6)
	await wait_physics_frames(1)
	var at: Vector3 = _avatar.grasp._clear_point(eye.origin + forward * 1.0, 0.2)
	var along := (at - eye.origin).dot(forward)
	assert_lt(along, 0.55 - 0.2, "short of the ground's face by the thing's half size")
	assert_gt(along, 0.0, "and still in front of you")

func test_on_the_suit_and_aboard_you_are_where_you_were():
	_lone()
	assert_false(_avatar.is_outside(), "aboard")
	_avatar.enter_suit(_world, Transform3D.IDENTITY, Vector3.ZERO, null)
	assert_true(_avatar.is_outside(), "on a spacewalk")

## Review focus: with no input you stay standing, and do not creep.
func test_with_no_input_you_stand_on_the_ground_and_do_not_drift():
	_lone()
	_ground()
	_field(Vector3(0, 0.02, 0))
	await wait_physics_frames(60)
	assert_true(_avatar.is_on_floor(), "standing")
	var p := _avatar.global_position
	assert_almost_eq(Vector2(p.x, p.z), Vector2.ZERO, Vector2.ONE * 0.001, "no creep")
	assert_almost_eq(p.y, 0.0, 0.02, "on the ground, not in it")

## Planetfall §11.2: Space adds 3.1 m/s along up -- about a metre at 5 m/s² --
## and you come back down.
func test_a_jump_leaves_the_floor_and_comes_back():
	_lone()
	_ground()
	_field(Vector3(0, 0.02, 0))
	await wait_physics_frames(20)
	assert_true(_avatar.is_on_floor())
	_avatar._unhandled_input(_action(&"jump"))
	var left := false
	var top := 0.0
	for i in 120:
		await wait_physics_frames(1)
		left = left or not _avatar.is_on_floor()
		top = maxf(top, _avatar.global_position.y)
	assert_true(left, "off the ground")
	var expected := Avatar.JUMP_SPEED * Avatar.JUMP_SPEED / (2.0 * 5.0)
	assert_almost_eq(top, expected, 0.1, "as high as 3.1 m/s takes you at 5 m/s²")
	assert_true(_avatar.is_on_floor(), "and back down")
	assert_almost_eq(_avatar.global_position.y, 0.0, 0.02)

## Jump is on foot on a world only (Planetfall §11.2): aboard, Space does nothing.
func test_aboard_space_does_not_jump():
	_lone()
	var deck := StaticBody3D.new()
	deck.collision_layer = 2
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.2, 20)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = Vector3(0, -0.1, 0)
	deck.add_child(shape)
	_world.add_child(deck)
	await wait_physics_frames(10)
	_avatar._unhandled_input(_action(&"jump"))
	var top := 0.0
	for i in 20:
		await wait_physics_frames(1)
		top = maxf(top, _avatar.global_position.y)
	assert_lt(top, 0.02, "still on the deck")

## Planetfall §11.1: up is away from the world's centre, the body turns to
## stand on it, and floor detection follows it.
func test_up_follows_the_world():
	_lone()
	var tilted := Vector3(0.3, 1.0, 0.0).normalized()
	_field(Vector3(0, 5, 0), -tilted * 5.0)
	_avatar._physics_process(DT)
	assert_almost_eq(_avatar.up, tilted, Vector3.ONE * 1e-5)
	assert_almost_eq(_avatar.up_direction, tilted, Vector3.ONE * 1e-5)
	assert_almost_eq(_avatar.global_basis.y, tilted, Vector3.ONE * 1e-4)
	assert_almost_eq(_avatar.velocity, -tilted * 5.0 * DT, Vector3.ONE * 1e-5, "falling toward the centre")

## With no pull to read (the scene not wired yet), up stays as it was.
func test_with_no_pull_up_stays():
	_lone()
	_field(Vector3(0, 5, 0), Vector3.ZERO)
	_avatar._physics_process(DT)
	assert_eq(_avatar.up, Vector3.UP)
	assert_eq(_avatar.velocity, Vector3.ZERO)

## Planetfall §11.1: mouse yaw turns you about the world's up.
func test_the_mouse_turns_you_about_up():
	_lone()
	var tilted := Vector3(0.3, 1.0, 0.0).normalized()
	_field(Vector3(0, 5, 0), -tilted * 5.0)
	_avatar._physics_process(DT)
	var before := _avatar.global_basis
	_avatar.look(Vector2(100, 0))
	var turned := -100.0 * Avatar.MOUSE_SENSITIVITY
	assert_almost_eq(_avatar.global_basis.y, tilted, Vector3.ONE * 1e-4, "still standing on the world")
	assert_almost_eq(-_avatar.global_basis.z, Basis(tilted, turned) * -before.z, Vector3.ONE * 1e-4)

## In FIELD the suit's thrusters are off (desert world spec §5.5): walking
## costs the cell nothing and never fires them.
func test_the_suit_thrusters_never_run_on_a_world():
	_lone()
	_ground()
	_avatar.suit_cell.charge = SuitCell.CAPACITY
	_field(Vector3(0, 0.02, 0))
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	for i in 30:
		await wait_physics_frames(1)
		assert_false(_avatar.thrusting)
	Input.action_release(&"sprint")
	Input.action_release(&"move_forward")
	assert_eq(_avatar.suit_cell.charge, SuitCell.CAPACITY, "nothing spent")
	assert_lt(_avatar.global_position.z, -1.0, "you walked instead")
	assert_true(_avatar.is_on_floor())

## What the energy panel's status line says for the avatar as it stands.
func _suit_status() -> String:
	var panel := EnergyPanel.new()
	add_child_autofree(panel)
	panel.render(_avatar.build_telemetry())
	return panel.status_label.text

## The dry-suit trip home is a spacewalk's (airlock spec §9): on foot the
## thrusters are off and nothing returns you, so the HUD shows the charge only.
func test_on_foot_with_a_dry_suit_the_hud_does_not_say_returning():
	_lone()
	_ground()
	_field(Vector3(0, 0.02, 0))
	_avatar.suit_cell.charge = 0.0
	var t := _avatar.build_telemetry()
	assert_eq(t.energy, 0)
	var status := _suit_status()
	assert_false(status.contains("RETURNING"), status)
	assert_false(status.contains("SUIT DRY"), status)

## ...and the spacewalk's wording is pinned.
func test_on_a_spacewalk_with_a_dry_suit_the_hud_says_dry_and_returning():
	_lone()
	_avatar.enter_suit(_world, Transform3D.IDENTITY, Vector3.ZERO, null)
	_avatar.suit_cell.charge = 0.0
	var status := _suit_status()
	assert_true(status.contains("SUIT DRY"), status)
	assert_true(status.contains("RETURNING"), status)

# --- the suit lamp (Planetfall §11.3) ------------------------------------------

func test_the_lamp_is_a_spot_on_your_head_and_starts_off():
	_lone()
	var lamp := _avatar.lamp
	assert_not_null(lamp)
	assert_eq(lamp.get_parent(), _avatar.head)
	assert_almost_eq(lamp.spot_range, Avatar.LAMP_RANGE, 1e-6)
	assert_eq(Avatar.LAMP_RANGE, 25.0)
	assert_almost_eq(lamp.spot_angle, Avatar.LAMP_ANGLE, 1e-6)
	assert_eq(Avatar.LAMP_ANGLE, 35.0)
	assert_false(lamp.shadow_enabled, "no shadows (GTX 960)")
	assert_eq(lamp.light_color, HullPalette.WORK_LIGHT, "the outside's work light, from the palette")
	assert_false(lamp.visible, "off aboard")

func test_l_switches_the_lamp_outside():
	_lone()
	_field()
	_avatar._unhandled_input(_action(&"lights_flood"))
	assert_true(_avatar.lamp.visible, "on")
	assert_eq(_avatar.lamp.light_cull_mask, 1 | ExteriorBuilder.OWN_HULL_LAYER, "the world and your own hull")
	assert_eq(_avatar.lamp.layers, 1)
	_avatar._unhandled_input(_action(&"lights_flood"))
	assert_false(_avatar.lamp.visible, "and off")

func test_the_lamp_spares_your_hands_and_a_dimmer_fill_lights_them():
	_lone()
	_field()
	assert_eq(_avatar.lamp.light_cull_mask & Avatar.HANDS_LAYER, 0, "the lamp's mask omits the hands' layer")
	var fill := _avatar.lamp.get_node("HandsFill") as SpotLight3D
	assert_eq(fill.light_cull_mask, Avatar.HANDS_LAYER, "the fill lights only the hands")
	assert_lt(fill.light_energy, Avatar.LAMP_ENERGY)
	var seen := 0
	for node in _avatar.hands.find_children("*", "MeshInstance3D", true, false):
		seen += 1
		assert_eq((node as MeshInstance3D).layers, Avatar.HANDS_LAYER)
	assert_gt(seen, 0, "the hands have meshes")

func test_l_does_nothing_aboard():
	_lone()
	_avatar._unhandled_input(_action(&"lights_flood"))
	assert_false(_avatar.lamp.visible)

func test_coming_back_in_puts_back_everything_the_field_changed():
	_lone()
	var root := _avatar.grasp.world_root
	var interior := Node3D.new()
	_world.add_child(interior)
	_field(Vector3(0, 0, 0), -Vector3(0.3, 1.0, 0.0).normalized() * 5.0)
	_avatar._physics_process(DT)
	_avatar._unhandled_input(_action(&"lights_flood"))
	assert_true(_avatar.lamp.visible)
	_avatar.enter_plating(interior, Transform3D(Basis.IDENTITY, Vector3(0, 1, 0)), 0.0, Vector3.ZERO, Quaternion.IDENTITY)
	assert_eq(_avatar.mode, Avatar.Mode.PLATING)
	assert_false(_avatar.is_outside())
	assert_eq(_avatar.grasp.world_root, root, "drops land aboard again")
	assert_eq(_avatar.grasp.ray_mask, Grasp.RAY_MASK, "the hands' ray as aboard")
	assert_false(_avatar.grasp.suspended)
	assert_eq(_avatar.motion_mode, CharacterBody3D.MOTION_MODE_GROUNDED)
	assert_eq(_avatar.up, Vector3.UP)
	assert_eq(_avatar.up_direction, Vector3.UP)
	assert_false(_avatar.is_in_group(Universe.EXTERIOR_SPACE))
	assert_false(_avatar.is_in_group(AsteroidStream.SPACE_ANCHOR))
	assert_false(_avatar.lamp.visible, "the lamp is off and hidden aboard")
	_avatar._unhandled_input(_action(&"lights_flood"))
	assert_false(_avatar.lamp.visible, "and stays so")

# --- what reads "outside" (the Mode.SUIT sweep) --------------------------------

func test_on_foot_on_a_world_you_are_a_target_as_on_a_spacewalk():
	_lone()
	Weapons.join(_avatar, Weapons.YOU)
	assert_false(Weapons.usable(_avatar), "aboard, never")
	_field()
	assert_true(Weapons.usable(_avatar), "outside, on foot")
	Weapons.leave(_avatar)

func test_a_package_works_on_foot_outside():
	_lone()
	assert_false(PackageUse._outside(_avatar))
	_field()
	assert_true(PackageUse._outside(_avatar))

# --- in the real scene -------------------------------------------------------

var _root: Node
var _ship: Ship
var _airlock: Airlock

## The starter in the flight scene, you aboard with a full suit, its airlock
## stepped by hand: on a world (landed) if `on_world`, else in open space or a
## ring.
func _flight(on_world: bool) -> void:
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_airlock = _ship.airlocks.get(Vector3i(0, 0, 3))
	_avatar = _root.get_node("Ship/Interior/Avatar")
	_avatar.suit_cell.charge = SuitCell.CAPACITY
	_airlock.set_physics_process(false)
	if on_world:
		_ship.flight_computer.gravity = OnWorld.new()
		_ship.landing.restore_landed()

## As _flight, with you in the airlock room and the outer hatch open.
func _scene(on_world: bool) -> void:
	_flight(on_world)
	_airlock.room.corridor_panel.interact(null)
	_step(AirlockCycle.OPEN_TIME + 0.1)
	_avatar.position = _airlock.room.room_frame.origin
	_step(DT)
	_airlock.room.room_panel.interact(null)
	_step(5.0)
	assert_eq(_airlock.room.outer_hatch.open_amount, 1.0, "the outer hatch stands open")

func _step(seconds: float) -> void:
	for i in int(round(seconds / DT)):
		_airlock.tick(DT)

func _cross_out() -> void:
	_avatar.position = _airlock.room.outer_frame * Vector3(0, 0, -0.1)
	_step(DT)

func test_the_flight_scene_gives_you_the_worlds_gravity():
	_scene(false)
	assert_not_null(_root.world_gravity)
	assert_same(_avatar.gravity, _root.world_gravity)

## Review focus 1: out of a landed ship on a world you stand on it.
func test_out_of_a_landed_ship_on_a_world_is_field():
	_scene(true)
	assert_true(_ship.on_world())
	_cross_out()
	assert_eq(_avatar.mode, Avatar.Mode.FIELD, "on foot on the world")
	assert_eq(_avatar.get_parent(), _ship.outside)
	assert_eq(_avatar.grasp.world_root, _ship.outside)
	assert_true(_avatar.beacon_source.is_valid(), "the way home on the HUD")
	assert_same(_root.get_node("Universe").focus, _avatar, "the origin follows you")
	assert_false(_airlock.occupancy()["clear_outer"], "standing in the doorway: the hatch waits for you")

## Review focus 1: above the air, a ring included, it is a spacewalk.
func test_out_into_open_space_or_a_ring_is_a_spacewalk():
	_scene(false)
	assert_false(_ship.on_world())
	_cross_out()
	assert_eq(_avatar.mode, Avatar.Mode.SUIT)
	assert_true(_avatar.grasp.suspended)

func test_back_in_from_the_world_you_are_aboard():
	_scene(true)
	_cross_out()
	_avatar._unhandled_input(_action(&"lights_flood"))
	var hull := _ship.exterior.global_transform
	_avatar.global_position = hull * (_airlock.alcove.outer_frame * Vector3(0, 0, 0.1))
	_step(DT)
	assert_eq(_avatar.mode, Avatar.Mode.PLATING, "in through the outer hatch")
	assert_eq(_avatar.get_parent(), _ship.interior)
	assert_eq(_avatar.grasp.world_root, _ship.items, "what you drop lands aboard")
	assert_eq(_avatar.up_direction, Vector3.UP)
	assert_false(_avatar.lamp.visible)
	assert_same(_root.get_node("Universe").focus, _ship.exterior)

## Desert world spec §5.5: dropped on a world, a thing is a stray (saved, and
## moved by the floating origin); taken back up, it is not.
func test_what_you_drop_on_a_world_is_a_stray_until_you_take_it_back():
	_scene(true)
	_cross_out()
	var item := Item.new()
	item.setup(_ship.item_catalog.get_def(&"crate"))
	_ship.outside.add_child(item)
	item.global_position = _avatar.global_position + _avatar.global_basis * Vector3(0, 1.0, -1.0)
	item.set_space(true)
	item.set_loose()
	assert_true(_avatar.grasp.take(item), "hands work on the ground")
	var strays: StrayField = _root.strays
	var before := strays.count()
	_avatar.grasp.drop()
	assert_eq(strays.count(), before + 1, "a stray")
	assert_eq(item.get_parent(), strays)
	assert_true(item.is_in_group(Universe.EXTERIOR_SPACE))
	assert_true(item.in_space)
	assert_true(_avatar.grasp.take(item))
	assert_eq(strays.count(), before, "taken back: no stray")
	assert_false(item.is_in_group(Universe.EXTERIOR_SPACE), "it moves with your hands now")

func test_you_cannot_sit_from_outside_on_a_world():
	_scene(true)
	_cross_out()
	var director: CameraDirector = _root.get_node("CameraDirector")
	director.sit(_root.get_node("Ship/Interior/PilotSeat"))
	assert_false(director.is_seated)
	assert_false(_root.board_nearest(), "F8 waits for you to come aboard")
	assert_eq(_root.warp_panel.toast_label.text, "NOT ON FOOT")

## A hole where you stand (health and damage spec §7.4) on a landed ship puts
## you on the ground beside it, on your feet -- never adrift in a suit beside
## the ground.
func test_a_hole_where_you_stand_on_a_world_puts_you_on_your_feet():
	_flight(true)
	assert_true(_ship.on_world())
	_stand_in_a_hole()
	assert_eq(_avatar.mode, Avatar.Mode.FIELD)
	assert_eq(_avatar.get_parent(), _ship.outside)
	assert_true(_avatar.beacon_source.is_valid(), "the way home on the HUD")

## In open space, or a ring, it is a spacewalk, as it always was.
func test_a_hole_where_you_stand_in_open_space_is_a_spacewalk():
	_flight(false)
	assert_false(_ship.on_world())
	_stand_in_a_hole()
	assert_eq(_avatar.mode, Avatar.Mode.SUIT)
	assert_eq(_avatar.get_parent(), _ship.outside)

## Stands you, aboard, in a cell the ship has no block in -- two past its
## furthest -- and tells the scene blocks were lost.
func _stand_in_a_hole() -> void:
	var far := 0
	for c: Vector3i in _ship.grid.coords():
		far = maxi(far, c.x)
	var cell := Vector3i(far + 2, 0, 0)
	assert_false(_ship.grid.has_block(cell))
	_avatar.global_position = _ship.interior.to_global(ShipGrid.cell_center(cell))
	_root._on_blocks_lost([] as Array[Vector3i], _ship)
