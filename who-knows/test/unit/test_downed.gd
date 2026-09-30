extends GutTest

## Blacking out (docs/superpowers/specs/2026-09-29-health-and-damage-design.md
## §7.2): its timing, and what the avatar does at each step.

func _run(d: Downed, seconds: float, home := true) -> void:
	for i in roundi(seconds / 0.1):
		d.tick(0.1, home)

func test_it_fades_goes_black_and_wakes():
	var d := Downed.new()
	watch_signals(d)
	assert_eq(d.darkness(), 0.0)
	_run(d, 0.7)
	assert_almost_eq(d.darkness(), 0.7 / Downed.FADE, 0.05)
	_run(d, 1.0)
	assert_eq(d.step, Downed.Step.BLACK)
	assert_eq(d.darkness(), 1.0)
	_run(d, Downed.BLACK)
	assert_eq(d.step, Downed.Step.WAKING)
	_run(d, Downed.WAKE + 0.1)
	assert_eq(d.step, Downed.Step.DONE)
	assert_eq(d.darkness(), 0.0)
	assert_signal_emit_count(d, "stepped", 3)

func test_outside_the_black_waits_for_home_but_not_for_ever():
	var d := Downed.new()
	_run(d, Downed.FADE + Downed.BLACK + 1.0, false)
	assert_eq(d.step, Downed.Step.BLACK, "still on the way home")
	_run(d, 1.0, true)
	assert_eq(d.step, Downed.Step.WAKING)
	var lost := Downed.new()
	_run(lost, Downed.FADE + Downed.BLACK_AT_MOST + 0.5, false)
	assert_eq(lost.step, Downed.Step.WAKING, "never stranded")

# --- the avatar (spec §5.3, §7) ------------------------------------------------

var _world: Node3D
var _avatar: Avatar
var _rescued := 0
var _paid := 0

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)
	var floor := StaticBody3D.new()
	floor.collision_layer = 2
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.2, 20)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = Vector3(0, -0.1, 0)
	floor.add_child(shape)
	_world.add_child(floor)
	_avatar = load("res://scenes/avatar.tscn").instantiate()
	_world.add_child(_avatar)
	_avatar.grasp.world_root = _world
	_rescued = 0
	_paid = 0
	_avatar.rescue = func(_a: Avatar) -> void: _rescued += 1
	_avatar.rescue_cost = func(n: int) -> int:
		_paid += n
		return n

func _hit(damage: float) -> Hit:
	var hit := Hit.make(Vector3.ZERO, Vector3.UP, Vector3.FORWARD, Vector3.FORWARD * 12.0, null)
	hit.damage = damage
	return hit

func _item() -> Item:
	var d := ItemDefinition.new()
	d.id = &"mug"
	d.display_name = "Mug"
	d.mass_kg = 0.3
	d.size = Vector3(0.1, 0.1, 0.1)
	d.look = &"mug"
	var item := Item.new()
	item.setup(d)
	_world.add_child(item)
	item.global_position = Vector3(0, 1, -0.5)
	return item

func test_a_hit_hurts_and_shoves():
	watch_signals(_avatar)
	_avatar.receive_hit(_hit(15.0))
	assert_eq(_avatar.health.current, Avatar.MAX_HEALTH - 15.0)
	assert_signal_emitted(_avatar, "hurt")
	assert_almost_eq(_avatar.velocity.z, -12.0 / Avatar.SUIT_MASS, 0.001)

func test_at_the_helm_the_ship_takes_it():
	_avatar.seated_source = func() -> bool: return true
	_avatar.receive_hit(_hit(15.0))
	assert_eq(_avatar.health.current, Avatar.MAX_HEALTH)

func test_striking_a_rock_fast_on_a_spacewalk_hurts():
	var rock := AsteroidBody.new()
	rock.mass = 10_000.0
	_world.add_child(rock)
	rock.global_position = Vector3(50, 0, 0)
	var gentle := _avatar.bump(Vector3(3, 0, 0), Vector3.ZERO, [[rock, Vector3(-1, 0, 0), Vector3.ZERO]])
	assert_eq(_avatar.health.current, Avatar.MAX_HEALTH, "3 m/s is a bump: %s" % gentle)
	_avatar.bump(Vector3(7, 0, 0), Vector3.ZERO, [[rock, Vector3(-1, 0, 0), Vector3.ZERO]])
	assert_almost_eq(_avatar.health.current, Avatar.MAX_HEALTH - Avatar.EVA_HURT_K * 3.0, 0.5)

func test_empty_you_black_out_let_go_and_wake_at_the_ship_s_cost():
	var mug := _item()
	assert_true(_avatar.grasp.take(mug))
	watch_signals(_avatar)
	_avatar.receive_hit(_hit(500.0))
	assert_not_null(_avatar.downed)
	assert_eq(_avatar.busy(), "blacked out")
	assert_null(_avatar.grasp.item, "let go")
	assert_signal_emitted_with_parameters(_avatar, "let_fall", [mug, false])
	_avatar.receive_hit(_hit(10.0))
	assert_eq(_avatar.health.current, 0.0, "nothing more happens to you")
	for i in roundi((Downed.FADE + Downed.BLACK + Downed.WAKE + 0.5) / 0.1):
		_avatar._process(0.1)
	assert_null(_avatar.downed)
	assert_eq(_avatar.health.current, Avatar.WAKE_HEALTH)
	assert_eq(_rescued, 1)
	assert_eq(_paid, Avatar.RESCUE_COST)
	assert_ne(_avatar.busy(), "blacked out")
	assert_signal_emit_count(_avatar, "downed_changed", 2)

func test_the_edge_flashes_fades_and_stays_faint_when_low():
	var edge := HurtEdge.new()
	add_child_autofree(edge)
	edge.bind(_avatar)
	assert_eq(edge.edge(), 0.0)
	_avatar.take_damage(10.0)
	assert_eq(edge.edge(), HurtEdge.FLASH)
	edge._process(HurtEdge.FLASH_FADE + 0.1)
	assert_eq(edge.edge(), 0.0)
	_avatar.take_damage(Avatar.MAX_HEALTH - Avatar.LOW_HEALTH)
	edge._process(HurtEdge.FLASH_FADE + 0.1)
	assert_eq(edge.edge(), HurtEdge.LOW, "low: it stays")
	_avatar.take_damage(500.0)
	_avatar._process(Downed.FADE)
	assert_almost_eq(edge.darkness(), 1.0, 0.01)
