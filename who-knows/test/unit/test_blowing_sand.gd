extends GutTest

## Blowing sand (phase 2 plan, Task 6; call 10): thin pale streaks close to
## you over a desert's ground, by the air and how high you are, blowing along
## the world's wind; a member of the exterior space that never holds the
## floating origin back.

var _root: Node
var _ship: Ship
var _universe: Universe
var _sand: BlowingSand

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_universe = _root.get_node("Universe")
	_sand = _root.star_system.sand
	await wait_physics_frames(3)

func _body(id: StringName) -> SystemBody:
	return (_root.system as SystemRecipe).body(id)

func _where() -> Whereabouts:
	return _root.star_system.whereabouts

func _process_material() -> ParticleProcessMaterial:
	return _sand.process_material as ParticleProcessMaterial

## Hops to world `id` and holds the hull still and upright `clearance` m over
## its ground (past the hull's own stance), frozen so nothing drifts: low
## enough for the sand at full strength. Returns the ground's up.
func _set_down(id: StringName, clearance := 2.0) -> Vector3:
	var planet := _body(id)
	_root.hop_index = (_root.system as SystemRecipe).bodies.find(planet) - 1
	assert_true(_root.hop(1))
	await wait_physics_frames(2)
	var centre := _universe.to_engine(planet.point)
	var out := (_ship.exterior.global_position - centre).normalized()
	var terrain := _where().terrain_of(planet)
	var ground := planet.radius + terrain.height_at(out)
	var along := out.cross(Vector3.UP if absf(out.y) < 0.9 else Vector3.RIGHT).normalized()
	var hull := _ship.exterior
	hull.linear_velocity = Vector3.ZERO
	hull.angular_velocity = Vector3.ZERO
	hull.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	hull.freeze = true
	hull.global_transform = Transform3D(Basis(along, out, along.cross(out).normalized()),
		centre + out * (ground + _ship.stance_depth() + clearance))
	# 3 km down from the hop: bring the origin along now, as the hop does.
	var p := hull.global_position
	_universe.shift(Vector3(snappedf(p.x, Universe.STEP), snappedf(p.y, Universe.STEP), snappedf(p.z, Universe.STEP)))
	_root.star_system.place_all()
	_where().look()
	await wait_physics_frames(2)
	return out

func test_strength():
	assert_eq(BlowingSand.strength(false, 1.0, 0.0), 0.0, "never off a desert")
	assert_eq(BlowingSand.strength(true, 0.2, 0.0), 0.0, "never in air under SAND_AIR")
	assert_eq(BlowingSand.strength(true, 1.0, 0.0), 1.0)
	assert_eq(BlowingSand.strength(true, 1.0, 15.0), 1.0, "full at SAND_LOW")
	assert_eq(BlowingSand.strength(true, 1.0, 60.0), 0.0, "gone at SAND_TOP")
	assert_between(BlowingSand.strength(true, 1.0, 35.0), 0.001, 0.999, "smooth between")
	assert_gte(BlowingSand.strength(true, 0.35, 0.0), 0.4, "thin air still shows some")
	assert_eq(BlowingSand.strength(true, 1.0, INF), 0.0, "nowhere near a ground")

func test_off_in_space_and_on_other_worlds():
	assert_null(_where().well(), "the flight starts in deep space")
	await wait_physics_frames(1)
	assert_false(_sand.emitting, "no sand in space")
	var p2 := _body(&"p2")
	assert_ne(p2.recipe.archetype, WorldRecipe.Archetype.DUNES, "p2 is no desert")
	await _set_down(&"p2")
	assert_eq(_where().well(), p2)
	assert_gt(_where().air(), BlowingSand.SAND_AIR, "p2 has air")
	assert_lt(_where().altitude(), BlowingSand.SAND_LOW, "and the hull is low over its ground")
	assert_false(_sand.emitting, "no sand on a world that is not a desert")
	assert_eq(_sand.amount_ratio, 0.0)

func test_on_at_the_desert_s_ground():
	var p3 := _body(&"p3")
	assert_eq(p3.recipe.archetype, WorldRecipe.Archetype.DUNES, "p3 is the desert")
	await _set_down(&"p3")
	assert_eq(_where().well(), p3)
	assert_lt(_where().altitude(), BlowingSand.SAND_LOW)
	assert_true(_sand.emitting, "sand at a desert's ground")
	assert_almost_eq(_sand.amount_ratio, 1.0, 0.005, "full, in thick air and low")
	var up := _where().up()
	var wind := _where().terrain_of(p3).wind_at(up)
	assert_almost_eq(wind.length(), 1.0, 1e-4)
	var m := _process_material()
	var along := _sand.global_basis.inverse() * wind
	var up_here := _sand.global_basis.inverse() * up
	assert_lt(rad_to_deg(m.direction.angle_to(along)), 1.0, "it blows along the world's wind")
	assert_lt(absf(m.direction.normalized().dot(up_here)), 0.02, "along the ground, not up or down")
	assert_lt(rad_to_deg(m.emission_ring_axis.angle_to(up_here)), 1.0, "the slab is turned to the local up")
	# The slab's middle is on the ground under you.
	var focus := _sand.to_local(_universe.focus.global_position)
	var rel := focus - m.emission_shape_offset
	assert_lt((rel - up * rel.dot(up)).length(), 0.01, "centred under the focus")
	assert_almost_eq(rel.dot(up), _where().altitude(), 0.01, "on the ground, not round the hull")
	assert_true(_sand.local_coords)
	assert_true(_sand.is_in_group(Universe.EXTERIOR_SPACE))
	assert_false(_sand.is_in_group(Universe.HOLDS_SHIFT))
	assert_true(_sand.visibility_aabb.has_point(m.emission_shape_offset), "drawn where it blows")

## Puts the frozen hull, already in `planet`'s well, `clearance` m over its
## ground at the unit direction `out` from its middle, the origin brought
## along, and lets the sand tick.
func _move_over(planet: SystemBody, out: Vector3, clearance := 2.0) -> void:
	var centre := _universe.to_engine(planet.point)
	var ground := planet.radius + _where().terrain_of(planet).height_at(out)
	var along := out.cross(Vector3.UP if absf(out.y) < 0.9 else Vector3.RIGHT).normalized()
	_ship.exterior.global_transform = Transform3D(Basis(along, out, along.cross(out).normalized()),
		centre + out * (ground + _ship.stance_depth() + clearance))
	var p := _ship.exterior.global_position
	_universe.shift(Vector3(snappedf(p.x, Universe.STEP), snappedf(p.y, Universe.STEP), snappedf(p.z, Universe.STEP)))
	_root.star_system.place_all()
	_where().look()
	await wait_physics_frames(2)

## Final review, deferred: toward the wind axis's poles the dunes fade into a
## flat sheet (WorldTerrain.DUNE_POLE) and the wind's way spins round the
## pole; the sand fades out with the dunes, by the same pole_fade, and
## is gone where they are.
func test_the_sand_fades_out_with_the_dunes_toward_the_wind_s_poles():
	assert_eq(WorldTerrain.pole_fade(0.0), 1.0)
	assert_eq(WorldTerrain.pole_fade(WorldTerrain.DUNE_POLE), 1.0, "whole up to DUNE_POLE")
	assert_eq(WorldTerrain.pole_fade(-(1.0 + WorldTerrain.DUNE_POLE) * 0.5), 0.0, "gone halfway to the pole")
	assert_eq(WorldTerrain.pole_fade(1.0), 0.0)
	for a: float in [0.0, 0.5, 0.91, -0.93, 0.95, 0.99]:
		assert_eq(WorldTerrain._dune_stand(a, 0.0), WorldTerrain.pole_fade(a), "the dunes stand by it")
	var p3 := _body(&"p3")
	await _set_down(&"p3")
	assert_true(_sand.emitting, "sand on the open dunes")
	var axis := _where().terrain_of(p3).wind_axis
	var across := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	await _move_over(p3, (axis * 0.98 + across * sqrt(1.0 - 0.98 * 0.98)).normalized())
	assert_almost_eq(_where().up().dot(axis), 0.98, 0.001)
	assert_lt(_where().altitude(), BlowingSand.SAND_LOW, "low over the sheet")
	assert_eq(_sand.amount_ratio, 0.0, "none where the dunes are gone")
	assert_false(_sand.emitting)
	await _move_over(p3, (axis * 0.925 + across * sqrt(1.0 - 0.925 * 0.925)).normalized())
	assert_lt(_where().altitude(), BlowingSand.SAND_LOW)
	assert_between(_sand.amount_ratio, 0.05, 0.95, "thinning as the dunes do")

## Moves the frozen hull straight up or down until it is `altitude` m over
## the ground, and lets the sand tick.
func _hull_to(altitude: float) -> void:
	_ship.exterior.global_position += _where().up() * (altitude - _where().altitude())
	await wait_physics_frames(1)

func test_it_stops_high_up_and_blows_again_low_where_it_was():
	await _set_down(&"p3")
	assert_true(_sand.emitting)
	var place := _universe.to_universe(_sand.global_position)
	await _hull_to(BlowingSand.SAND_TOP + 5.0)
	assert_false(_sand.emitting, "no sand %.0f m up" % _where().altitude())
	assert_eq(_sand.amount_ratio, 0.0)
	await _hull_to(2.0)
	assert_true(_sand.emitting, "it blows again low down")
	assert_almost_eq(_sand.amount_ratio, 1.0, 0.005)
	assert_almost_eq(_universe.to_universe(_sand.global_position).minus(place).length(), 0.0, 0.01,
		"not put back onto you nor restarted: a moment off near where it was pops no streaks")

func test_it_stops_when_you_leave_the_desert():
	await _set_down(&"p3")
	assert_true(_sand.emitting)
	var p2 := _body(&"p2")
	_root.hop_index = (_root.system as SystemRecipe).bodies.find(p2) - 1
	assert_true(_root.hop(1))
	await wait_physics_frames(1)
	assert_eq(_where().well(), p2)
	assert_false(_sand.emitting, "no sand by a world that is not a desert")
	assert_eq(_sand.amount_ratio, 0.0)

## Wadoo spec §10: no sand blows under a roof; the streaks went through the
## queen's hall's walls. The flight scene says where a roof is (`sheltered`).
func test_none_blows_under_a_roof():
	assert_true(_sand.sheltered.is_valid(), "the flight scene says where a roof is")
	await _set_down(&"p3")
	assert_true(_sand.emitting)
	_sand.sheltered = func() -> bool: return true
	await wait_physics_frames(2)
	assert_false(_sand.emitting, "indoors: no sand")
	assert_eq(_sand.amount_ratio, 0.0)
	_sand.sheltered = func() -> bool: return false
	await wait_physics_frames(2)
	assert_true(_sand.emitting, "out again: it blows")

func test_sand_never_holds_the_origin():
	var up := await _set_down(&"p3")
	assert_true(_sand.emitting)
	# Puffs from the hop may hold it a moment; the sand never does.
	await wait_until(func() -> bool: return not _universe.is_held(), 3.0)
	assert_false(_universe.is_held(), "nothing holds the origin with the sand blowing")
	assert_true(_sand.emitting, "and it is still blowing")
	# Along the ground until the focus is past SHIFT_AT, well short of FORCE_AT.
	var hull := _ship.exterior
	var p3 := _body(&"p3")
	var centre := _universe.to_engine(p3.point)
	var along := up.cross(Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT).normalized()
	var at := hull.global_position
	var p := at
	var far := 0.0
	var away := 2100.0
	while far < 2100.0 and away < 3500.0:
		var dir := (at - centre + along * away).normalized()
		var ground := p3.radius + _where().terrain_of(p3).height_at(dir)
		p = centre + dir * (ground + _ship.stance_depth() + 2.0)
		far = maxf(absf(p.x), maxf(absf(p.y), absf(p.z)))
		away += 100.0
	hull.global_position = p
	assert_between(far, Universe.SHIFT_AT, Universe.FORCE_AT, "past SHIFT_AT, short of the forced shift")
	var shifts := _universe.shifts
	await wait_physics_frames(1)
	assert_eq(_universe.shifts, shifts + 1, "the origin moved on the next tick")
	await wait_physics_frames(1)
	assert_true(_sand.emitting, "the sand blows on over the shift")

func test_streaks_keep_their_place_across_a_shift():
	await _set_down(&"p3")
	assert_true(_sand.emitting)
	var m := _process_material()
	var at := _sand.global_position
	var place := _universe.to_universe(at)
	var offset := m.emission_shape_offset
	var delta := Vector3(2000.0, 0.0, -1000.0)
	_universe.shift(delta)
	assert_almost_eq(_sand.global_position + delta, at, Vector3.ONE * 0.01, "the shift moved it with everything")
	assert_almost_eq(_universe.to_universe(_sand.global_position).minus(place).length(), 0.0, 0.01,
		"its place in the universe is the same")
	await wait_physics_frames(2)
	assert_almost_eq(_universe.to_universe(_sand.global_position).minus(place).length(), 0.0, 0.01,
		"not re-placed: its live streaks stay where they were")
	assert_almost_eq(m.emission_shape_offset, offset, Vector3.ONE * 0.01,
		"the slab is where it was, relative to the node")
	assert_true(_sand.emitting)
	# As you go, the slab follows you and the node stays put.
	var up := _where().up()
	var along := up.cross(Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT).normalized()
	_ship.exterior.global_position += along * 50.0
	await wait_physics_frames(1)
	assert_almost_eq(_universe.to_universe(_sand.global_position).minus(place).length(), 0.0, 0.01,
		"not re-placed as you go")
	var moved := m.emission_shape_offset - offset
	assert_almost_eq((moved - up * moved.dot(up)).length(), 50.0, 0.5, "the slab came along")

func test_colours_come_from_the_palette():
	var streak: Color = SpacePalette.WORLDS[SpacePalette.DESERT_PALETTE][&"streak"]
	var mesh := _sand.draw_pass_1 as QuadMesh
	assert_not_null(mesh)
	var look := mesh.material as StandardMaterial3D
	assert_not_null(look)
	var albedo := look.albedo_color
	assert_true(Color(albedo.r, albedo.g, albedo.b).is_equal_approx(Color(streak.r, streak.g, streak.b)),
		"%s is the desert's streak %s" % [albedo, streak])
	assert_almost_eq(albedo.a, BlowingSand.SAND_ALPHA, 1e-6)
	assert_eq(look.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_eq(look.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_false(look.no_depth_test, "depth-tested")
	# The fade over a streak's life changes its alpha only: its colour stays
	# the streak's.
	var m := _process_material()
	assert_null(m.color_ramp)
	assert_not_null(m.alpha_curve)
	assert_eq(m.color, Color(1, 1, 1, 1))
	var fade := (m.alpha_curve as CurveTexture).curve
	assert_almost_eq(fade.sample(0.0), 0.0, 1e-3, "fades in")
	assert_almost_eq(fade.sample(0.5), 1.0, 1e-3)
	assert_almost_eq(fade.sample(1.0), 0.0, 1e-3, "and out")
