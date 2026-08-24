class_name VelocityMarker
extends HudElement

## Where the vehicle is actually going, drawn over the scene it refers to.
##
## Mounted twice: once inside the ship's canopy SubViewport (projected with
## CanopyCam, so it agrees with the space visible through the glass) and once
## screen-space for chase view (projected with ChaseCamera). Same code, two
## cameras -- see the design doc §6 for why the cockpit case cannot be done
## screen-space.
##
## The two mounts fade differently, which is easy to miss when reading only
## this file: the screen-space mount lives inside the faded `Screen` Control
## and fades with the rest of the HUD, while the canopy mount lives inside
## the ship's own SubViewport and hard-cuts instead. That is acceptable --
## stale world geometry should stop drawing rather than linger -- but it
## surprises readers expecting one fade behaviour for both.

enum Mode {
	HIDDEN,           ## below the speed deadband, or nothing to show
	ON_FRAME,         ## the real projected position
	CLAMPED_AHEAD,    ## ahead but outside the frame, pinned to the edge
	CLAMPED_BEHIND,   ## behind the camera, pinned to the opposite edge
}

## Below this, velocity direction is numerical noise rather than information.
const MIN_SPEED_MPS := 1.0
## How far inside the frame a clamped marker sits.
const EDGE_MARGIN_PX := 16.0

## Decides what the marker should show, given a projected point.
##
## Pure on purpose. The two rules it encodes are both traps that are easy to
## get wrong and impossible to notice in review: unproject_position() returns
## a mirrored, meaningless point for anything behind the camera, and velocity
## direction is noise at rest. Keeping them here means both are covered by
## tests that need no camera and no viewport.
static func resolve(
	speed: float,
	is_behind: bool,
	screen_pos: Vector2,
	viewport_size: Vector2
) -> Dictionary:
	if speed < MIN_SPEED_MPS:
		return {"mode": Mode.HIDDEN, "position": Vector2.ZERO}

	var centre := viewport_size * 0.5

	if is_behind:
		# The projected point is mirrored through centre, so negate the
		# offset to recover the true bearing before pinning it.
		return {
			"mode": Mode.CLAMPED_BEHIND,
			"position": _clamp_to_edge(-(screen_pos - centre), viewport_size),
		}

	var margin := Vector2(EDGE_MARGIN_PX, EDGE_MARGIN_PX)
	var inset := Rect2(margin, viewport_size - margin * 2.0)
	if inset.has_point(screen_pos):
		return {"mode": Mode.ON_FRAME, "position": screen_pos}

	return {
		"mode": Mode.CLAMPED_AHEAD,
		"position": _clamp_to_edge(screen_pos - centre, viewport_size),
	}

## Pushes `offset` out from centre until it meets the inset rectangle.
static func _clamp_to_edge(offset: Vector2, viewport_size: Vector2) -> Vector2:
	var centre := viewport_size * 0.5
	var half := centre - Vector2(EDGE_MARGIN_PX, EDGE_MARGIN_PX)

	# Dead astern (or dead ahead) leaves no bearing at all. Pick one rather
	# than divide by zero and hand NAN to the renderer.
	if offset.length_squared() < 0.000001:
		offset = Vector2.DOWN

	# Scale to whichever boundary is reached first.
	var sx := INF if is_zero_approx(offset.x) else half.x / absf(offset.x)
	var sy := INF if is_zero_approx(offset.y) else half.y / absf(offset.y)
	return centre + offset * minf(sx, sy)

const RING_RADIUS := 13.0
const RING_WING := 9.0
const BORESIGHT_GAP := 6.0
const BORESIGHT_ARM := 11.0
const CHEVRON_SIZE := 10.0
const LINE_WIDTH := 2.0
## How much a behind-the-camera marker is faded, so it never reads as a real
## position the pilot could steer toward.
const BEHIND_ALPHA := 0.5

## The camera whose projection this marker annotates. CanopyCam for the
## cockpit mount, ChaseCamera for the screen-space one.
@export var camera_path: NodePath

## True when there is a vehicle to report on and a camera to project with.
var armed: bool = false
var mode: int = Mode.HIDDEN

var _position: Vector2 = Vector2.ZERO
var _camera: Camera3D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not camera_path.is_empty():
		_camera = get_node_or_null(camera_path) as Camera3D

func render(telemetry: VehicleTelemetry) -> void:
	# `current` is what gates the two mounts against each other: the chase
	# marker draws only while the chase camera is live, and the cockpit one
	# draws whenever its SubViewport camera is. Cycling views therefore needs
	# no signal -- whoever owns the view already flips `current`, and this
	# just notices.
	armed = telemetry != null and _camera != null and _camera.current
	if not armed:
		mode = Mode.HIDDEN
		queue_redraw()
		return

	var target := telemetry.hull_origin + telemetry.world_velocity
	var state := resolve(
		telemetry.speed,
		_camera.is_position_behind(target),
		_camera.unproject_position(target),
		size
	)
	mode = state["mode"]
	_position = state["position"]
	queue_redraw()

func _draw() -> void:
	if not armed:
		return
	_draw_boresight()
	match mode:
		Mode.ON_FRAME:
			_draw_ring(_position, 1.0)
		Mode.CLAMPED_AHEAD:
			_draw_chevron(_position, 1.0)
		Mode.CLAMPED_BEHIND:
			_draw_chevron(_position, BEHIND_ALPHA)

## The nose reference: four ticks around viewport centre. Static, because
## viewport centre IS where the hull points, by construction. The gap between
## this and the ring is the actual readout.
func _draw_boresight() -> void:
	var centre := size * 0.5
	var colour := Color(HudPalette.READOUT, 0.45)
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(
			centre + direction * BORESIGHT_GAP,
			centre + direction * (BORESIGHT_GAP + BORESIGHT_ARM),
			colour,
			1.0
		)

func _draw_ring(at: Vector2, alpha: float) -> void:
	var colour := Color(HudPalette.READOUT, alpha)
	draw_arc(at, RING_RADIUS, 0.0, TAU, 32, colour, LINE_WIDTH)
	draw_line(at + Vector2(-RING_RADIUS - RING_WING, 0.0), at + Vector2(-RING_RADIUS, 0.0), colour, LINE_WIDTH)
	draw_line(at + Vector2(RING_RADIUS, 0.0), at + Vector2(RING_RADIUS + RING_WING, 0.0), colour, LINE_WIDTH)
	draw_line(at + Vector2(0.0, -RING_RADIUS - RING_WING), at + Vector2(0.0, -RING_RADIUS), colour, LINE_WIDTH)

## Clamped markers render as a chevron rather than a ring, so an edge-pinned
## marker never reads as a real position.
func _draw_chevron(at: Vector2, alpha: float) -> void:
	var colour := Color(HudPalette.READOUT, alpha)
	var direction := (at - size * 0.5).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	var perpendicular := Vector2(-direction.y, direction.x)
	draw_colored_polygon(
		PackedVector2Array([
			at + direction * CHEVRON_SIZE,
			at - direction * CHEVRON_SIZE * 0.4 + perpendicular * CHEVRON_SIZE * 0.8,
			at - direction * CHEVRON_SIZE * 0.4 - perpendicular * CHEVRON_SIZE * 0.8,
		]),
		colour
	)
