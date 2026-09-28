extends GutTest

## Rocks in a star system (the system skeleton spec §6): big rocks and their
## swarms only in belts, rubble and mid-size rocks crowding rings, none inside
## a body, and the flight starting by the first belt's first group.

const T := AsteroidRecipe.Tier

var _system: SystemRecipe
var _recipe: AsteroidRecipe

func before_all():
	_system = SystemRecipe.from_seed(1337)
	_recipe = AsteroidRecipe.new(_system.seed, null, _system.asteroid_shapes())

## The first seed from `from` with a ringed planet: [system, planet].
func _ringed(from := 1) -> Array:
	for s in range(from, from + 200):
		var sys := SystemRecipe.from_seed(s)
		for p in sys.planets():
			if p.ring != null:
				return [sys, p]
	fail_test("no ringed planet")
	return []

## A point in `ring`'s slab, at the middle of its width.
func _in_ring(ring: AsteroidShapes.Ring, angle: float) -> UniversePoint:
	var across := ring.normal.cross(Vector3.RIGHT)
	if across.length() < 0.1:
		across = ring.normal.cross(Vector3.FORWARD)
	across = across.normalized()
	var sideways := ring.normal.cross(across)
	return ring.centre.plus((across * cos(angle) + sideways * sin(angle)) * (ring.inner + ring.outer) * 0.5)

func test_big_rocks_lie_only_in_belts():
	var shapes := _recipe.shapes
	var seen := 0
	for x in range(-32, 33):
		for z in range(-32, 33, 4):
			var cell := Vector3i(x, 0, z)
			for rock in _recipe.cell_rocks(T.GIANT, cell):
				seen += 1
				var at := AsteroidRecipe.cell_corner(T.GIANT, cell).plus(rock.local)
				assert_gt(shapes.belt_profile(at), 0.0, "a big rock outside every belt at %s" % at)
	assert_gt(seen, 0, "the sweep found no big rocks at all")

func test_a_belt_is_busy():
	var belt := _system.belts[0]
	var cells := {}
	var groups := 0
	var steps := ceili(TAU * belt.radius / 2500.0)
	for k in steps:
		var angle := TAU * k / steps
		var at := belt.centre.plus(Vector3(cos(angle), 0.0, sin(angle)) * belt.radius)
		var cell := AsteroidRecipe.cell_of(T.GIANT, at)
		if cells.has(cell):
			continue
		cells[cell] = true
		if not _recipe.cell_rocks(T.GIANT, cell).is_empty():
			groups += 1
	gut.p("belt at %.0f km: %d groups in %d regions along its centre" % [belt.radius / 1000.0, groups, cells.size()])
	assert_gt(groups, cells.size() / 5)

func test_nothing_big_lies_off_the_belts_where_the_old_field_had_groups():
	# Open space between belts: the old field's noise would put groups here.
	var open := AsteroidRecipe.new(_system.seed)
	var field := 0
	var system := 0
	for x in range(-8, 9):
		for z in range(-8, 9):
			var cell := Vector3i(x, 0, z)
			field += open.cell_rocks(T.GIANT, cell).size()
			system += _recipe.cell_rocks(T.GIANT, cell).size()
	assert_gt(field, 0)
	assert_eq(system, 0, "the star's neighbourhood holds no groups")

func test_rings_are_crowded_with_rubble_and_never_giants():
	var found: Array = _ringed()
	var sys: SystemRecipe = found[0]
	var planet: SystemBody = found[1]
	var recipe := AsteroidRecipe.new(sys.seed, null, sys.asteroid_shapes())
	var inside := 0
	var total := 0
	for k in 6:
		var at := _in_ring(planet.ring, k * 1.0)
		var cell := AsteroidRecipe.cell_of(T.RUBBLE, at)
		for rock in recipe.cell_rocks(T.RUBBLE, cell):
			total += 1
			var p := AsteroidRecipe.cell_corner(T.RUBBLE, cell).plus(rock.local)
			if planet.ring.profile(p) > 0.0:
				inside += 1
		var region := AsteroidRecipe.cell_of(T.GIANT, at)
		assert_eq(recipe.cell_rocks(T.GIANT, region).size(), 0, "a big rock in a ring")
	gut.p("ring: %d rubble, %d in the slab" % [total, inside])
	assert_gt(total, 6 * 4)
	assert_gt(float(inside), total * 0.8)

func test_no_rock_lies_inside_a_body():
	var found: Array = _ringed()
	var sys: SystemRecipe = found[0]
	var recipe := AsteroidRecipe.new(sys.seed, null, sys.asteroid_shapes())
	for b in sys.bodies:
		for tier in [T.RUBBLE, T.MID]:
			for k in 6:
				var dir := Vector3(sin(k * 1.7), cos(k * 2.3), sin(k * 0.9)).normalized()
				var cell := AsteroidRecipe.cell_of(tier, b.point.plus(dir * b.radius))
				for rock in recipe.cell_rocks(tier, cell):
					var p := AsteroidRecipe.cell_corner(tier, cell).plus(rock.local)
					assert_gt(p.minus(b.point).length(), b.radius * 1.1 + rock.radius - 0.01,
						"a rock inside %s" % b.id)

func test_the_flight_starts_by_the_first_belt_s_first_group():
	var entry := _system.entry()
	var belt := _system.belts[0]
	assert_gt(belt.profile(entry), 0.0, "the start is off the belt")
	var region := AsteroidRecipe.cell_of(T.GIANT, entry.plus(Vector3(0, 0, -1000)))
	var found := false
	for dz in range(-1, 2):
		for rock in _recipe.cell_rocks(T.GIANT, region + Vector3i(0, 0, dz)):
			var centre := AsteroidRecipe.cell_corner(T.GIANT, region + Vector3i(0, 0, dz)).plus(rock.local)
			var off := entry.minus(centre)
			if absf(off.z - (rock.radius + AsteroidRecipe.START_STANDOFF)) < 1.0 and Vector2(off.x, off.y).length() < 1.0:
				found = true
	assert_true(found, "the start is 700 m off a big rock's surface, on its +z side")

func test_the_same_system_gives_the_same_start():
	assert_true(_system.entry().is_equal_approx(SystemRecipe.from_seed(1337).entry()))
