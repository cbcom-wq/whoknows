extends GutTest

## The entry glow (desert-world spec §6.5): a cap at the bow that follows the heat.

class HotFlight extends FlightComputer:
	var h := 0.0
	func entry_heat() -> float:
		return h
	func _physics_process(_d: float) -> void:
		pass

var _hull: RigidBody3D
var _flight: HotFlight
var _glow: EntryGlow

func before_each():
	_hull = RigidBody3D.new()
	_hull.gravity_scale = 0.0
	add_child_autofree(_hull)
	_flight = HotFlight.new()
	_flight.hull_path = NodePath("../" + _hull.name)
	_hull.get_parent().add_child(_flight)
	autofree(_flight)
	_glow = EntryGlow.new()
	_hull.add_child(_glow)
	_glow.setup(_flight, _hull)
	_glow.fit(AABB(Vector3(-3, -2, -6), Vector3(6, 4, 12)))

func _cap() -> MeshInstance3D:
	for c in _glow.get_children():
		if c is MeshInstance3D:
			return c
	return null

func test_the_cap_is_brightest_at_its_pole():
	var a := EntryGlow.cap_mesh().surface_get_arrays(0)
	var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var cols: PackedColorArray = a[Mesh.ARRAY_COLOR]
	var best := 0
	for i in verts.size():
		if verts[i].distance_to(Vector3(0, 0, -1)) < verts[best].distance_to(Vector3(0, 0, -1)):
			best = i
		if verts[i].z > -0.01:
			assert_lt(cols[i].a, 0.01)
	assert_almost_eq(cols[best].a, 1.0, 1e-3)

func test_the_glow_follows_the_heat():
	_flight.h = 0.0
	await wait_physics_frames(2)
	assert_false(_cap().visible)
	_flight.h = 1.0
	await wait_physics_frames(2)
	assert_true(_cap().visible)
	var c := (_cap().material_override as StandardMaterial3D).albedo_color
	assert_almost_eq(c.r, SpacePalette.ENTRY_HIGH.r, 1e-3)
	assert_almost_eq(c.g, SpacePalette.ENTRY_HIGH.g, 1e-3)
	assert_almost_eq(c.a, EntryGlow.GLOW_ALPHA, 1e-3)

func test_it_points_along_the_velocity():
	_hull.linear_velocity = Vector3(50, 0, 0)
	_flight.h = 1.0
	await wait_physics_frames(2)
	var dir := (_cap().global_basis * Vector3.FORWARD).normalized()
	assert_almost_eq(dir, Vector3.RIGHT, Vector3.ONE * 1e-3)

func test_the_buffet_is_never_harder_than_a_light_hit():
	var got: Array[float] = []
	_glow.buffet.connect(func(s: float, _f: Vector3): got.append(s))
	_hull.linear_velocity = Vector3(0, 0, -50)
	_flight.h = 1.0
	await wait_physics_frames(60)
	assert_gte(got.size(), 5)
	for s in got:
		assert_lte(s, EntryGlow.buffet_most() + 1e-6)
