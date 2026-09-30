class_name HullPanel
extends HudElement

## The hull, seated (docs/superpowers/specs/
## 2026-09-29-health-and-damage-design.md §4.4, §11): *HULL 87%*, and beneath
## it *CRIPPLED · NO THRUST* in the warning colour while the ship is crippled.
## Built in code, like the band's other panels (CLAUDE.md on the text-scene
## parser); the flight scene adds it to the band's row.

var hull_label: Label
var status_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(170.0, 64.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hull_label = Label.new()
	hull_label.text = "HULL 100%"
	hull_label.add_theme_font_size_override("font_size", 30)
	hull_label.add_theme_color_override("font_color", HudPalette.READOUT)
	add_child(hull_label)
	status_label = Label.new()
	status_label.text = ""
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", HudPalette.WARNING)
	status_label.position = Vector2(0.0, 48.0)
	add_child(status_label)

func render(telemetry: VehicleTelemetry) -> void:
	if telemetry == null or not telemetry.has_hull:
		visible = false
		return
	visible = true
	hull_label.text = "HULL %d%%" % floori(clampf(telemetry.hull, 0.0, 1.0) * 100.0)
	var crippled := telemetry.crippled_reason != ""
	hull_label.add_theme_color_override("font_color", HudPalette.WARNING if crippled else HudPalette.READOUT)
	status_label.text = "CRIPPLED · %s" % telemetry.crippled_reason.to_upper() if crippled else ""
