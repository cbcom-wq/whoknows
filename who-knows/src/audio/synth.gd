class_name Synth
extends RefCounted

## Every sound the game has, synthesized in code (docs/superpowers/specs/
## 2026-09-24-airlock-design.md §6): noise, sines, one-pole filters and
## envelopes, from fixed seeds, so the same sound comes out every time. There
## are no sound files. The style is soft and warm, never harsh -- the ear's
## version of the chunky, warm look.
##
## build() makes one sound from scratch. warm_up() builds them all on a worker
## thread when a ship loads; sound() hands out the cached one, or null until it
## is ready, so nothing ever waits on it.

const MIX_RATE := 22050
const NAMES: Array[StringName] = [
	&"hatch_motor", &"bolt_clunk", &"seal_thump", &"hiss_out", &"steam_in",
	&"panel_beep", &"warning_chime", &"ship_hum", &"breath", &"thruster_puff", &"hull_thump",
	&"rcs_puff", &"core_hum", &"convert", &"materialize", &"charge",
]
## Sounds that play as seamless loops.
const LOOPED: Array[StringName] = [&"ship_hum", &"breath", &"thruster_puff", &"core_hum", &"charge"]

static var _cache: Dictionary = {}
static var _mutex := Mutex.new()
static var _warming := false

## Starts building every sound on a worker thread, once.
static func warm_up() -> void:
	_mutex.lock()
	var start := not _warming
	_warming = true
	_mutex.unlock()
	if start:
		WorkerThreadPool.add_task(_build_all)

static func _build_all() -> void:
	for sound_name in NAMES:
		var s := build(sound_name)
		_mutex.lock()
		_cache[sound_name] = s
		_mutex.unlock()

## The cached sound, or null while it is still being built.
static func sound(sound_name: StringName) -> AudioStreamWAV:
	_mutex.lock()
	var s: AudioStreamWAV = _cache.get(sound_name)
	_mutex.unlock()
	return s

static func is_warm() -> bool:
	_mutex.lock()
	var warm := _cache.size() == NAMES.size()
	_mutex.unlock()
	return warm

## Builds `sound_name` from scratch. Pure: the same bytes every time.
static func build(sound_name: StringName) -> AudioStreamWAV:
	var x: PackedFloat32Array
	match sound_name:
		&"hatch_motor":
			x = _hatch_motor()
		&"bolt_clunk":
			x = _bolt_clunk()
		&"seal_thump":
			x = _seal_thump()
		&"hull_thump":
			x = _hull_thump()
		&"hiss_out":
			x = _hiss_out()
		&"steam_in":
			x = _steam_in()
		&"panel_beep":
			x = _tones([988.0, 1319.0], 0.15, 0.25)
		&"warning_chime":
			x = _tones([660.0, 440.0], 0.5, 0.25)
		&"ship_hum":
			x = _ship_hum()
		&"breath":
			x = _breath()
		&"thruster_puff":
			x = _thruster()
		&"rcs_puff":
			x = _rcs_puff()
		&"core_hum":
			x = _core_hum()
		&"convert":
			x = _convert()
		&"materialize":
			x = _materialize()
		&"charge":
			x = _charge()
		_:
			push_error("Synth: no sound called %s" % sound_name)
			return null
	return _to_wav(x, LOOPED.has(sound_name))

# --- the sounds -------------------------------------------------------------

## A low whirr that rises a little as the leaves move.
static func _hatch_motor() -> PackedFloat32Array:
	var n := _len(0.9)
	var x := _lowpass(_noise(n, 11), 800.0)
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var f := lerpf(90.0, 120.0, t / 0.9)
		phase += TAU * f / MIX_RATE
		var tone := sin(phase) + 0.5 * sin(2.0 * phase) + 0.25 * sin(3.0 * phase)
		x[i] = (tone * 0.5 + x[i] * 0.6) * _ramp(t, 0.08, 0.9, 0.15)
	return _gain(_lowpass(x, 1200.0), 0.45)

## A bolt driving home: a dropping thump, a click and a short ring.
static func _bolt_clunk() -> PackedFloat32Array:
	var n := _len(0.3)
	var click := _highpass(_noise(n, 12), 2000.0)
	var x := PackedFloat32Array()
	x.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		phase += TAU * lerpf(90.0, 55.0, minf(t / 0.12, 1.0)) / MIX_RATE
		x[i] = sin(phase) * exp(-t / 0.06) + click[i] * exp(-t / 0.004) * 0.8 \
			+ sin(TAU * 880.0 * t) * exp(-t / 0.05) * 0.15
	return _gain(x, 0.7)

## Leaves meeting: a deep, soft thump.
static func _seal_thump() -> PackedFloat32Array:
	var n := _len(0.35)
	var rumble := _lowpass(_noise(n, 13), 300.0)
	var x := PackedFloat32Array()
	x.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		phase += TAU * lerpf(55.0, 40.0, minf(t / 0.2, 1.0)) / MIX_RATE
		x[i] = sin(phase) * exp(-t / 0.1) + rumble[i] * exp(-t / 0.05) * 2.0
	return _gain(x, 0.75)

## The hull struck: a deep, heavy thump through the structure, with a short
## metallic ring (asteroids spec §7.5).
static func _hull_thump() -> PackedFloat32Array:
	var n := _len(0.6)
	var rumble := _lowpass(_noise(n, 27), 250.0)
	var x := PackedFloat32Array()
	x.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		phase += TAU * lerpf(48.0, 30.0, minf(t / 0.35, 1.0)) / MIX_RATE
		x[i] = sin(phase) * exp(-t / 0.18) + rumble[i] * exp(-t / 0.07) * 2.2 			+ sin(TAU * 173.0 * t) * exp(-t / 0.12) * 0.12
	return _gain(x, 0.8)

## Air going: a hiss whose brightness and loudness fall away with the pressure.
static func _hiss_out() -> PackedFloat32Array:
	var n := _len(2.8)
	var x := _sweep_lowpass(_highpass(_noise(n, 14), 400.0), 7000.0, 900.0)
	for i in n:
		var u := float(i) / n
		x[i] *= minf(u / 0.02, 1.0) * pow(1.0 - u, 1.5)
	return _gain(x, 0.9)

## Air coming: three sharp jets, then a roar that swells as the room fills.
static func _steam_in() -> PackedFloat32Array:
	var n := _len(2.8)
	var jets := _lowpass(_highpass(_noise(n, 15), 1500.0), 8000.0)
	var roar := _sweep_lowpass(_noise(n, 16), 500.0, 5000.0)
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var u := float(i) / n
		var burst := 0.0
		for start in [0.0, 0.28, 0.6]:
			if t >= start:
				burst += minf((t - start) / 0.01, 1.0) * exp(-(t - start) / 0.25)
		var swell := pow(u, 0.7) * _ramp(t, 0.0, 2.8, 0.3)
		x[i] = jets[i] * burst * 0.6 + roar[i] * swell * 1.2
	return _gain(x, 0.75)

## Soft sine notes one after another over `length` seconds.
static func _tones(freqs: Array, length: float, level: float) -> PackedFloat32Array:
	var n := _len(length)
	var x := PackedFloat32Array()
	x.resize(n)
	var each := length / freqs.size()
	for i in n:
		var t := float(i) / MIX_RATE
		var k := mini(int(t / each), freqs.size() - 1)
		var local := t - k * each
		var f: float = freqs[k]
		x[i] = sin(TAU * f * t) * _ramp(local, 0.008, each, each * 0.6)
	return _gain(x, level)

## The ship's air handling: a low mains hum and a breath of filtered air.
static func _ship_hum() -> PackedFloat32Array:
	var n := _len(2.0)
	var total := n + n / 10
	var air := _lowpass(_noise(total, 17), 400.0)
	var x := PackedFloat32Array()
	x.resize(total)
	for i in total:
		var t := float(i) / MIX_RATE
		x[i] = sin(TAU * 60.0 * t) * 0.3 + sin(TAU * 120.0 * t) * 0.15 + air[i] * 1.2
	return _gain(_loopable(x, n), 0.3)

## Slow suit breathing: in, a pause, out, a pause.
static func _breath() -> PackedFloat32Array:
	var n := _len(4.0)
	var inhale := _lowpass(_highpass(_noise(n, 18), 150.0), 900.0)
	var exhale := _lowpass(_highpass(_noise(n, 19), 120.0), 600.0)
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var a := sin(PI * clampf(t / 1.4, 0.0, 1.0)) if t < 1.4 else 0.0
		var b := sin(PI * clampf((t - 1.9) / 1.8, 0.0, 1.0)) if t >= 1.9 and t < 3.7 else 0.0
		x[i] = inhale[i] * a * 1.2 + exhale[i] * b * 1.4
	return _gain(x, 0.6)

## A suit thruster: a soft, fluttering band of air.
static func _thruster() -> PackedFloat32Array:
	var n := _len(1.0)
	var total := n + n / 10
	var x := _lowpass(_highpass(_noise(total, 20), 250.0), 2500.0)
	for i in total:
		var t := float(i) / MIX_RATE
		x[i] *= 1.0 + 0.2 * sin(TAU * 7.0 * t)
	return _gain(_loopable(x, n), 0.55)

## An RCS thruster firing, heard aboard (flight controls spec §6.3): a short,
## soft hiss with a rounded tail -- warm, never a crack.
static func _rcs_puff() -> PackedFloat32Array:
	var n := _len(0.25)
	var x := _lowpass(_highpass(_noise(n, 28), 300.0), 3000.0)
	for i in n:
		var t := float(i) / MIX_RATE
		x[i] *= minf(t / 0.012, 1.0) * exp(-t / 0.07)
	return _gain(x, 0.6)

## The quantum core (quantum energy spec §13): two soft sines a hair apart,
## beating slowly, with a quieter octave beating along. Every partial fits a
## whole number of cycles into the loop, so it loops without a seam; softer
## than the ship's hum, so the bridge stays calm. The player lifts its pitch
## while boosting.
static func _core_hum() -> PackedFloat32Array:
	var n := _len(4.0)
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		x[i] = sin(TAU * 110.0 * t) + sin(TAU * 110.5 * t) \
			+ 0.3 * (sin(TAU * 220.0 * t) + sin(TAU * 221.0 * t))
	return _gain(x, 0.22)

## Converting (spec §13): a rising shimmer -- filtered noise swept up and a
## sine gliding up an octave and more over the convert's 1.2 s -- ending in a
## soft pop as the energy leaves.
static func _convert() -> PackedFloat32Array:
	var n := _len(1.4)
	var shimmer := _sweep_lowpass(_highpass(_noise(n, 29), 400.0), 700.0, 6000.0)
	var x := PackedFloat32Array()
	x.resize(n)
	var phase := 0.0
	var pop_phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var rise := clampf(t / 1.2, 0.0, 1.0)
		phase += TAU * lerpf(220.0, 660.0, rise * rise) / MIX_RATE
		var swell := _ramp(t, 0.15, 1.2, 0.08) * (0.4 + 0.6 * rise)
		var pop := 0.0
		if t >= 1.18:
			var p := t - 1.18
			pop_phase += TAU * lerpf(520.0, 260.0, minf(p / 0.05, 1.0)) / MIX_RATE
			pop = sin(pop_phase) * minf(p / 0.004, 1.0) * exp(-p / 0.045)
		x[i] = (shimmer[i] * 0.5 + sin(phase) * 0.35) * swell + pop * 0.8
	return _gain(x, 0.5)

## Making (spec §13): the convert's shimmer falling -- noise swept down, a
## sine gliding down -- over the make's 1.5 s, ending in a soft thump as the
## item arrives.
static func _materialize() -> PackedFloat32Array:
	var n := _len(1.8)
	var shimmer := _sweep_lowpass(_highpass(_noise(n, 30), 300.0), 6000.0, 600.0)
	var rumble := _lowpass(_noise(n, 31), 250.0)
	var x := PackedFloat32Array()
	x.resize(n)
	var phase := 0.0
	var thump_phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var fall := clampf(t / 1.5, 0.0, 1.0)
		phase += TAU * lerpf(660.0, 220.0, sqrt(fall)) / MIX_RATE
		var swell := _ramp(t, 0.1, 1.5, 0.1)
		var thump := 0.0
		if t >= 1.46:
			var p := t - 1.46
			thump_phase += TAU * lerpf(90.0, 50.0, minf(p / 0.15, 1.0)) / MIX_RATE
			thump = sin(thump_phase) * minf(p / 0.006, 1.0) * exp(-p / 0.09) + rumble[i] * exp(-p / 0.04) * 1.5
		x[i] = (shimmer[i] * 0.5 + sin(phase) * 0.35) * swell + thump * 0.9
	return _gain(x, 0.55)

## Charging the suit (spec §7.3, §13): a soft tone, a fifth with a faint
## octave, shimmering gently, looped while the charge runs. It rises because
## the plate's player lifts its pitch as the suit fills. Every partial and
## the shimmer fit a whole number of cycles into the loop, so it has no seam.
static func _charge() -> PackedFloat32Array:
	var n := _len(1.0)
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var shimmer := 1.0 + 0.25 * sin(TAU * 6.0 * t)
		x[i] = (sin(TAU * 330.0 * t) + 0.6 * sin(TAU * 495.0 * t) + 0.15 * sin(TAU * 660.0 * t)) * shimmer
	return _gain(x, 0.3)

# --- building blocks ----------------------------------------------------------

static func _len(seconds: float) -> int:
	return int(round(seconds * MIX_RATE))

## White noise in [-1, 1] from a fixed seed.
static func _noise(n: int, seed_value: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		x[i] = rng.randf_range(-1.0, 1.0)
	return x

static func _lowpass(x: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var a := exp(-TAU * cutoff / MIX_RATE)
	var y := PackedFloat32Array()
	y.resize(x.size())
	var last := 0.0
	for i in x.size():
		last = (1.0 - a) * x[i] + a * last
		y[i] = last
	return y

static func _highpass(x: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var low := _lowpass(x, cutoff)
	for i in x.size():
		low[i] = x[i] - low[i]
	return low

## A lowpass whose cutoff glides exponentially from `from` to `to` Hz.
static func _sweep_lowpass(x: PackedFloat32Array, from: float, to: float) -> PackedFloat32Array:
	var y := PackedFloat32Array()
	y.resize(x.size())
	var last := 0.0
	var n := x.size()
	for i in n:
		var cutoff := from * pow(to / from, float(i) / n)
		var a := exp(-TAU * cutoff / MIX_RATE)
		last = (1.0 - a) * x[i] + a * last
		y[i] = last
	return y

## 0 -> 1 over `attack`, holding to `length - release`, then back to 0.
static func _ramp(t: float, attack: float, length: float, release: float) -> float:
	var up := 1.0 if attack <= 0.0 else minf(t / attack, 1.0)
	var down := clampf((length - t) / release, 0.0, 1.0)
	return up * down

## Scales `x` so its loudest sample is `peak`.
static func _gain(x: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var most := 0.0
	for v in x:
		most = maxf(most, absf(v))
	if most <= 0.0:
		return x
	var k := peak / most
	for i in x.size():
		x[i] *= k
	return x

## The first `n` samples of `x`, looping without a seam: `x` runs on past `n`,
## and that overrun is crossfaded into the start, so the loop's last sample
## leads straight into its first.
static func _loopable(x: PackedFloat32Array, n: int) -> PackedFloat32Array:
	var fade := x.size() - n
	var y := x.slice(0, n)
	for i in fade:
		var w := float(i) / fade
		y[i] = x[i] * w + x[n + i] * (1.0 - w)
	return y

static func _to_wav(x: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(x.size() * 2)
	for i in x.size():
		data.encode_s16(i * 2, int(clampf(x[i], -1.0, 1.0) * 32766.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = MIX_RATE
	s.stereo = false
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = x.size()
	return s
