class_name Downed
extends RefCounted

## Blacking out (docs/superpowers/specs/2026-09-29-health-and-damage-design.md
## §7.2), as timing only: the view fades out, stays black while you are
## brought home, and comes back. Pure: Avatar ticks it and acts on each step.

enum Step { FADING, BLACK, WAKING, DONE }

const FADE := 1.5
const BLACK := 3.0
const WAKE := 1.0
## Outside, the black lasts until the emergency cell has you home, or this.
const BLACK_AT_MOST := 20.0

signal stepped(step: Step)

var step := Step.FADING
var t := 0.0

## Advances by `delta`. `home` is whether you may wake now: aboard always,
## outside once the suit has brought you to the airlock.
func tick(delta: float, home := true) -> void:
	if step == Step.DONE:
		return
	t += delta
	match step:
		Step.FADING:
			if t >= FADE:
				_to(Step.BLACK)
		Step.BLACK:
			if (t >= BLACK and home) or t >= BLACK_AT_MOST:
				_to(Step.WAKING)
		Step.WAKING:
			if t >= WAKE:
				_to(Step.DONE)

## How dark the view is, 0 to 1.
func darkness() -> float:
	match step:
		Step.FADING:
			return clampf(t / FADE, 0.0, 1.0)
		Step.BLACK:
			return 1.0
		Step.WAKING:
			return clampf(1.0 - t / WAKE, 0.0, 1.0)
	return 0.0

func _to(next: Step) -> void:
	step = next
	t = 0.0
	stepped.emit(next)
