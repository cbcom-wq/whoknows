extends GutTest

## The queen's hall (docs/superpowers/specs/2026-11-16-wadoo-design.md §8, §10): the
## room built in house_b (WadooRooms), its door (WadooDoor), the walking grid open
## inside it (WadooPaths), its floor and dais under the walkers' feet (WadooSite),
## Oru before or beside the door, and the queen on her throne rising to receive you.

const POOL_RADIUS := 11.0
const HALL := "house_b"

var _layout: Dictionary
var _shell: Dictionary

func before_all():
	_layout = JSON.parse_string(FileAccess.get_file_as_string("res://data/places/oasis.json"))
	for s: Dictionary in _layout["shells"]:
		if s["id"] == HALL:
			_shell = s

## The hall's frame on flat ground at height 0, as PlaceField sets it.
func _frame() -> Transform3D:
	var at: Array = _shell["at"]
	return Transform3D(Basis(Vector3.UP, -deg_to_rad(float(_shell["yaw"]))),
		Vector3(float(at[0]), BrickShell.FOUNDATION, -float(at[1])))

func _size() -> Vector3:
	var sz: Array = _shell["size"]
	return Vector3(float(sz[0]), float(sz[1]), float(sz[2]))

## A site whose place node says where the hall is, as PlaceField's would.
func _site(state: WadooState = null) -> WadooSite:
	var node := Node3D.new()
	add_child_autofree(node)
	node.set_meta(&"rooms", {HALL: {"room": &"hall", "frame": _frame(), "size": _size()}})
	var site := WadooSite.new(node, _layout, POOL_RADIUS, func(e: float, n: float) -> Vector3: return Vector3(e, 0.0, -n))
	site.state = state
	return site

func _in_hall(local: Vector3) -> Vector2:
	return WadooSite.flat(_frame() * local)

func test_the_hall_is_open_and_has_a_room() -> void:
	assert_true(bool(_shell.get("open", false)))
	assert_eq(str(_shell.get("room", "")), "hall")

func test_the_room_has_its_marks_solids_and_dais() -> void:
	for name in ["seat", "stand", "sit"]:
		assert_not_null(WadooRooms.mark(&"hall", name), name)
	var sit: Transform3D = WadooRooms.mark(&"hall", "sit")
	var stand: Transform3D = WadooRooms.mark(&"hall", "stand")
	assert_almost_eq(sit.origin.y, 0.3, 0.01, "the throne stands on the dais")
	assert_almost_eq(WadooRooms.raised(&"hall", Vector2(sit.origin.x, sit.origin.z)), 0.3, 0.001)
	assert_almost_eq(WadooRooms.raised(&"hall", Vector2(stand.origin.x, stand.origin.z)), 0.3, 0.001)
	assert_almost_eq(WadooRooms.raised(&"hall", Vector2(0.0, 1.1)), 0.15, 0.001, "the step")
	assert_eq(WadooRooms.raised(&"hall", Vector2(0.0, 0.0)), 0.0, "the floor")
	var solids := WadooRooms.solids(&"hall")
	assert_gt(solids.size(), 8, "throne, basin, lamps, rack, jars")
	for sol: Array in solids:
		var half: Vector2 = sol[1]
		assert_gt(half.x, 0.05)
		assert_lt(absf((sol[0] as Vector2).x) + half.x, 3.31, "inside the walls")

func test_the_room_builds_lit_solid_and_painted() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	var room := WadooRooms.build(&"hall", parent, _frame())
	assert_eq(room.transform, _frame())
	var lights := room.find_children("*", "OmniLight3D", true, false)
	assert_eq(lights.size(), 4)
	assert_lte((lights[0] as OmniLight3D).light_energy, 1.0, "warm and dim: four lamps light pale walls")
	var solid := room.get_node("Solid") as StaticBody3D
	assert_eq(solid.collision_layer, BodyProxy.LAYER)
	assert_eq(solid.get_child_count(), WadooRooms.solids(&"hall").size() + 2, "and the dais and its step")
	var keys := {}
	for mi: Node in room.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		assert_eq(m.layers, OasisLooks.WORLD_LAYER)
		for s in m.mesh.get_surface_count():
			var mat := m.get_surface_override_material(s) as StandardMaterial3D
			assert_not_null(mat)
			assert_true(WadeePalette.ROOM.has(mat.resource_name), "%s is a room colour" % mat.resource_name)
			keys[mat.resource_name] = true
	assert_true(keys.has("sunglass") and keys.has("bronze") and keys.has("water"), str(keys.keys()))

func test_the_door_swings_in_and_stays_solid() -> void:
	var door := WadooDoor.make(1.08, 1.98, 0.5)
	add_child_autofree(door)
	assert_eq(door.name, WadooDoor.NAME)
	assert_eq(door.body.collision_layer, BodyProxy.LAYER)
	assert_eq(door.leaf.rotation.y, 0.0)
	door.set_open(true, true)
	assert_almost_eq(door.leaf.rotation.y, -WadooDoor.SWING, 0.001)
	var tip := door.leaf.transform * Vector3(1.0, 0.0, 0.0)
	assert_gt(tip.z, 0.9, "it swings into the room")
	door.set_open(false, true)
	assert_eq(door.leaf.rotation.y, 0.0)

func test_paths_open_the_hall_and_its_doorway() -> void:
	var paths := WadooPaths.build(_layout, POOL_RADIUS)
	assert_eq(paths.rooms.size(), 1)
	assert_true(paths.is_open(_in_hall(Vector3(0.0, 0.0, -1.8))), "the floor before the basin")
	assert_true(paths.is_open(_in_hall(Vector3(0.0, 0.0, -2.775))), "the doorway")
	assert_false(paths.is_open(_in_hall(Vector3(0.0, 0.0, -0.45))), "the basin")
	assert_false(paths.is_open(_in_hall(Vector3(-3.6, 0.0, 0.0))), "the west wall")
	var door: Dictionary = paths.doors[HALL][0]
	var sit: Transform3D = WadooRooms.mark(&"hall", "sit")
	var r := paths.route(door["at"], _in_hall(sit.origin))
	assert_false(r.is_empty(), "a way from the door to the throne")
	assert_lt(r[r.size() - 1].distance_to(_in_hall(sit.origin)), 1.2, "within the last stretch")

func test_the_floor_dais_and_ramp_under_their_feet() -> void:
	var site := _site()
	var f := _frame()
	assert_almost_eq(site.ground(_in_hall(Vector3(0.0, 0.0, -1.2))).y, f.origin.y, 0.001, "the floor")
	var sit: Transform3D = WadooRooms.mark(&"hall", "sit")
	assert_almost_eq(site.ground(_in_hall(sit.origin)).y, f.origin.y + 0.3, 0.001, "the dais")
	var half_z := _size().z * 0.5
	var mid := site.ground(_in_hall(Vector3(0.0, 0.0, -half_z - WadooSite.RAMP * 0.5))).y
	assert_almost_eq(mid, f.origin.y * 0.5, 0.01, "half way up the ramp")
	assert_almost_eq(site.ground(_in_hall(Vector3(0.0, 0.0, -half_z - 3.0))).y, 0.0, 0.001, "the ground outside")

func test_the_queen_wakes_on_her_throne() -> void:
	var site := _site()
	var throne := site.spot(&"court", "court:throne")
	assert_false(throne.is_empty())
	assert_eq(throne["action"], &"sit")
	var n := -1
	for k in WadooCast.count():
		if WadooCast.PEOPLE[k]["role"] == &"queen":
			n = k
	var pose := site.start_pose(WadooCast.record(n, _layout), 0.0)
	assert_lt(WadooSite.flat(pose.origin).distance_to(WadooSite.flat(throne["at"])), 0.01)
	assert_almost_eq(pose.origin.y, _frame().origin.y + 0.3, 0.01, "on the dais")
	var to_door := WadooSite.flat(throne["face"]) - WadooSite.flat(pose.origin)
	var fwd := -pose.basis.z
	assert_gt(Vector2(fwd.x, -fwd.z).normalized().dot(to_door.normalized()), 0.95, "looking down her hall")

func test_oru_stands_before_the_shut_door_and_beside_the_open() -> void:
	var state := WadooState.new()
	var site := _site(state)
	var shut := site.post_of("queen_door")
	assert_eq(shut["key"], "post:queen_door:shut")
	var door: Dictionary = site.door_of(HALL)
	assert_lt(WadooSite.flat(shut["at"]).distance_to(WadooSite.flat(door["at"])), 0.6, "in the way")
	state.do_task(&"pump")
	assert_eq(site.post_of("queen_door")["key"], "post:queen_door", "aside once they speak for you")
	state.turn_hostile()
	assert_eq(site.post_of("queen_door")["key"], "post:queen_door:shut")
	site.state = null
	assert_eq(site.post_of("queen_door")["key"], "post:queen_door", "unwired: as before")

## The queen's context at `at`, you at `player`, as the site fills it.
func _ctx(site: WadooSite, at: Vector3, player: Variant, time: float) -> NpcContext:
	var n := -1
	for k in WadooCast.count():
		if WadooCast.PEOPLE[k]["role"] == &"queen":
			n = k
	return _ctx_of(site, n, at, player, time)

## The context of the Wadee called `who`.
func _person_ctx(site: WadooSite, who: String, at: Vector3, player: Variant, time: float) -> NpcContext:
	var n := -1
	for k in WadooCast.count():
		if WadooCast.PEOPLE[k]["name"] == who:
			n = k
	return _ctx_of(site, n, at, player, time)

func _ctx_of(site: WadooSite, n: int, at: Vector3, player: Variant, time: float) -> NpcContext:
	var c := NpcContext.new()
	c.record = WadooCast.record(n, _layout)
	c.position = at
	var face: Vector3 = site.spot(&"court", "court:throne")["face"]
	c.forward = (face - at).normalized()
	c.player = player
	c.time = time
	c.needs = {}
	site.fill(c, _npc_of(site, c.record))
	return c

var _npcs := {}
func _npc_of(site: WadooSite, record: NpcRecord) -> Npc:
	var key := [site, record.id]
	if not _npcs.has(key):
		var npc := Npc.new()
		autofree(npc)
		npc.record = record
		npc.site = site
		_npcs[key] = npc
	return _npcs[key]

func test_oru_holds_his_post_and_never_steps_through_the_door() -> void:
	var site := _site(WadooState.new())
	var at: Vector3 = site.post_of("queen_door")["at"]
	var out: Vector2 = site.door_of(HALL)["out"]
	var gw := NpcBehaviours.make(&"give_way")
	var far := _person_ctx(site, "Oru", at, site.ground(WadooSite.flat(at) + out * 5.0), 9.0)
	assert_true(far.extra[&"holds_ground"], "at his post")
	gw.score(far)
	var near := _person_ctx(site, "Oru", at, site.ground(WadooSite.flat(at) + out * 1.2), 10.0)
	assert_eq(gw.score(near), 0.0, "you walk right up to him: he holds his post")
	assert_false(near.extra[&"nearby"].is_empty(), "somewhere to step to, were he not on guard")
	for p: Vector3 in near.extra[&"nearby"]:
		assert_eq(site.room_at(WadooSite.flat(p)), "", "never through the door into the hall")
	var off := site.ground(WadooSite.flat(at) + out * 4.0 + Vector2(out.y, -out.x) * 3.0)
	var away := _person_ctx(site, "Oru", off, site.ground(WadooSite.flat(off) + out * 1.0), 11.0)
	assert_false(away.extra[&"holds_ground"], "off his post")
	assert_eq(NpcBehaviours.make(&"give_way").score(away), 0.9, "off it, he steps aside as anyone does")
	var queen := _ctx(site, site.spot(&"court", "court:queen")["at"], null, 12.0)
	assert_false(queen.extra[&"holds_ground"])
	for p: Vector3 in queen.extra[&"nearby"]:
		assert_eq(site.room_at(WadooSite.flat(p)), HALL, "the queen's steps stay in her hall")

func test_the_queen_sits_and_rises_to_receive_you() -> void:
	var site := _site()
	var b := NpcBehaviours.make(&"hold_court")
	var throne: Dictionary = site.spot(&"court", "court:throne")
	var at: Vector3 = throne["at"]
	var ctx := _ctx(site, at, null, 10.0)
	b.start(ctx)
	var i := b.think(ctx)
	assert_eq(i.action, &"sit", "alone, she sits")
	assert_eq(site._state.get(ctx.record.id), &"seated")
	var you := site.ground(_in_hall(Vector3(0.0, 0.0, -0.9)))
	ctx = _ctx(site, at, you, 12.0)
	assert_eq(b.think(ctx).action, &"rise", "you come near: she rises")
	ctx = _ctx(site, at, you, 12.0 + 1.5)
	i = b.think(ctx)
	assert_eq(i.action, &"")
	assert_eq(i.face, you, "and turns to you")
	assert_eq(site._state.get(ctx.record.id, &""), &"", "no longer seated")
	var by_door := site.ground(_in_hall(Vector3(0.0, 0.0, -3.5)))
	ctx = _ctx(site, at, by_door, 20.0)
	assert_eq(b.think(ctx).face, by_door, "still near enough (SIT_AGAIN)")
	ctx = _ctx(site, at, null, 30.0)
	assert_eq(b.think(ctx).action, &"sit", "you have gone: she sits again")
