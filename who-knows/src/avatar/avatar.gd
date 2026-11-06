class_name Avatar
extends CharacterBody3D

## Walks in interior space. Interior geometry never moves, so this is an
## ordinary character controller. All felt motion from the ship arrives
## through `external_accel`, written by MotionCoupling (Task 6).
##
## Three modes (docs/superpowers/specs/2026-09-24-airlock-design.md §7.4, §8;
## docs/superpowers/specs/2026-11-03-desert-world-design.md §5.5): PLATING
## aboard -- walking, plating gravity, the ship's shoves -- SUIT on a
## spacewalk, in the real world under the scene's Outside root, floating on
## suit thrusters (Suit), and FIELD on foot on a world, out there too, walking
## and jumping in the world's gravity with up away from its centre
## (docs/superpowers/specs/2026-09-23-planetfall-design.md §11), the suit's
## thrusters off. An airlock's threshold switches between them with
## enter_suit(), enter_field() and enter_plating(); nothing else does. FIELD is
## only reached by stepping out of a landed ship, so a spacewalk never crosses
## into it. SUIT and FIELD are both outside (is_outside()).
##
## Its hands (docs/superpowers/specs/2026-09-23-hands-and-items-design.md §7)
## are a Grasp: take_item and can_take_item are the actor contract every Item
## talks to.

const WALK_SPEED := 4.0
const SPRINT_SPEED := 7.0
const CROUCH_SPEED := 2.0
const ACCEL := 30.0
const MOUSE_SENSITIVITY := 0.0022
const PITCH_LIMIT := deg_to_rad(89.0)
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.0
## How hard walking into a loose thing pushes it, at walking pace
## (hands-and-items spec §7.5).
const PUSH_FORCE := 150.0
## interior_geometry | items | npcs (project.godot 3d_physics layers 2, 6 and 8).
const COLLISION_MASK := 2 | 32 | Npc.LAYER
## Every avatar is in this group, so the things it walks through -- an
## airlock's doorways -- can find it.
const GROUP := &"avatar"
## exterior_hull | terrain | items | asteroids | npcs: on a spacewalk you bump
## along your own hull, off worlds' shells (the system skeleton spec §7.3),
## into rocks (asteroids spec §7.6) and into skitters.
const SUIT_MASK := 1 | BodyProxy.LAYER | 32 | AsteroidBody.LAYER | Npc.LAYER
## You and your suit, kilograms, for bumping into things in space.
const SUIT_MASS := 120.0
const BUMP_BOUNCE := 0.2
const FOOTFALL_EVERY := 0.5
## Meeting a rock slower than this, m/s, jolts nothing.
const JOLT_SPEED := 0.3
## How long the view takes to right itself after floating in tilted.
const RIGHTING_TIME := 0.4
## How long after bumping a rock a save waits (saving spec §5).
const BUMP_CALM := 5.0
## A jump's take-off speed on a world, m/s (Planetfall §11.2): fixed, so the
## height tells you the world's pull -- 2.4 m at 2 m/s², 0.6 m at 8.
const JUMP_SPEED := 3.1
## The suit lamp on your head (Planetfall §11.3): its reach, m, and its
## spot_angle, degrees. Its energy is a first guess, for the renders to tune.
const LAMP_RANGE := 25.0
const LAMP_ANGLE := 35.0
const LAMP_ENERGY := 3.0
## The render layer (bit 4, unnamed in the project) your hands, and what they
## hold, are on outside: the camera sees it, and the sun (flight_test.gd), the
## ship's floods (ShipLights.LIGHT_MASK) and the airlock's lights
## (AirlockAlcove.LIGHT_MASK) light it -- every light outside must, or your
## hands are black in daylight (final review I1). Only the lamp's cull mask
## omits it, so the lamp never blows them out; its HandsFill lights them.
const HANDS_LAYER := 8
## The lamp's dimmer light for the hands, which only they see.
const HANDS_FILL_ENERGY := 0.5
const HANDS_FILL_RANGE := 3.0
## A world's pull weaker than this (m/s², squared) has no direction to take up
## from: up stays as it was (Planetfall §11.1).
const MIN_PULL_SQUARED := 1e-6

## Appended, never inserted: nothing may renumber a mode.
enum Mode { PLATING, SUIT, FIELD }

## Health and damage (docs/superpowers/specs/
## 2026-09-29-health-and-damage-design.md §5.3, §7).
const MAX_HEALTH := 100.0
const HEAL_AFTER := 10.0
const HEAL_RATE := 5.0
## Hurt below this: the view's edge stays warm red.
const LOW_HEALTH := 30.0
## Striking a rock or a creature faster than EVA_HURT_FROM m/s on a spacewalk
## takes EVA_HURT_K hp for every m/s over.
const EVA_HURT_FROM := 4.0
const EVA_HURT_K := 10.0
## Waking after blacking out, and what the ship pays for it.
const WAKE_HEALTH := 50.0
const RESCUE_COST := 50
## The most QE a spacewalk's Limpets take from your suit in all, per second
## (rock creatures spec §6.1): a budget that refills at this rate, up to this.
const SIP_CAP := 1.2
## Close enough to home, on a spacewalk, to wake.
const HOME_REACHED := 3.0
## How far the head rolls when you are hit, radians, easing back over
## JOLT_BACK seconds.
const JOLT := 0.05
const JOLT_BACK := 0.25

signal mode_changed(mode: Mode)
## You took `amount` from the way `from` (a world direction, or zero).
signal hurt(amount: float, from: Vector3)
## You blacked out, and woke (health and damage spec §7.2).
signal downed_changed(is_down: bool)
## What you held as you blacked out, let go where you fell. `outside` when it
## fell on a spacewalk: it is in space now, for the flight scene to adopt.
signal let_fall(item: Item, outside: bool)
## A line for the toast near the reticle: what the hose just swallowed.
signal toast(text: String)

var mode: Mode = Mode.PLATING
## The suit's assist (Z on a spacewalk): holds you still relative to `hull`.
var suit_assist := true
## The ship whose airlock you left, while on a spacewalk.
var hull: RigidBody3D
## True while the suit's thrusters are firing.
var thrusting := false
## Returns where home is -- the airlock you left -- for the suit's HUD.
var beacon_source: Callable
## The other kind of home's airlock (habitat modules spec §5.5): returns
## {at: Vector3, label: String}, or {} when there is none.
var other_beacon_source: Callable
## The suit's quantum cell (quantum energy spec §9): empty at the start,
## charged at the quantum machine's plate, spent by the suit's thrusters.
var suit_cell := SuitCell.new()
## Returns where a dry suit takes the middle of you, in the world (the
## airlock you left: Airlock.home), or a non-finite point for nowhere. With
## nowhere to go, a dry suit holds station beside the ship.
var home_source: Callable

## Local gravity, supplied by Grav Plating. Zero means the cell is unplated.
var grav_strength: float = 9.8

## What pulls where outside (desert world spec §5.1), set by the flight scene.
## Only FIELD asks it: aboard the plating's gravity is all there is, and a
## spacewalk feels no world's pull.
var gravity: WorldGravity
## Away from the world's centre, in FIELD (Planetfall §11.1); +Y otherwise.
var up := Vector3.UP
## The suit lamp (Planetfall §11.3): a spot on your head, L outside, off and
## hidden aboard.
var lamp: SpotLight3D

## Acceleration felt from the hull, in interior-space metres per second squared.
var external_accel: Vector3 = Vector3.ZERO

## What is in your hands.
var grasp: Grasp
## The gloves you see them with.
var hands: Hands
## The ray that finds interactables, when the scene gives the head one.
var interactor: Interactor
## True while the camera is at a computer station (computer mode spec §3.3):
## Esc and a click are the station's, not for letting go of and taking back
## the mouse, and the Interactor rests.
var at_station := false

## Seconds since you last bumped a rock on a spacewalk.
var since_bumped := INF

## QE the Limpets may still take from the suit just now (SIP_CAP).
var _sip_budget := SIP_CAP

## How hurt you are (health and damage spec §7.1).
var health := Health.make(MAX_HEALTH, HEAL_AFTER, HEAL_RATE)
## While blacked out, the blackout's timing; null when awake.
var downed: Downed
## True while you sit at the helm: the ship takes hits then, not you (§7.3).
var seated_source: Callable
## Puts you aboard, somewhere safe, when you wake (§7.2). Given you.
var rescue: Callable
## What waking costs, paid by the ship (§7.2): returns what it took.
var rescue_cost: Callable
var _jolt := 0.0
## A hit on the ship you are in, knocking the camera you see through (hostile
## ships spec §6.1): on the camera, not the head, as seated it hangs from the
## seat's eye. Whether it was shown last frame, to put the camera back once.
var _knock := HitFeel.new()
var _knock_shown := false
var _hurt_sound: AudioStreamPlayer

var _control_enabled: bool = true
var _yaw: float = 0.0
var _pitch: float = 0.0
var _interior_environment: Environment
var _righting_from := Quaternion.IDENTITY
var _righting_t := RIGHTING_TIME
## Where the camera eases from and to while righting, in the head's frame.
var _eye_from := Vector3.ZERO
var _camera_home := Vector3.ZERO

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var _collider: CollisionShape3D = $Collider

## Seconds to the next footfall while sprinting.
var _footfall_in := 0.0
## Space pressed on a world: a jump at the next physics tick, if you stand on
## something then.
var _jump_wanted := false
## True from enter_field to your first step outside, which then starts on
## whatever floor is within a snap under you -- the hatch's sill, a landing
## ramp (desert world Task 14). Crossing a threshold leaves no floor contact of
## its own, and without one the first step out of a hatch onto a ramp was a
## leap off the sill to its foot. Snapped in the physics step, not in
## enter_field.
var _stepping_out := false
## In FIELD, where what you let go of lands once you are aboard again: your
## hands drop onto the ground meanwhile (set_aboard_root).
var _aboard_root: Node3D

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_to_group(GROUP)
	collision_mask = COLLISION_MASK
	interactor = get_node_or_null("Head/Interactor") as Interactor
	grasp = Grasp.new()
	grasp.name = "Grasp"
	add_child(grasp)
	hands = Hands.new()
	camera.add_child(hands)
	grasp.bind(self, head, hands.wield_socket, hands.carry_socket)
	grasp.let_go.connect(func(item: Item) -> void: let_fall.emit(item, true))
	grasp.taken.connect(_on_item_taken)
	grasp.released.connect(_on_item_released)
	hands.bind(grasp, self)
	var sounds := SuitSounds.new()
	sounds.name = "SuitSounds"
	add_child(sounds)
	sounds.bind(self)
	health.emptied.connect(_black_out)
	_hurt_sound = AudioStreamPlayer.new()
	_hurt_sound.name = "HurtSound"
	_hurt_sound.volume_db = -8.0
	add_child(_hurt_sound)
	_make_lamp()

## The suit lamp, off: shining along your view, warm white as the ship's work
## lights, and casting no shadows (Planetfall §11.3: a GTX 960). Going out
## puts it on the world's layers with everything else you carry
## (_set_render_layer): it lights layer 1, as Planetfall asks, and your own
## hull's layer too, as the ship's floods do -- never the interior.
func _make_lamp() -> void:
	lamp = SpotLight3D.new()
	lamp.name = "Lamp"
	lamp.light_color = HullPalette.WORK_LIGHT
	lamp.light_energy = LAMP_ENERGY
	lamp.spot_range = LAMP_RANGE
	lamp.spot_angle = LAMP_ANGLE
	lamp.shadow_enabled = false
	lamp.visible = false
	head.add_child(lamp)
	# The lamp's gentler half for your hands, which are off its mask so it
	# cannot blow them out; a child, so it is on and off with the lamp.
	var fill := SpotLight3D.new()
	fill.name = "HandsFill"
	fill.light_color = HullPalette.WORK_LIGHT
	fill.light_energy = HANDS_FILL_ENERGY
	fill.spot_range = HANDS_FILL_RANGE
	fill.spot_angle = LAMP_ANGLE * 1.5
	fill.shadow_enabled = false
	lamp.add_child(fill)

## Switches the suit lamp. It shines only outside: aboard it is always off.
func set_lamp(on: bool) -> void:
	lamp.visible = on and is_outside()

## Outside the ship: on a spacewalk (SUIT) or on foot on a world (FIELD).
func is_outside() -> bool:
	return mode == Mode.SUIT or mode == Mode.FIELD

## Where what you let go of lands aboard: the items of the home you are in (the
## flight scene's board()). On foot on a world your hands drop onto the ground
## instead, so it is kept for enter_plating to put back.
func set_aboard_root(root: Node3D) -> void:
	if mode == Mode.FIELD:
		_aboard_root = root
	else:
		grasp.world_root = root

## The actor contract Item talks to.
func take_item(item: Item) -> void:
	grasp.take(item)

func can_take_item(item: Item) -> bool:
	return grasp.can_take(item)

## An item with a `swallowed` signal (the hose's nozzle) tells the toast. One
## taken while you are outside goes onto your hands' layer, as one carried out
## does (_go_out), so the lamp never blows it out (final review M6).
func _on_item_taken(item: Item, _from: Transform3D) -> void:
	if is_outside():
		_set_hands_layer(HANDS_LAYER)
	var use := item.use_node
	if use != null and use.has_signal(&"swallowed") and not use.is_connected(&"swallowed", _on_swallowed):
		use.connect(&"swallowed", _on_swallowed)

## Let go of outside in any way (dropped, thrown, stowed, home to its reel), a
## thing leaves your hands' layer for the world's: Item.set_space rebuilds its
## look there, so the head lamp's beam lights it where it lies. Every visual
## part still on HANDS_LAYER (a flare's flame and glow, which set_space does
## not rebuild) goes to the world's layer too (Task 15, N3).
func _on_item_released(item: Item) -> void:
	if is_outside() and is_instance_valid(item):
		item.set_space(true)
		for node in item.find_children("*", "VisualInstance3D", true, false):
			if (node as VisualInstance3D).layers == HANDS_LAYER:
				(node as VisualInstance3D).layers = Item.SPACE_LAYER

func _on_swallowed(label: String, value: int) -> void:
	toast.emit("+%d QE · %s" % [value, label])

## Whether you fit standing at `pose` (feet at its origin, upright): nothing
## in your body's way, and a floor underfoot.
func can_stand_at(pose: Transform3D) -> bool:
	var space := get_world_3d().direct_space_state
	var pose_up := pose.basis.y.normalized()
	var body := PhysicsShapeQueryParameters3D.new()
	body.shape = _collider.shape
	# Lifted a touch, so the floor you would stand on isn't in the way.
	body.transform = pose.translated(pose_up * 0.02) * _collider.transform
	body.collision_mask = COLLISION_MASK
	body.exclude = [get_rid()]
	if not space.intersect_shape(body, 1).is_empty():
		return false
	var ray := PhysicsRayQueryParameters3D.create(pose.origin + pose_up * 0.3, pose.origin - pose_up * 0.3,
		COLLISION_MASK, [get_rid()])
	return not space.intersect_ray(ray).is_empty()

## Why a save must wait (saving spec §5), or "": the view still righting
## after coming aboard, a dry suit's emergency cell bringing you home, a rock
## bumped less than BUMP_CALM ago, or your hands busy.
func busy() -> String:
	if downed != null:
		return "blacked out"
	if _righting_t < RIGHTING_TIME:
		return "coming aboard"
	if mode == Mode.SUIT and suit_cell.is_dry():
		return "suit dry, coming home"
	if since_bumped < BUMP_CALM:
		return "bumped a rock"
	return grasp.busy() if grasp != null else ""

## How far the head is pitched, radians: up is positive.
func head_pitch() -> float:
	return _pitch

func set_head_pitch(pitch: float) -> void:
	_pitch = clampf(pitch, -PITCH_LIMIT, PITCH_LIMIT)
	head.rotation.x = _pitch

## Stands you at `pose` (upright), turned its way, at rest.
func place(pose: Transform3D) -> void:
	global_transform = pose
	_yaw = rotation.y
	velocity = Vector3.ZERO

## Moves you, standing aboard, into another ship's `interior` at `pose` (many
## ships spec §4.3): F8's hop to a helm. Not for a spacewalk: that is
## enter_plating's.
func move_aboard(interior: Node3D, pose: Transform3D) -> void:
	_move_to(interior)
	place(pose)

func set_control_enabled(enabled: bool) -> void:
	_control_enabled = enabled
	grasp.set_enabled(enabled)
	if not enabled:
		velocity = Vector3.ZERO

func set_at_station(on: bool) -> void:
	at_station = on
	if interactor != null:
		interactor.suspended = on

func _unhandled_input(event: InputEvent) -> void:
	if at_station:
		return
	# Mouse capture is released and regained regardless of who currently has
	# control. This node captured the cursor, so it owns letting go of it --
	# and being unable to release it while seated would trap the player.
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# The click only brings the mouse back. Nothing else may act on it --
		# it must not also fire whatever is in your hand.
		get_viewport().set_input_as_handled()
		return

	if not _control_enabled:
		return
	if mode == Mode.SUIT and event.is_action_pressed(&"toggle_assist"):
		suit_assist = not suit_assist
	# Space jumps only on a world (Planetfall §11.2): seated it is boost, which
	# only the helm reads.
	if mode == Mode.FIELD and event.is_action_pressed(&"jump"):
		_jump_wanted = true
	# L is the helm's floods while you sit; outside it is your lamp.
	if is_outside() and event.is_action_pressed(&"lights_flood"):
		set_lamp(not lamp.visible)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.relative)

## Turns you by a mouse move of `relative` pixels: the head pitches, and the
## body turns about your own up on a spacewalk (there is no other), about the
## world's on foot on a world (Planetfall §11.1), and about +Y aboard. Split
## from _unhandled_input so tests can drive it: a headless run cannot capture
## the mouse.
func look(relative: Vector2) -> void:
	_pitch = clampf(_pitch - relative.y * MOUSE_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
	head.rotation.x = _pitch
	var turn := -relative.x * MOUSE_SENSITIVITY
	match mode:
		Mode.SUIT:
			rotate_object_local(Vector3.UP, turn)
		Mode.FIELD:
			global_basis = Basis(up, turn) * global_basis
		_:
			_yaw += turn
			rotation.y = _yaw

func _physics_process(delta: float) -> void:
	refill_sip(delta)
	if downed != null:
		_downed_physics(delta)
		return
	if not _control_enabled:
		# Parked — seated, or handed off to something else. Integrate
		# nothing: otherwise the body keeps accumulating gravity and
		# external_accel and slides off the seat while the pilot flies.
		return
	if mode == Mode.SUIT:
		_suit_physics(delta)
		return
	if mode == Mode.FIELD:
		_field_physics(delta)
		return

	# Gravity plus whatever the hull is doing to us. Both are just
	# accelerations; the avatar cannot tell them apart, which is the point.
	velocity += (Vector3.DOWN * grav_strength + external_accel) * delta

	var crouching := Input.is_action_pressed("crouch")
	_apply_height(CROUCH_HEIGHT if crouching else STAND_HEIGHT)

	var speed := CROUCH_SPEED if crouching else (
		SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	)
	var input_2d := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := (transform.basis * Vector3(input_2d.x, 0.0, input_2d.y)).normalized()
	var target := wish * speed
	velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)

	var pushing := velocity
	move_and_slide()
	_push_loose_things(pushing, delta)
	_footfalls(speed == SPRINT_SPEED and Vector2(velocity.x, velocity.z).length() > WALK_SPEED * 0.5, delta)

func _process(delta: float) -> void:
	tick_righting(delta)
	tick_knock(delta)
	since_bumped += delta
	health.tick(delta)
	_jolt = move_toward(_jolt, 0.0, JOLT / JOLT_BACK * delta)
	head.rotation.z = _jolt
	if downed != null:
		# Only a spacewalk waits for the emergency cell to bring you home.
		downed.tick(delta, mode != Mode.SUIT or _home_reached())

# --- being hurt (health and damage spec §5.3, §7) ------------------------------

## Gives the Limpets' sip budget back `delta` seconds of SIP_CAP. Called every
## physics tick; tests call it directly.
func refill_sip(delta: float) -> void:
	_sip_budget = minf(_sip_budget + SIP_CAP * delta, SIP_CAP)

## A hit on you: a bolt, a bite. Seated, the ship takes it; blacked out,
## nothing more happens to you.
func receive_hit(hit: Hit) -> void:
	if is_seated() or downed != null:
		return
	velocity += hit.impulse / SUIT_MASS
	take_damage(hit.damage, hit.direction)
	if hit.drain > 0.0 and is_outside():
		# A Limpet's sip: the suit's cell, within the budget all of them share.
		hit.drained = suit_cell.drain(minf(hit.drain, _sip_budget))
		_sip_budget -= hit.drained

## Takes `amount` hp, from the way `from` points (world, or zero).
func take_damage(amount: float, from := Vector3.ZERO) -> float:
	if downed != null or amount <= 0.0:
		return 0.0
	var taken := health.take(amount)
	if taken > 0.0:
		# A roll away from where it came from, and a thump you feel.
		var side := (global_basis.inverse() * from).x if from != Vector3.ZERO else 1.0
		_jolt = -JOLT * signf(side if side != 0.0 else 1.0)
		var thump := Synth.sound(&"hull_thump")
		if thump != null and _hurt_sound != null and _hurt_sound.is_inside_tree():
			_hurt_sound.stream = thump
			_hurt_sound.play()
		hurt.emit(taken, from)
	return taken

## A hit on the ship you are in (Ship.felt_hit): the view knocked away from
## the world direction `from` by HitFeel's rule, settling. Only the camera
## moves: the stick, the aim and your body are untouched.
func knock(strength: float, from: Vector3) -> void:
	_knock.knock(strength, camera.global_basis.inverse() * from)
	_show_knock()

## Settles a knock by `delta` seconds. Called every frame; tests call it
## directly.
func tick_knock(delta: float) -> void:
	_knock.settle(delta)
	_show_knock()

## The camera's roll from a knock, radians.
func view_roll() -> float:
	return camera.rotation.z

func _show_knock() -> void:
	# Righting from a spacewalk owns the camera's turn for its moment.
	if (not _knock.live() and not _knock_shown) or _righting_t < RIGHTING_TIME:
		return
	camera.rotation.z = _knock.roll
	camera.h_offset = _knock.shift.x
	camera.v_offset = _knock.shift.y
	_knock_shown = _knock.live()

func is_seated() -> bool:
	return seated_source.is_valid() and bool(seated_source.call())

func is_low() -> bool:
	return health.current < LOW_HEALTH

## Health emptied: let go of what you hold, lose control, and fade out.
func _black_out() -> void:
	if downed != null:
		return
	_jump_wanted = false
	var outside := is_outside()
	var into: Node3D = get_parent() as Node3D if outside else grasp.world_root
	var item := grasp.let_fall(into)
	if item != null:
		if outside:
			item.set_space(true)
		let_fall.emit(item, outside)
	set_control_enabled(false)
	downed = Downed.new()
	downed.stepped.connect(_on_downed_step)
	downed_changed.emit(true)

func _on_downed_step(step: Downed.Step) -> void:
	match step:
		Downed.Step.WAKING:
			if rescue.is_valid():
				rescue.call(self)
			health.current = WAKE_HEALTH
			health.since_hurt = 0.0
			if rescue_cost.is_valid():
				rescue_cost.call(RESCUE_COST)
		Downed.Step.DONE:
			downed = null
			set_control_enabled(true)
			downed_changed.emit(false)

## Blacked out: aboard you lie where you fell; on a spacewalk, the suit's
## emergency cell brings you home, as when it runs dry (quantum energy spec
## §9); on a world there is no trip home (desert world spec §5.5): you fall
## and lie where you fell.
func _downed_physics(delta: float) -> void:
	if mode == Mode.FIELD:
		_field_move(_stand_on_world(), Vector3.ZERO, 0.0, delta)
		return
	if mode != Mode.SUIT:
		velocity = Vector3.ZERO
		return
	var v_ref := hull.linear_velocity if is_instance_valid(hull) else Vector3.ZERO
	velocity = Suit.home_step(velocity, v_ref, _to_home(), delta)
	var before := velocity
	move_and_slide()
	velocity = bump(before, velocity, _slide_hits())

func _home_reached() -> bool:
	var to_home := _to_home()
	return to_home == Vector3.ZERO or to_home.length() < HOME_REACHED

func _slide_hits() -> Array:
	var hits := []
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		hits.append([hit.get_collider(), hit.get_normal(), hit.get_position()])
	return hits

## Sprinting aboard is loud enough for NPCs to hear (NPC foundation spec
## §6.1): a footfall every FOOTFALL_EVERY seconds.
func _footfalls(sprinting: bool, delta: float) -> void:
	if not sprinting:
		_footfall_in = 0.0
		return
	_footfall_in -= delta
	if _footfall_in <= 0.0:
		_footfall_in = FOOTFALL_EVERY
		StimulusBus.send(self, Stimulus.make(Stimulus.SOUND, global_position, 0.4, 6.0, self))

## Steps off the ship onto a spacewalk, at `pose` in the world, moving at
## `velocity`, with `ship_hull` as the ship you left.
func enter_suit(outside: Node3D, pose: Transform3D, start_velocity: Vector3, ship_hull: RigidBody3D) -> void:
	_go_out(outside, pose, start_velocity, ship_hull)
	mode = Mode.SUIT
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	grasp.suspended = true
	mode_changed.emit(mode)

## Steps out of a landed ship onto a world (desert world spec §5.5), as
## enter_suit, but on your feet: walking in the world's gravity with up away
## from its centre (from `gravity` at `pose`, or `pose`'s own up with no pull
## to read), and hands that work as aboard -- what you let go of lands outside,
## and the root it landed in aboard is kept for enter_plating to put back.
## Your first step out starts on whatever is within a snap under you
## (_stepping_out).
func enter_field(outside: Node3D, pose: Transform3D, start_velocity: Vector3, ship_hull: RigidBody3D) -> void:
	if mode != Mode.FIELD:
		_aboard_root = grasp.world_root
	_go_out(outside, pose, start_velocity, ship_hull)
	mode = Mode.FIELD
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	var g := gravity.at(pose.origin) if gravity != null else Vector3.ZERO
	up = -g.normalized() if g.length_squared() > MIN_PULL_SQUARED else pose.basis.y.normalized()
	up_direction = up
	_stepping_out = true
	_jump_wanted = false
	grasp.world_root = outside
	grasp.suspended = false
	mode_changed.emit(mode)

## What every way out shares: into the world under `outside` at `pose`, in the
## floating origin's group and anchoring the ground and rocks round you, on the
## world's layers and look, bumping the hull, the ground, rocks, items and
## creatures, with `ship_hull` as the ship you left.
func _go_out(outside: Node3D, pose: Transform3D, start_velocity: Vector3, ship_hull: RigidBody3D) -> void:
	if mode == Mode.PLATING:
		_interior_environment = camera.environment
	_move_to(outside)
	add_to_group(Universe.EXTERIOR_SPACE)
	add_to_group(AsteroidStream.SPACE_ANCHOR)
	set_meta(AsteroidStream.ANCHOR_RADIUS, 1.0)
	global_transform = pose
	hull = ship_hull
	thrusting = false
	_apply_height(STAND_HEIGHT)
	collision_mask = SUIT_MASK
	velocity = start_velocity
	external_accel = Vector3.ZERO
	camera.environment = null
	if interactor != null:
		interactor.set_mask(Interactor.SUIT_MASK)
	# A thing let go against a hull, the ground or a rock lands on your side.
	grasp.ray_mask = Grasp.OUTSIDE_RAY_MASK
	# What you hold comes out with you, drawn for outside.
	if grasp.item != null:
		grasp.item.set_space(true)
	_set_render_layer(1, 1 | ExteriorBuilder.OWN_HULL_LAYER)
	# Your hands sit a hand's breadth from the lamp: on HANDS_LAYER, off its mask,
	# they take the sun, the floods and the airlock's lights (all of whose masks
	# include that layer) but are never blown out by the lamp.
	_set_hands_layer(HANDS_LAYER)
	(lamp.get_node("HandsFill") as Light3D).light_cull_mask = HANDS_LAYER
	_righting_t = RIGHTING_TIME
	camera.quaternion = Quaternion.IDENTITY

## Comes back aboard at `pose` (upright) in interior space, head pitched
## `pitch`, moving at `start_velocity`, the view starting `righting` away from
## upright (Threshold.upright) and -- given `eye_from`, where your eye was in
## the world -- from exactly there, easing back to your head. Whatever FIELD
## changed goes back: where your hands drop things, up, and the lamp, off.
func enter_plating(interior: Node3D, pose: Transform3D, pitch: float, start_velocity: Vector3,
		righting: Quaternion, eye_from := Vector3.INF) -> void:
	_let_go_tool()
	if mode == Mode.FIELD:
		grasp.world_root = _aboard_root
	_aboard_root = null
	_camera_home = camera.position
	_move_to(interior)
	remove_from_group(Universe.EXTERIOR_SPACE)
	remove_from_group(AsteroidStream.SPACE_ANCHOR)
	global_transform = pose
	mode = Mode.PLATING
	hull = null
	thrusting = false
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	up = Vector3.UP
	up_direction = Vector3.UP
	_jump_wanted = false
	set_lamp(false)
	collision_mask = COLLISION_MASK
	velocity = start_velocity
	_yaw = rotation.y
	_pitch = pitch
	head.rotation.x = pitch
	camera.environment = _interior_environment
	if interactor != null:
		interactor.set_mask(Interactor.MASK)
	grasp.ray_mask = Grasp.RAY_MASK
	grasp.suspended = false
	if grasp.item != null:
		grasp.item.set_space(false)
	_set_render_layer(InteriorKit.LAYER, InteriorKit.LAYER)
	_righting_from = righting
	_righting_t = 0.0
	camera.quaternion = righting
	_eye_from = _camera_home
	if eye_from.is_finite():
		_eye_from = head.global_transform.affine_inverse() * eye_from
	camera.position = _eye_from
	mode_changed.emit(mode)

## The suit's HUD (airlock spec §8.3): the same duck-typed contract a ship's
## flight computer answers, so the HUD needs no idea what a suit is. Speed is
## relative to your own ship, and the beacon is the way home. Its energy is
## the suit's cell (quantum energy spec §12): whole QE of 100, floored so it
## never shows more than is there, with no low-power line.
func build_telemetry() -> VehicleTelemetry:
	var t := VehicleTelemetry.from_state(head.global_basis, global_position,
		velocity - _hull_velocity_at(global_position), Vector3.ZERO, suit_assist, false, Suit.ASSIST_CAP)
	if beacon_source.is_valid():
		t.has_beacon = true
		t.beacon = beacon_source.call()
	if other_beacon_source.is_valid():
		var other: Dictionary = other_beacon_source.call()
		if not other.is_empty():
			t.has_other_beacon = true
			t.other_beacon = other["at"]
			t.other_label = other["label"]
	t.has_energy = true
	t.energy = floori(suit_cell.charge)
	t.energy_capacity = int(SuitCell.CAPACITY)
	t.energy_line = 0
	t.energy_label = &"SUIT"
	# The dry-suit trip home is a spacewalk's: on foot the thrusters are off and
	# nothing returns you.
	t.energy_state = suit_cell.level() if mode != Mode.FIELD else &"ok"
	if grasp != null and grasp.item != null and grasp.item.use_node != null:
		t.tool_text = grasp.item.use_node.tool_text()
	if mode == Mode.FIELD:
		# On foot nothing draws on the suit's cell or needs it, so its charge is
		# not shown -- "SUIT 0%" on a world only alarms (final review, T13/T14).
		# The panel stays for a tool's text in hand, with no store beside it; the
		# charge is back on the next spacewalk.
		t.energy_label = &""
		t.has_energy = t.tool_text != ""
	return t

## Eases the view upright after floating in (enter_plating).
func tick_righting(delta: float) -> void:
	if _righting_t >= RIGHTING_TIME:
		return
	_righting_t = minf(_righting_t + delta, RIGHTING_TIME)
	var k := smoothstep(0.0, RIGHTING_TIME, _righting_t)
	camera.quaternion = _righting_from.slerp(Quaternion.IDENTITY, k)
	camera.position = _eye_from.lerp(_camera_home, k)

## One suit step with thrust `input` (view axes: +x right, +y up, +z back).
## Called every physics frame on a spacewalk; tests call it directly.
##
## The suit's cell pays for the Δv its thrusters deliver, assist included
## (quantum energy spec §9). Whatever else pulls on you after this step --
## the hose's tether at full length (§11.3) -- is not the suit's doing, and
## costs the cell nothing. Dry, the thrusters are off and the emergency cell
## steers you home instead, free.
func suit_step(delta: float, input: Vector3) -> void:
	var v_ref := _hull_velocity_at(global_position)
	if suit_cell.is_dry():
		_let_go_tool()
		velocity = Suit.home_step(velocity, v_ref, _to_home(), delta)
		thrusting = false
		return
	var cargo := grasp.item.definition.mass_kg if grasp.item != null and grasp.item.definition.eva_cargo else 0.0
	var v := Suit.step(velocity, v_ref, input, head.global_basis, suit_assist, delta,
		Suit.cargo_accel(SUIT_MASS, cargo))
	suit_cell.spend_dv((v - velocity).length())
	velocity = v
	thrusting = input.length() > 0.01
	_tether(delta)

## An EVA tool in hand goes home: the suit ran dry, or you are coming aboard.
## On a world your hands work, so it is simply let go: home to its reel, or,
## with nowhere to go, a stray, as on a spacewalk.
func _let_go_tool() -> void:
	if grasp == null or grasp.item == null or not grasp.item.definition.eva_tool:
		return
	if mode == Mode.FIELD:
		grasp.drop()
	else:
		grasp.let_go_outside()

## The held tool's tether (the hose's line): outward velocity removed at its
## length and a pull back, after the suit's own step, so it costs the cell
## nothing.
func _tether(delta: float) -> void:
	if grasp.item == null or grasp.item.use_node == null:
		return
	var t := grasp.item.use_node.tether()
	if t.is_empty():
		return
	# The reel rides the hull, so the line holds you in your ship's frame, not
	# the world's: a ship drifting at 5 m/s must not be braked against space.
	var v_ref := _hull_velocity_at(global_position)
	velocity = v_ref + Tether.constrain(_collider.global_position, velocity - v_ref, t["anchor"], t["length"], delta)

## From the middle of you to where a dry suit takes you, or zero -- hold
## station -- with nowhere to go.
func _to_home() -> Vector3:
	var home: Vector3 = home_source.call() if home_source.is_valid() else Vector3.INF
	if not home.is_finite():
		return Vector3.ZERO
	return home - _collider.global_position

func _suit_physics(delta: float) -> void:
	var input := Vector3(
		Input.get_axis(&"move_left", &"move_right"),
		Input.get_axis(&"crouch", &"sprint"),
		Input.get_axis(&"move_forward", &"move_back"),
	)
	suit_step(delta, input)
	var roll := Input.get_axis(&"roll_left", &"roll_right")
	if roll != 0.0:
		# Roll about your line of sight, pivoting on your head.
		var eye := head.global_position
		global_basis = Basis(-head.global_basis.z, -roll * Suit.ROLL_RATE * delta) * global_basis
		global_position += eye - head.global_position
	var before := velocity
	move_and_slide()
	_bump_in_space(before)

## On foot on a world (Planetfall §11.1, §11.2): walking as aboard -- crouch,
## sprint, footfalls -- but along the ground under the world's up, in its
## pull, with a jump. The suit's thrusters never run (desert world spec §5.5).
func _field_physics(delta: float) -> void:
	var g := _stand_on_world()
	var crouching := Input.is_action_pressed(&"crouch")
	_apply_height(CROUCH_HEIGHT if crouching else STAND_HEIGHT)
	var speed := CROUCH_SPEED if crouching else (
		SPRINT_SPEED if Input.is_action_pressed(&"sprint") else WALK_SPEED
	)
	var input_2d := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var wish := (global_basis * Vector3(input_2d.x, 0.0, input_2d.y)).normalized()
	_field_move(g, wish, speed, delta)
	var along_ground := velocity - up * velocity.dot(up)
	_footfalls(speed == SPRINT_SPEED and along_ground.length() > WALK_SPEED * 0.5, delta)

## The world's pull where you are, having turned up away from its centre and
## stood your body on it, with floor detection following (Planetfall §11.1).
## With no pull to read -- no gravity given, or none here -- up stays.
func _stand_on_world() -> Vector3:
	var g := gravity.at(global_position) if gravity != null else Vector3.ZERO
	if g.length_squared() > MIN_PULL_SQUARED:
		up = -g.normalized()
	global_basis = field_basis(global_basis, up)
	up_direction = up
	return g

## One move on the ground in pull `g`: toward `wish` (world, unit or zero) at
## `speed`, a jump if Space asked for one and you stand on something, the held
## tool's tether, and the slide, nudging loose things.
func _field_move(g: Vector3, wish: Vector3, speed: float, delta: float) -> void:
	if _stepping_out:
		_stepping_out = false
		apply_floor_snap()
	velocity = field_velocity(velocity, up, wish, speed, ACCEL, g, delta)
	if gravity != null:
		velocity += gravity.drag_at(global_position, velocity) * delta
	if _jump_wanted and is_on_floor():
		velocity += up * JUMP_SPEED
	_jump_wanted = false
	_tether(delta)
	var pushing := velocity
	move_and_slide()
	_push_loose_things(pushing, delta)

## `b` stood on `new_up`, keeping its heading (Planetfall §11.1): its forward
## laid onto the new ground, so a walk round the curve holds its line and the
## view never twists. For a tilt along forward this is exactly the shortest arc
## from b.y to new_up; across it, it differs from the shortest arc by a twist
## of the order of the tilt squared -- nothing, at a tick's tilt -- and is the
## turn that keeps forward's heading on the ground. Forward standing along
## new_up has no heading to keep: then it is the shortest arc.
static func field_basis(b: Basis, new_up: Vector3) -> Basis:
	var y := new_up.normalized()
	var old_y := b.y.normalized()
	if old_y.is_equal_approx(y):
		return b
	var forward := -b.z
	var on_ground := forward - y * forward.dot(y)
	if on_ground.length_squared() > 1e-8:
		var z := -on_ground.normalized()
		return Basis(y.cross(z), y, z)
	var axis := old_y.cross(y)
	if axis.length_squared() < 1e-12:
		axis = b.x
	axis = axis.normalized()
	return (Basis(axis, old_y.signed_angle_to(y, axis)) * b).orthonormalized()

## Velocity `v` after one step of `delta` on a world: the pull `g` added, then
## the part along the ground (across `up`) eased toward `wish`, laid on the
## ground, times `speed`, by at most `accel` × `delta`. The part along `up` --
## a fall, a jump -- is the pull's alone.
static func field_velocity(v: Vector3, up_dir: Vector3, wish: Vector3, speed: float, accel: float, g: Vector3,
		delta: float) -> Vector3:
	var pulled := v + g * delta
	var along_up := up_dir * pulled.dot(up_dir)
	var target := (wish - up_dir * wish.dot(up_dir)) * speed
	return along_up + (pulled - along_up).move_toward(target, accel * delta)

## Two bodies in space (asteroids spec §7.6): bumping a rock shares momentum
## along the contact, with a little bounce. A 1 m rock drifts off slowly; a
## giant stops you dead.
func _bump_in_space(before: Vector3) -> void:
	var hits := []
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		hits.append([hit.get_collider(), hit.get_normal(), hit.get_position()])
	_jolt_rocks(before, hits)
	velocity = bump(before, velocity, hits)

## Landing on or bumping into a rock jolts it: a vibration through the stone
## that anything living on it feels (NPC foundation spec §6.1).
func _jolt_rocks(before: Vector3, hits: Array) -> void:
	var jolted := {}
	for h in hits:
		var rock: AsteroidRock = null
		if h[0] is AsteroidDetail:
			rock = (h[0] as AsteroidDetail).rock
		elif h[0] is AsteroidBody:
			rock = (h[0] as AsteroidBody).rock
		if rock == null or jolted.has(rock):
			continue
		jolted[rock] = true
		var closing := -before.dot(h[1])
		if closing > JOLT_SPEED:
			StimulusBus.send(self, Stimulus.make(Stimulus.VIBRATION, h[2], clampf(closing / 3.0, 0.0, 1.0),
				30.0, self, RockHerds.site_of(rock)))

## Your velocity after bumping the rocks in `hits` ([collider, normal,
## point]), moving at `before` into them and `slid` after the slide. Sliding
## along a rock can touch it twice in one step: that is still one bump.
func bump(before: Vector3, slid: Vector3, hits: Array) -> Vector3:
	var v := slid
	var bumped := {}
	for h in hits:
		var body := h[0] as AsteroidBody
		# A skitter is bumped the same way (NPC foundation spec §12.1): it is
		# kinematic, so it is told the impulse instead of being given it.
		var npc := h[0] as Npc
		if (body == null and npc == null) or bumped.has(h[0]):
			continue
		bumped[h[0]] = true
		var n: Vector3 = h[1]
		var other_v := npc.velocity if npc != null else Vector3.ZERO
		var other_mass := npc.species.mass if npc != null else 0.0
		var at := Vector3.ZERO
		if body != null:
			at = h[2] - body.global_position
			other_v = body.linear_velocity + body.angular_velocity.cross(at)
			other_mass = body.mass
		var closing := -(before - other_v).dot(n)
		if closing <= 0.0:
			continue
		since_bumped = 0.0
		if closing > EVA_HURT_FROM:
			take_damage(EVA_HURT_K * (closing - EVA_HURT_FROM), -n)
		var m := SUIT_MASS * other_mass / (SUIT_MASS + other_mass)
		var j := (1.0 + BUMP_BOUNCE) * m * closing
		if body != null:
			body.apply_impulse(-n * j, at)
		else:
			npc.shove(-n * j)
		v += n * (before.dot(n) + j / SUIT_MASS - v.dot(n))
	return v

## Your own ship's velocity where `p` is, spin included.
func _hull_velocity_at(p: Vector3) -> Vector3:
	if not is_instance_valid(hull):
		return Vector3.ZERO
	var com_local := hull.center_of_mass if hull.center_of_mass_mode == RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM \
		else Vector3.ZERO
	return Threshold.point_velocity(hull.linear_velocity, hull.angular_velocity, hull.global_transform * com_local, p)

func _move_to(parent: Node3D) -> void:
	var old := get_parent()
	if old == parent:
		return
	var was_current := camera.current
	old.remove_child(self)
	parent.add_child(self)
	if was_current:
		camera.make_current()

## Puts your hands and whatever is in them on render layer `layer`, and their
## lights on `light_mask`: the interior's aboard, the world's outside.
func _set_render_layer(layer: int, light_mask: int) -> void:
	for node in find_children("*", "", true, false):
		if node is VisualInstance3D:
			node.layers = layer
		if node is Light3D:
			node.light_cull_mask = light_mask

## Moves your hands, and what is in them, to render layer `layer`, leaving the
## rest of you (and the lamp) where `_set_render_layer` put them.
func _set_hands_layer(layer: int) -> void:
	for node in hands.find_children("*", "", true, false):
		if node is VisualInstance3D:
			node.layers = layer

## Nudges the loose things you walk into (hands-and-items spec §7.5), instead
## of stopping dead against them as if they were walls.
func _push_loose_things(pushing: Vector3, delta: float) -> void:
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var body := hit.get_collider() as RigidBody3D
		if body == null or body.freeze:
			continue
		# Along the floor: across up_direction, which is +Y aboard and the
		# world's up on a world.
		var into := -hit.get_normal()
		into -= up_direction * into.dot(up_direction)
		if into.length_squared() < 0.0001:
			continue
		into = into.normalized()
		var speed := pushing.dot(into)
		if speed <= 0.0:
			continue
		var force := PUSH_FORCE * clampf(speed / WALK_SPEED, 0.0, 1.0)
		body.apply_impulse(into * force * delta, hit.get_position() - body.global_position)

func _apply_height(height: float) -> void:
	var capsule := _collider.shape as CapsuleShape3D
	capsule.height = height
	_collider.position.y = height * 0.5
	head.position.y = height - 0.2
