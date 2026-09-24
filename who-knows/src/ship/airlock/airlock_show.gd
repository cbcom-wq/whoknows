class_name AirlockShow
extends Node3D

## The airlock's spectacle for one room (docs/superpowers/specs/
## 2026-09-24-airlock-design.md §5): chunky steam puffs from the nozzles, fog
## that blooms and drains, a haze over the viewer's own camera, and the room
## light shifting through the cycle. It only shows the cycle -- the Airlock
## calls apply() once a frame -- so it never runs a clock of its own.
##
## Built from engine particles and a plain material: no new shader. Knows
## nothing about ships; it takes frames and a render layer.

## Puffs: a chunky low-poly sphere, lit, fading through a colour ramp.
const PUFF_SEGMENTS := 8
const PUFF_RINGS := 4
const JET_PUFFS := 36
const JET_LIFETIME := 1.9
const JET_SPEED := 3.4
const JET_TIME := 1.2
const FOG_PUFFS := 70
const FOG_LIFETIME := 2.4
## Distance fog density at full haze. The peaks below stay well short of it: a
## mist going out, thicker steam coming in (1 - exp(-d x) is about 60% at the
## hatch 1.5 m away, 72% at the far wall) -- foggy, never a whiteout, so the
## room and its glowing hatch strips still show through.
const HAZE_DENSITY := 0.9
const HAZE_PEAK_OUT := 0.5
const HAZE_PEAK_IN := 0.7
## Puffs closer to the camera than this fade away, so one drifting through
## your head never fills the screen.
const FADE_NEAR := 0.25
const FADE_FAR := 0.9
## How fast the haze follows its target, per second, up and down: it gathers
## quickly and lingers a little as it clears.
const HAZE_RISE := 2.2
const HAZE_FALL := 0.9
## The room light while the outer hatch is open: dimmer, and a touch cooler.
const OPEN_ENERGY := 0.4
const OPEN_COOL := 0.3
## The alcove's one-shot burst out of the hatch onto vacuum.
const BURST_PUFFS := 36
const BURST_LIFETIME := 1.4

var haze := 0.0

var _jets: Array[GPUParticles3D] = []
var _fog: GPUParticles3D
var _burst: GPUParticles3D
var _fog_process: ParticleProcessMaterial
var _room_frame := Transform3D.IDENTITY
var _outward := Vector3.FORWARD
var _light: OmniLight3D
var _base_energy := 1.0
var _alert := 0.0

## `room_frame`: the room's floor centre, -z toward the outer hatch. `nozzles`:
## each jet's tip, -z along the jet. `light`: the room light it recolours.
## `burst_only` builds just the outward burst, for the copy on the hull.
func setup(room_frame: Transform3D, nozzles: Array[Transform3D], light: OmniLight3D, layer: int,
		burst_only := false) -> void:
	name = "AirlockShow"
	_room_frame = room_frame
	_outward = (room_frame.basis * Vector3.FORWARD).normalized()
	_light = light
	if light != null:
		_base_energy = light.light_energy
	var puff := _puff_mesh(false)
	if burst_only:
		# Vapor in sunlight, not rocks: flat and pale, fading as it spreads.
		_burst = _emitter("Burst", _puff_mesh(true), layer, BURST_PUFFS, BURST_LIFETIME, _burst_process())
		_burst.one_shot = true
		_burst.explosiveness = 0.85
		_burst.transform = room_frame * Transform3D(Basis.IDENTITY,
			Vector3(0, InteriorProps.HATCH_HEIGHT * 0.5, -InteriorProps.BAY * 0.5))
		return
	for i in nozzles.size():
		var jet := _emitter("Jet%d" % i, puff, layer, JET_PUFFS, JET_LIFETIME, _jet_process())
		jet.transform = nozzles[i]
		_jets.append(jet)
	_fog_process = _fog_process_material()
	_fog = _emitter("Fog", puff, layer, FOG_PUFFS, FOG_LIFETIME, _fog_process)
	_fog.transform = room_frame * Transform3D(Basis.IDENTITY, Vector3(0, InteriorProps.AIRLOCK_CLEAR * 0.5, 0))

## Shows `cycle` as it is now. `delta` eases the haze and light.
func apply(cycle: AirlockCycle, delta: float) -> void:
	var stage := cycle.stage
	var out := cycle.going_out()
	var t := cycle.cycle_time()
	var cycling := stage == AirlockCycle.Stage.CYCLING
	for jet in _jets:
		jet.emitting = cycling and not out and t < JET_TIME
	if _fog != null:
		_fog.emitting = cycling or (stage == AirlockCycle.Stage.OPENING and cycle.outer_open < 0.5 and out)
		_fog.amount_ratio = 0.8 if out else 0.4
		# Going out, the fog streams out through the opening hatch; coming in, it
		# sinks into the vents.
		if stage == AirlockCycle.Stage.OPENING and out:
			_fog_process.gravity = _outward * 5.0
		elif not out and (stage == AirlockCycle.Stage.OPENING or stage == AirlockCycle.Stage.IDLE):
			_fog_process.gravity = Vector3.DOWN * 1.6
		else:
			_fog_process.gravity = Vector3.ZERO
	var target := haze_target(cycle)
	haze = move_toward(haze, target, delta * (HAZE_RISE if target > haze else HAZE_FALL))
	_alert = move_toward(_alert, 0.0 if stage == AirlockCycle.Stage.IDLE else 1.0, delta * 3.0)
	if _light != null:
		var colour := InteriorPalette.LIGHT_WARM.lerp(InteriorPalette.AMBER, _alert)
		colour = colour.lerp(InteriorPalette.SKY, OPEN_COOL * cycle.outer_open)
		_light.light_color = colour
		_light.light_energy = _base_energy * lerpf(1.0, OPEN_ENERGY, cycle.outer_open)

## The one-shot puff out of the hatch as it opens onto vacuum (the hull copy).
func burst_out() -> void:
	if _burst != null:
		_burst.restart()

## How thick the haze wants to be for `cycle` right now (0 clear .. 1 a near
## whiteout): it blooms early going out and with the steam coming in, holds
## through the cycle, and clears as the far hatch opens.
static func haze_target(cycle: AirlockCycle) -> float:
	match cycle.stage:
		AirlockCycle.Stage.CYCLING:
			if cycle.going_out():
				return smoothstep(0.0, 0.9, cycle.cycle_time()) * HAZE_PEAK_OUT
			return smoothstep(0.1, 1.5, cycle.cycle_time()) * HAZE_PEAK_IN
		AirlockCycle.Stage.OPENING:
			var far := cycle.outer_open if cycle.going_out() else cycle.inner_open
			var peak := HAZE_PEAK_OUT if cycle.going_out() else HAZE_PEAK_IN
			return peak * (1.0 - far)
	return 0.0

## The environment a viewer in the room should see through: `base` with
## distance fog at this show's haze, written into `into` (a copy owned by the
## caller, so the interior's own environment is never touched).
func tint(into: Environment) -> void:
	into.fog_enabled = haze > 0.001
	into.fog_light_color = InteriorPalette.STEAM
	into.fog_light_energy = 0.8
	into.fog_density = haze * HAZE_DENSITY
	into.fog_sky_affect = 0.0

static func _puff_mesh(flat: bool) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = PUFF_SEGMENTS
	mesh.rings = PUFF_RINGS
	var material := StandardMaterial3D.new()
	material.albedo_color = InteriorPalette.STEAM
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 1.0
	if flat:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.shadow_to_opacity = false
	material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	material.distance_fade_min_distance = FADE_NEAR
	material.distance_fade_max_distance = FADE_FAR
	mesh.material = material
	return mesh

func _emitter(emitter_name: String, puff: Mesh, layer: int, amount: int, lifetime: float,
		process: ParticleProcessMaterial) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = emitter_name
	p.amount = amount
	p.lifetime = lifetime
	p.draw_pass_1 = puff
	p.process_material = process
	p.layers = layer
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	add_child(p)
	return p

## Fades in, holds, fades out: steam in the palette's off-white.
static func _fade(peak: float) -> GradientTexture1D:
	var clear := InteriorPalette.STEAM
	clear.a = 0.0
	var thick := InteriorPalette.STEAM
	thick.a = peak
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
	g.colors = PackedColorArray([clear, thick, thick, clear])
	var tex := GradientTexture1D.new()
	tex.gradient = g
	return tex

static func _grow(from: float, to: float) -> CurveTexture:
	var c := Curve.new()
	c.max_value = maxf(from, to)
	c.add_point(Vector2(0.0, from))
	c.add_point(Vector2(1.0, to))
	var tex := CurveTexture.new()
	tex.curve = c
	return tex

static func _jet_process() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 0, -1)
	m.spread = 12.0
	m.initial_velocity_min = JET_SPEED * 0.8
	m.initial_velocity_max = JET_SPEED
	m.damping_min = 2.2
	m.damping_max = 3.0
	m.gravity = Vector3.ZERO
	m.scale_min = 0.12
	m.scale_max = 0.18
	m.scale_curve = _grow(1.0, 5.5)
	m.color_ramp = _fade(0.8)
	m.angle_min = 0.0
	m.angle_max = 360.0
	return m

func _fog_process_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(0.75, 0.75, 0.75)
	m.direction = Vector3(0, 1, 0)
	m.spread = 180.0
	m.initial_velocity_min = 0.05
	m.initial_velocity_max = 0.35
	m.gravity = Vector3.ZERO
	m.damping_min = 0.2
	m.damping_max = 0.5
	m.scale_min = 0.25
	m.scale_max = 0.45
	m.scale_curve = _grow(0.6, 1.3)
	m.color_ramp = _fade(0.35)
	m.angle_min = 0.0
	m.angle_max = 360.0
	return m

func _burst_process() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(0.4, 0.7, 0.1)
	m.direction = Vector3(0, 0, -1)
	m.spread = 35.0
	m.initial_velocity_min = 2.0
	m.initial_velocity_max = 4.5
	m.gravity = Vector3.ZERO
	m.scale_min = 0.25
	m.scale_max = 0.45
	m.scale_curve = _grow(0.8, 2.2)
	m.color_ramp = _fade(0.35)
	return m
