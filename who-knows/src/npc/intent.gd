class_name Intent
extends RefCounted

## What the brain wants the body to do until its next think
## (docs/superpowers/specs/2026-09-26-npc-foundation-design.md §5.2). The
## active locomotor follows it every physics tick. Points are site-local.

## Where to go, or null to stay.
var move_to: Variant = null
## What to look at, or null to look where it is going.
var face: Variant = null
## A fraction of the species' top speed.
var speed := 0.0
## Played by the look; some locomotors act on it too (&"leap", &"brace").
var action: StringName = &""
## Where to leap to, site-local, when action is &"leap".
var leap_to: Variant = null

static func idle(p_action: StringName = &"") -> Intent:
	var i := Intent.new()
	i.action = p_action
	return i

static func go(to: Vector3, p_speed: float, p_action: StringName = &"") -> Intent:
	var i := Intent.new()
	i.move_to = to
	i.speed = p_speed
	i.action = p_action
	return i

func facing(at: Vector3) -> Intent:
	face = at
	return self
