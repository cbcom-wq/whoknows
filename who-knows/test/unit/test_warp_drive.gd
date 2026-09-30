extends GutTest

## The warp drive (the warp spec §5): it spools while you keep the helm,
## spends the QE as it leaves, flies the hull along the line touching
## nothing, and lets go at the target's limit moving in at 120 m/s. Stepped by
## hand here, so a 40 s warp runs in no time.

var _system: SystemRecipe
var _universe: Universe
var _hull: RigidBody3D
var _where: Whereabouts
var _store: QuantumStore
var _drive: WarpDrive

func before_each():
	_system = SystemRecipe.from_seed(1337)
	_universe = Universe.new()
	add_child_autofree(_universe)
	_hull = RigidBody3D.new()
	_hull.gravity_scale = 0.0
	_hull.collision_layer = 1
	_hull.collision_mask = 5
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	_hull.add_child(shape)
	add_child_autofree(_hull)
	_hull.add_to_group(Universe.EXTERIOR_SPACE)
	_universe.set_focus(_hull)
	_where = Whereabouts.new()
	add_child_autofree(_where)
	_where.setup(_system, _universe)
	_store = QuantumStore.new(1200, 1200)
	_drive = WarpDrive.new()
	add_child_autofree(_drive)
	_drive.set_physics_process(false)
	_drive.hull = _hull
	_drive.store = _store
	_drive.bind(_system, _universe, _where, null, null, Callable())

## The hull at rest at `at`, its nose on `look`.
func _put(at: UniversePoint, look: UniversePoint) -> void:
	_universe.origin = at
	var dir := look.minus(at).normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.BACK
	_hull.global_transform = Transform3D(Basis.looking_at(dir, up), Vector3.ZERO)
	_where.look()

## A planet with a clear line from high above it: the hull put there, nose on
## it, the warp charted and ready. Returns the planet.
func _ready_above_a_planet() -> WarpTarget:
	for t in _system.warp_targets():
		if t.kind != WarpTarget.Kind.PLANET:
			continue
		_put(t.point.plus(Vector3.UP * (t.limit + 30000.0)), t.point)
		_drive.chart(t.id)
		if _drive.check().status == WarpPlan.Status.READY:
			return t
	fail_test("no planet with a clear line from above")
	return null

func _run(seconds: float) -> void:
	var dt := 1.0 / 60.0
	for i in ceili(seconds / dt):
		_drive.step(dt)

func test_a_warp_spools_spends_and_arrives_at_the_limit_moving_in():
	var t := _ready_above_a_planet()
	var cost := _drive.plan.cost
	_drive.engage()
	assert_eq(_drive.stage, WarpDrive.Stage.SPOOLING)
	_run(WarpDrive.SPOOL - 0.5)
	assert_eq(_store.amount, 1200, "nothing spent while spooling")
	_run(1.0)
	assert_eq(_drive.stage, WarpDrive.Stage.TRAVELLING)
	assert_eq(_store.amount, 1200 - cost)
	assert_eq(_hull.collision_layer, 0)
	assert_eq(_hull.collision_mask, 0)
	assert_true(_hull.freeze)
	assert_gt(_drive.velocity().length(), WarpProfile.EDGE_SPEED)
	_run(_drive.time_left() + 0.1)
	assert_eq(_drive.stage, WarpDrive.Stage.IDLE)
	var at := _universe.to_universe(_hull.global_position)
	var to_it := t.point.minus(at)
	assert_almost_eq(to_it.length(), t.limit, 5.0, "at the limit")
	assert_almost_eq(_hull.linear_velocity.length(), WarpProfile.EDGE_SPEED, 0.5)
	assert_gt(_hull.linear_velocity.normalized().dot(to_it.normalized()), 0.999, "moving in")
	assert_gt((-_hull.global_basis.z).dot(to_it.normalized()), 0.999, "facing it")
	assert_false(_hull.freeze)
	assert_eq(_hull.collision_layer, 1)
	assert_eq(_hull.collision_mask, 5)
	assert_lt(_hull.global_position.length(), Universe.FORCE_AT, "the origin followed")

func test_turning_away_while_spooling_aborts_with_nothing_spent():
	_ready_above_a_planet()
	var why := []
	_drive.aborted.connect(func(w: String) -> void: why.append(w))
	_drive.engage()
	_run(3.0)
	_hull.global_basis = Basis(Vector3.RIGHT, deg_to_rad(30.0)) * _hull.global_basis
	_run(0.1)
	assert_eq(_drive.stage, WarpDrive.Stage.IDLE)
	assert_eq(_store.amount, 1200)
	assert_eq(why.size(), 1)
	assert_false(_hull.freeze)
	assert_eq(_hull.collision_mask, 5)

func test_j_again_aborts_the_spool():
	_ready_above_a_planet()
	_drive.engage()
	_drive.engage()
	assert_eq(_drive.stage, WarpDrive.Stage.IDLE)
	assert_eq(_store.amount, 1200)

func test_a_warp_that_is_not_ready_never_starts():
	_drive.engage()
	assert_eq(_drive.stage, WarpDrive.Stage.IDLE, "nothing charted")
	_ready_above_a_planet()
	_store.amount = 30
	_drive.engage()
	assert_eq(_drive.stage, WarpDrive.Stage.IDLE, "low power")

func test_a_save_during_travel_is_at_the_drop_out_point():
	var t := _ready_above_a_planet()
	assert_eq(_drive.arrival(), {}, "nothing while idle")
	_drive.engage()
	_run(WarpDrive.SPOOL + 5.0)
	var a := _drive.arrival()
	assert_almost_eq((a["at"] as UniversePoint).minus(t.point).length(), t.limit, 5.0)
	assert_almost_eq((a["v"] as Vector3).length(), WarpProfile.EDGE_SPEED, 0.01)
	assert_gt((-(a["turn"] as Basis).z).dot(t.point.minus(a["at"]).normalized()), 0.999)

func test_the_chart_is_saved_and_a_stale_one_forgotten():
	_drive.chart(_system.planets()[0].id)
	var saved := _drive.to_dict()
	var other := WarpDrive.new()
	add_child_autofree(other)
	other.from_dict(saved)
	other.bind(_system, _universe, _where, null, null, Callable())
	assert_eq(other.charted, _drive.charted)
	other.from_dict({"charted": "p99"})
	other.bind(_system, _universe, _where, null, null, Callable())
	assert_eq(other.charted, &"", "a target the system lacks is dropped")

func test_the_streak_grows_through_the_spool_and_runs_at_speed():
	_ready_above_a_planet()
	assert_eq(_drive.streak(), Vector3.ZERO)
	_drive.engage()
	_run(WarpDrive.SPOOL * 0.5)
	assert_almost_eq(_drive.streak().length(), WarpDrive.SPOOL_STREAK * 0.5, 0.2)
	_run(WarpDrive.SPOOL * 0.5 + 10.0)
	assert_almost_eq(_drive.streak().length(), _drive.velocity().length() * WarpDrive.STREAK_SHUTTER, 1e-3)
