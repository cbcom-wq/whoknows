extends GutTest

## A star, planet or moon as you see it (the system skeleton spec §7.4): its
## true place and size within PROXY_AT; beyond, along the same direction at
## PROXY_AT, scaled so its angular size is exact. Its ground is solid, on `terrain`
## (the surface's own collision: see test_world_surface).

var _universe: Universe
var _system: SystemRecipe

func before_each():
	_universe = Universe.new()
	add_child_autofree(_universe)
	_system = SystemRecipe.from_seed(1337)

## A proxy queues its surface to be freed as it leaves; let that happen
## before the script ends.
func after_all():
	await wait_physics_frames(2)

func _planet() -> SystemBody:
	return _system.planets()[0]

func _proxy(b: SystemBody) -> BodyProxy:
	var p := BodyProxy.new()
	p.setup(b)
	add_child_autofree(p)
	return p

## The angle a body of `radius` at `centre` fills, seen from `eye`.
static func _angle(centre: Vector3, radius: float, eye: Vector3) -> float:
	return asin(radius / centre.distance_to(eye))

func test_near_it_is_where_it_is_at_full_size():
	var b := _planet()
	var focus := b.point.plus(Vector3(0, 0, 10000))
	_universe.origin = focus
	var at := BodyProxy.placement(b.point, focus, _universe)
	assert_almost_eq((at[0] as Vector3).distance_to(Vector3(0, 0, -10000)), 0.0, 0.01)
	assert_eq(at[1], 1.0)

func test_far_off_it_keeps_its_direction_and_angular_size():
	var b := _planet()
	var focus := b.point.plus(Vector3(-900000, 2500, 400000))
	_universe.origin = focus.plus(Vector3(0, -500, 1000))
	var eye := _universe.to_engine(focus)
	var at := BodyProxy.placement(b.point, focus, _universe)
	var pos: Vector3 = at[0]
	var s: float = at[1]
	var true_dir := b.point.minus(focus).normalized()
	assert_almost_eq((pos - eye).normalized().dot(true_dir), 1.0, 1e-6)
	assert_almost_eq(pos.distance_to(eye), BodyProxy.PROXY_AT, 0.05)
	var true_angle := asin(b.radius / b.point.minus(focus).length())
	assert_almost_eq(_angle(pos, b.radius * s, eye), true_angle, 1e-6)

func test_the_two_rules_meet_at_proxy_at():
	var b := _planet()
	var focus := b.point.plus(Vector3(BodyProxy.PROXY_AT + 0.001, 0, 0))
	var inside := b.point.plus(Vector3(BodyProxy.PROXY_AT - 0.001, 0, 0))
	var a := BodyProxy.placement(b.point, focus, _universe)
	var c := BodyProxy.placement(b.point, inside, _universe)
	assert_almost_eq((a[0] as Vector3).distance_to(_universe.to_engine(b.point)), 0.0, 0.05)
	assert_almost_eq(a[1], c[1], 1e-4)

func test_a_shift_changes_nothing_you_see():
	var b := _planet()
	var p := _proxy(b)
	var focus := b.point.plus(Vector3(3000, 4000, 600000))
	_universe.origin = UniversePoint.at(focus.x, focus.y, focus.z)
	p.place(_universe, focus)
	var before := p.global_position - _universe.to_engine(focus)
	var scale_before := p.global_basis.get_scale()
	_universe.origin = _universe.origin.plus(Vector3(2000, -1000, 3000))
	p.place(_universe, focus)
	assert_almost_eq((p.global_position - _universe.to_engine(focus)).distance_to(before), 0.0, 0.01)
	assert_almost_eq(p.global_basis.get_scale().distance_to(scale_before), 0.0, 1e-6)

func test_it_is_a_member_of_exterior_space():
	var p := _proxy(_planet())
	assert_true(p.is_in_group(Universe.EXTERIOR_SPACE))

func test_the_hull_and_a_spacewalker_bump_off_worlds():
	assert_eq(Avatar.SUIT_MASK & BodyProxy.LAYER, BodyProxy.LAYER)
	assert_eq(AsteroidBody.MASK & BodyProxy.LAYER, BodyProxy.LAYER)

func test_it_casts_shadows_only_close_in():
	var b := _planet()
	var p := _proxy(b)
	p.place(_universe, b.point.plus(Vector3(0, 0, b.radius + 1000)))
	assert_eq((p.get_node("Far") as GeometryInstance3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	p.place(_universe, b.point.plus(Vector3(0, 0, b.radius + 9000)))
	assert_eq((p.get_node("Far") as GeometryInstance3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

func test_every_face_takes_a_colour_from_its_palette():
	var b := _planet()
	var mesh := BodyLook.mesh(b, BodyLook.FAR_DETAIL)
	var colours: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	assert_eq(colours.size(), 1280 * 3)
	var palette: Dictionary = SpacePalette.WORLDS[b.recipe.palette]
	var allowed: Array[Color] = []
	for key in [&"ground_low", &"ground_high", &"rock", &"dust"]:
		for k in SpacePalette.SHADES.size():
			allowed.append(SpacePalette.shade(palette[key], k))
	var kinds := {}
	for c in colours:
		# Vertex colours are kept to 8 bits a channel.
		var ok := allowed.any(func(a: Color) -> bool:
			return absf(a.r - c.r) < 0.004 and absf(a.g - c.g) < 0.004 and absf(a.b - c.b) < 0.004)
		assert_true(ok, "a colour from outside the palette: %s" % c)
		kinds[c.to_html()] = true
	assert_gt(kinds.size(), 2, "a little world, not a ball")

func test_the_far_mesh_is_lifted_by_the_real_ground():
	# The world scale spec §5.1: the far mesh is sampled from WorldTerrain.
	var b := _planet()
	var t := WorldTerrain.new(b.recipe)
	var positions: PackedVector3Array = BodyLook.mesh(b, BodyLook.FAR_DETAIL).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i in range(0, positions.size(), 97):
		var p := positions[i]
		assert_almost_eq(p.length(), 1.0 + t.height_at(p) / t.radius, 1e-4)

## The wadis land spec §7, §8: WADIS's far mesh is lifted to its surface, the
## higher of the ground and the sea, so its sea lies flat at sea level, one
## colour, and its ranges stand over it.
func test_the_far_mesh_shows_the_sea_flat_and_the_ranges():
	var b := _system.body(&"p3")
	var t := WorldTerrain.new(b.recipe)
	var arrays := BodyLook.mesh(b, BodyLook.FAR_DETAIL).surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var flat := 1.0 + t.sea_level / t.radius
	var water: Color = t.palette[&"ground_low"]
	var sea_faces := 0
	var highest := -INF
	for f in range(0, positions.size(), 3):
		var wet := 0
		for i in range(f, f + 3):
			var p := positions[i]
			var h := t.height_at(p)
			assert_almost_eq(p.length(), 1.0 + t.surface_at(p) / t.radius, 2e-6, "lifted to the surface")
			highest = maxf(highest, h)
			if h < t.sea_level - 1.0:
				wet += 1
				assert_almost_eq(p.length(), flat, 1e-6, "under the sea, the water's level")
		var mid := (positions[f] + positions[f + 1] + positions[f + 2]).normalized()
		if wet == 3 and t.height_at(mid) < t.sea_level:
			sea_faces += 1
			assert_almost_eq(colours[f].r, water.r, 0.004, "a sea face is the sea's colour")
			assert_almost_eq(colours[f].g, water.g, 0.004)
			assert_almost_eq(colours[f].b, water.b, 0.004)
	gut.p("WADIS from afar: %d faces of sea; the highest point %.0f m" % [sea_faces, highest])
	assert_gt(sea_faces, 20, "the sea shows")
	assert_gt(highest, 800.0, "and a range stands over the dunes")

func test_near_a_world_its_surface_takes_over():
	var b := _planet()
	var p := _proxy(b)
	var near := b.point.plus(Vector3(0, 0, b.radius * 3.0))
	_universe.origin = near
	p.place(_universe, near)
	var s := p.surface()
	assert_not_null(s, "within %.0f km" % (p.surface_at() / 1000.0))
	assert_false((p.get_node("Far") as Node3D).visible, "the far mesh gives way")
	assert_eq(s.get_parent(), p.get_parent(), "beside the proxy, under a parent that never moves")
	var far := b.point.plus(Vector3(0, 0, p.surface_at() * 1.2))
	_universe.origin = far
	p.place(_universe, far)
	assert_null(p.surface())
	assert_true((p.get_node("Far") as Node3D).visible)

func test_no_surface_starts_while_frozen():
	var b := _planet()
	var p := _proxy(b)
	p.frozen = true
	var near := b.point.plus(Vector3(0, 0, b.radius * 3.0))
	_universe.origin = near
	p.place(_universe, near)
	assert_null(p.surface(), "a warp is carrying you past")

func test_the_surface_starts_within_ten_radii_and_300_km():
	var b := _planet()
	var p := _proxy(b)
	assert_eq(p.surface_at(), minf(b.radius * BodyProxy.SURFACE_RADII, BodyProxy.SURFACE_MOST))

func _limb_glows(p: BodyProxy) -> int:
	var n := 0
	for c in p.get_children():
		if c is LimbGlow:
			n += 1
	return n

func test_a_world_with_air_has_one_limb_glow_and_one_without_has_none():
	var b := _planet()
	var was := b.recipe.atmosphere
	b.recipe.atmosphere = WorldRecipe.Atmosphere.THICK
	assert_eq(_limb_glows(_proxy(b)), 1)
	b.recipe.atmosphere = WorldRecipe.Atmosphere.NONE
	assert_eq(_limb_glows(_proxy(b)), 0)
	b.recipe.atmosphere = was
	assert_eq(_limb_glows(_proxy(_system.star)), 0, "the star has no recipe")

func test_place_air_reaches_the_glow():
	var b := _planet()
	var was := b.recipe.atmosphere
	b.recipe.atmosphere = WorldRecipe.Atmosphere.THICK
	var p := _proxy(b)
	p.place_air(Vector3(0, 0, b.radius * 10.0), Vector3.UP, 0.0)
	var glow: LimbGlow
	for c in p.get_children():
		if c is LimbGlow:
			glow = c
	assert_true(glow.visible)
	p.place_air(Vector3(0, 0, b.radius * 10.0), Vector3.UP, 1.0)
	assert_false(glow.visible)
	b.recipe.atmosphere = was

func test_the_limb_glow_keeps_its_angles_when_the_proxy_is_scaled_down():
	var b := _planet()
	var was := b.recipe.atmosphere
	b.recipe.atmosphere = WorldRecipe.Atmosphere.THICK
	var p := _proxy(b)
	var focus := b.point.plus(Vector3(-900000, 2500, 400000))
	_universe.origin = focus
	p.place(_universe, focus)
	assert_lt(p.global_basis.x.length(), 0.5, "scaled down: it is beyond PROXY_AT")
	var eye := _universe.to_engine(focus)
	var off := focus.minus(b.point)
	p.place_air(off, Vector3.UP, 0.0)
	var glow: LimbGlow
	for c in p.get_children():
		if c is LimbGlow:
			glow = c
	var want := LimbGlow.angles(b.radius, b.recipe.air_top(), off.length())
	var verts: PackedVector3Array = glow.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var to_centre := p.global_position - eye
	var lo := INF
	var hi := 0.0
	for v in verts:
		var a := (p.global_transform * v - eye).angle_to(to_centre)
		lo = minf(lo, a)
		hi = maxf(hi, a)
	assert_almost_eq(lo, want.x, 1e-3)
	assert_almost_eq(hi, want.y, 1e-3)
	b.recipe.atmosphere = was
