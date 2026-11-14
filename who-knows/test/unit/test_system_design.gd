extends GutTest

## System designs (desert world spec §8; phase 3 plan, Task 3): tweaks, stamps
## and places from JSON, validated, and no change at all where there is no design.

const TEST_FILE := "user://test_system_design.json"
const FIELDS: Array[String] = ["name", "radius_m", "relief_m", "surface_gravity", "archetype", "palette", "atmosphere"]

## The designs, as dictionaries, from the data and for tests.
func _design(bodies: Dictionary, seed := 4242) -> SystemDesign:
	return SystemDesign.from_data({"seed": seed, "bodies": bodies}, "test")

func _first_planet(system: SystemRecipe) -> SystemBody:
	return system.planets()[0]

func _problems(bodies: Dictionary) -> PackedStringArray:
	var system := SystemRecipe.from_seed(4242, false)
	return _design(bodies).problems(system)

func _write(data: Dictionary) -> void:
	var file := FileAccess.open(TEST_FILE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func after_all() -> void:
	DirAccess.remove_absolute(TEST_FILE)

func test_every_design_in_the_data_is_valid() -> void:
	var files := DirAccess.get_files_at(SystemDesign.DIR)
	assert_gt(files.size(), 0, "there is at least the kesdra design")
	for file in files:
		if file.get_extension() != "json":
			continue
		var design := SystemDesign.load_file("%s/%s" % [SystemDesign.DIR, file])
		assert_not_null(design, file)
		var system := SystemRecipe.from_seed(design.seed)
		assert_eq(design.problems(system), PackedStringArray(), file)

func test_a_tweak_changes_only_its_fields() -> void:
	var plain := SystemRecipe.from_seed(4242, false)
	var target := _first_planet(plain)
	_write({"seed": 4242, "bodies": {str(target.id): {"tweak": {"name": "WELL MET", "palette": "ice"}}}})
	var design := SystemDesign.load_file(TEST_FILE)
	var changed := SystemRecipe.with_design(4242, design)
	var was := plain.body(target.id).recipe
	var now := changed.body(target.id).recipe
	assert_eq(now.name, "WELL MET")
	assert_eq(SpacePalette.WORLDS[now.palette][&"name"], &"ice")
	for field in ["radius_m", "relief_m", "surface_gravity", "archetype", "atmosphere"]:
		assert_eq(now.get(field), was.get(field), field)
	assert_eq(changed.bodies.size(), plain.bodies.size())
	for b in plain.bodies:
		if b.id == target.id:
			continue
		var other := changed.body(b.id)
		if b.parent_id != target.id:
			assert_eq(other.name, b.name, "%s's name" % b.id)
		assert_eq(other.point.minus(b.point).length(), 0.0, "%s's point" % b.id)
		if b.recipe != null:
			for field in FIELDS:
				assert_eq(other.recipe.get(field), b.recipe.get(field), "%s's %s" % [b.id, field])
			assert_eq(other.recipe.stamps.size(), 0)

func test_a_renamed_planet_names_its_moons() -> void:
	var plain: SystemRecipe
	var planet: SystemBody
	for seed in range(4242, 4342):
		plain = SystemRecipe.from_seed(seed, false)
		for p in plain.planets():
			if not plain.moons_of(p).is_empty() and planet == null:
				planet = p
		if planet != null:
			break
	assert_not_null(planet, "some seed has a planet with moons")
	var design := _design({str(planet.id): {"tweak": {"name": "HALLOW"}}}, plain.seed)
	var changed := SystemRecipe.with_design(plain.seed, design)
	assert_eq(changed.body(planet.id).name, "HALLOW")
	for m in changed.moons_of(changed.body(planet.id)):
		assert_true(m.name.begins_with("HALLOW "), m.name)
	assert_eq(changed.warp_target(planet.id).name, "HALLOW")

func test_stamps_land_on_the_recipe() -> void:
	var plain := SystemRecipe.from_seed(4242, false)
	var id := str(_first_planet(plain).id)
	var bodies := {id: {
		"places": [{"id": "camp", "name": "CAMP", "lat": 20.0, "lon": 35.0, "heading": 30.0}],
		"stamps": [
			{"id": "floor", "kind": "flatten", "place": "camp", "at": [12.0, -7.0], "radius": 60.0, "edge": 40.0, "ground": ""},
			{"id": "pool", "kind": "basin", "lat": 20.0, "lon": 35.0, "radius": 17.0, "floor": 9.0, "depth": 1.3},
		]}}
	var design := _design(bodies, plain.seed)
	var system := SystemRecipe.with_design(plain.seed, design)
	var recipe := system.body(StringName(id)).recipe
	var place := design.places_on(StringName(id))[0]
	assert_eq(recipe.stamps.size(), 2)
	var want := place.local_dir(12.0, -7.0, recipe.radius_m)
	assert_lt(recipe.stamps[0].centre.distance_to(want), 1e-9)
	assert_eq(recipe.stamps[0].radius, 60.0)
	assert_true(is_nan(recipe.stamps[0].level), "no level pinned: the terrain finds it")
	assert_eq(recipe.stamps[1].kind, TerrainStamp.Kind.BASIN)
	assert_eq(recipe.stamps[1].floor_radius, 9.0)
	assert_eq(recipe.stamps[1].depth, 1.3)
	assert_lt(recipe.stamps[1].centre.distance_to(SystemDesign.dir_of(20.0, 35.0)), 1e-12)
	# The offset really is 12 m east and 7 m south of the place, in metres on the ground.
	var off := (want - place.dir()) * recipe.radius_m
	assert_almost_eq(off.length(), Vector2(12.0, 7.0).length(), 0.01)
	assert_eq(system.places().size(), 1)
	assert_eq(design.problems(system), PackedStringArray())

func test_problems_name_the_body() -> void:
	var plain := SystemRecipe.from_seed(4242, false)
	var id := str(_first_planet(plain).id)
	var flat := {"id": "a", "kind": "flatten", "lat": 10.0, "lon": 10.0, "radius": 50.0, "edge": 20.0}
	var cases := {
		"no such body": {"p99": {"tweak": {}}},
		"unknown tweak key": {id: {"tweak": {"colour": "red"}}},
		"unknown archetype": {id: {"tweak": {"archetype": "SWAMP"}}},
		"unknown atmosphere": {id: {"tweak": {"atmosphere": "SOUP"}}},
		"unknown palette": {id: {"tweak": {"palette": "mauve"}}},
		"unknown stamp key": {id: {"stamps": [flat.merged({"wobble": 1}, true)]}},
		"latitude": {id: {"stamps": [flat.merged({"lat": 95.0}, true)]}},
		"keep outside 0 to 1": {id: {"stamps": [flat.merged({"keep": 1.0}, true)]}},
		"ground the palette lacks": {id: {"tweak": {"palette": "ice"}, "stamps": [flat.merged({"ground": "pad"}, true)]}},
		"stamps that overlap": {id: {"stamps": [flat, flat.merged({"id": "b", "lon": 10.01}, true)]}},
		"a place off the flat": {id: {"stamps": [flat],
			"places": [{"id": "far", "lat": 40.0, "lon": 10.0}]}},
		"a stamp's place that is not there": {id: {"stamps": [{"id": "s", "place": "nowhere", "at": [0, 0], "radius": 5.0}]}},
	}
	for label: String in cases:
		var out := _problems(cases[label])
		assert_eq(out.size(), 1, "%s: %s" % [label, out])
		if out.size() == 1:
			assert_string_contains(out[0], "p99" if label == "no such body" else id, label)

func test_problems_pass_stamps_that_nest_or_keep_apart() -> void:
	var plain := SystemRecipe.from_seed(4242, false)
	var id := str(_first_planet(plain).id)
	var floor_stamp := {"id": "floor", "kind": "flatten", "lat": 10.0, "lon": 10.0, "radius": 120.0, "edge": 150.0}
	var pad := {"id": "pad", "kind": "flatten", "lat": 10.0, "lon": 10.0, "radius": 26.0, "edge": 4.0}
	var far := {"id": "far", "kind": "flatten", "lat": 11.0, "lon": 10.0, "radius": 26.0, "edge": 4.0}
	var places := [{"id": "home", "lat": 10.0, "lon": 10.0}]
	assert_eq(_problems({id: {"stamps": [floor_stamp, pad, far], "places": places}}), PackedStringArray())
	assert_eq(_problems({id: {"stamps": [pad, floor_stamp]}}).size(), 1, "the outer one comes first")

func test_a_malformed_file_is_null_and_an_error() -> void:
	var file := FileAccess.open(TEST_FILE, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	assert_null(SystemDesign.load_file(TEST_FILE))
	assert_push_error("is not a system design")

func test_lat_lon_frame() -> void:
	assert_lt(SystemDesign.dir_of(0.0, 0.0).distance_to(Vector3.RIGHT), 1e-9)
	assert_lt(SystemDesign.dir_of(90.0, 0.0).distance_to(Vector3.UP), 1e-9)
	assert_lt(SystemDesign.dir_of(0.0, 90.0).distance_to(Vector3(0.0, 0.0, -1.0)), 1e-9)
	var d := SystemDesign.dir_of(30.0, 40.0)
	var frame := SystemDesign.frame_at(d, 0.0)
	assert_lt(frame.y.distance_to(d), 1e-9)
	var north := -frame.z
	assert_gt(north.dot(Vector3.UP), 0.0)
	assert_almost_eq(north.dot(d), 0.0, 1e-9)
	assert_lt(frame.x.distance_to(north.cross(d)), 1e-9)
	assert_almost_eq(frame.determinant(), 1.0, 1e-9)
	var turned := SystemDesign.frame_at(d, 90.0)
	assert_lt((-turned.z).distance_to(frame.x), 1e-6, "heading 90 faces east")
	assert_lt(turned.y.distance_to(d), 1e-6)

func test_no_design_no_change() -> void:
	var plain := SystemRecipe.from_seed(1337, false)
	var designed := SystemRecipe.from_seed(1337)
	assert_null(plain.design)
	assert_not_null(designed.design)
	assert_eq(designed.describe(), plain.describe())
	assert_eq(designed.bodies.size(), plain.bodies.size())
	for b in plain.bodies:
		var other := designed.body(b.id)
		if b.recipe == null:
			continue
		for field in FIELDS:
			assert_eq(other.recipe.get(field), b.recipe.get(field), "%s's %s" % [b.id, field])
		assert_eq(other.recipe.seed, b.recipe.seed)
		assert_eq(other.recipe.kind, b.recipe.kind)
		# Only p3 has the design's stamps (the oasis floor, its pad and its pool).
		assert_eq(other.recipe.stamps.size(), 3 if b.id == &"p3" else 0, "%s's stamps" % b.id)

func test_the_kesdra_tweak_pins_what_p3_rolls() -> void:
	var p3 := SystemRecipe.from_seed(1337, false).body(&"p3").recipe
	assert_eq(p3.archetype, WorldRecipe.Archetype.DUNES)
	assert_eq(p3.palette, SpacePalette.DESERT_PALETTE)
	assert_eq(p3.atmosphere, WorldRecipe.Atmosphere.THICK)

func test_the_offset_points_east_and_north_of_the_place() -> void:
	var plain := SystemRecipe.from_seed(4242, false)
	var id := StringName(str(_first_planet(plain).id))
	var r := plain.body(id).recipe.radius_m
	for heading in [0.0, 90.0]:
		var bodies := {str(id): {"places": [{"id": "camp", "lat": 20.0, "lon": 35.0, "heading": heading}]}}
		var place := _design(bodies).places_on(id)[0]
		var true_frame := SystemDesign.frame_at(place.dir(), 0.0)
		var east: Vector3 = true_frame.x
		var north: Vector3 = -true_frame.z
		# Layout [east, north] metres, in metres on the ground (the call 3 formula).
		var e_off := (place.local_dir(12.0, 0.0, r) - place.dir()) * r
		var n_off := (place.local_dir(0.0, 7.0, r) - place.dir()) * r
		if heading == 0.0:
			assert_almost_eq(e_off.dot(east), 12.0, 0.01, "+e is east")
			assert_almost_eq(n_off.dot(north), 7.0, 0.01, "+n is north")
		else:
			# Clockwise about up: layout north turns onto true east, layout east onto true south.
			assert_almost_eq(n_off.dot(east), 7.0, 0.01, "+n is east at heading 90")
			assert_almost_eq(e_off.dot(-north), 12.0, 0.01, "+e is south at heading 90")
		assert_almost_eq(e_off.length(), 12.0, 0.01)
		assert_almost_eq(n_off.length(), 7.0, 0.01)

func test_a_moons_own_name_tweak_wins() -> void:
	var plain: SystemRecipe
	var planet: SystemBody
	for seed in range(4242, 4442):
		plain = SystemRecipe.from_seed(seed, false)
		for p in plain.planets():
			if planet == null and plain.moons_of(p).size() >= 2:
				planet = p
		if planet != null:
			break
	assert_not_null(planet, "some seed has a planet with two moons")
	var moons := plain.moons_of(planet)
	var design := _design({str(moons[0].id): {"tweak": {"name": "PEBBLE"}}}, plain.seed)
	var changed := SystemRecipe.with_design(plain.seed, design)
	assert_eq(changed.body(moons[0].id).name, "PEBBLE")
	assert_eq(changed.body(moons[0].id).recipe.name, "PEBBLE")
	assert_eq(changed.warp_target(moons[0].id).name, "PEBBLE")
	assert_eq(changed.body(moons[1].id).name, moons[1].name, "a sibling keeps its derived name")
	assert_eq(changed.body(planet.id).name, planet.name)
