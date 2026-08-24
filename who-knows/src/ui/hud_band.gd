class_name HudBand
extends PanelContainer

## The console band's own surface -- the lit panel the readouts sit on.
##
## Without this the band is bare text floating over the scene, which reads as
## game chrome rather than as the ship's instrumentation. Built in code, not
## authored, for two reasons: the colours must come from HudPalette rather
## than being restated as literals in the scene file, and a StyleBoxFlat
## authored in .tscn would be another sub_resource block in exactly the file
## CLAUDE.md warns about.

const CORNER_RADIUS := 4
const CONTENT_MARGIN := 14

func _ready() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = HudPalette.BACKDROP
	box.border_color = HudPalette.BORDER
	box.set_border_width_all(1)
	box.set_corner_radius_all(CORNER_RADIUS)
	box.content_margin_left = CONTENT_MARGIN
	box.content_margin_right = CONTENT_MARGIN
	box.content_margin_top = CONTENT_MARGIN * 0.5
	box.content_margin_bottom = CONTENT_MARGIN * 0.5
	add_theme_stylebox_override("panel", box)
