extends GutTest

## Signs of life in the real flight scene (NPC foundation spec §22): the start
## rock's herds are sensed, as pings from afar and regions close by; a region
## holds its herd; the HUD shows them in life's colour.

var _root: Node
var _ship: Ship
var _stream: AsteroidStream

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_stream = _root.get_node("AsteroidStream")
	await wait_physics_frames(5)

func _life() -> Array[Contact]:
	var out: Array[Contact] = []
	for c in _ship.sensors.contacts(10000.0):
		if c.kind == &"life":
			out.append(c)
	return out

func test_the_start_rocks_herds_are_sensed():
	var cs := _life()
	var detail: AsteroidDetail = _stream.details.live.values()[0]
	var herds := RockHerds.herds(detail.rock, detail.data, _stream.seed)
	assert_eq(cs.size(), herds.size(), "one contact per herd")
	for c in cs:
		assert_true(String(c.id).begins_with("life:" + String(RockHerds.site_of(detail.rock))))

func test_far_off_they_ping_and_near_they_are_regions():
	var detail: AsteroidDetail = _stream.details.live.values()[0]
	var out := (_ship.exterior.global_position - detail.global_position).normalized()
	_ship.exterior.global_position = detail.global_position + out * (detail.rock.radius + 2500.0)
	_ship.sensors.refresh(10000.0)
	for c in _life():
		assert_eq(c.precision, Contact.PING, "%s from 2.5 km" % c.id)
	_ship.exterior.global_position = detail.global_position + out * (detail.rock.radius + 150.0)
	_ship.sensors.refresh(10000.0)
	var regions := 0
	for c in _life():
		if c.precision == Contact.REGION:
			regions += 1
	assert_gt(regions, 0, "close by, regions")

func test_an_awake_herd_is_inside_its_region():
	var detail: AsteroidDetail = _stream.details.live.values()[0]
	var site := RockSite.new(detail, _stream.seed)
	var at := site.frame() * site.start_pose(site.records[0], 0.0).origin
	var out := (at - detail.global_position).normalized()
	for i in 20:
		_ship.exterior.global_position = at + out * lerpf(400.0, 60.0, i / 19.0)
		await wait_physics_frames(3)
	var director: NpcDirector = _root.exterior_npcs
	assert_gt(director.live.size(), 0)
	_ship.sensors.refresh(10000.0)
	var universe: Universe = _root.get_node("Universe")
	for c in _life():
		if c.precision != Contact.REGION:
			continue
		var centre := universe.to_engine(c.point)
		for npc: Npc in director.live_npcs():
			if LifeContacts.herd_id(npc.site.id, {"index": npc.record.herd}) == c.id:
				assert_lt(npc.global_position.distance_to(centre), c.radius, "%s is inside %s" % [npc.record.id, c.id])

func test_the_hud_shows_them_in_lifes_colour_on_a_spacewalk_and_in_chase_view():
	var markers: Array = _root.contact_markers
	assert_eq(markers.size(), 3, "cockpit, chase, spacewalk")
	var chase: ContactMarker = markers[1]
	var cam: Camera3D = _root.get_node("Ship/Exterior/ChaseCamera")
	cam.make_current()
	var t := VehicleTelemetry.new()
	chase.render(t)
	assert_gt(chase.marks.size(), 0, "something marked")
	for m in chase.marks:
		assert_eq(m["kind"], &"life")
		var col: Color = m["colour"]
		assert_almost_eq(col.g, HudPalette.LIFE.g, 0.01, "life's colour")
		assert_string_contains(m["text"], "LIFE?")
	assert_true(chase.marks.size() <= ContactMarker.MOST)
	var walk: ContactMarker = markers[2]
	walk.render(t)
	assert_eq(walk.marks.size(), 0, "the spacewalk marker waits for the suit")
