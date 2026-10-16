class_name WeaponsJob
extends SeatJob

## The weapons station's job (ship weapons spec §7). Sitting holds the ship
## (FlightComputer.gunner_hold) and, with a heavy turret aboard, puts you
## behind its gun camera: the mouse aims, the trigger (use) fires, the wheel
## zooms, T marks the target nearest the reticle, Tab cycles the list, Q and E
## change heavy turrets. Standing gives the gun back to fire control. With no
## heavy turret the station is the target board, and you still are not flying.

const SENSITIVITY := 0.003
## The gun camera's field of view at each zoom: 1x, 2x, 4x.
const ZOOMS: Array[float] = [70.0, 35.0, 17.5]
## The camera stands this far over the barrels' pivot, m.
const CAMERA_UP := 0.6

var ship: Ship
var fire_control: FireControl
var active := false
var heavy_index := 0
var zoom := 0
## The reticle's mount-frame (yaw, elevation).
var aim := Vector2(0.0, WeaponValues.PARK_ELEVATION)
var camera: Camera3D
var sight: GunSight
var _layer: CanvasLayer
var _whine: AudioStreamPlayer

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "Sight"
	_layer.layer = 5
	add_child(_layer)
	sight = GunSight.new()
	sight.visible = false
	_layer.add_child(sight)
	_whine = AudioStreamPlayer.new()
	_whine.bus = AudioBuses.SHIP
	_whine.volume_db = -12.0
	add_child(_whine)

func heavy() -> Turret:
	if ship == null:
		return null
	var all := ship.heavy_turrets()
	return all[heavy_index % all.size()] if not all.is_empty() else null

func sat(_avatar: Avatar) -> void:
	active = true
	if ship != null:
		ship.flight_computer.gunner_hold = true
	_take()

func stood(_avatar: Avatar) -> void:
	active = false
	if ship != null:
		ship.flight_computer.gunner_hold = false
		for t in ship.heavy_turrets():
			t.manual = false
	if camera != null:
		camera.current = false
	sight.visible = false

func view_camera() -> Camera3D:
	return camera if active and heavy() != null else null

func takes_mouse() -> bool:
	return active and heavy() != null

func _take() -> void:
	var t := heavy()
	if t == null:
		return
	for other in ship.heavy_turrets():
		other.manual = other == t
	aim = Vector2(t.yaw, t.elevation)
	t.manual_aim = t.barrel_dir()
	if camera == null:
		camera = Camera3D.new()
		camera.name = "GunCamera"
		camera.cull_mask = ship.chase_camera.cull_mask
		camera.far = ship.chase_camera.far
	if camera.get_parent() != t:
		if camera.get_parent() != null:
			camera.get_parent().remove_child(camera)
		t.add_child(camera)
	camera.fov = ZOOMS[zoom]
	_pose_camera()
	sight.visible = true
	sight.camera = camera
	var d := get_tree().get_first_node_in_group(CameraDirector.GROUP) as CameraDirector if is_inside_tree() else null
	if d != null:
		d.refresh_view()

func _pose_camera() -> void:
	camera.transform = Transform3D(Basis.from_euler(Vector3(aim.y, -aim.x, 0.0)),
		Vector3(0, WeaponValues.MUZZLE_UP + CAMERA_UP, 0))

func _process(_delta: float) -> void:
	var t := heavy()
	if not active or t == null or camera == null:
		return
	_pose_camera()
	t.manual_aim = -camera.global_basis.z
	sight.barrel_point = t.muzzle() + t.barrel_dir() * 1000.0
	sight.lead_point = _lead(t)
	var left := t.recharge_left()
	sight.status = "HEAVY %d · %s · ×%d" % [heavy_index % ship.heavy_turrets().size() + 1,
		"READY" if left <= 0.0 else "CHARGING %.1f S" % left, 1 << zoom]
	if left > 0.0 and not _whine.playing:
		var s := Synth.sound(&"phaser_whine")
		if s != null:
			_whine.stream = s
			_whine.play()

## Where to aim for the first target listed, world, or null.
func _lead(t: Turret) -> Variant:
	if fire_control == null or fire_control.entries.is_empty():
		return null
	var node := fire_control.entries[0]["node"] as Node3D
	if node == null or not is_instance_valid(node):
		return null
	var s := WeaponAim.intercept(t.muzzle(), ship.exterior.linear_velocity, WeaponValues.spec(t.kind)["speed"],
		Weapons.point_of(node), Weapons.velocity_of(node))
	return null if s.is_empty() else t.muzzle() + (s["dir"] as Vector3) * 1000.0

func _unhandled_input(event: InputEvent) -> void:
	if active and handle(event):
		get_viewport().set_input_as_handled()

## One input event while sat here; true if it was the gun's. Split from
## _unhandled_input so tests can drive it.
func handle(event: InputEvent) -> bool:
	var t := heavy()
	if not active or t == null:
		return false
	var motion := event as InputEventMouseMotion
	if motion != null:
		var scale := SENSITIVITY * camera.fov / ZOOMS[0]
		aim.x = wrapf(aim.x + motion.relative.x * scale, -PI, PI)
		aim.y = clampf(aim.y - motion.relative.y * scale, 0.0, PI * 0.5)
		return true
	var wheel := event as InputEventMouseButton
	if wheel != null and wheel.pressed and wheel.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		zoom = clampi(zoom + (1 if wheel.button_index == MOUSE_BUTTON_WHEEL_UP else -1), 0, ZOOMS.size() - 1)
		camera.fov = ZOOMS[zoom]
		return true
	if event.is_action_pressed(&"use"):
		t.pull_trigger()
		return true
	if event.is_action_pressed(&"weapons_mark", false, true) and fire_control != null:
		fire_control.mark_nearest(camera.global_position, -camera.global_basis.z, WeaponValues.MARK_CONE,
			WeaponValues.spec(WeaponValues.HEAVY)["manned_range"])
		return true
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_TAB and fire_control != null:
		fire_control.rotate_list()
		return true
	if event.is_action_pressed(&"roll_left") or event.is_action_pressed(&"roll_right"):
		var n := ship.heavy_turrets().size()
		if n > 1:
			heavy_index = posmod(heavy_index + (1 if event.is_action_pressed(&"roll_right") else -1), n)
			_take()
		return true
	return false
