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
	# Round the first belt's +x side: the system's belts are a thousand
	# kilometres out.
	var belt := _system.belts[0]
	var middle := AsteroidRecipe.cell_of(T.GIANT, belt.centre.plus(Vector3(belt.radius, 0.0, 0.0)))
	for x in range(-32, 33):
		for z in range(-32, 33, 4):
			var cell := middle + Vector3i(x, 0, z)
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
	# The ring alone: the planet's orbital debris (the warp spec §3.3) scatters
	# rubble round the slab too, which is not what this counts.
	var shapes := sys.asteroid_shapes()
	shapes.debris.clear()
	var recipe := AsteroidRecipe.new(sys.seed, null, shapes)
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
	var inside := 0
	for b in sys.bodies:
		for tier in [T.RUBBLE, T.MID]:
			for k in 6:
				var dir := Vector3(sin(k * 1.7), cos(k * 2.3), sin(k * 0.9)).normalized()
				var cell := AsteroidRecipe.cell_of(tier, b.point.plus(dir * b.radius))
				for rock in recipe.cell_rocks(tier, cell):
					var p := AsteroidRecipe.cell_corner(tier, cell).plus(rock.local)
					if p.minus(b.point).length() <= b.radius * 1.1 + rock.radius - 0.01:
						inside += 1
	# Counted, so the test asserts even when a world's well leaves no rock near
	# its surface to look at.
	assert_eq(inside, 0, "rocks inside a body")

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

# --- debris and clusters (the warp spec §3.1, §3.3) ---------------------------

func test_debris_crowds_a_planet_s_disc():
	var p := _system.planets()[0]
	var d := _system.debris[0]
	var bare_shapes := _system.asteroid_shapes()
	bare_shapes.debris.clear()
	var bare := AsteroidRecipe.new(_system.seed, null, bare_shapes)
	var across := d.normal.cross(Vector3.RIGHT)
	if across.length() < 0.1:
		across = d.normal.cross(Vector3.FORWARD)
	across = across.normalized()
	var with_debris := 0
	var without := 0
	for k in 12:
		var r := lerpf(d.inner + 800.0, d.outer - 3000.0, k / 11.0)
		var at := d.centre.plus(across.rotated(d.normal, k * 0.5) * r)
		var cell := AsteroidRecipe.cell_of(T.RUBBLE, at)
		with_debris += _recipe.cell_rocks(T.RUBBLE, cell).size()
		without += bare.cell_rocks(T.RUBBLE, cell).size()
		assert_eq(_recipe.cell_rocks(T.GIANT, AsteroidRecipe.cell_of(T.GIANT, at)).size(),
			bare.cell_rocks(T.GIANT, AsteroidRecipe.cell_of(T.GIANT, at)).size(), "debris adds no big rock")
	gut.p("debris round %s: %d rubble in 12 cells, %d without" % [p.id, with_debris, without])
	assert_gt(with_debris, maxi(without * 3, 12))

func test_no_debris_lies_in_a_well():
	var planets := _system.planets()
	for k in planets.size():
		var p := planets[k]
		var d := _system.debris[k]
		for j in 8:
			var dir := Vector3(sin(j * 1.3), cos(j * 2.1), sin(j * 0.7)).normalized()
			assert_eq(d.profile(p.point.plus(dir * p.well_radius * 0.95)), 0.0, "%s's well" % p.id)
		for b in _system.bodies:
			if b != p and b.point.minus(p.point).length() < d.outer + d.half_thickness + b.well_radius:
				assert_eq(d.profile(b.point), 0.0, "%s's well, in %s's debris" % [b.id, p.id])

func test_a_cluster_lifts_the_chance_of_groups_round_it():
	var lifted := AsteroidRecipe.new(_system.seed, null, _system.asteroid_shapes())
	var flat := AsteroidRecipe.new(_system.seed, null, _system.asteroid_shapes(false))
	var more := 0
	# A belt this wide is often at certainty already, where a lift has nothing
	# to add: so look at every cluster, not one.
	for c in _system.clusters:
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var cell := AsteroidRecipe.cell_of(T.GIANT, c.point) + Vector3i(dx, 0, dz)
				var a := lifted.group_chance(cell)
				var b := flat.group_chance(cell)
				assert_gte(a, b - 1e-6, "a lift never lowers the chance")
				if a > b + 0.01:
					more += 1
	assert_gt(more, 0, "no cluster lifted anything")

func test_the_start_ignores_the_clusters_lift():
	var flat := AsteroidRecipe.new(_system.seed, null, _system.asteroid_shapes(false))
	assert_true(_system.entry().is_equal_approx(flat.find_start()))
