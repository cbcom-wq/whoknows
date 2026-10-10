class_name QuantumToast
extends Control

## What the hose just swallowed (docs/superpowers/specs/
## 2026-09-24-quantum-energy-design.md §12): *+12 QE · ICE CHUNK*, a little
## under the reticle, rising and fading over LIFE seconds. Built in code, as
## the reticle is (CLAUDE.md on the text-scene parser defect).

const LIFE := 1.2
## How far it rises over its life, pixels.
const RISE := 36.0
## Below the middle of the view.
const DROP := 56.0

var _label: Label
var _age := LIFE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", HudPalette.READOUT)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(-160.0, DROP)
	_label.size = Vector2(320.0, 40.0)
	add_child(_label)
	visible = false

## Shows `line`, from the start.
func say(line: String) -> void:
	_label.text = line
	_age = 0.0
	visible = true
	_place()

func text() -> String:
	return _label.text

## Steps the rise and fade by `delta`; _process does it every frame.
func advance(delta: float) -> void:
	if not visible:
		return
	_age += delta
	if _age >= LIFE:
		visible = false
		return
	_place()

func _process(delta: float) -> void:
	advance(delta)

func _place() -> void:
	var k := clampf(_age / LIFE, 0.0, 1.0)
	_label.position.y = DROP - RISE * k
	modulate.a = 1.0 - k
