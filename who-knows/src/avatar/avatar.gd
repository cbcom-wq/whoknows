class_name Avatar
extends CharacterBody3D

## Walks in interior space. Interior geometry never moves, so this is an
## ordinary character controller. All felt motion from the ship arrives
## through `external_accel`, written by MotionCoupling (Task 6).
##
## Two modes (docs/superpowers/specs/2026-09-24-airlock-design.md §7.4, §8):
## PLATING aboard -- walking, plating gravity, the ship's shoves -- and SUIT on
## a spacewalk, in the real world under the scene's Outside root, floating on
## suit thrusters (Suit). An airlock's threshold switches between them with
## enter_suit() and enter_plating(); nothing else does.
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
## interior_geometry | items (project.godot 3d_physics layers 2 and 6).
const COLLISION_MASK := 2 | 32
## Every avatar is in this group, so the things it walks through -- an
## airlock's doorways -- can find it.
const GROUP := &"avatar"
## exterior_hull | items | asteroids: on a spacewalk you bump along your own
## hull, and into rocks (asteroids spec §7.6).
const SUIT_MASK := 1 | 32 | AsteroidBody.LAYER
## You and your suit, kilograms, for bumping into things in space.
const SUIT_MASS := 120.0
const BUMP_BOUNCE := 0.2
## How long the view takes to right itself after floating in tilted.
const RIGHTING_TIME := 0.4

enum Mode { PLATING, SUIT }

signal mode_changed(mode: Mode)

var mode: Mode = Mode.PLATING
## The suit's assist (Z on a spacewalk): holds you still relative to `hull`.
var suit_assist := true
## The ship whose airlock you left, while on a spacewalk.
var hull: RigidBody3D
## True while the suit's thrusters are firing.
var thrusting := false
## Returns where home is -- the airlock you left -- for the suit's HUD.
var beacon_source: Callable

## Local gravity, supplied by Grav Plating. Zero means the cell is unplated.
var grav_strength: float = 9.8

## Acceleration felt from the hull, in interior-space metres per second squared.
var external_accel: Vector3 = Vector3.ZERO

## What is in your hands.
var grasp: Grasp
## The gloves you see them with.
var hands: Hands
## The ray that finds interactables, when the scene gives the head one.
var interactor: Interactor

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
	hands.bind(grasp, self)
	var sounds := SuitSounds.new()
	sounds.name = "SuitSounds"
	add_child(sounds)
	sounds.bind(self)

## The actor contract Item talks to.
func take_item(item: Item) -> void:
	grasp.take(item)

func can_take_item(item: Item) -> bool:
	return grasp.can_take(item)

## Whether you fit standing at `pose` (feet at its origin, upright): nothing
## in your body's way, and a floor underfoot.
func can_stand_at(pose: Transform3D) -> bool:
	var space := get_world_3d().direct_space_state
	var up := pose.basis.y.normalized()
	var body := PhysicsShapeQueryParameters3D.new()
	body.shape = _collider.shape
	# Lifted a touch, so the floor you would stand on isn't in the way.
	body.transform = pose.translated(up * 0.02) * _collider.transform
	body.collision_mask = COLLISION_MASK
	body.exclude = [get_rid()]
	if not space.intersect_shape(body, 1).is_empty():
		return false
	var ray := PhysicsRayQueryParameters3D.create(pose.origin + up * 0.3, pose.origin - up * 0.3,
		COLLISION_MASK, [get_rid()])
	return not space.intersect_ray(ray).is_empty()

## Stands you at `pose` (upright), turned its way, at rest.
func place(pose: Transform3D) -> void:
	global_transform = pose
	_yaw = rotation.y
	velocity = Vector3.ZERO

func set_control_enabled(enabled: bool) -> void:
	_control_enabled = enabled
	grasp.set_enabled(enabled)
	if not enabled:
		velocity = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
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
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
		head.rotation.x = _pitch
		if mode == Mode.SUIT:
			# No up in space: turn about your own.
			rotate_object_local(Vector3.UP, -event.relative.x * MOUSE_SENSITIVITY)
		else:
			_yaw -= event.relative.x * MOUSE_SENSITIVITY
			rotation.y = _yaw

func _physics_process(delta: float) -> void:
	if not _control_enabled:
		# Parked — seated, or handed off to something else. Integrate
		# nothing: otherwise the body keeps accumulating gravity and
		# external_accel and slides off the seat while the pilot flies.
		return
	if mode == Mode.SUIT:
		_suit_physics(delta)
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

func _process(delta: float) -> void:
	tick_righting(delta)

## Steps off the ship onto a spacewalk, at `pose` in the world, moving at
## `velocity`, with `ship_hull` as the ship you left.
func enter_suit(outside: Node3D, pose: Transform3D, start_velocity: Vector3, ship_hull: RigidBody3D) -> void:
	_interior_environment = camera.environment
	_move_to(outside)
	add_to_group(Universe.EXTERIOR_SPACE)
	add_to_group(AsteroidStream.SPACE_ANCHOR)
	set_meta(AsteroidStream.ANCHOR_RADIUS, 1.0)
	global_transform = pose
	mode = Mode.SUIT
	hull = ship_hull
	_apply_height(STAND_HEIGHT)
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_mask = SUIT_MASK
	velocity = start_velocity
	external_accel = Vector3.ZERO
	camera.environment = null
	if interactor != null:
		interactor.set_mask(Interactor.SUIT_MASK)
	grasp.suspended = true
	_set_render_layer(1, 1 | ExteriorBuilder.OWN_HULL_LAYER)
	_righting_t = RIGHTING_TIME
	camera.quaternion = Quaternion.IDENTITY
	mode_changed.emit(mode)

## Comes back aboard at `pose` (upright) in interior space, head pitched
## `pitch`, moving at `start_velocity`, the view starting `righting` away from
## upright (Threshold.upright) and -- given `eye_from`, where your eye was in
## the world -- from exactly there, easing back to your head.
func enter_plating(interior: Node3D, pose: Transform3D, pitch: float, start_velocity: Vector3,
		righting: Quaternion, eye_from := Vector3.INF) -> void:
	_camera_home = camera.position
	_move_to(interior)
	remove_from_group(Universe.EXTERIOR_SPACE)
	remove_from_group(AsteroidStream.SPACE_ANCHOR)
	global_transform = pose
	mode = Mode.PLATING
	hull = null
	thrusting = false
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	collision_mask = COLLISION_MASK
	velocity = start_velocity
	_yaw = rotation.y
	_pitch = pitch
	head.rotation.x = pitch
	camera.environment = _interior_environment
	if interactor != null:
		interactor.set_mask(Interactor.MASK)
	grasp.suspended = false
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
## relative to your own ship, and the beacon is the way home.
func build_telemetry() -> VehicleTelemetry:
	var t := VehicleTelemetry.from_state(head.global_basis, global_position,
		velocity - _hull_velocity_at(global_position), Vector3.ZERO, suit_assist, false, Suit.ASSIST_CAP)
	if beacon_source.is_valid():
		t.has_beacon = true
		t.beacon = beacon_source.call()
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
func suit_step(delta: float, input: Vector3) -> void:
	velocity = Suit.step(velocity, _hull_velocity_at(global_position), input, head.global_basis, suit_assist, delta)
	thrusting = input.length() > 0.01

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

## Two bodies in space (asteroids spec §7.6): bumping a rock shares momentum
## along the contact, with a little bounce. A 1 m rock drifts off slowly; a
## giant stops you dead.
func _bump_in_space(before: Vector3) -> void:
	var hits := []
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		hits.append([hit.get_collider(), hit.get_normal(), hit.get_position()])
	velocity = bump(before, velocity, hits)

## Your velocity after bumping the rocks in `hits` ([collider, normal,
## point]), moving at `before` into them and `slid` after the slide. Sliding
## along a rock can touch it twice in one step: that is still one bump.
func bump(before: Vector3, slid: Vector3, hits: Array) -> Vector3:
	var v := slid
	var bumped := {}
	for h in hits:
		var body := h[0] as AsteroidBody
		if body == null or bumped.has(body):
			continue
		bumped[body] = true
		var n: Vector3 = h[1]
		var at: Vector3 = h[2] - body.global_position
		var closing := -(before - (body.linear_velocity + body.angular_velocity.cross(at))).dot(n)
		if closing <= 0.0:
			continue
		var m := SUIT_MASS * body.mass / (SUIT_MASS + body.mass)
		var j := (1.0 + BUMP_BOUNCE) * m * closing
		body.apply_impulse(-n * j, at)
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

## Nudges the loose things you walk into (hands-and-items spec §7.5), instead
## of stopping dead against them as if they were walls.
func _push_loose_things(pushing: Vector3, delta: float) -> void:
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var body := hit.get_collider() as RigidBody3D
		if body == null or body.freeze:
			continue
		var into := -hit.get_normal()
		into.y = 0.0
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
