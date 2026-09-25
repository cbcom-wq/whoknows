class_name PilotStick
extends RefCounted

## The virtual stick (docs/superpowers/specs/2026-09-25-flight-controls-design.md
## §4.1). The mouse moves a cursor away from the centre of view and it stays
## where you leave it; how far out it sits is the turn you ask for. The command
## comes from the cursor's position, never from one frame's mouse delta, so the
## same mouse travel gives the same turn at any frame rate. That delta was the
## old steering, and it stopped the moment the mouse did.

## Full deflection, as a fraction of the viewport's height.
const RADIUS := 0.2
## Inside this the stick asks for nothing.
const DEADZONE := 0.02
## Past the dead zone the command is its share of the travel to this power, so
## small movements aim finely.
const CURVE := 1.5

## The cursor's offset from the centre of view, in fractions of the viewport's
## height, screen axes (+x right, +y down).
var offset := Vector2.ZERO

## Moves the cursor by `pixels` of mouse travel, clamped to full deflection.
func move(pixels: Vector2, viewport_height: float) -> void:
	if viewport_height <= 0.0:
		return
	offset = (offset + pixels / viewport_height).limit_length(RADIUS)

func centre() -> void:
	offset = Vector2.ZERO

## True inside the dead zone.
func is_centred() -> bool:
	return offset.length() <= DEADZONE

## (pitch, yaw), each -1..1: up is nose up, left is yaw left, matching the
## right-handed torques about the hull's own X and Y.
func command() -> Vector2:
	var r := offset.length()
	if r <= DEADZONE:
		return Vector2.ZERO
	var d := offset / r * pow((r - DEADZONE) / (RADIUS - DEADZONE), CURVE)
	return Vector2(-d.y, -d.x)
