extends GutTest

## The game's first sound (docs/superpowers/specs/2026-09-24-airlock-design.md
## §6): every sound synthesized in code, deterministically.

const LENGTHS := {
	&"hatch_motor": 0.9, &"bolt_clunk": 0.3, &"seal_thump": 0.35, &"hiss_out": 2.8, &"steam_in": 2.8,
	&"panel_beep": 0.15, &"warning_chime": 0.5, &"ship_hum": 2.0, &"breath": 4.0, &"thruster_puff": 1.0,
	&"hull_thump": 0.6, &"rcs_puff": 0.25,
}

func test_every_sound_builds_at_its_length():
	assert_eq(Synth.NAMES.size(), LENGTHS.size())
	for sound_name: StringName in Synth.NAMES:
		var s := Synth.build(sound_name)
		assert_not_null(s, sound_name)
		assert_eq(s.format, AudioStreamWAV.FORMAT_16_BITS)
		assert_eq(s.mix_rate, Synth.MIX_RATE)
		assert_false(s.stereo)
		assert_almost_eq(s.get_length(), LENGTHS[sound_name], 0.01, sound_name)

func test_sounds_are_the_same_every_time():
	for sound_name in [&"hiss_out", &"bolt_clunk", &"breath"]:
		assert_eq(Synth.build(sound_name).data, Synth.build(sound_name).data, sound_name)

func test_every_sound_is_audible_and_never_clips():
	for sound_name: StringName in Synth.NAMES:
		var data := Synth.build(sound_name).data
		var n := data.size() / 2
		var sum := 0.0
		var peak := 0
		for i in n:
			var v := data.decode_s16(i * 2)
			sum += float(v) * float(v)
			peak = maxi(peak, absi(v))
		var rms := sqrt(sum / n) / 32768.0
		assert_gt(rms, 0.01, "%s is audible" % sound_name)
		assert_lt(peak, 32767, "%s never clips" % sound_name)

func test_ambient_sounds_loop():
	for sound_name in Synth.LOOPED:
		var s := Synth.build(sound_name)
		assert_eq(s.loop_mode, AudioStreamWAV.LOOP_FORWARD, sound_name)
		assert_eq(s.loop_end, s.data.size() / 2)
	assert_eq(Synth.build(&"bolt_clunk").loop_mode, AudioStreamWAV.LOOP_DISABLED)

func test_the_cache_hands_out_one_stream_per_sound():
	Synth.warm_up()
	var deadline := Time.get_ticks_msec() + 20000
	while not Synth.is_warm() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_true(Synth.is_warm())
	assert_same(Synth.sound(&"panel_beep"), Synth.sound(&"panel_beep"))
