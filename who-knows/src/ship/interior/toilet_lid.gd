class_name ToiletLid
extends Area3D

## The toilet's lid, on its own node so it can lift, and -- in a dev build
## only -- a button in the bowl under it that fills the ship's quantum store
## (a testing aid, not a game mechanic). Look at the lid to lift or close it;
## with it up, press the button. In a release build the lid is drawn, shut,
## and nothing here can be used: the toilet is only a toilet.
##
## Knows nothing about ships. Its frame is the washstand's (InteriorProps);
## the dressing places it beside one and the ship binds it to its store after
## each rebuild. A rebuild makes a new one, shut.

const OPEN_TIME := 0.3
## How far the lid swings up: upright, clear of the cistern behind it.
const OPEN_ANGLE := PI * 0.5

## Whether the lid lifts and the button is there. Set before setup().
var dev := OS.is_debug_build()
var is_open := false
## The refill button (a ReadoutPanel), or null in a release build.
var button: ReadoutPanel

var _store: QuantumStore
var _angle := 0.0
var _lid: Node3D
var _hit: CollisionShape3D
var _tween: Tween
var _sound: AudioStreamPlayer3D

## Builds the lid on render layer `render_layer`, worn like its cell (the
## kit's `wear`), and in a dev build its hit box and the button. Call once,
## before it enters the tree.
func setup(render_layer: int, wear := 0) -> void:
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	_lid = Node3D.new()
	_lid.name = "Lid"
	add_child(_lid)
	var kit := InteriorKit.new(_lid)
	kit.layer = render_layer
	kit.light_mask = render_layer
	kit.wear = wear
	InteriorProps.toilet_lid(kit, Transform3D.IDENTITY)
	kit.commit()
	if dev:
		_make_usable(render_layer)
	_swing(0.0)

func _make_usable(render_layer: int) -> void:
	collision_layer = InteriorKit.LAYER
	monitorable = true
	add_to_group("interactable")
	var shape := BoxShape3D.new()
	shape.size = InteriorProps.TOILET_LID + Vector3(0, 0.04, 0)
	_hit = CollisionShape3D.new()
	_hit.name = "Hit"
	_hit.shape = shape
	add_child(_hit)

	button = ReadoutPanel.new()
	button.setup(&"dev_refill", InteriorKit.LAYER, render_layer, InteriorProps.TOILET_BUTTON, false)
	button.transform = InteriorProps.toilet_button()
	button.prompt_source = _button_prompt
	button.pressed.connect(func(_role: StringName) -> void: _refill())
	add_child(button)

	_sound = AudioStreamPlayer3D.new()
	_sound.name = "Sound"
	_sound.bus = AudioBuses.SHIP
	add_child(_sound)

func bind(store: QuantumStore) -> void:
	_store = store

func prompt_text() -> String:
	return "Close lid" if is_open else "Lift lid"

func interact(_actor: Node) -> void:
	set_open(not is_open)
	_play(&"light_switch")

## Lifts or shuts the lid; animated when in the tree, instant otherwise.
func set_open(open: bool, animate := true) -> void:
	is_open = open
	if _tween != null:
		_tween.kill()
		_tween = null
	var target := OPEN_ANGLE if open else 0.0
	if animate and is_inside_tree():
		_tween = create_tween()
		_tween.tween_method(_swing, _angle, target, OPEN_TIME)
	else:
		_swing(target)

## The lid's frame as it stands: on its hinge, swung up by its angle.
func lid_frame() -> Transform3D:
	return InteriorProps.toilet_hinge() * Transform3D(Basis(Vector3.RIGHT, -_angle), Vector3.ZERO)

## Moves the lid and its hit box together.
func _swing(angle: float) -> void:
	_angle = angle
	var frame := lid_frame()
	_lid.transform = frame
	if _hit != null:
		_hit.transform = frame * InteriorKit.at(Vector3(0, 0, InteriorProps.TOILET_LID.z * 0.5))

func _button_prompt() -> String:
	return "Refill QE (dev)" if is_open and _store != null else ""

func _refill() -> void:
	if not is_open or _store == null:
		return
	_store.credit(_store.room(), &"dev")
	_play(&"convert")

func _play(sound_name: StringName) -> void:
	var s := Synth.sound(sound_name)
	if s != null and _sound != null and _sound.is_inside_tree():
		_sound.stream = s
		_sound.play()
