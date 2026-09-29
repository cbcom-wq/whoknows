class_name LightsPanel
extends Node3D

## The lights panel on the bridge (docs/superpowers/specs/
## 2026-09-28-ship-exterior-design.md §7.3): FLOOD and FWD, two big buttons,
## each lit SIGNAL_GO while its group is on. It drives the same ShipLights as
## the helm's keys, so either shows what the other did. The dressing places it
## and the ship binds it after each rebuild.

const GROUPS: Array[StringName] = [ShipLights.FLOOD, ShipLights.FORWARD]
const LABELS := {ShipLights.FLOOD: "FLOOD", ShipLights.FORWARD: "FWD"}
const PROMPTS := {ShipLights.FLOOD: "Floods", ShipLights.FORWARD: "Forward lights"}

## The shoulder cell it is on.
var cell := Vector3i.ZERO
var buttons: Dictionary = {}   # StringName -> ReadoutPanel

var _lights: ShipLights
var _click: AudioStreamPlayer3D

## Builds the buttons and labels in this node's frame (on the wall, +z into
## the room). Call once, before it enters the tree.
func setup(render_layer: int) -> void:
	var frames := InteriorProps.lights_panel_buttons()
	var labels := InteriorProps.lights_panel_labels()
	for i in GROUPS.size():
		var group := GROUPS[i]
		var button := ReadoutPanel.new()
		button.setup(group, InteriorKit.LAYER, render_layer, InteriorProps.LIGHTS_BUTTON, false)
		button.transform = frames[i]
		button.prompt_source = func() -> String: return _prompt(group)
		button.pressed.connect(func(_role: StringName) -> void: _press(group))
		add_child(button)
		buttons[group] = button
		var label := ReadoutPanel.make_readout(render_layer, 120.0)
		label.text = LABELS[group]
		label.transform = labels[i]
		add_child(label)
	_click = AudioStreamPlayer3D.new()
	_click.name = "Click"
	_click.bus = AudioBuses.SHIP
	add_child(_click)
	_show()

func bind(lights: ShipLights) -> void:
	if _lights != null and _lights.changed.is_connected(_show):
		_lights.changed.disconnect(_show)
	_lights = lights
	if _lights != null:
		_lights.changed.connect(_show)
	_show()

func _prompt(group: StringName) -> String:
	if _lights == null:
		return ""
	return "%s %s" % [PROMPTS[group], "off" if _lights.is_on(group) else "on"]

func _press(group: StringName) -> void:
	if _lights == null:
		return
	_lights.toggle(group)
	var s := Synth.sound(&"light_switch")
	if s != null and _click.is_inside_tree():
		_click.stream = s
		_click.play()

func _show() -> void:
	for group: StringName in buttons:
		var on := _lights != null and _lights.is_on(group)
		(buttons[group] as ReadoutPanel).set_readout(PackedStringArray(), &"go" if on else &"")
