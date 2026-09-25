extends GutTest

## A big rock up close (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §18): finely faceted, cratered, with boulders sitting on it -- shape, not
## texture -- and inside its bounds, so nothing in its swarm ever overlaps it.

const T := AsteroidRecipe.Tier

var _recipe: AsteroidRecipe

func before_all():
	RockMesh.warm()
	_recipe = AsteroidRecipe.new(1337)

## The `n`th big rock along a line of regions.
func _big(n := 0) -> AsteroidRock:
	var found := 0
	for x in 600:
		var rocks := _recipe.cell_rocks(T.GIANT, Vector3i(x, 3, -2))
		if rocks.is_empty():
			continue
		if found == n:
			return rocks[0]
		found += 1
	fail_test("no big rock found")
	return null

## A direction `angle` radians away from `d`.
static func _tilted(d: Vector3, angle: float) -> Vector3:
	var side := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	return d.rotated(side, angle)

func test_it_is_finely_faceted():
	var detail := RockDetail.build(_big(), 1337)
	assert_eq(detail.positions.size() / 3, 5120)

func test_flat_shaded_and_wound_for_godot():
	var detail := RockDetail.build(_big(), 1337)
	var v := detail.positions
	var n := detail.normals
	var bad := 0
	for t in range(0, v.size(), 3):
		var face := (v[t + 1] - v[t]).cross(v[t + 2] - v[t])
		if n[t] != n[t + 1] or n[t] != n[t + 2]:
			bad += 1
		elif face.length() > 1e-6 and face.dot(n[t]) >= 0.0:
			bad += 1
	assert_eq(bad, 0, "every triangle flat, drawn from outside")

func test_everything_stays_inside_the_rocks_bounds():
	for k in 4:
		var rock := _big(k)
		var detail := RockDetail.build(rock, 1337)
		var worst := 0.0
		for p in detail.positions:
			worst = maxf(worst, p.length())
		for b in detail.boulders:
			var t: Transform3D = b[0]
			worst = maxf(worst, t.origin.length() + AsteroidRecipe.BOUND * float(b[3]) * AsteroidRecipe.STRETCH_MAX)
		assert_lte(worst, rock.radius, "so no rock of its swarm ever overlaps it")

func test_craters_are_bowls_with_rims():
	var detail := RockDetail.build(_big(), 1337)
	assert_between(detail.craters.size(), RockDetail.CRATERS_MIN, RockDetail.CRATERS_MAX)
	var bowls := 0
	for c in detail.craters:
		var d: Vector3 = c[0]
		var a: float = c[1]
		var floor_r := detail.radius_at(d)
		var rim_r := detail.radius_at(_tilted(d, a * 1.15))
		if floor_r < rim_r - RockDetail.CRATER_DEPTH * a * 0.5:
			bowls += 1
	# Craters may overlap, and a cut can flatten one's rim: most read as bowls.
	assert_gt(bowls, detail.craters.size() / 2, "the floor lies well below the rim")

func test_boulders_rest_on_the_surface():
	var rock := _big(1)
	var detail := RockDetail.build(rock, 1337)
	assert_between(detail.boulders.size(), RockDetail.BOULDERS_MIN, RockDetail.BOULDERS_MAX)
	for b in detail.boulders:
		var t: Transform3D = b[0]
		var across: float = b[3]
		var surface := detail.surface_point(b[4])
		var height := t.origin.length() - surface.length()
		assert_between(height, -0.15 * across, 0.5 * across, "half-sunk, not floating or buried")

func test_bigger_rocks_carry_more_boulders():
	var small: RockDetail = null
	var large: RockDetail = null
	for k in 12:
		var rock := _big(k)
		var d := pow(rock.size.x * rock.size.y * rock.size.z, 1.0 / 3.0)
		if d < 250.0 and small == null:
			small = RockDetail.build(rock, 1337)
		if d > 450.0 and large == null:
			large = RockDetail.build(rock, 1337)
	if small == null or large == null:
		pending("no small and large rock in the sample")
		return
	assert_gt(large.boulders.size(), small.boulders.size())

func test_the_same_rock_gives_the_same_detail():
	var a := RockDetail.build(_big(2), 1337)
	var b := RockDetail.build(_big(2), 1337)
	assert_eq(a.positions, b.positions)
	assert_eq(a.boulders.size(), b.boulders.size())
	assert_eq(a.craters.size(), b.craters.size())

func test_its_collision_is_its_surface_and_its_boulders():
	var detail := RockDetail.build(_big(), 1337)
	assert_eq(detail.faces.size(), detail.positions.size() + detail.boulders.size() * 60)

func test_facets_are_shades_of_the_rocks_own_colour():
	var rock := _big()
	var detail := RockDetail.build(rock, 1337)
	var allowed := {}
	for base in [rock.colour, SpacePalette.ASH, SpacePalette.CRYSTAL]:
		for k in SpacePalette.SHADES.size():
			allowed[SpacePalette.shade(base, k)] = true
	var shades := {}
	for c in detail.colours:
		assert_true(allowed.has(c), "%s is a shade of the palette" % c)
		shades[c] = true
	assert_gt(shades.size(), 1, "neighbouring facets differ")

func test_its_collision_faces_the_outside_everywhere():
	# Physics meets a face from the side the renderer draws: (b - a) x (c - a)
	# points in, for the surface and for every boulder.
	var detail := RockDetail.build(_big(1), 1337)
	var f := detail.faces
	var surface := detail.positions.size()
	var bad := 0
	for t in range(0, surface, 3):
		if (f[t + 1] - f[t]).cross(f[t + 2] - f[t]).dot(f[t] + f[t + 1] + f[t + 2]) > 0.0:
			bad += 1
	for i in detail.boulders.size():
		var centre: Vector3 = (detail.boulders[i][0] as Transform3D).origin
		for k in 20:
			var t := surface + (i * 20 + k) * 3
			var mid := (f[t] + f[t + 1] + f[t + 2]) / 3.0
			if (f[t + 1] - f[t]).cross(f[t + 2] - f[t]).dot(mid - centre) > 0.0:
				bad += 1
	assert_eq(bad, 0, "every face turns its front outward")

func test_a_flat_face_is_one_shade():
	# Shading by plane, not by triangle: triangles on the same cut face share a
	# colour, so faces read as big flat pieces, never as noise.
	var detail := RockDetail.build(_big(), 1337)
	var dirs: PackedVector3Array = RockMesh.sphere(RockDetail.DETAIL)[0]
	var tris: PackedInt32Array = RockMesh.sphere(RockDetail.DETAIL)[1]
	var by_face := {}
	var mixed := 0
	for t in range(0, tris.size(), 3):
		var d := (dirs[tris[t]] + dirs[tris[t + 1]] + dirs[tris[t + 2]]).normalized()
		var face := detail.governing(d)
		if face < 0:
			continue
		var colour := detail.colours[t]
		if by_face.has(face) and by_face[face] != colour:
			mixed += 1
		by_face[face] = colour
	assert_gt(by_face.size(), 10, "many faces")
	assert_eq(mixed, 0)

func test_crater_floors_are_darker_than_their_rims():
	var detail := RockDetail.build(_big(), 1337)
	assert_eq(detail.shade_of(RockDetail.CRATER_FLOOR), 0)
	assert_eq(detail.shade_of(RockDetail.CRATER_RIM), SpacePalette.SHADES.size() - 1)

func test_pebbles_lie_on_the_ground_and_are_not_solid():
	var rock := _big(1)
	var detail := RockDetail.build(rock, 1337)
	var rock_across := pow(rock.size.x * rock.size.y * rock.size.z, 1.0 / 3.0)
	# About one per 100 square metres of surface.
	assert_between(detail.pebbles.size(), roundi(PI * rock_across * rock_across / RockDetail.PEBBLE_AREA * 0.8),
		RockDetail.PEBBLES_MOST)
	for b in detail.pebbles:
		var t: Transform3D = b[0]
		var across: float = b[3]
		var height := t.origin.length() - detail.surface_point(b[4]).length()
		assert_between(height, -0.15 * across, 0.5 * across)
		assert_lte(t.origin.length() + AsteroidRecipe.BOUND * across * AsteroidRecipe.STRETCH_MAX, rock.radius)
		assert_eq(b[2], SpacePalette.scree(rock.colour), "scree, darker than the ground")
	assert_eq(detail.faces.size(), detail.positions.size() + detail.boulders.size() * 60, "only boulders are solid")
