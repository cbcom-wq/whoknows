extends GutTest

## Skitters on the start's big rock, in the real flight scene
## (docs/superpowers/specs/2026-09-26-npc-foundation-design.md §4.3, §4.6):
## approaching a herd wakes it out of sight, leaving puts it back, and live
## skitters ride the floating origin.

var _root: Node
var _ship: Ship
var _stream: AsteroidStream
var _director: NpcDirector
var _chase: Camera3D

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_stream = _root.get_node("AsteroidStream")
	_chase = _root.get_node("Ship/Exterior/ChaseCamera")
	await wait_physics_frames(5)
	_director = _root.exterior_npcs

## The start's big rock: in a belt, others can be in detail too.
func _detail() -> AsteroidDetail:
	return _stream.details.nearest(_ship.exterior.global_position)

## A herd's place on the start rock, and the way out from the rock there.
func _herd() -> Array:
	var detail := _detail()
	var site := RockSite.new(detail, _stream.seed)
	assert_gt(site.records.size(), 0, "the start rock has herds")
	var at := site.frame() * site.start_pose(site.records[0], _director.time).origin
	return [at, (at - detail.global_position).normalized()]

func _hull_to(at: Vector3) -> void:
	_ship.exterior.global_position = at
	_ship.exterior.linear_velocity = Vector3.ZERO
	_ship.exterior.angular_velocity = Vector3.ZERO

## Flies the hull from `from` to `to` at `speed` m/s; returns the chase
## camera's distance to each skitter as it came alive.
func _fly(from: Vector3, to: Vector3, speed: float) -> Dictionary:
	var woke := {}
	var steps := int(from.distance_to(to) / (speed / 60.0))
	for i in steps + 1:
		_hull_to(from.lerp(to, float(i) / float(maxi(steps, 1))))
		await wait_physics_frames(1)
		for id in _director.live:
			if not woke.has(id):
				woke[id] = _chase.global_position.distance_to((_director.live[id] as Npc).global_position)
	return woke

func test_none_are_live_at_the_start():
	assert_eq(_director.live.size(), 0, "the start is 700 m off the rock")

func test_approaching_a_herd_wakes_it_where_you_cannot_see():
	var herd := _herd()
	var woke: Dictionary = await _fly(herd[0] + herd[1] * 600.0, herd[0] + herd[1] * 60.0, 120.0)
	assert_gt(woke.size(), 0, "a herd woke")
	for id in woke:
		assert_gt(float(woke[id]), 250.0, "%s woke %.0f m from the camera: beyond its fade" % [id, woke[id]])
	for npc: Npc in _director.live.values():
		assert_true(npc.is_in_group(Universe.EXTERIOR_SPACE))
		assert_eq(npc.species.id, &"skitter")

func test_leaving_puts_them_back_to_sleep():
	var herd := _herd()
	await _fly(herd[0] + herd[1] * 600.0, herd[0] + herd[1] * 60.0, 150.0)
	assert_gt(_director.live.size(), 0)
	await _fly(herd[0] + herd[1] * 60.0, herd[0] + herd[1] * 900.0, 150.0)
	await wait_physics_frames(20)
	assert_eq(_director.live.size(), 0, "all asleep again")

func test_live_skitters_keep_their_place_through_a_shift():
	var herd := _herd()
	await _fly(herd[0] + herd[1] * 500.0, herd[0] + herd[1] * 60.0, 150.0)
	assert_gt(_director.live.size(), 0)
	var universe: Universe = _root.get_node("Universe")
	var before := {}
	for id in _director.live:
		before[id] = (_director.live[id] as Npc).local_position()
	universe.shift(Vector3(1000, 0, 0))
	for id in before:
		var npc: Npc = _director.live[id]
		assert_lt(npc.local_position().distance_to(before[id]), 0.001, "%s held its place on the rock" % id)

func test_woken_skitters_stand_on_the_rock():
	var herd := _herd()
	await _fly(herd[0] + herd[1] * 400.0, herd[0] + herd[1] * 60.0, 150.0)
	await wait_physics_frames(60)
	assert_gt(_director.live.size(), 0)
	var on_rock := 0
	for npc: Npc in _director.live.values():
		if npc.active is SurfaceCrawler and (npc.active as SurfaceCrawler).gripping:
			on_rock += 1
	assert_eq(on_rock, _director.live.size(), "every one gripping the rock")

func test_herds_that_a_drill_has_quietened_are_left_out_of_a_rock_that_loads():
	var herd := _herd()
	_hull_to(herd[0] + herd[1] * 60.0)
	await wait_physics_frames(2)
	var source := RockHerdSource.new(_stream)
	var all := source.records(_director)
	assert_gt(all.size(), 1, "the start rock has herds on offer")
	var target: Vector3 = all[0][1].frame() * all[0][0].home
	var target_id: StringName = all[0][0].id
	# A site already built keeps its records when quiet turns true...
	source.quiet = func(_site: StringName, _point: Vector3) -> bool: return true
	assert_eq(source.records(_director).size(), all.size(), "skitters in view are not taken away")
	# ...and a rebuilt one (the rock left detail and came back) drops them.
	var again := RockHerdSource.new(_stream)
	again.quiet = source.quiet
	assert_eq(again.records(_director).size(), 0, "a quiet rock loads with no herds")
	# Only the non-quiet ones, by point.
	var near := RockHerdSource.new(_stream)
	near.quiet = func(_site: StringName, point: Vector3) -> bool: return point.distance_to(target) < 0.01
	var left := near.records(_director)
	assert_eq(left.size(), all.size() - 1)
	for pair in left:
		assert_ne(pair[0].id, target_id)
