extends GutTest

## WadooPaths on the real oasis layout (docs/superpowers/specs/2026-11-16-wadoo-design.md
## §12): every door and every place a Wadee works is reachable, and no route
## crosses a wall, a shell or the pool.

const POOL_RADIUS := 11.0

var _layout: Dictionary
var _paths: WadooPaths

func before_all():
	_layout = JSON.parse_string(FileAccess.get_file_as_string("res://data/places/oasis.json"))
	_paths = WadooPaths.build(_layout, POOL_RADIUS)

func _hub() -> Vector2:
	# the open bank north-east of the pool
	return _paths.nearest_open(Vector2(14.0, 10.0))

func _reachable(to: Vector2) -> bool:
	var r := _paths.route(_hub(), to)
	return not r.is_empty() and r[r.size() - 1].distance_to(_paths.nearest_open(to)) < 0.01

func test_the_pool_and_the_shells_are_solid():
	assert_false(_paths.is_open(Vector2.ZERO), "the pool's middle")
	assert_false(_paths.is_open(Vector2(POOL_RADIUS * 0.9, 0.0)), "in the water")
	assert_false(_paths.is_open(Vector2(-8.0, 38.5)), "inside house_b")
	assert_false(_paths.is_open(Vector2(9.8, 35.9)), "inside hut_b")
	assert_false(_paths.is_open(Vector2(17.0, 1.2)), "the pump")
	assert_false(_paths.is_open(Vector2(0.0, 60.0)), "outside the walls")
	assert_true(_paths.is_open(_hub()))

## Doors no route reaches, on purpose: home_5's opens into its own yard, walled by
## the Listening House and yard_south_0 (a gap under a metre). No one lives there
## now (WadooCast).
const SEALED := ["home_5"]

func test_every_door_is_reachable():
	assert_gt(_paths.doors.size(), 10)
	for id: String in _paths.doors:
		if id in SEALED:
			continue
		for d: Dictionary in _paths.doors[id]:
			var at: Vector2 = d["at"]
			assert_true(_paths.is_open(at) or _paths.nearest_open(at).distance_to(at) < 1.5,
				"%s's door spot %s is near open ground" % [id, at])
			assert_true(_reachable(at), "%s's door is reachable" % id)

func test_job_places_are_reachable():
	var places := {"garden_0": Vector2(-42.1, -5.9), "garden_1": Vector2(-20.4, 36.1),
		"garden_dry": Vector2(44.5, 1.6), "pump": Vector2(17.0, 1.2), "breach": Vector2(42.0, -10.0),
		"sail_0": Vector2(-19.5, -33.77), "sail_1": Vector2(-33.59, 23.52), "sail_2": Vector2(42.69, 10.64),
		"gate": Vector2(-40.0, -21.0), "bank_south": Vector2(0.0, -POOL_RADIUS - 1.5)}
	for id: String in places:
		var p: Vector2 = places[id]
		assert_lt(_paths.nearest_open(p).distance_to(p), 3.5, "%s has open ground beside it" % id)
		assert_true(_reachable(p), "%s is reachable" % id)

func test_routes_never_cross_a_solid():
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var tried := 0
	while tried < 150:
		var a := Vector2(rng.randf_range(-45, 45), rng.randf_range(-45, 45))
		var b := Vector2(rng.randf_range(-45, 45), rng.randf_range(-45, 45))
		if not _paths.is_open(a) or not _paths.is_open(b):
			continue
		tried += 1
		var r := _paths.route(a, b)
		for k in r.size() - 1:
			assert_true(_paths.clear_line(r[k], r[k + 1]), "leg %s -> %s of %s -> %s" % [r[k], r[k + 1], a, b])
			if not _paths.clear_line(r[k], r[k + 1]):
				return

func test_the_gate_leads_outside():
	var outside := _paths.gate + (_paths.gate - Vector2.ZERO).normalized() * 6.0
	assert_true(_paths.is_open(outside), "the ground before the gate")
	assert_true(_reachable(outside))
	assert_false(_paths.is_open(Vector2(-48.7, -5.1)), "the wall itself")

func test_the_turn_matches_the_place_field():
	# a point 1 m in front of a shell turned 90 degrees clockwise lies 1 m to its west
	var p := WadooPaths.local_to_place(Vector2(0.0, -1.0), 90.0)
	var back := WadooPaths.place_to_local(p, 90.0)
	assert_almost_eq(back.x, 0.0, 0.0001)
	assert_almost_eq(back.y, -1.0, 0.0001)
	var f := Transform3D(Basis(Vector3.UP, -deg_to_rad(90.0)), Vector3.ZERO)
	var q := f * Vector3(0.0, 0.0, -1.0)
	assert_almost_eq(p.x, q.x, 0.0001)
	assert_almost_eq(p.y, -q.z, 0.0001)
