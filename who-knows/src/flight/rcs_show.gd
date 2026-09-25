class_name RcsShow
extends Node3D

## The RCS thrusters you see and hear (docs/superpowers/specs/
## 2026-09-25-flight-controls-design.md §6). Each `rcs` block puffs vapour, and
## sounds aboard, in proportion to how much it helps the twist and push the
## flight computer commanded this tick. The physics is untouched: the flight
## computer still applies one twist and one push to the hull. This only shows
## which thrusters would be doing it.

const BLOCK_ID := &"rcs"
## A block lined up within 45 deg of the command fires fully; past 70 deg, not
## at all; a smoothstep between.
const FULL_ALIGN := 0.7071
const NO_ALIGN := 0.342
## Below this an emitter stops.
const SHOW_AT := 0.05
## A block puffs aloud when its firing rises past PUFF_ON, re-arms once it falls
## below PUFF_REARM, and puffs at most once per PUFF_GAP seconds. A held turn is
## heard as a puff when it starts and one from the other side when it stops.
const PUFF_ON := 0.15
const PUFF_REARM := 0.05
const PUFF_GAP := 0.12
const PUFFS := 16
const LIFETIME := 0.5
const EXHAUST_SPEED := 6.0
const LOUD_DB := -8.0
const SOFT_DB := -26.0
## The world's render layer: the canopy camera leaves the own-hull layer out,
## and the puffs are what you should see through it.
const LAYER := 1

## One entry per `rcs` block, in hull axes: {coord, force (N), torque about the
## centre of mass (N m), nozzle (the middle of the face the exhaust leaves)}.
var blocks: Array = []
## Each block's firing this tick, 0..1, in `blocks` order.
var firing := PackedFloat32Array()
var emitters: Array[GPUParticles3D] = []
var players: Array[AudioStreamPlayer3D] = []

var _flight: FlightComputer
var _interior: Node3D
var _armed := PackedByteArray()
var _last_puff := PackedFloat32Array()

## `flight` is read each physics tick; the puff sounds go under `interior`,
## where each block sits aboard.
func setup(flight: FlightComputer, interior: Node3D) -> void:
	_flight = flight
	_interior = interior

## One emitter and one sound per `rcs` block of `grid`, replacing the last set.
func rebuild(grid: ShipGrid, catalog: BlockCatalog, center_of_mass: Vector3) -> void:
	for e in emitters:
		e.free()
	for p in players:
		p.free()
	emitters.clear()
	players.clear()
	blocks = gather(grid, catalog, center_of_mass)
	# A player on a bus that does not exist yet falls back to Master for good.
	AudioBuses.ensure()
	var mesh := Puffs.mesh(true)
	var process := _process_material()
	for b in blocks:
		emitters.append(_emitter(b, mesh, process))
		if _interior != null:
			players.append(_player(b))
	firing.resize(blocks.size())
	firing.fill(0.0)
	_armed.resize(blocks.size())
	_armed.fill(1)
	_last_puff.resize(blocks.size())
	_last_puff.fill(-INF)

## Every `rcs` block of `grid`, with its push and its twist about
## `center_of_mass`, worked out the way ShipStats does.
static func gather(grid: ShipGrid, catalog: BlockCatalog, center_of_mass: Vector3) -> Array:
	var out: Array = []
	for coord: Vector3i in grid.coords():
		var inst := grid.get_block(coord)
		if inst.block_id != BLOCK_ID:
			continue
		var def := catalog.get_def(inst.block_id)
		if def == null or def.thrust_kn <= 0.0:
			continue
		var force := BlockOrientation.basis_for(inst.orientation) * Vector3(0, 0, -1) \
			* def.thrust_kn * ShipStats.N_PER_KN
		var centre := ShipGrid.cell_center(coord)
		out.append({
			"coord": coord,
			"force": force,
			"torque": (centre - center_of_mass).cross(force),
			"nozzle": centre - force.normalized() * ShipGrid.CELL_SIZE * 0.5,
		})
	return out

## How hard each block fires, 0..1, for the commanded twist `torque` and push
## `force`, both in hull axes (spec §6.1). Pure.
##
## Everything is measured as a share of its budget, so a strong axis does not
## drown a weak one. A block fires as hard as the command asks, times how well
## its own twist or push lines up with it. Only blocks that push across the
## hull count for turning -- exactly the ones ShipStats sums into the torque
## budget, so the off-centre retros never light up for yaw -- and only aft
## pushes count for moving, since a forward push is the main engines'.
static func firing_for(blocks: Array, torque: Vector3, force: Vector3,
		torque_budget: Vector3, thrust_budget: Dictionary) -> PackedFloat32Array:
	var push_budget := Vector3(thrust_budget[&"lateral"], thrust_budget[&"vertical"],
		thrust_budget[&"reverse"])
	var twist_wanted := _share(torque, torque_budget)
	var push_wanted := _share(_aft_only(force), push_budget)
	var out := PackedFloat32Array()
	out.resize(blocks.size())
	for i in blocks.size():
		var f: Vector3 = blocks[i]["force"]
		var twist := 0.0
		if not (is_zero_approx(f.x) and is_zero_approx(f.y)):
			twist = _helps(_share(blocks[i]["torque"], torque_budget), twist_wanted)
		var push := _helps(_share(_aft_only(f), push_budget), push_wanted)
		out[i] = maxf(twist, push)
	return out

## Whether a block should puff aloud now, and whether it stays armed after.
static func puff_step(fire: float, armed: bool, since_last: float) -> Array:
	if fire < PUFF_REARM:
		return [false, true]
	if armed and fire >= PUFF_ON and since_last >= PUFF_GAP:
		return [true, false]
	return [false, armed]

func _physics_process(_delta: float) -> void:
	if _flight == null or blocks.is_empty():
		return
	firing = firing_for(blocks, _flight.commanded_torque_local, _flight.commanded_force_local,
		_flight.torque_budget, _flight.thrust_budget)
	apply(firing)
	_sound(firing)

## Puffs each block's emitter at its firing amount.
func apply(amounts: PackedFloat32Array) -> void:
	for i in emitters.size():
		emitters[i].amount_ratio = clampf(amounts[i], 0.0, 1.0)
		emitters[i].emitting = amounts[i] >= SHOW_AT

func _sound(amounts: PackedFloat32Array) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var aboard := _aboard()
	for i in players.size():
		var step := puff_step(amounts[i], _armed[i] == 1, now - _last_puff[i])
		_armed[i] = 1 if step[1] else 0
		if not step[0]:
			continue
		_last_puff[i] = now
		var s := Synth.sound(&"rcs_puff")
		if not aboard or s == null:
			continue
		players[i].stream = s
		players[i].volume_db = lerpf(SOFT_DB, LOUD_DB, amounts[i])
		players[i].play()

## True while the camera you see through is aboard. Space is silent: the chase
## view hears nothing, like the ship's hum (spec §6.3).
func _aboard() -> bool:
	var cam := get_viewport().get_camera_3d()
	return cam != null and _interior != null and _interior.is_ancestor_of(cam)

func _emitter(b: Dictionary, mesh: Mesh, process: ParticleProcessMaterial) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Rcs%d" % emitters.size()
	p.amount = PUFFS
	p.lifetime = LIFETIME
	p.draw_pass_1 = mesh
	p.process_material = process
	p.layers = LAYER
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	var exhaust: Vector3 = -(b["force"] as Vector3).normalized()
	var up := Vector3.UP if absf(exhaust.dot(Vector3.UP)) < 0.9 else Vector3.BACK
	p.transform = Transform3D(Basis.looking_at(exhaust, up), b["nozzle"])
	# World-space puffs cannot be moved once out, so they hold the floating
	# origin's shift while alive (CLAUDE.md).
	p.add_to_group(Universe.HOLDS_SHIFT)
	add_child(p)
	return p

func _player(b: Dictionary) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = "RcsPuff%d" % players.size()
	p.bus = AudioBuses.SHIP
	var coord: Vector3i = b["coord"]
	p.position = ShipGrid.cell_center(coord) + Vector3(0.0, InteriorBuilder.storey_offset(coord.y), 0.0)
	_interior.add_child(p)
	return p

## Puffs blow out of the nozzle, slow in a metre or two, grow and fade. They
## keep the hull's velocity, so a fast ship does not smear them into a trail.
static func _process_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 0, -1)
	m.spread = 14.0
	m.initial_velocity_min = EXHAUST_SPEED * 0.7
	m.initial_velocity_max = EXHAUST_SPEED
	m.damping_min = 6.0
	m.damping_max = 9.0
	m.gravity = Vector3.ZERO
	m.inherit_velocity_ratio = 1.0
	m.scale_min = 0.3
	m.scale_max = 0.45
	m.scale_curve = Puffs.grow(0.7, 2.2)
	m.color_ramp = Puffs.fade(0.7)
	m.angle_min = 0.0
	m.angle_max = 360.0
	return m

## `v` with its forward (-z) part dropped.
static func _aft_only(v: Vector3) -> Vector3:
	return Vector3(v.x, v.y, maxf(v.z, 0.0))

## `v` per axis as a share of `budget`; an axis with no budget is left out.
static func _share(v: Vector3, budget: Vector3) -> Vector3:
	return Vector3(
		0.0 if budget.x <= 0.0 else v.x / budget.x,
		0.0 if budget.y <= 0.0 else v.y / budget.y,
		0.0 if budget.z <= 0.0 else v.z / budget.z,
	)

## How hard a block whose share is `mine` fires for the command `wanted`.
static func _helps(mine: Vector3, wanted: Vector3) -> float:
	var strength := minf(maxf(absf(wanted.x), maxf(absf(wanted.y), absf(wanted.z))), 1.0)
	if strength < 0.0001 or mine.length() < 0.0001:
		return 0.0
	var align := mine.dot(wanted) / (mine.length() * wanted.length())
	return strength * smoothstep(NO_ALIGN, FULL_ALIGN, align)
