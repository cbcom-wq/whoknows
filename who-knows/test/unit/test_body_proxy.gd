extends GutTest

## A star, planet or moon as you see it (the system skeleton spec §7.4): its
## true place and size within 28 km; beyond, along the same direction at
## 28 km, scaled so its angular size is exact. Solid up close, on `terrain`.

var _universe: Universe
var _system: SystemRecipe

func before_each():
	_universe = Universe.new()
	add_child_autofree(_universe)
	_system = SystemRecipe.from_seed(1337)

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
	var focus := UniversePoint.at(-90000, 2500, 40000)
	_universe.origin = UniversePoint.at(-90000, 2000, 41000)
	var eye := _universe.to_engine(focus)
	var at := BodyProxy.placement(b.point, focus, _universe)
	var pos: Vector3 = at[0]
	var s: float = at[1]
	var true_dir := b.point.minus(focus).normalized()
	assert_almost_eq((pos - eye).normalized().dot(true_dir), 1.0, 1e-6)
	assert_almost_eq(pos.distance_to(eye), BodyProxy.PROXY_AT, 0.05)
	var true_angle := asin(b.radius / b.point.minus(focus).length())
	assert_almost_eq(_angle(pos, b.radius * s, eye), true_angle, 1e-6)

func test_the_two_rules_meet_at_28_km():
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
	var focus := b.point.plus(Vector3(3000, 4000, 60000))
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

func test_up_close_it_is_solid_exactly_as_drawn():
	var b := _planet()
	var p := _proxy(b)
	var far := b.point.plus(Vector3(0, 0, b.radius + 20000))
	_universe.origin = UniversePoint.at(far.x, far.y, far.z)
	p.place(_universe, far)
	assert_false(p.is_near())
	assert_null(p.collider())
	var near := b.point.plus(Vector3(0, 0, b.radius + 3000))
	p.place(_universe, near)
	assert_true(p.is_near())
	var shell := p.collider()
	assert_not_null(shell)
	assert_eq(shell.collision_layer, BodyProxy.LAYER)
	assert_eq(ProjectSettings.get_setting("layer_names/3d_physics/layer_4"), "terrain")
	var hull := (shell.get_child(0) as CollisionShape3D).shape as ConvexPolygonShape3D
	var farthest := 0.0
	for q in hull.points:
		farthest = maxf(farthest, q.length())
	assert_almost_eq(farthest, b.radius, 0.01)
	# A little back out stays near; well out lets it go.
	p.place(_universe, b.point.plus(Vector3(0, 0, b.radius + BodyProxy.NEAR_WITHIN + 100)))
	assert_true(p.is_near())
	p.place(_universe, far)
	assert_false(p.is_near())

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
	assert_eq(colours.size(), 320 * 3)
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

func test_shades_come_in_patches_not_triangle_by_triangle():
	# Style guide §3.5: faces read as big flat pieces, never as noise. Most
	# faces share their neighbour's shade up close.
	var b := _planet()
	var colours: PackedColorArray = BodyLook.mesh(b, BodyLook.NEAR_DETAIL).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var same := 0
	var faces := colours.size() / 3
	for f in range(1, faces):
		if colours[f * 3].is_equal_approx(colours[(f - 1) * 3]):
			same += 1
	assert_gt(float(same) / faces, 0.6)
