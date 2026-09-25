extends GutTest

## QuantumCore (quantum energy spec §6.2): the core's moving parts -- the
## heart, three rings and the gauge -- driven by hand here, as the plant will
## drive them (Task 4). Knows nothing about ships: it takes a frame and a
## render layer.

var _core: QuantumCore

func before_each():
	_core = QuantumCore.new()
	_core.setup(Transform3D(Basis.IDENTITY, Vector3(2, -0.95, -4)), InteriorKit.LAYER)
	add_child_autofree(_core)

func _bars() -> Array:
	var out := []
	for i in InteriorProps.QUANTUM_GAUGE_BARS:
		out.append(_core.bar_look(i))
	return out

## The first vertex colour of a mesh under the core, by name.
func _colour_of(mesh_name: String) -> Color:
	var mi: MeshInstance3D = _core.find_child(mesh_name, true, false)
	return (mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray)[0]

func test_it_builds_a_heart_three_rings_and_ten_bars():
	assert_not_null(_core.heart)
	assert_eq(_core.rings.size(), 3)
	assert_eq(_bars().size(), 10)
	for mesh in _core.find_children("*", "MeshInstance3D", true, false):
		assert_eq(mesh.layers, InteriorKit.LAYER, "%s on the interior layer" % mesh.name)

func test_the_heart_is_glow_in_its_frame():
	assert_eq(_core.heart.material_override, InteriorMaterials.glow())
	assert_almost_eq(_core.heart.global_position, Vector3(2, -0.95, -4) + InteriorProps.QUANTUM_HEART,
		Vector3.ONE * 0.0001)

func test_its_crown_is_where_a_conduit_ends():
	assert_almost_eq(_core.crown(), Vector3(2, -0.95, -4) + InteriorProps.quantum_core_crown(), Vector3.ONE * 0.0001)

func test_half_full_lights_five_bars():
	_core.set_fill(0.5, 0.1)
	assert_eq(_core.lit_bars(), 5)
	assert_eq(_bars(), [&"lit", &"lit", &"lit", &"lit", &"lit", &"dark", &"dark", &"dark", &"dark", &"dark"])

func test_full_lights_every_bar():
	_core.set_fill(1.0, 0.1)
	assert_eq(_core.lit_bars(), 10)

## The lowest bar is the low-power line: amber when it is all that is left.
func test_below_the_line_only_the_lowest_bar_is_lit_amber():
	_core.set_fill(0.08, 0.1)
	assert_eq(_core.lit_bars(), 1)
	assert_eq(_core.bar_look(0), &"amber")

func test_the_lowest_bar_is_violet_again_once_another_is_lit():
	_core.set_fill(0.15, 0.1)
	assert_eq(_core.lit_bars(), 2)
	assert_eq(_core.bar_look(0), &"lit")

## At 0 it stays lit, so the gauge never reads as dead.
func test_empty_still_lights_the_lowest_bar_amber_at_half_brightness():
	_core.set_fill(0.0, 0.1)
	assert_eq(_core.lit_bars(), 1)
	assert_eq(_core.bar_look(0), &"amber_dim")
	var full := _colour_of("Bar0_amber")
	var half := _colour_of("Bar0_amber_dim")
	# Vertex colours are stored in 8 bits a channel: a step is 1/255.
	var step := 1.0 / 255.0
	assert_almost_eq(half.r, full.r * 0.5, step)
	assert_almost_eq(half.g, full.g * 0.5, step)
	assert_almost_eq(half.b, full.b * 0.5, step)

func test_the_rates_follow_the_state():
	assert_eq(_core.state, &"full")
	assert_almost_eq(_core.ring_rate(), 0.25, 0.0001)
	assert_almost_eq(_core.pulse_rate(), 0.5, 0.0001)
	_core.set_state(&"boost")
	assert_almost_eq(_core.ring_rate(), 0.75, 0.0001, "three times as fast")
	assert_almost_eq(_core.pulse_rate(), 2.0, 0.0001)

func test_low_power_slows_the_rings_and_pulse_to_a_crawl():
	_core.set_state(&"low_power")
	assert_almost_eq(_core.ring_rate(), 0.05, 0.0001)
	assert_almost_eq(_core.pulse_rate(), 0.2, 0.0001)

## Spec §6.2, §8.3: power restored spins the rings up to full over 1.5 s, the
## heart flaring, from wherever they were.
func test_restoring_spins_up_to_full_over_a_second_and_a_half():
	_core.set_state(&"low_power")
	_core.set_state(&"restoring")
	assert_almost_eq(_core.ring_rate(), 0.05, 0.0001, "from where it was")
	assert_true(_core.flaring())
	_core._process(0.75)
	assert_almost_eq(_core.ring_rate(), 0.15, 0.001, "halfway")
	assert_almost_eq(_core.pulse_rate(), 0.35, 0.001)
	_core._process(0.8)
	assert_eq(_core.state, &"full")
	assert_almost_eq(_core.ring_rate(), 0.25, 0.0001)
	assert_false(_core.flaring())

func test_the_rings_turn_at_the_ring_rate():
	var before: Array[Basis] = []
	for ring in _core.rings:
		before.append(ring.basis)
	_core._process(1.0)
	for i in _core.rings.size():
		var turned := before[i].inverse() * _core.rings[i].basis
		assert_almost_eq(turned.get_rotation_quaternion().get_angle(), TAU * 0.25, 0.001,
			"ring %d turned a quarter turn in a second" % i)

func test_the_heart_breathes_four_percent_at_the_pulse_rate():
	var lo := INF
	var hi := -INF
	for i in 40:
		_core._process(0.05)   # 2 s: one full breath at 0.5 Hz
		lo = minf(lo, _core.heart.scale.x)
		hi = maxf(hi, _core.heart.scale.x)
	assert_almost_eq(lo, 0.96, 0.002)
	assert_almost_eq(hi, 1.04, 0.002)

func test_a_flash_brightens_the_heart_for_a_moment():
	assert_false(_core.flaring())
	_core.flash()
	assert_true(_core.flaring())
	_core._process(QuantumCore.FLASH_TIME + 0.01)
	assert_false(_core.flaring())

func test_the_flare_is_brighter_than_the_heart():
	var heart := _colour_of("Heart")
	var flare := _colour_of("HeartFlare")
	assert_gt(flare.b, heart.b)
