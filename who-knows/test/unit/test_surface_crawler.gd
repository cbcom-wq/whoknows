extends GutTest

## Crawling any way up, and drifting back (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §5.3, §5.4), on shapes made here: a
## cube, a sphere, a corner, a moving crate.

class FakeSite extends NpcSite:
	func frame() -> Transform3D:
		return Transform3D.IDENTITY

var _root: Node3D
var _npc: Npc
var _species: NpcSpecies

func before_each():
	_root = Node3D.new()
	add_child_autofree(_root)
	_species = NpcSpecies.new()
	_species.id = &"crawler"
	_species.size = 0.85
	_species.height = 0.4
	_species.width = 0.5
	_species.mass = 25.0
	_species.top_speed = 4.0
	_species.locomotors = [&"surface_crawler", &"zero_g_drift"] as Array[StringName]

func _solid(shape: Shape3D, at: Vector3, body: PhysicsBody3D = null) -> PhysicsBody3D:
	var b := body if body != null else StaticBody3D.new()
	b.collision_layer = AsteroidBody.LAYER
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	b.add_child(cs)
	_root.add_child(b)
	b.global_position = at
	return b

func _box(size: Vector3, at: Vector3) -> PhysicsBody3D:
	var s := BoxShape3D.new()
	s.size = size
	return _solid(s, at)

func _spawn(pose: Transform3D) -> void:
	var site := FakeSite.new()
	site.id = &"test"
	_npc = Npc.new()
	_root.add_child(_npc)
	_npc.setup(NpcRecord.make(&"crawler:0", &"crawler", &"test", pose.origin, 1), _species, site, false, pose)

func test_it_walks_over_a_cubes_edge_and_down_its_side():
	_box(Vector3(10, 10, 10), Vector3.ZERO)
	_spawn(Transform3D(Basis.IDENTITY, Vector3(0, 5.05, 0)))
	await wait_physics_frames(5)
	var goal := Vector3(5.0, -2.0, 0.0)
	_npc.intent = Intent.go(goal, 1.0)
	var missing := 0.0
	for i in 60 * 6:
		await wait_physics_frames(1)
		if not (_npc.active is SurfaceCrawler and (_npc.active as SurfaceCrawler).gripping):
			missing += 1.0 / 60.0
		if _npc.global_position.distance_to(goal) < 0.4:
			break
	assert_lt(_npc.global_position.distance_to(goal), 0.4, "arrived at %s" % _npc.global_position)
	assert_true(_npc.active is SurfaceCrawler, "still crawling")
	assert_gt(_npc.global_basis.y.dot(Vector3.RIGHT), 0.95, "standing on the side face")
	assert_lt(missing, 0.3, "gripping all the way")

func test_it_walks_round_a_sphere_to_hang_upside_down():
	var sphere := SphereShape3D.new()
	sphere.radius = 8.0
	_solid(sphere, Vector3.ZERO)
	_spawn(Transform3D(Basis.IDENTITY, Vector3(0, 8.02, 0)))
	await wait_physics_frames(5)
	var theta := 0.0
	for i in 60 * 10:
		# A target a little ahead on the great circle through +x.
		var here := _npc.global_position.normalized()
		theta = atan2(here.x, here.y)
		var ahead := theta + 0.3
		_npc.intent = Intent.go(Vector3(sin(ahead), cos(ahead), 0) * 8.0, 1.0)
		await wait_physics_frames(1)
		if theta > PI * 0.97 or theta < -PI * 0.97:
			break
	assert_true(absf(theta) > PI * 0.95, "made it round, at %.2f rad" % theta)
	assert_true(_npc.active is SurfaceCrawler)
	assert_gt(_npc.global_basis.y.dot(_npc.global_position.normalized()), cos(deg_to_rad(10.0)),
		"up along the sphere's normal")
	assert_almost_eq(_npc.global_position.length(), 8.0, 0.3, "on the surface")

func test_into_a_corner_it_climbs_the_wall():
	_box(Vector3(20, 1, 20), Vector3(0, -0.5, 0))
	_box(Vector3(1, 20, 20), Vector3(5.5, 10, 0))
	_spawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	await wait_physics_frames(5)
	var goal := Vector3(5.0, 3.0, 0.0)
	_npc.intent = Intent.go(goal, 1.0)
	for i in 60 * 5:
		await wait_physics_frames(1)
		if _npc.global_position.distance_to(goal) < 0.4:
			break
	assert_lt(_npc.global_position.distance_to(goal), 0.4, "up the wall to %s" % _npc.global_position)
	assert_gt(_npc.global_basis.y.dot(Vector3.LEFT), 0.9, "standing on the wall")

func test_knocked_off_it_drifts_then_puffs_back():
	var sphere := SphereShape3D.new()
	sphere.radius = 8.0
	_solid(sphere, Vector3.ZERO)
	_spawn(Transform3D(Basis.IDENTITY, Vector3(0, 8.02, 0)))
	await wait_physics_frames(5)
	_npc.shove(Vector3(0, 3.0 * 25.0, 0))
	await wait_physics_frames(3)
	assert_true(_npc.active is ZeroGDrift, "knocked into space")
	var back := false
	for i in 60 * 15:
		await wait_physics_frames(1)
		if _npc.active is SurfaceCrawler:
			back = true
			break
	assert_true(back, "back on the rock (at %s, %d puffs left)" % [_npc.global_position,
		(_npc.locomotors[&"zero_g_drift"] as ZeroGDrift).puffs_left])
	assert_lt((_npc.locomotors[&"zero_g_drift"] as ZeroGDrift).puffs_left, ZeroGDrift.PUFFS, "it puffed")

func test_a_small_shove_does_not_knock_it_off():
	_box(Vector3(10, 10, 10), Vector3.ZERO)
	_spawn(Transform3D(Basis.IDENTITY, Vector3(0, 5.05, 0)))
	await wait_physics_frames(5)
	_npc.shove(Vector3(0, 1.0 * 25.0, 0))
	await wait_physics_frames(30)
	assert_true(_npc.active is SurfaceCrawler)

func test_it_leaps_only_at_something_to_land_on():
	_box(Vector3(10, 1, 10), Vector3(0, -0.5, 0))
	_spawn(Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	await wait_physics_frames(5)
	var nowhere := Intent.idle(&"leap")
	nowhere.leap_to = Vector3(0, 30, 0)
	_npc.intent = nowhere
	await wait_physics_frames(10)
	assert_true(_npc.active is SurfaceCrawler, "nothing up there: it stays")
	_box(Vector3(6, 6, 6), Vector3(0, 20, 0))
	await wait_physics_frames(2)
	var there := Intent.idle(&"leap")
	there.leap_to = Vector3(0, 17, 0)
	_npc.intent = there
	await wait_physics_frames(5)
	assert_true(_npc.active is ZeroGDrift, "off it goes")
	var landed := false
	for i in 60 * 6:
		await wait_physics_frames(1)
		if _npc.active is SurfaceCrawler:
			landed = true
			break
	assert_true(landed, "and lands")
	assert_gt(_npc.global_position.y, 15.0, "on the other box")

func test_footing_that_moves_too_fast_is_lost():
	var crate := RigidBody3D.new()
	crate.gravity_scale = 0.0
	crate.mass = 10000.0
	var s := BoxShape3D.new()
	s.size = Vector3(8, 2, 8)
	_solid(s, Vector3.ZERO, crate)
	_spawn(Transform3D(Basis.IDENTITY, Vector3(0, 1.05, 0)))
	await wait_physics_frames(5)
	crate.linear_velocity = Vector3(2, 0, 0)
	await wait_physics_frames(60)
	assert_true(_npc.active is SurfaceCrawler, "2 m/s: it keeps its footing")
	assert_lt(Vector2(_npc.global_position.x - crate.global_position.x, _npc.global_position.z).length(), 1.5,
		"carried along")
	crate.linear_velocity = Vector3(4, 0, 0)
	await wait_physics_frames(30)
	assert_true(_npc.active is ZeroGDrift, "4 m/s: it lets go")

## A rock that leaves detail all at once (a jump far away, the debug hop) is
## freed before the director's next review demotes its skitters: in between,
## they must not step on ground that is gone.
class GoneSite extends NpcSite:
	var ground: Node
	func alive() -> bool:
		return is_instance_valid(ground) and ground.is_inside_tree()

func test_a_place_gone_stops_it_stepping_at_once():
	var rock := _box(Vector3(10, 10, 10), Vector3.ZERO)
	var site := GoneSite.new()
	site.id = &"test"
	site.ground = rock
	_npc = Npc.new()
	_root.add_child(_npc)
	var pose := Transform3D(Basis.IDENTITY, Vector3(0, 5.05, 0))
	_npc.setup(NpcRecord.make(&"crawler:0", &"crawler", &"test", pose.origin, 1), _species, site, false, pose)
	await wait_physics_frames(5)
	_npc.intent = Intent.go(Vector3(4.0, 5.0, 0.0), 1.0)
	await wait_physics_frames(10)
	rock.free()
	var at := _npc.global_position
	await wait_physics_frames(30)
	assert_false(site.alive(), "the place is gone")
	assert_eq(_npc.global_position, at, "and it has not moved since")
