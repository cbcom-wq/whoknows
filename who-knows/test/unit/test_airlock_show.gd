extends GutTest

## The airlock's show (docs/superpowers/specs/2026-09-24-airlock-design.md §5):
## what it does at each stage, headless.

const DT := 1.0 / 60.0

var _show: AirlockShow
var _light: OmniLight3D
var _cycle: AirlockCycle

func before_each():
	_light = OmniLight3D.new()
	_light.light_color = InteriorPalette.LIGHT_WARM
	_light.light_energy = 0.55
	add_child_autofree(_light)
	_show = AirlockShow.new()
	add_child_autofree(_show)
	var nozzles: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY]
	_show.setup(Transform3D.IDENTITY, nozzles, _light, InteriorKit.LAYER)
	_cycle = AirlockCycle.new()

func _run(seconds: float) -> void:
	for i in int(round(seconds / DT)):
		_cycle.step(DT, true, true, false)
		_show.apply(_cycle, DT)

func _jets() -> Array:
	return _show.get_children().filter(func(n): return n is GPUParticles3D and String(n.name).begins_with("Jet"))

func _fog() -> GPUParticles3D:
	return _show.get_node("Fog")

func test_it_builds_a_jet_per_nozzle_and_a_room_fog():
	assert_eq(_jets().size(), 2)
	assert_not_null(_fog())
	for p in _show.get_children():
		assert_eq(p.layers, InteriorKit.LAYER)

func test_at_rest_nothing_steams_and_the_air_is_clear():
	_run(0.5)
	for jet in _jets():
		assert_false(jet.emitting)
	assert_false(_fog().emitting)
	assert_eq(AirlockShow.haze_target(_cycle), 0.0)

func test_going_out_blooms_a_mist_but_fires_no_jets():
	_cycle.press(&"room")
	_run(1.0)
	for jet in _jets():
		assert_false(jet.emitting, "decompression fog, not steam")
	assert_true(_fog().emitting)
	assert_almost_eq(AirlockShow.haze_target(_cycle), AirlockShow.HAZE_PEAK_OUT, 0.01)

func test_coming_in_fires_the_jets_first():
	_cycle.press(&"room")
	_run(5.0)   # out
	_cycle.press(&"room")
	_run(AirlockCycle.SEAL_TIME + 0.5)
	for jet in _jets():
		assert_true(jet.emitting, "steam shoots in")
	_run(1.0)
	for jet in _jets():
		assert_false(jet.emitting, "only for the first 1.2 s")
	assert_almost_eq(AirlockShow.haze_target(_cycle), AirlockShow.HAZE_PEAK_IN, 0.02, "at its thickest")

func test_the_haze_clears_once_the_far_hatch_is_open():
	_cycle.press(&"room")
	_run(5.0)
	assert_eq(AirlockShow.haze_target(_cycle), 0.0)
	_run(1.0)
	assert_almost_eq(_show.haze, 0.0, 0.001)

func test_the_haze_never_whites_out_the_room():
	var env := Environment.new()
	_cycle.press(&"room")
	_run(5.0)
	_cycle.press(&"room")
	var worst := 0.0
	for i in 300:
		_cycle.step(DT, true, true, false)
		_show.apply(_cycle, DT)
		_show.tint(env)
		worst = maxf(worst, 1.0 - exp(-env.fog_density * ShipGrid.CELL_SIZE))
	assert_lt(worst, 0.75, "the far wall always shows through")
	assert_gt(worst, 0.4, "but it does get properly foggy")
	assert_eq(env.fog_light_color, InteriorPalette.STEAM)

func test_the_light_turns_amber_while_cycling_and_dims_onto_space():
	_cycle.press(&"room")
	_run(1.5)
	assert_true(_light.light_color.is_equal_approx(InteriorPalette.AMBER), "amber through the cycle")
	_run(4.0)
	assert_almost_eq(_light.light_energy, 0.55 * AirlockShow.OPEN_ENERGY, 0.001, "dimmed with the outer hatch open")
