extends GutTest

## The dev spawner (rock creatures spec §7.2): what F10 makes lives for the
## session only, and is offered to its director like any source's records.

class UpSite extends NpcSite:
	var up := true
	func alive() -> bool:
		return up

var _dev: DevCreatures
var _director: NpcDirector
var _site: UpSite

func before_each():
	DevCreatures.restart()
	_dev = DevCreatures.new()
	_director = NpcDirector.new()
	autofree(_director)
	_site = UpSite.new()

func _record(id: StringName) -> NpcRecord:
	return NpcRecord.make(id, &"skitter", &"rock:test", Vector3.ZERO, 1)

func test_records_are_offered_until_demoted_then_forgotten():
	var r := _record(&"dev:skitter:1")
	_dev.add(r, _site)
	var offered := _dev.records(_director)
	assert_eq(offered.size(), 1, "offered before it is live")
	assert_same(offered[0][0], r)
	assert_same(offered[0][1], _site)
	_director.live[r.id] = null
	assert_eq(_dev.records(_director).size(), 1, "offered while live")
	_director.live.erase(r.id)
	assert_eq(_dev.records(_director).size(), 0, "demoted or dead: forgotten")
	assert_eq(_dev.records(_director).size(), 0, "and it stays forgotten")

func test_records_go_with_their_site():
	_dev.add(_record(&"dev:skitter:1"), _site)
	_site.up = false
	assert_eq(_dev.records(_director).size(), 0)

func test_ids_count_up_and_never_look_like_a_rocks():
	assert_eq(_dev.next_id(&"limpet"), &"dev:limpet:1")
	assert_eq(_dev.next_id(&"limpet"), &"dev:limpet:2")
	assert_eq(_dev.next_id(&"skitter"), &"dev:skitter:1", "each species counts for itself")

## One ledger holds every director's creatures by id, so two ships' droids
## must not share one.
func test_two_sources_never_hand_out_the_same_id():
	var other := DevCreatures.new()
	var seen := {}
	for i in 3:
		for dev in [_dev, other]:
			var id: StringName = dev.next_id(&"maintenance_droid")
			assert_false(seen.has(id), "%s was given twice" % id)
			seen[id] = true
	assert_eq(seen.size(), 6)

# --- in the real flight scene -------------------------------------------------

var _root: Node
var _stream: AsteroidStream
var _avatar: Avatar

func _scene() -> void:
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_stream = _root.get_node("AsteroidStream")
	_avatar = _root.get_node("Ship/Interior/Avatar")
	await wait_physics_frames(5)

## On a spacewalk `metres` off the start rock's surface above a herd, looking
## at the rock (or, with `away`, the other way). Returns the rock's detail.
func _walk_to_the_rock(metres: float, away := false) -> AsteroidDetail:
	var ship: Ship = _root.get_node("Ship")
	var detail := _stream.details.nearest(ship.exterior.global_position)
	var site := RockSite.new(detail, _stream.seed)
	var at: Vector3 = site.frame() * site.start_pose(site.records[0], 0.0).origin
	var out := (at - detail.global_position).normalized()
	ship.exterior.global_position = at + out * 400.0
	ship.exterior.linear_velocity = Vector3.ZERO
	var look := out if away else -out
	var pose := Transform3D(Basis.looking_at(look, Vector3.UP), at + out * metres)
	_avatar.enter_suit(_root.get_node("Outside"), pose, Vector3.ZERO, ship.exterior)
	await wait_physics_frames(40)
	return detail

func _dev_npcs() -> Array[Npc]:
	var out: Array[Npc] = []
	for npc: Npc in _root.exterior_npcs.live_npcs():
		if String(npc.record.id).begins_with("dev:"):
			out.append(npc)
	return out

func test_spawning_a_skitter_group_on_the_start_rock():
	await _scene()
	var detail := await _walk_to_the_rock(30.0)
	assert_eq(_root.spawn_creature(&"skitter"), "Skitter x3 on the rock")
	await wait_physics_frames(40)
	var npcs := _dev_npcs()
	assert_eq(npcs.size(), 3)
	for npc in npcs:
		assert_true(String(npc.record.id).begins_with("dev:skitter:"))
		var up := (npc.global_position - detail.global_position).normalized()
		var q := PhysicsRayQueryParameters3D.create(npc.global_position + up * 2.0, npc.global_position - up * 2.0,
			AsteroidBody.LAYER)
		var hit := detail.get_world_3d().direct_space_state.intersect_ray(q)
		assert_false(hit.is_empty(), "%s stands at the rock" % npc.record.id)
		if not hit.is_empty():
			assert_lt((hit["position"] as Vector3).distance_to(npc.global_position), 1.0)

func test_the_group_stands_where_the_crosshair_was():
	await _scene()
	var detail := await _walk_to_the_rock(30.0)
	var cam := get_viewport().get_camera_3d()
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_basis.z * 60.0,
		AsteroidBody.LAYER)
	var hit := detail.get_world_3d().direct_space_state.intersect_ray(q)
	assert_false(hit.is_empty(), "the crosshair is on the rock")
	_root.spawn_creature(&"skitter")
	await wait_physics_frames(40)
	for npc in _dev_npcs():
		assert_lt(npc.global_position.distance_to(hit["position"]), 8.0, "%s is in the huddle" % npc.record.id)

func test_no_rock_in_view_says_why():
	await _scene()
	await _walk_to_the_rock(30.0, true)
	var before: int = _root.exterior_npcs.live_npcs().size()
	assert_eq(_root.spawn_creature(&"skitter"), "needs a big rock in view")
	await wait_physics_frames(40)
	assert_eq(_root.exterior_npcs.live_npcs().size(), before)
	assert_eq(_dev_npcs().size(), 0)

func test_a_rock_beyond_sixty_metres_is_not_in_view():
	await _scene()
	await _walk_to_the_rock(90.0)
	assert_eq(_root.spawn_creature(&"skitter"), "needs a big rock in view")

func test_the_droid_needs_a_deck_under_you():
	await _scene()
	await _walk_to_the_rock(30.0)
	assert_eq(_root.spawn_creature(&"maintenance_droid"), "needs to be aboard")

## Looks straight down from where the eye is: at the deck.
func _look_at_the_deck() -> void:
	var cam := _avatar.camera
	cam.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), cam.global_position)

func _droid_ids(ship: Ship) -> Array[StringName]:
	var out: Array[StringName] = []
	for npc: Npc in ship.npc_director.live_npcs():
		if String(npc.record.id).begins_with("dev:"):
			out.append(npc.record.id)
	out.sort()
	return out

func test_the_droid_is_made_aboard():
	await _scene()
	await wait_physics_frames(2)
	var ship: Ship = _root.aboard
	var before: int = ship.npc_director.live_npcs().size()
	_look_at_the_deck()
	assert_eq(_root.spawn_creature(&"maintenance_droid"), "Maintenance droid x1 aboard")
	await wait_physics_frames(40)
	assert_eq(ship.npc_director.live_npcs().size(), before + 1)
	var found := false
	for npc: Npc in ship.npc_director.live_npcs():
		if npc.record.id == &"dev:maintenance_droid:1":
			found = true
			assert_same(npc.site, ship.crew_site)
	assert_true(found)

func test_the_droid_needs_the_deck_in_view():
	await _scene()
	await wait_physics_frames(2)
	var ship: Ship = _root.aboard
	var cam := _avatar.camera
	cam.global_transform = Transform3D(Basis.IDENTITY, cam.global_position + Vector3(0, 5000, 0))
	assert_eq(_root.spawn_creature(&"maintenance_droid"), "needs the deck in view")
	await wait_physics_frames(40)
	assert_eq(_droid_ids(ship).size(), 0, "nothing was made")

func test_an_id_the_ledger_remembers_is_never_reused():
	await _scene()
	await wait_physics_frames(2)
	var ship: Ship = _root.aboard
	_root.npc_ledger.mark_dead(&"dev:maintenance_droid:1")
	_root.npc_ledger.set_health(&"dev:maintenance_droid:2", 5.0, 20.0)
	_look_at_the_deck()
	assert_eq(_root.spawn_creature(&"maintenance_droid"), "Maintenance droid x1 aboard")
	await wait_physics_frames(40)
	assert_eq(_droid_ids(ship), [&"dev:maintenance_droid:3"] as Array[StringName])

func test_two_ships_never_share_a_dev_id():
	await _scene()
	var a: Ship = _root.aboard
	var dev_a: DevCreatures = _root.dev_creatures[a.npc_director]
	var dev_ex: DevCreatures = _root.dev_creatures[_root.exterior_npcs]
	assert_ne(dev_a.next_id(&"maintenance_droid"), dev_ex.next_id(&"maintenance_droid"))

func test_a_skitter_asked_for_aboard_is_not_made():
	await _scene()
	assert_eq(_root.spawn_creature(&"skitter"), "needs a big rock in view")
