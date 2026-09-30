class_name WarpDrive
extends Node

## The warp (docs/superpowers/specs/2026-09-28-warp-design.md §4, §5): charted
## at the bridge computer, lined up at the helm, then J. It spools for SPOOL
## seconds while you keep the helm, spends the QE as it leaves, flies the hull
## along a straight line to the target's warp limit and lets go there at
## 120 m/s, moving in.
##
## The only thing that moves a ship at warp. While it travels the hull is
## frozen kinematic, placed every tick from WarpProfile, and touches nothing
## (its layer and mask cleared). It knows nothing about the world outside: it
## emits travel_started and travel_ended, and the flight scene suspends and
## resumes the rocks, the salvage and the look of belts and dust.

signal stage_changed(stage: Stage)
signal travel_started
signal travel_ended
## A spool that stopped with nothing spent, and why, as a WarpPlan line.
signal aborted(why: String)

enum Stage { IDLE, SPOOLING, TRAVELLING }

const SPOOL := 10.0
## Swinging further than this off the line while spooling aborts it.
const ABORT_ANGLE := deg_to_rad(10.0)
## The dust streaks the velocity over this shutter, metres (§5.2).
const STREAK_SHUTTER := 0.01
## While spooling, the dust stretches up to this, metres.
const SPOOL_STREAK := 4.0
## The hull swings from where it pointed onto the line over this long.
const SWING := WarpProfile.RAMP

var hull: RigidBody3D
var universe: Universe
var system: SystemRecipe
var whereabouts: Whereabouts
## Optional: the course follows the chart.
var sensors: ShipSensors
## Optional: arrivals are stepped clear of its rocks.
var rocks: AsteroidRecipe
## Where the QE comes from: the plant's store, or `store` in tests.
var plant: QuantumPlant
var store: QuantumStore
## Optional: the speed lock holds 120 m/s after a drop-out.
var flight_computer: FlightComputer
## Returns &"crew" while someone is outside, &"airlock" while one cycles, or &"".
var busy := Callable()

## The target charted, by WarpTarget id; empty for none.
var charted: StringName = &""
var stage := Stage.IDLE
## The latest check, for the HUD.
var plan := WarpPlan.new()
var spool_left := 0.0

var _profile: WarpProfile
var _t := 0.0
var _from: UniversePoint
var _dir := Vector3.ZERO
var _drop: UniversePoint
var _start_basis := Basis.IDENTITY
var _layer := 0
var _mask := 0
var _player: AudioStreamPlayer

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "Sound"
	_player.bus = AudioBuses.SHIP
	add_child(_player)

func _physics_process(delta: float) -> void:
	step(delta)

## Hands it the system and what it asks, once the flight scene has them. A
## chart saved for a target this system lacks is dropped.
func bind(p_system: SystemRecipe, p_universe: Universe, p_whereabouts: Whereabouts,
		p_sensors: ShipSensors, p_rocks: AsteroidRecipe, p_busy: Callable) -> void:
	system = p_system
	universe = p_universe
	whereabouts = p_whereabouts
	sensors = p_sensors
	rocks = p_rocks
	busy = p_busy
	if sensors != null and not sensors.course_changed.is_connected(_on_course_changed):
		sensors.course_changed.connect(_on_course_changed)
	if charted != &"":
		var t := target()
		if t == null:
			charted = &""
		elif sensors != null:
			sensors.set_course(t.contact_id())

func the_store() -> QuantumStore:
	return plant.store if plant != null and plant.store != null else store

func target() -> WarpTarget:
	return system.warp_target(charted) if system != null and charted != &"" else null

## The warp target a sensor contact stands for, or null.
func target_for(contact_id: StringName) -> WarpTarget:
	if system == null:
		return null
	return system.warp_target(StringName(String(contact_id).trim_prefix(BodyContacts.PREFIX)))

## Charts a warp to target `id` and sets the course to it (§4.1).
func chart(id: StringName) -> void:
	if system == null or system.warp_target(id) == null or stage != Stage.IDLE:
		return
	charted = id
	if sensors != null:
		sensors.set_course(system.warp_target(id).contact_id())

func clear_chart() -> void:
	if stage != Stage.IDLE or charted == &"":
		return
	var t := target()
	charted = &""
	if sensors != null and t != null and sensors.course == t.contact_id():
		sensors.clear_course()

## A course set elsewhere, or cleared by arriving, ends the chart.
func _on_course_changed(id: StringName) -> void:
	var t := target()
	if stage == Stage.IDLE and t != null and id != t.contact_id():
		charted = &""

## Works out the plan from where the hull is now.
func check() -> WarpPlan:
	var t := target()
	if t == null or universe == null or hull == null or not hull.is_inside_tree():
		plan = WarpPlan.check(null, Vector3.FORWARD, null, [], [], null)
		return plan
	var inside: Array[StringName] = whereabouts.limits() if whereabouts != null else []
	var why: StringName = busy.call() if busy.is_valid() else &""
	plan = WarpPlan.check(universe.to_universe(hull.global_position), -hull.global_basis.z, t,
		system.warp_targets(), inside, the_store(), why)
	return plan

## J (§5.1): starts the spool when ready; during the spool, aborts it.
func engage() -> void:
	match stage:
		Stage.IDLE:
			check()
			if plan.status == WarpPlan.Status.READY:
				stage = Stage.SPOOLING
				spool_left = SPOOL
				_play(&"warp_spool")
				stage_changed.emit(stage)
		Stage.SPOOLING:
			abort("WARP · ABORTED")

## Stops a spool with nothing spent.
func abort(why: String) -> void:
	if stage != Stage.SPOOLING:
		return
	stage = Stage.IDLE
	spool_left = 0.0
	if _player != null:
		_player.stop()
	stage_changed.emit(stage)
	aborted.emit(why)

func step(delta: float) -> void:
	match stage:
		Stage.IDLE:
			check()
		Stage.SPOOLING:
			check()
			if not _lined_up():
				abort(plan.text())
				return
			spool_left -= delta
			if spool_left <= 0.0:
				_leave()
		Stage.TRAVELLING:
			_t = minf(_t + delta, _profile.duration)
			if _t >= _profile.duration:
				_arrive()
			else:
				_place()

func is_spinning() -> bool:
	return stage != Stage.IDLE

func travelling() -> bool:
	return stage == Stage.TRAVELLING

func velocity() -> Vector3:
	return _dir * _profile.speed_at(_t) if stage == Stage.TRAVELLING else Vector3.ZERO

## What the dust stretches along, metres (§5.1, §5.2).
func streak() -> Vector3:
	match stage:
		Stage.SPOOLING:
			return plan.direction * SPOOL_STREAK * (1.0 - spool_left / SPOOL)
		Stage.TRAVELLING:
			return velocity() * STREAK_SHUTTER
	return Vector3.ZERO

## Seconds left of the spool or the travel.
func time_left() -> float:
	match stage:
		Stage.SPOOLING:
			return spool_left
		Stage.TRAVELLING:
			return _profile.duration - _t
	return 0.0

## Where a save made now should put the hull (§5.5): during travel, at the
## drop-out point, moving in; otherwise nothing.
func arrival() -> Dictionary:
	if stage != Stage.TRAVELLING:
		return {}
	return {"at": _drop, "turn": _facing(), "v": _dir * WarpProfile.EDGE_SPEED}

func to_dict() -> Dictionary:
	return {"charted": String(charted)}

## Takes a saved chart; bind() checks it against the system.
func from_dict(d: Dictionary) -> void:
	charted = StringName(String(d.get("charted", "")))

func _lined_up() -> bool:
	return plan.status == WarpPlan.Status.READY \
		or (plan.status == WarpPlan.Status.ALIGN and plan.off_line <= ABORT_ANGLE)

func _leave() -> void:
	var s := the_store()
	if s == null or not s.spend(plan.cost, &"warp"):
		abort("WARP · NEED %d QE" % plan.cost)
		return
	_from = universe.to_universe(hull.global_position)
	_dir = plan.direction
	_drop = WarpPlan.stepped_clear(rocks, plan.drop, _dir) if rocks != null else plan.drop
	_profile = WarpProfile.new(_drop.minus(_from).length())
	_t = 0.0
	_start_basis = hull.global_basis.orthonormalized()
	_layer = hull.collision_layer
	_mask = hull.collision_mask
	hull.collision_layer = 0
	hull.collision_mask = 0
	hull.linear_velocity = Vector3.ZERO
	hull.angular_velocity = Vector3.ZERO
	hull.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	hull.freeze = true
	stage = Stage.TRAVELLING
	_play(&"warp_travel")
	stage_changed.emit(stage)
	travel_started.emit()

func _place() -> void:
	var at := _from.plus(_dir * _profile.travelled_at(_t))
	var swing := clampf(_t / SWING, 0.0, 1.0)
	hull.global_transform = Transform3D(_start_basis.slerp(_facing(), swing), universe.to_engine(at))
	universe.check()

func _arrive() -> void:
	hull.global_transform = Transform3D(_facing(), universe.to_engine(_drop))
	hull.freeze = false
	hull.collision_layer = _layer
	hull.collision_mask = _mask
	hull.linear_velocity = _dir * WarpProfile.EDGE_SPEED
	hull.angular_velocity = Vector3.ZERO
	universe.check()
	if flight_computer != null and flight_computer.assist_enabled:
		flight_computer.speed_locked = true
		flight_computer.locked_speed = WarpProfile.EDGE_SPEED
	stage = Stage.IDLE
	_play(&"warp_drop")
	stage_changed.emit(stage)
	travel_ended.emit()

## Facing along the line, keeping the hull's up as near as it can.
func _facing() -> Basis:
	var up := _start_basis.y if absf(_start_basis.y.dot(_dir)) < 0.99 else Vector3.UP
	if absf(up.dot(_dir)) >= 0.99:
		up = Vector3.RIGHT
	return Basis.looking_at(_dir, up)

func _play(sound: StringName) -> void:
	var s := Synth.sound(sound)
	if s != null and _player != null and _player.is_inside_tree():
		_player.stream = s
		_player.play()
