class_name GunSight
extends Control

## What you see over the gun camera (ship weapons spec §7.2): the reticle where
## you aim (the middle), a ring where the barrel points now, a diamond where to
## aim for the first target listed, and a line of status. HUD colours.

const RETICLE := 14.0
const RING := 9.0
const DIAMOND := 8.0

var camera: Camera3D
var barrel_point := Vector3.ZERO
var lead_point: Variant = null
var status := ""

func _ready() -> void:
	# Anchors *and* offsets: set_anchors_preset alone keeps the control's zero
	# size, and the cross -- drawn at the rect's centre -- lands in the corner.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if camera == null or not is_instance_valid(camera) or not camera.is_inside_tree():
		return
	var c := size * 0.5
	draw_line(c - Vector2(RETICLE, 0), c + Vector2(RETICLE, 0), HudPalette.READOUT, 2.0)
	draw_line(c - Vector2(0, RETICLE), c + Vector2(0, RETICLE), HudPalette.READOUT, 2.0)
	if not camera.is_position_behind(barrel_point):
		draw_arc(camera.unproject_position(barrel_point), RING, 0.0, TAU, 24, HudPalette.DIM, 2.0)
	if lead_point != null and not camera.is_position_behind(lead_point):
		var p := camera.unproject_position(lead_point)
		var pts := PackedVector2Array([p + Vector2(0, -DIAMOND), p + Vector2(DIAMOND, 0), p + Vector2(0, DIAMOND),
			p + Vector2(-DIAMOND, 0), p + Vector2(0, -DIAMOND)])
		draw_polyline(pts, HudPalette.TARGET, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(c.x - 160.0, size.y - 40.0), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		HudPalette.READOUT)
