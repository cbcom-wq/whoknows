extends GutTest

## A wrecked ceiling light flickers (health and damage spec §9, the owner's
## call on 2026-10-02): mostly 90% dark, with short bursts at full.

func _dark_share(phase: float, seconds := 600.0, step := 0.01) -> float:
	var dark := 0
	var n := 0
	var t := 0.0
	while t < seconds:
		if LightFlicker.level_at(t, phase) < 1.0:
			dark += 1
		n += 1
		t += step
	return float(dark) / n

func test_it_is_only_ever_dim_or_full():
	for i in 2000:
		var level := LightFlicker.level_at(i * 0.013, 0.37)
		assert_true(is_equal_approx(level, LightFlicker.DIM) or is_equal_approx(level, 1.0), "%s" % level)
	assert_almost_eq(LightFlicker.DIM, 0.1, 0.0001, "90% dark")

func test_it_spends_most_of_its_time_dark_and_still_flickers():
	for phase in [0.0, 0.21, 0.5, 0.83]:
		var dark := _dark_share(phase)
		assert_between(dark, 0.85, 0.97, "phase %s is dark %d%% of the time" % [phase, roundi(dark * 100.0)])

func test_two_lights_do_not_flicker_together():
	var same := 0
	for i in 3000:
		var t := i * 0.02
		if LightFlicker.level_at(t, 0.1) == LightFlicker.level_at(t, 0.6):
			same += 1
	assert_lt(same, 3000)

func test_it_dims_the_lamp_and_the_disc_together():
	var lamp := OmniLight3D.new()
	lamp.light_energy = 0.45
	add_child_autofree(lamp)
	var disc := MeshInstance3D.new()
	add_child_autofree(disc)
	var mat := InteriorMaterials.glow().duplicate() as ShaderMaterial
	var f := LightFlicker.attach(lamp, disc, mat)
	for t in [0.0, 0.7, 1.3, 2.9, 5.5]:
		f._clock = t - 0.001
		f._process(0.001)
		var level := LightFlicker.level_at(t, f.phase)
		assert_almost_eq(lamp.light_energy, 0.45 * level, 0.0001)
		assert_almost_eq(float(mat.get_shader_parameter(&"energy")), InteriorMaterials.GLOW_ENERGY * level, 0.0001)
	assert_ne(mat, InteriorMaterials.glow(), "its own copy: the shared glow never flickers")
