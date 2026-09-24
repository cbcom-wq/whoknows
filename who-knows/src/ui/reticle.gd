class_name Reticle
extends Control

## The centre dot you aim and pick things up with (docs/superpowers/specs/
## 2026-09-23-hands-and-items-design.md §10). Knows nothing about avatars; the
## bootstrap shows it on foot in first person.

const RADIUS := 2.5
const OUTLINE := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var centre := size * 0.5
	draw_circle(centre, RADIUS + OUTLINE, HudPalette.BACKDROP)
	draw_circle(centre, RADIUS, HudPalette.READOUT)
