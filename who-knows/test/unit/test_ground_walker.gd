extends GutTest

## GroundWalker (docs/superpowers/specs/2026-11-16-wadoo-design.md §12): a person walks
## the site's route over its ground, turning as a person does, feet on the ground,
## keeps a little room from others where the ground is open, and tells its look how
## fast it goes.

const DT := 1.0 / 60.0

class FakeSite extends NpcSite:
	var slope := 0.0
	var wall_east := INF
	var others := PackedVector2Array()
	var via: Variant = null
	var routes := 0
	var _frame := Transform3D(Basis(Vector3.UP, 0.4), Vector3(100.0, 5.0, -30.0))

	func frame() -> Transform3D:
		return _frame

	func route(from: Vector2, to: Vector2) -> PackedVector2Array:
		routes += 1
		if via != null:
			return PackedVector2Array([from, via, to])
		return PackedVector2Array([from, to])

	func ground(p: Vector2) -> Vector3:
		return Vector3(p.x, slope * p.x, -p.y)

	func up_at(_local: Vector3) -> Vector3:
		return Vector3.UP

	func neighbours(_npc: Npc) -> PackedVector2Array:
		return others

	func open(p: Vector2) -> bool:
		return p.x < wall_east

var _site: FakeSite
var _npc: Npc
var _walker: GroundWalker

func _make(at := Vector2.ZERO, top_speed := 1.5) -> void:
	_site = FakeSite.new()
	var species := NpcSpecies.new()
	species.top_speed = top_speed
	_npc = Npc.new()
	_npc.site = _site
	_npc.species = species
	add_child_autofree(_npc)
	_npc.global_transform = _site.frame() * Transform3D(Basis.IDENTITY, _site.ground(at))
	_walker = GroundWalker.new()
	_walker.enter(_npc)

func _at() -> Vector2:
	var p := _npc.local_position()
	return Vector2(p.x, -p.z)

func _run(intent: Intent, seconds: float, each := Callable()) -> void:
	for i in int(seconds / DT):
		_walker.step(_npc, intent, DT)
		if each.is_valid():
			each.call()

func test_walks_the_route():
	_make()
	_site.via = Vector2(0.0, 5.0)
	var closest := [INF]
	_run(Intent.go(Vector3(5.0, 0.0, -5.0), 1.0), 15.0,
		func() -> void: closest[0] = minf(closest[0], _at().distance_to(Vector2(0.0, 5.0))))
	assert_lt(closest[0], GroundWalker.CORNER + 0.05, "it went by the route's corner")
	assert_lt(_at().distance_to(Vector2(5.0, 5.0)), GroundWalker.ARRIVED + 0.02, "and got there")

func test_feet_on_the_ground():
	_make()
	_site.slope = 0.2
	var worst := [0.0]
	_run(Intent.go(Vector3(6.0, 0.0, 0.0), 1.0), 8.0, func() -> void:
		var p := _npc.local_position()
		worst[0] = maxf(worst[0], absf(p.y - 0.2 * p.x)))
	assert_lt(worst[0], 0.001, "its feet stay on the slope")
	assert_gt(_at().x, 5.5)
	var up := _site.frame().basis.inverse() * _npc.global_basis.y
	assert_almost_eq(up.dot(Vector3.UP), 1.0, 0.001, "and it stands upright")

func test_turns_to_face():
	_make()
	var intent := Intent.idle().facing(Vector3(10.0, 0.0, 0.0))
	_run(intent, 0.1)
	var fwd := _site.frame().basis.inverse() * -_npc.global_basis.z
	assert_almost_eq(Vector2(0, 1).angle_to(Vector2(fwd.x, -fwd.z)), -GroundWalker.TURN_RATE * 0.1, 0.05,
		"it turns at its own rate, not at once")
	_run(intent, 1.0)
	fwd = _site.frame().basis.inverse() * -_npc.global_basis.z
	assert_almost_eq(Vector2(fwd.x, -fwd.z).angle_to(Vector2(1, 0)), 0.0, 0.02, "and ends facing it")
	assert_eq(_at(), Vector2.ZERO, "turning on the spot")

func test_turns_before_it_walks_away():
	_make()
	var intent := Intent.go(Vector3(0.0, 0.0, 5.0), 1.0)
	_walker.step(_npc, intent, DT)
	assert_lt(_at().length(), 0.01, "facing away, it turns first")

func test_keeps_apart():
	_make()
	_site.others = PackedVector2Array([Vector2(0.3, 0.0)])
	_run(Intent.idle(), 1.5)
	assert_gt(_at().distance_to(Vector2(0.3, 0.0)), GroundWalker.PERSONAL - 0.05, "it makes room")
	_make()
	_site.wall_east = 0.2
	_site.others = PackedVector2Array([Vector2(-0.3, 0.0)])
	_run(Intent.idle(), 1.5)
	assert_lt(_at().x, 0.2, "but never into a wall")

func test_stops_at_the_target():
	_make(Vector2.ZERO, 2.0)
	var target := Vector3(0.0, 0.0, -4.0)
	var slow := [INF]
	_run(Intent.go(target, 1.0), 6.0, func() -> void:
		if absf(_at().y - 3.6) < 0.05:
			slow[0] = minf(slow[0], _npc.velocity.length()))
	assert_lt(slow[0], 2.0 * 0.6, "it slows as it comes near")
	assert_lt(_at().distance_to(Vector2(0.0, 4.0)), GroundWalker.ARRIVED + 0.02)
	assert_almost_eq(_npc.velocity.length(), 0.0, 0.001, "and stands")
	var before := _at()
	_run(Intent.go(target, 1.0), 1.0)
	assert_eq(_at(), before, "without dithering")

func test_velocity_for_the_look():
	_make(Vector2.ZERO, 1.0)
	_run(Intent.go(Vector3(0.0, 0.0, -20.0), 1.0), 1.0)
	var local := _site.frame().basis.inverse() * _npc.velocity
	assert_almost_eq(local.length(), 1.0, 0.02, "its velocity is how fast it walks")
	assert_almost_eq(local.z, -1.0, 0.02, "north is -z")

func test_replans_when_the_target_moves():
	_make()
	_run(Intent.go(Vector3(0.0, 0.0, -5.0), 1.0), 0.5)
	assert_eq(_site.routes, 1, "once for one target")
	_run(Intent.go(Vector3(3.0, 0.0, -5.0), 1.0), 0.5)
	assert_eq(_site.routes, 2, "again for a new one")

func test_a_shove_slides_and_dies_away():
	_make()
	_walker.shoved(_npc, _site.frame().basis * Vector3(2.0, 0.0, 0.0))
	_run(Intent.idle(), 2.0)
	var east := _at().x
	assert_gt(east, 0.2, "it slid")
	assert_lt(east, 1.0, "a little")
	_run(Intent.idle(), 1.0)
	assert_almost_eq(_at().x, east, 0.01, "and stopped")
