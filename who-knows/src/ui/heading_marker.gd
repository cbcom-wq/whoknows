class_name HeadingMarker
extends HudElement

## The heading the flight computer is holding (docs/superpowers/specs/
## 2026-09-25-flight-controls-design.md §8): a diamond on that direction, drawn
## over the view it refers to. Mounted twice, like VelocityMarker -- in the
## canopy overlay, projected with CanopyCam, and screen-space for chase view,
## projected with ChaseCamera -- and gated the same way, by the camera's
## `current`.

const SIZE := 9.0
const LINE_WIDTH := 2.0
## How much an edge-pinned marker for a heading behind you is faded.
const BEHIND_ALPHA := 0.5
## How far out along the heading the marker is projected from, metres. A
## direction has no distance; any point this far off reads the same on screen.
const REACH := 1000.0

@export var camera_path: NodePath

var armed := false
var mode: int = VelocityMarker.Mode.HIDDEN
var marker_at := Vector2.ZERO

var _camera: Camera3D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not camera_path.is_empty():
		_camera = get_node_or_null(camera_path) as Camera3D

func render(telemetry: VehicleTelemetry) -> void:
	armed = telemetry != null and telemetry.heading_hold and _camera != null and _camera.current
	if not armed:
		mode = VelocityMarker.Mode.HIDDEN
		queue_redraw()
		return
	var target := _camera.global_position + telemetry.heading * REACH
	# resolve() hides anything slower than its speed deadband. A heading has no
	# speed, so it is handed exactly the deadband to pass.
	var state := VelocityMarker.resolve(VelocityMarker.MIN_SPEED_MPS,
		_camera.is_position_behind(target), _camera.unproject_position(target), size)
	mode = state["mode"]
	marker_at = state["position"]
	queue_redraw()

func _draw() -> void:
	if not armed:
		return
	match mode:
		VelocityMarker.Mode.ON_FRAME:
			_diamond(marker_at, 1.0, false)
		VelocityMarker.Mode.CLAMPED_AHEAD:
			_diamond(marker_at, 1.0, true)
		VelocityMarker.Mode.CLAMPED_BEHIND:
			_diamond(marker_at, BEHIND_ALPHA, true)

## An open diamond on the heading; a filled one pinned to the edge, so an
## edge-pinned marker never reads as a real position.
func _diamond(at: Vector2, alpha: float, filled: bool) -> void:
	var colour := Color(HudPalette.READOUT, alpha)
	var points := PackedVector2Array([
		at + Vector2(0.0, -SIZE), at + Vector2(SIZE, 0.0),
		at + Vector2(0.0, SIZE), at + Vector2(-SIZE, 0.0),
	])
	if filled:
		draw_colored_polygon(points, colour)
	else:
		points.append(points[0])
		draw_polyline(points, colour, LINE_WIDTH)
