class_name AirlockMarker
extends HudElement

## Your way home on a spacewalk (docs/superpowers/specs/
## 2026-09-24-airlock-design.md §8.3): a ring over your airlock's outer hatch
## with its distance, pinned to the screen edge with a chevron when it is
## off-screen or behind you -- the velocity marker's clamp policy
## (VelocityMarker.resolve), so the two never disagree about an edge. It
## shows whenever the vehicle offers a beacon: only the suit does.

const RING_RADIUS := 11.0
const CHEVRON_SIZE := 10.0
const LINE_WIDTH := 2.0
const LABEL_SIZE := 12
const BEHIND_ALPHA := 0.5

var shown := false
var mode: int = VelocityMarker.Mode.HIDDEN
var distance := 0.0

var _position := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func render(telemetry: VehicleTelemetry) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	shown = telemetry != null and telemetry.has_beacon and cam != null
	if not shown:
		mode = VelocityMarker.Mode.HIDDEN
		queue_redraw()
		return
	# A beacon always has a bearing, so the speed deadband never applies.
	var state := VelocityMarker.resolve(INF, cam.is_position_behind(telemetry.beacon),
		cam.unproject_position(telemetry.beacon), size)
	mode = state["mode"]
	_position = state["position"]
	distance = cam.global_position.distance_to(telemetry.beacon)
	queue_redraw()

func _draw() -> void:
	if not shown:
		return
	var colour := HudPalette.READOUT
	if mode == VelocityMarker.Mode.CLAMPED_BEHIND:
		colour.a *= BEHIND_ALPHA
	if mode == VelocityMarker.Mode.ON_FRAME:
		draw_arc(_position, RING_RADIUS, 0.0, TAU, 32, colour, LINE_WIDTH, true)
		draw_arc(_position, 2.5, 0.0, TAU, 12, colour, LINE_WIDTH, true)
	else:
		var out := (_position - size * 0.5).normalized()
		var side := Vector2(-out.y, out.x) * CHEVRON_SIZE * 0.6
		var tip := _position + out * CHEVRON_SIZE * 0.5
		var back := _position - out * CHEVRON_SIZE * 0.5
		draw_polyline(PackedVector2Array([back + side, tip, back - side]), colour, LINE_WIDTH, true)
	var text := "AIRLOCK %d M" % roundi(distance)
	var at := _position + Vector2(RING_RADIUS + 6.0, 4.0)
	if at.x > size.x - 110.0:
		at.x = _position.x - RING_RADIUS - 100.0
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, colour)
