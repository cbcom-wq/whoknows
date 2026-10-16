class_name Turret
extends Node3D

## One turret on a ship's hull (ship weapons spec §3, §5.3): it turns toward the
## target fire control gave it at its own slew, leads it (WeaponAim), and fires
## bursts while its barrel is on the solution, the shot is in range and clear
## of its own hull, and the store can pay above the low-power line. A heavy
## turret can be aimed by hand instead (`manual`, the weapons station). On the
## hull, so the floating origin carries it; its own look turns with it.

signal fired(kind: StringName)

var kind := WeaponValues.LIGHT
var coord := Vector3i.ZERO
var normal := Vector3i.UP
var sky: SkyMap
var hull: RigidBody3D
var store: QuantumStore
## () -> BlockDamage.Stage of this turret's component.
var stage_of: Callable
## Whose bolts these are: the ship.
var source: Node
## Set by fire control, or null.
var target: Node3D
## Engaged, with a list, and nothing on it this turret can reach.
var no_arc := false
## Aimed by hand (spec §7.2): it turns toward `manual_aim` (world) and fires
## only on pull_trigger().
var manual := false
var manual_aim := Vector3.FORWARD
## Mount-frame yaw (0 ahead, + to the right) and elevation, radians. Yaw turns
## a full circle. Elevation runs 0..PI: level, up through PI/2, and past it the
## barrels lean back over the top to the far horizon (the dome faces the other
## way then). Every direction in the half-sky has two poses, upright and flipped.
var yaw := 0.0
var elevation := WeaponValues.PARK_ELEVATION
## &"idle", &"tracking", &"firing", &"no_arc", &"damaged", &"low_power",
## &"wrecked": the HUD's pip and the board's word.
var state: StringName = &"idle"

var _spec: Dictionary
var _recharge := 0.0
var _burst_left := 0
var _gap := 0.0
var _solution := {}
var _yaw_node: Node3D
var _pitch_node: Node3D
var _rng := RandomNumberGenerator.new()
var _outside_sound: AudioStreamPlayer3D
var _inside_sound: AudioStreamPlayer

func setup(p_kind: StringName, p_coord: Vector3i, p_normal: Vector3i, p_sky: SkyMap) -> void:
	kind = p_kind
	coord = p_coord
	normal = p_normal
	sky = p_sky
	_spec = WeaponValues.spec(kind)
	name = "Turret_%d_%d_%d" % [coord.x, coord.y, coord.z]
	transform = Transform3D(SkyMap.mount_basis(normal), ShipGrid.cell_center(coord) + Vector3(normal) * WeaponValues.FACE_OUT)
	_rng.seed = hash(coord)
	_yaw_node = Node3D.new()
	_yaw_node.name = "Yaw"
	_yaw_node.position = Vector3(0, WeaponValues.MUZZLE_UP, 0)
	add_child(_yaw_node)
	_pitch_node = Node3D.new()
	_pitch_node.name = "Pitch"
	_yaw_node.add_child(_pitch_node)
	_look(self, Transform3D(Basis.IDENTITY, Vector3.ZERO), TurretLook.plinth)
	_look(_yaw_node, Transform3D.IDENTITY, TurretLook.dome)
	_look(_pitch_node, Transform3D.IDENTITY, TurretLook.barrels)
	_pose()

func _look(root: Node3D, f: Transform3D, part: Callable) -> void:
	var holder := Node3D.new()
	holder.name = "Look"
	root.add_child(holder)
	var kit := InteriorKit.new(holder)
	kit.layer = Item.SPACE_LAYER
	kit.light_mask = 1 | ExteriorBuilder.OWN_HULL_LAYER
	kit.materials = {InteriorKit.Batch.HULL: HullMaterials.livery(), InteriorKit.Batch.SOLID: HullMaterials.trim(),
		InteriorKit.Batch.GLOW: HullMaterials.glow_instance(1.0)}
	part.call(kit, f, kind)
	kit.commit()

func _ready() -> void:
	_outside_sound = AudioStreamPlayer3D.new()
	_outside_sound.name = "Shot"
	_outside_sound.bus = AudioBuses.SUIT
	_outside_sound.max_distance = 200.0
	add_child(_outside_sound)
	_inside_sound = AudioStreamPlayer.new()
	_inside_sound.name = "ShotInside"
	_inside_sound.bus = AudioBuses.SHIP
	_inside_sound.volume_db = -14.0
	add_child(_inside_sound)

func _physics_process(delta: float) -> void:
	step(delta)

## The barrels' pivot, world.
func muzzle() -> Vector3:
	return to_global(Vector3(0, WeaponValues.MUZZLE_UP, 0))

## Where the barrels point now, world.
func barrel_dir() -> Vector3:
	return (global_basis * _mount_dir(yaw, elevation)).normalized()

func recharge_left() -> float:
	return _recharge

## Whether this turret could fire on `node` now: not wrecked, a solution in
## range, along a clear part of its sky.
func can_engage(node: Node3D) -> bool:
	if _stage() == BlockDamage.Stage.WRECKED or not Weapons.usable(node):
		return false
	var s := _solve(node)
	return not s.is_empty() and _reaches(s) and _sky_clear(s["dir"])

## The gunner's trigger (spec §7.2): one bolt (a burst for a light turret)
## where the barrels point, if recharged, paid for and at full power.
func pull_trigger() -> bool:
	if not manual or _recharge > 0.0 or _burst_left > 0 or not _can_pay():
		return false
	if _stage() == BlockDamage.Stage.WRECKED or not _manual_clear():
		return false
	_burst_left = int(_spec["burst"])
	_gap = 0.0
	return true

func step(delta: float) -> void:
	var stage := _stage()
	if stage == BlockDamage.Stage.WRECKED:
		state = &"wrecked"
		_burst_left = 0
		return
	var damaged := stage == BlockDamage.Stage.DAMAGED
	_solution = _solve(target) if target != null and not manual else {}
	var goal := Vector2(0.0, WeaponValues.PARK_ELEVATION)
	if manual:
		goal = pose_toward(manual_aim)
	elif not _solution.is_empty():
		goal = pose_toward(_solution["dir"])
	var rate := deg_to_rad(_spec["slew"]) * (WeaponValues.DAMAGED_SLEW if damaged else 1.0) * delta
	yaw = _toward_angle(yaw, goal.x, rate)
	elevation = clampf(move_toward(elevation, goal.y, rate), 0.0, WeaponValues.ELEVATION_MAX)
	_pose()
	_recharge = maxf(_recharge - delta / (WeaponValues.DAMAGED_RECHARGE if damaged else 1.0), 0.0)
	if _burst_left == 0 and not manual and _recharge <= 0.0 and _ready_to_fire():
		_burst_left = int(_spec["burst"])
		_gap = 0.0
	if _burst_left > 0:
		_gap -= delta
		if _gap <= 0.0:
			if _can_pay() and (_manual_clear() if manual else _ready_to_fire()):
				_fire_one()
				_burst_left -= 1
				_gap = _spec["gap"]
			else:
				_burst_left = 0
			if _burst_left == 0:
				_recharge = _spec["recharge"]
	state = _state_now(damaged)

func _state_now(damaged: bool) -> StringName:
	if _burst_left > 0:
		return &"firing"
	if (target != null or manual) and store != null and store.is_low_power():
		return &"low_power"
	if target != null or manual:
		return &"tracking"
	if no_arc:
		return &"no_arc"
	return &"damaged" if damaged else &"idle"

func _stage() -> int:
	return stage_of.call() if stage_of.is_valid() else BlockDamage.Stage.INTACT

func _can_pay() -> bool:
	return store != null and not store.is_low_power() and store.can_spend(int(_spec["qe"]))

func _ready_to_fire() -> bool:
	if target == null or _solution.is_empty() or not _can_pay():
		return false
	if barrel_dir().angle_to(_solution["dir"]) > WeaponValues.AIM_TOLERANCE:
		return false
	return _reaches(_solution) and _sky_clear(_solution["dir"]) and _clear_of_hull()

## Where it points by hand is open sky and clear of its own hull: a gunner's
## aim gets no leave to fire through the ship.
func _manual_clear() -> bool:
	return _sky_clear(barrel_dir()) and _clear_of_hull()

func _solve(node: Node3D) -> Dictionary:
	if node == null or hull == null or not Weapons.usable(node):
		return {}
	return WeaponAim.intercept(muzzle(), hull.linear_velocity, _spec["speed"], Weapons.point_of(node),
		Weapons.velocity_of(node))

func _reaches(s: Dictionary) -> bool:
	return float(s["time"]) * float(_spec["speed"]) <= float(_spec["manned_range"] if manual else _spec["range"])

func _sky_clear(dir: Vector3) -> bool:
	return sky == null or hull == null or sky.can_bear(hull.global_basis.inverse() * dir)

## The ray every shot casts along its barrels against its own hull (spec §5.3):
## the sky map is coarse.
func _clear_of_hull() -> bool:
	if hull == null or not is_inside_tree():
		return true
	var from := muzzle()
	var query := PhysicsRayQueryParameters3D.create(from, from + barrel_dir() * WeaponValues.HULL_CHECK, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit["collider"] != hull

func _fire_one() -> void:
	if not store.spend(int(_spec["qe"]), &"weapons"):
		_burst_left = 0
		return
	var dir := barrel_dir()
	var spread := deg_to_rad(_spec["spread"])
	if spread > 0.0:
		var side := dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
		dir = dir.rotated(side, _rng.randf() * spread).rotated(dir, _rng.randf() * TAU).normalized()
	var pool := BoltPool.find(get_tree())
	if pool != null:
		var ex: Array[RID] = [hull.get_rid()]
		pool.fire(kind, muzzle() + dir * float(_spec["barrel"]), dir, hull.linear_velocity, source, ex)
	_sound()
	fired.emit(kind)

func _sound() -> void:
	var s := Synth.sound(&"phaser_heavy" if kind == WeaponValues.HEAVY else &"phaser_thrum")
	if s == null:
		return
	var aboard: bool = source != null and source.has_method(&"listener_aboard") and source.listener_aboard()
	var player: Node = _inside_sound if aboard else _outside_sound
	if player == null or not player.is_inside_tree():
		return
	player.stream = s
	player.play()

## A world direction's upright mount-frame (yaw, elevation): elevation kept to
## 0..PI/2, the half-sky.
func upright_angles(dir_world: Vector3) -> Vector2:
	var a := SkyMap.angles(global_basis.inverse() * dir_world)
	return Vector2(a.x, clampf(a.y, 0.0, PI * 0.5))

## The pose that aims along `dir_world` soonest from where the barrels are:
## upright or flipped over the top.
func pose_toward(dir_world: Vector3) -> Vector2:
	return choose_pose(Vector2(yaw, elevation), upright_angles(dir_world))

## Of the two poses for one direction, upright `a` and flipped, the one
## reached sooner from `now` (yaw and pitch slew together), keeping `now`'s
## branch unless the other is shorter by FLIP_MARGIN. Pure.
static func choose_pose(now: Vector2, a: Vector2) -> Vector2:
	var flipped := Vector2(wrapf(a.x + PI, -PI, PI), PI - a.y)
	var cost_a := _cost(now, a)
	var cost_f := _cost(now, flipped)
	if now.y > PI * 0.5:
		return a if cost_a + WeaponValues.FLIP_MARGIN < cost_f else flipped
	return flipped if cost_f + WeaponValues.FLIP_MARGIN < cost_a else a

static func _cost(now: Vector2, to: Vector2) -> float:
	return maxf(absf(wrapf(to.x - now.x, -PI, PI)), absf(to.y - now.y))

## Where the barrels point, as the upright pose: what a gunner's reticle
## starts from.
func barrel_angles() -> Vector2:
	return upright_angles(barrel_dir())

static func _mount_dir(y: float, e: float) -> Vector3:
	return Vector3(sin(y) * cos(e), sin(e), -cos(y) * cos(e))

static func _toward_angle(from: float, to: float, step: float) -> float:
	var diff := wrapf(to - from, -PI, PI)
	return wrapf(from + clampf(diff, -step, step), -PI, PI)

func _pose() -> void:
	if _yaw_node != null:
		_yaw_node.rotation = Vector3(0, -yaw, 0)
		_pitch_node.rotation = Vector3(elevation, 0, 0)
