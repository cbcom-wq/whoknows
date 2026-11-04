class_name LandingRamp
extends Node3D

## The landing ramp (desert world phase 0, Task 14; the owner's decision,
## 2026-11-04): a chunky boarding ramp that comes down under an airlock's
## outer hatch when the ship lands on a world, and folds away when it lifts
## off. A landed starter's sill stands 2.05 m over the ground and a jump peaks
## at 0.89 m, so without it you could step out of a ship and never walk back in
## (CLAUDE.md: every ship is usable).
##
## AirlockAlcove builds one under each outer hatch that needs one (need(),
## AirlockAlcove.ramp_plan); Ship puts it down and up with its LandingMonitor
## (Ship._sync_ramps). It builds from a hinge frame and the sill's height
## alone, never the grid: the frame's origin is on the outer hatch's plane at
## the sill, in the middle of the doorway, with +z out into the world, +y the
## hull's up and +x across. Its parent shares the hull body's frame, as the
## alcove does, so its collider can go straight on the body.
##
## The shape carries the detail (docs/design/visual-style.md §2.1, §3.8): a
## slab in hull plate with its top flush with the sill, two chunky side rails
## and the hinge housing in the hull's trim, raised tread strips in the panel
## line's grey (the one accent), and a foot pad that stays level on the ground.
## Flat colour on the hull's trim material; no new shader.
##
## It comes down in TRAVEL seconds: out of a slot under the sill (SLIDE_TIME),
## then down to its angle (SWING_TIME); stowing runs the same backwards. It is
## hidden while stowed. Its one collider is on the hull's exterior body (layer
## 1, which the avatar's SUIT_MASK walks on) and is enabled only while it is
## fully down: the hull is frozen then, so the ramp never pushes the ship or
## touches the ground for the landing monitor, and the airlock's hatch-clear
## cast leaves the hull out, so it never reads as a blocked hatch.

enum State { STOWED, DEPLOYING, DOWN, STOWING }

## What an outer hatch needs (need()): a ramp, nothing (you step up), or
## nothing it can have (a hatch in a floor or a ceiling).
const RAMP := &"ramp"
const STEP := &"step"
const UP_OR_DOWN := &"faces up/down"

## The design slope: on flat ground the ramp rests at it, and its length is
## set by it (length_for).
const SLOPE := deg_to_rad(30.0)
## The angles it may rest at on real ground (angle_for). The avatar walks any
## floor up to its floor_max_angle, the engine's 45 degrees: the steepest rest
## is 7 degrees under it.
const LEAST := deg_to_rad(15.0)
const MOST := deg_to_rad(38.0)

## The slab: the doorway and 15 cm each side, 18 cm thick.
const WIDTH := InteriorProps.DOOR_WIDTH + 0.3
const THICKNESS := 0.18
const SLAB_BEVEL := 0.04
## The side rails, on the slab's edges, from RAIL_FROM out from the hinge (clear
## of the hatch frame's posts) to RAIL_SHORT short of the tip.
const RAIL_HEIGHT := 0.12
const RAIL_WIDTH := 0.1
const RAIL_FROM := 0.25
const RAIL_SHORT := 0.12
## The raised tread strips across the slab, between the rails: shape, not
## texture. Four on a ramp at least TREADS_FOUR long, three on a shorter one.
const TREAD_HEIGHT := 0.03
const TREAD_DEPTH := 0.14
const TREADS_FOUR := 3.2
## The foot pad under the tip: level with the hull whatever the ramp's angle,
## its top PAD_TOP over the ground the tip rests on.
const PAD_SIZE := Vector3(WIDTH + 0.14, 0.08, 0.44)
const PAD_TOP := 0.05
const PAD_OUT := 0.07
## The hinge housing at the sill: a barrel along the hinge and a knuckle at
## each end, beside the slab.
const BARREL_RADIUS := 0.09
const KNUCKLE := Vector3(0.14, 0.26, 0.26)

## The travel: out of the slot under the sill, then down to the angle.
const SLIDE_TIME := 0.5
const SWING_TIME := 1.1
const TRAVEL := SLIDE_TIME + SWING_TIME
## The ground under the tip is looked for from this far over the sill down to
## this far under the keel's plane; found nowhere, it rests at SLOPE and looks
## again every SETTLE_EVERY seconds while down (a save loads before its ground
## streams in).
const PROBE_ABOVE := 0.5
const PROBE_BELOW := 3.0
const SETTLE_EVERY := 0.5
## The hatch's own motor (Synth's hatch_motor), heard as the ramp moves, as the
## airlock's players are.
const SOUND := &"hatch_motor"

var state := State.STOWED
## How far the sill stands over the keel's plane, and the ramp's length from
## the hinge to its tip along the top surface.
var sill_height := 0.0
var length := 0.0
## The angle it comes down to, below the hull's level: SLOPE until the ground
## says otherwise (settle()).
var angle := SLOPE
## On the hull body: enabled only while fully down.
var collider: CollisionShape3D

## Seconds into the travel: 0 stowed, TRAVEL down.
var _t := 0.0
var _swing: Node3D
var _foot: Node3D
var _housing: Node3D
var _motor: AudioStreamPlayer3D
## True while down with no ground found under the tip.
var _unsettled := false
var _settle_in := 0.0

## The ramp's length for a sill `sill_height` metres over the keel's plane:
## its tip on the plane at the design slope.
static func length_for(sill_height_m: float) -> float:
	return sill_height_m / sin(SLOPE)

## The angle (radians, below level) that rests a ramp `ramp_length` long,
## hinged `sill_height_m` over the keel's plane, on ground `ground_drop` metres
## below that plane under its tip (negative: above it), clamped to LEAST..MOST.
## Pure.
static func angle_for(sill_height_m: float, ramp_length: float, ground_drop: float) -> float:
	var fall := clampf((sill_height_m + ground_drop) / maxf(ramp_length, 0.001), -1.0, 1.0)
	return clampf(asin(fall), LEAST, MOST)

## What an outer hatch facing `normal` (in the hull's frame) with its sill
## `sill_height_m` over the keel's plane needs. Pure.
static func need(normal: Vector3, sill_height_m: float) -> StringName:
	if absf(normal.normalized().y) > 0.01:
		return UP_OR_DOWN
	return RAMP if sill_height_m > Airlock.HATCH_STEP else STEP

static func wants_ramp(normal: Vector3, sill_height_m: float) -> bool:
	return need(normal, sill_height_m) == RAMP

## Points through the slab, down at `down_angle`, for a ramp `ramp_length`
## long, in the hinge frame: along its top surface and its underside, at both
## edges and the middle, from 0.25 m out (the hinge itself sits on the hull's
## face). What AirlockAlcove checks against the grid. Pure.
static func sample_points(ramp_length: float, down_angle: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var along := Vector3(0.0, -sin(down_angle), cos(down_angle))
	var under := Vector3(0.0, -cos(down_angle), -sin(down_angle))
	var steps := maxi(ceili((ramp_length - 0.25) / 0.25), 1)
	for i in steps + 1:
		var s := lerpf(0.25, ramp_length, float(i) / steps)
		for x: float in [-WIDTH * 0.5, 0.0, WIDTH * 0.5]:
			for d: float in [0.0, THICKNESS]:
				out.append(Vector3(x, 0.0, 0.0) + along * s + under * d)
	return out

## Builds a stowed ramp under `parent` (which shares `body`'s frame) at
## `hinge`, for a sill `sill_height_m` over the keel's plane, with its collider
## on `body`, disabled.
static func build(parent: Node3D, body: CollisionObject3D, hinge: Transform3D, sill_height_m: float) -> LandingRamp:
	var ramp := LandingRamp.new()
	ramp.name = "LandingRamp"
	ramp.transform = hinge
	ramp.sill_height = sill_height_m
	ramp.length = length_for(sill_height_m)
	parent.add_child(ramp)
	ramp._make(body)
	return ramp

func _make(body: CollisionObject3D) -> void:
	_housing = Node3D.new()
	_housing.name = "Housing"
	add_child(_housing)
	_swing = Node3D.new()
	_swing.name = "Swing"
	add_child(_swing)
	_foot = Node3D.new()
	_foot.name = "Foot"
	_swing.add_child(_foot)
	_draw_slab(_kit(_swing))
	_draw_pad(_kit(_foot))
	_draw_housing(_kit(_housing))
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, THICKNESS, length)
	collider = CollisionShape3D.new()
	collider.name = "LandingRamp"
	collider.shape = shape
	collider.disabled = true
	body.add_child(collider)
	_motor = AudioStreamPlayer3D.new()
	_motor.name = "Motor"
	_motor.bus = AudioBuses.SHIP
	_motor.unit_size = 3.0
	_motor.max_distance = 30.0
	add_child(_motor)
	_apply()

## A kit drawing on the own hull's layer, as the alcove does, in the hull's
## trim material: flat vertex colour.
func _kit(root: Node3D) -> InteriorKit:
	var kit := InteriorKit.new(root)
	kit.layer = ExteriorBuilder.OWN_HULL_LAYER
	kit.light_mask = 1 | ExteriorBuilder.OWN_HULL_LAYER
	kit.materials = {InteriorKit.Batch.SOLID: HullMaterials.trim()}
	return kit

## The slab, its rails and its treads, lying along +z with the top at y = 0.
func _draw_slab(kit: InteriorKit) -> void:
	var solid := InteriorKit.Batch.SOLID
	var plate := InteriorKit.solid(HullPalette.PLATE)
	var trim := InteriorKit.solid(HullPalette.TRIM)
	var tread := InteriorKit.solid(HullPalette.PANEL_LINE)
	kit.bevel_box(solid, InteriorKit.at(Vector3(0.0, -THICKNESS * 0.5, length * 0.5)),
		Vector3(WIDTH, THICKNESS, length), SLAB_BEVEL, plate)
	var rail_length := length - RAIL_FROM - RAIL_SHORT
	for side: float in [-1.0, 1.0]:
		kit.bevel_box(solid, InteriorKit.at(Vector3(side * (WIDTH - RAIL_WIDTH) * 0.5, RAIL_HEIGHT * 0.5 - 0.01,
			RAIL_FROM + rail_length * 0.5)), Vector3(RAIL_WIDTH, RAIL_HEIGHT + 0.02, rail_length), 0.03, trim)
	var count := 4 if length >= TREADS_FOUR else 3
	var across := WIDTH - RAIL_WIDTH * 2.0 - 0.16
	for i in count:
		var z := RAIL_FROM + rail_length * (float(i) + 0.5) / count
		kit.bevel_box(solid, InteriorKit.at(Vector3(0.0, TREAD_HEIGHT * 0.5 - 0.01, z)),
			Vector3(across, TREAD_HEIGHT + 0.02, TREAD_DEPTH), 0.012, tread)
	kit.commit()

## The foot pad, in the foot's level frame: origin where the top surface meets
## the ground at the tip.
func _draw_pad(kit: InteriorKit) -> void:
	kit.bevel_box(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(0.0, PAD_TOP - PAD_SIZE.y * 0.5, PAD_OUT)),
		PAD_SIZE, 0.03, InteriorKit.solid(HullPalette.TRIM))
	kit.commit()

## The hinge housing at the sill: a barrel along the hinge under the slab's
## top, and a knuckle at each end beside the slab.
func _draw_housing(kit: InteriorKit) -> void:
	var solid := InteriorKit.Batch.SOLID
	var trim := InteriorKit.solid(HullPalette.TRIM)
	kit.tube_x(solid, InteriorKit.at(Vector3(0.0, -BARREL_RADIUS - 0.005, BARREL_RADIUS * 0.4)), BARREL_RADIUS,
		WIDTH + KNUCKLE.x, trim)
	for side: float in [-1.0, 1.0]:
		kit.bevel_box(solid, InteriorKit.at(Vector3(side * (WIDTH + KNUCKLE.x) * 0.5, -KNUCKLE.y * 0.5 + 0.03,
			KNUCKLE.z * 0.5 - 0.06)), KNUCKLE, 0.05, trim)
	kit.commit()

# --- down and up -----------------------------------------------------------------

func is_down() -> bool:
	return state == State.DOWN

func is_stowed() -> bool:
	return state == State.STOWED

## How far along its travel it is: 0 stowed, 1 down.
func progress() -> float:
	return _t / TRAVEL

## Down (or up, `down` false), animated or `instant`ly. Asking for where it is
## going already does nothing, unless `instant` finishes the travel now.
func set_down(down: bool, instant := false) -> void:
	if down:
		if state == State.STOWED or state == State.STOWING:
			deploy(instant)
		elif instant and state == State.DEPLOYING:
			_finish_down()
	else:
		if state == State.DOWN or state == State.DEPLOYING:
			stow(instant)
		elif instant and state == State.STOWING:
			_finish_up()

## Comes down: the angle is set from the ground under the tip first (settle()),
## then it slides out and swings down, or is down at once if `instant` (a save
## loaded landed, a hull rebuilt while landed).
func deploy(instant := false) -> void:
	if state == State.STOWED:
		_unsettled = not settle()
		_settle_in = SETTLE_EVERY
	collider.disabled = true
	if instant:
		_finish_down()
		return
	if state == State.STOWED:
		_play()
	state = State.DEPLOYING
	_apply()

## Goes up: the collider is off the moment it starts, and it is hidden once it
## is back in its slot.
func stow(instant := false) -> void:
	collider.disabled = true
	if instant:
		_finish_up()
		return
	if state == State.DOWN:
		_play()
	state = State.STOWING
	_apply()

func _finish_down() -> void:
	_t = TRAVEL
	state = State.DOWN
	_apply()
	collider.disabled = false

func _finish_up() -> void:
	_t = 0.0
	state = State.STOWED
	collider.disabled = true
	_apply()

func _process(delta: float) -> void:
	match state:
		State.DEPLOYING:
			var was := _t
			_t = minf(_t + delta, TRAVEL)
			if was < SLIDE_TIME and _t >= SLIDE_TIME:
				_play()
			if _t >= TRAVEL:
				_finish_down()
			else:
				_apply()
		State.STOWING:
			var was := _t
			_t = maxf(_t - delta, 0.0)
			if was > SLIDE_TIME and _t <= SLIDE_TIME:
				_play()
			if _t <= 0.0:
				_finish_up()
			else:
				_apply()
		State.DOWN:
			if _unsettled:
				_settle_in -= delta
				if _settle_in <= 0.0:
					_settle_in = SETTLE_EVERY
					if settle():
						_unsettled = false
						_apply()

## Rests the tip on the ground (Task 14 ruling 3): a ray down the hull's up,
## from where the tip will be, to the terrain (BodyProxy.LAYER) sets the angle
## (angle_for), and a second ray where that angle puts the tip settles it. True
## if ground was found; with none the angle is SLOPE.
func settle() -> bool:
	angle = SLOPE
	if not is_inside_tree():
		return false
	var space := get_world_3d().direct_space_state
	var frame := global_transform
	var found := false
	for i in 2:
		var reach := length * cos(angle)
		var query := PhysicsRayQueryParameters3D.create(frame * Vector3(0.0, PROBE_ABOVE, reach),
			frame * Vector3(0.0, -(sill_height + PROBE_BELOW), reach), BodyProxy.LAYER)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		var drop := -(frame.affine_inverse() * (hit["position"] as Vector3)).y - sill_height
		angle = angle_for(sill_height, length, drop)
		found = true
	return found

## Where the ramp is along its travel, shown: the slab slid `offset` back into
## its slot and turned `swing` down about the hinge, the foot level, and the
## collider where the slab is once it is down.
func _apply() -> void:
	visible = _t > 0.0
	var slide := smoothstep(0.0, SLIDE_TIME, _t)
	var swing := smoothstep(SLIDE_TIME, TRAVEL, _t) * angle
	_swing.transform = Transform3D(Basis(Vector3.RIGHT, swing), Vector3.ZERO) \
		* InteriorKit.at(Vector3(0.0, 0.0, -length * (1.0 - slide)))
	_foot.transform = Transform3D(Basis(Vector3.RIGHT, -swing), Vector3(0.0, 0.0, length))
	if state == State.DOWN:
		collider.transform = transform * slab_frame()

## The slab's middle, down at its angle, in the hinge frame: where its collider
## goes.
func slab_frame() -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, angle), Vector3.ZERO) \
		* InteriorKit.at(Vector3(0.0, -THICKNESS * 0.5, length * 0.5))

## The middle of the top surface's edge at the hinge, and at the tip, where it
## is now, in the world.
func top_edge() -> Vector3:
	return _swing.global_transform * Vector3.ZERO

func tip() -> Vector3:
	return _swing.global_transform * Vector3(0.0, 0.0, length)

func _play() -> void:
	var s := Synth.sound(SOUND)
	if s == null or not is_inside_tree():
		return
	_motor.stream = s
	_motor.play()
