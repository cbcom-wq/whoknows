class_name VelocityMarker
extends HudElement

## Where the vehicle is actually going, drawn over the scene it refers to.
##
## Mounted twice: once inside the ship's canopy SubViewport (projected with
## CanopyCam, so it agrees with the space visible through the glass) and once
## screen-space for chase view (projected with ChaseCamera). Same code, two
## cameras -- see the design doc §6 for why the cockpit case cannot be done
## screen-space.

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
