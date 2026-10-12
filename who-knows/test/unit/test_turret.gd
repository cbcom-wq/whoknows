extends GutTest

## Turret (ship weapons spec §5.3): it turns at its slew, leads its target,
## fires bursts only on target, in range, clear of its own hull and paid for,
## recharges, and suffers its damage.

var _world: Node3D
var _hull: RigidBody3D
var _store: QuantumStore
var _stage := BlockDamage.Stage.INTACT

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)
	_world.add_child(BoltPool.new())
	_hull = RigidBody3D.new()
	_hull.gravity_scale = 0.0
	_hull.freeze = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 2, 2)
	shape.shape = box
	_hull.add_child(shape)
	_world.add_child(_hull)
	_store = QuantumStore.new(1000, 1000)
	_stage = BlockDamage.Stage.INTACT

func _turret(kind := WeaponValues.LIGHT, layout: ShipGrid = null) -> Turret:
	var g := layout if layout != null else ShipGrid.new()
	if layout == null:
		var inst := BlockInstance.new()
		inst.block_id = kind
		g.set_block(Vector3i.ZERO, inst)
	var t := Turret.new()
	t.setup(kind, Vector3i.ZERO, Vector3i.UP, SkyMap.build(g, Vector3i.ZERO, Vector3i.UP))
	t.hull = _hull
	t.store = _store
	t.source = _hull
	t.stage_of = func() -> int: return _stage
	_hull.add_child(t)
	return t

func _target(at: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 6, 6)
	shape.shape = box
	b.add_child(shape)
	_world.add_child(b)
	b.global_position = at
	Weapons.join(b, &"ship:T")
	return b

func _count(t: Turret) -> Array:
	var shots := []
	t.fired.connect(func(_k: StringName) -> void: shots.append(1))
	return shots

func test_it_turns_at_its_slew():
	var t := _turret()
	t.target = _target(Vector3(300, 1.6, 0))
	await wait_physics_frames(15)
	var slew := deg_to_rad(90.0) * 0.25 + 0.02
	assert_lt(absf(t.yaw), slew, "no faster than 90 deg/s")
	assert_gt(t.yaw, 0.1, "toward the right")

func test_it_fires_a_burst_of_four_then_recharges():
	var t := _turret()
	t.yaw = 0.0
	t.elevation = 0.0
	t.target = _target(Vector3(0, 1.6, -300))
	var shots := _count(t)
	await wait_seconds(1.0)
	assert_eq(shots.size(), 4, "one burst; the next waits for its recharge")
	assert_eq(_store.amount, 996, "1 QE a bolt")

func test_it_holds_fire_off_target():
	var t := _turret()
	t.yaw = PI
	t.target = _target(Vector3(0, 1.6, -300))
	var shots := _count(t)
	await wait_physics_frames(10)
	assert_eq(shots.size(), 0, "not within 1 deg yet")

func test_it_holds_fire_out_of_range():
	var t := _turret()
	t.target = _target(Vector3(0, 1.6, -2000))
	var shots := _count(t)
	await wait_seconds(1.0)
	assert_eq(shots.size(), 0)
	assert_false(t.can_engage(t.target))

func test_a_burst_stops_at_the_low_power_line():
	var t := _turret()
	t.yaw = 0.0
	t.elevation = 0.0
	t.target = _target(Vector3(0, 1.6, -300))
	_store.amount = _store.line() + 1
	var shots := _count(t)
	await wait_seconds(1.0)
	assert_lt(shots.size(), 4, "it stopped mid-burst")
	assert_gte(_store.amount, _store.line() - 1, "never past one bolt under the line")
	var after := shots.size()
	await wait_seconds(2.0)
	assert_eq(shots.size(), after, "nothing more in low power")

func test_never_fires_through_its_own_hull():
	var g := ShipGrid.new()
	for at: Vector3i in [Vector3i.ZERO, Vector3i(0, 1, -1), Vector3i(0, 2, -1)]:
		var inst := BlockInstance.new()
		inst.block_id = &"hull" if at != Vector3i.ZERO else WeaponValues.LIGHT
		g.set_block(at, inst)
	var t := _turret(WeaponValues.LIGHT, g)
	# The same cells as hull colliders, as a ship's exterior has them.
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 4, 2)
	shape.shape = box
	shape.position = Vector3(0, 3, -2)
	_hull.add_child(shape)
	t.target = _target(Vector3(0, 1.6, -300))
	var shots := _count(t)
	await wait_seconds(1.0)
	assert_eq(shots.size(), 0, "its own ship is in the way")

## A wall of the ship's own hull right ahead of the muzzle, as a collider only:
## the sky map knows nothing of it, so only the per-shot ray can refuse.
func _wall() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 4, 2)
	shape.shape = box
	shape.position = Vector3(0, 3, -2)
	_hull.add_child(shape)

func test_the_shot_ray_alone_refuses_the_hull_ahead():
	var t := _turret()
	_wall()
	t.yaw = 0.0
	t.elevation = 0.0
	t.target = _target(Vector3(0, 1.6, -300))
	assert_true(t.can_engage(t.target), "the sky map alone calls it open")
	var shots := _count(t)
	await wait_seconds(1.0)
	assert_eq(shots.size(), 0, "the ray finds the hull")

func test_the_same_setup_without_the_wall_fires():
	var t := _turret()
	t.yaw = 0.0
	t.elevation = 0.0
	t.target = _target(Vector3(0, 1.6, -300))
	var shots := _count(t)
	await wait_seconds(1.0)
	assert_gt(shots.size(), 0, "control: open, it fires")

func test_by_hand_it_will_not_fire_into_its_own_hull():
	var t := _turret(WeaponValues.HEAVY)
	_wall()
	t.manual = true
	t.manual_aim = Vector3.FORWARD
	t.yaw = 0.0
	t.elevation = 0.0
	var shots := _count(t)
	await wait_physics_frames(2)   # the wall joins the physics space
	assert_false(t.pull_trigger(), "the hull is in the way")
	await wait_physics_frames(3)
	assert_eq(shots.size(), 0)
	assert_eq(_store.amount, 1000, "nothing spent")

func test_by_hand_a_sky_blocked_by_the_layout_refuses_too():
	var g := ShipGrid.new()
	for at: Vector3i in [Vector3i.ZERO, Vector3i(0, 1, -1), Vector3i(0, 2, -1)]:
		var inst := BlockInstance.new()
		inst.block_id = &"hull" if at != Vector3i.ZERO else WeaponValues.HEAVY
		g.set_block(at, inst)
	var t := _turret(WeaponValues.HEAVY, g)
	t.manual = true
	t.manual_aim = Vector3.FORWARD
	t.yaw = 0.0
	t.elevation = 0.0
	assert_false(t.pull_trigger(), "the sky map says the ship is there")

func test_damaged_it_slews_at_half_and_wrecked_it_is_silent():
	_stage = BlockDamage.Stage.DAMAGED
	var t := _turret()
	t.target = _target(Vector3(300, 1.6, 0))
	await wait_physics_frames(15)
	assert_lt(t.yaw, deg_to_rad(45.0) * 0.25 + 0.02)
	_stage = BlockDamage.Stage.WRECKED
	var shots := _count(t)
	await wait_seconds(1.0)
	assert_eq(shots.size(), 0)
	assert_eq(t.state, &"wrecked")

func test_by_hand_the_trigger_fires_where_it_points():
	var t := _turret(WeaponValues.HEAVY)
	t.manual = true
	t.manual_aim = Vector3.FORWARD
	t.yaw = 0.0
	t.elevation = 0.0
	var shots := _count(t)
	assert_true(t.pull_trigger())
	await wait_physics_frames(2)
	assert_eq(shots.size(), 1)
	assert_eq(_store.amount, 1000 - 15)
	assert_false(t.pull_trigger(), "recharging")
	assert_gt(t.recharge_left(), 2.5)
