class_name HitFeel
extends RefCounted

## How a hit feels aboard (hostile ships spec §6.1): the view you see through
## is knocked away from the hit's side and settles, and the cabin's ceiling
## lights dip. Both scale with the hit's strength, from a light bolt to a heavy
## one, and both are capped so a hammering never blurs or strobes.
##
## An instance is one view's knock: whatever owns the camera (the avatar, the
## gun camera) keeps one, knocks it, settles it each frame and shows `roll`
## and `shift` on its camera.

## The roll of the heaviest knock, radians, and the view's shift, m.
const ROLL_MOST := 0.03
const SHIFT_MOST := 0.06
## Seconds the heaviest knock takes to settle; a lighter one settles sooner.
const SETTLE := 0.25
## The summed strength the shake can hold: a burst storm reads as a rattle.
const CEILING := 1.0
## The lights' dip: a light bolt's quick one, and a heavy bolt's stutter with a
## near-dark beat and DIP_FLICKS flicks back up to DIP_FLICK_LEVEL in its first
## DIP_STUTTER share, then easing back.
const DIP_LIGHT_TIME := 0.1
const DIP_LIGHT_LEVEL := 0.5
const DIP_HEAVY_TIME := 0.5
const DIP_HEAVY_LEVEL := 0.08
const DIP_FLICKS := 2
const DIP_FLICK_LEVEL := 0.6
const DIP_STUTTER := 0.7
## A single hit of this many hp or more may knock a piece off its section at
## any health (spec §6.2): a heavy bolt does, a light one never.
const CHIP_FROM := 100.0

## The view's roll, radians, and its shift in the view's own right and up, m.
var roll := 0.0
var shift := Vector2.ZERO

## 0.1..1 for a hit of `damage` hp: a light bolt 0.125, a heavy one 1.0, and
## a crash on the same scale.
static func strength(damage: float) -> float:
	return clampf(damage / WeaponValues.spec(WeaponValues.HEAVY)["damage"], 0.1, 1.0)

## 0 for a light bolt's strength, 1 for a heavy one's: where between the two
## dips a dip of `s` falls.
static func heaviness(s: float) -> float:
	var light := strength(WeaponValues.spec(WeaponValues.LIGHT)["damage"])
	return clampf(inverse_lerp(light, 1.0, s), 0.0, 1.0)

## A knock of strength `s` from the way `from` points, in the view's frame
## (+x right, +y up): rolled away from its side, and shifted away from it as
## far as it comes from the side or above (a hit dead ahead only rolls), up to
## the ceiling.
func knock(s: float, from: Vector3) -> void:
	var dir := from.normalized()
	var side := signf(dir.x) if dir.x != 0.0 else 1.0
	roll = clampf(roll + ROLL_MOST * s * side, -ROLL_MOST * CEILING, ROLL_MOST * CEILING)
	shift = (shift - Vector2(dir.x, dir.y) * SHIFT_MOST * s).limit_length(SHIFT_MOST * CEILING)

## Eases the knock back toward rest by `delta` seconds.
func settle(delta: float) -> void:
	roll = move_toward(roll, 0.0, ROLL_MOST / SETTLE * delta)
	shift = shift.move_toward(Vector2.ZERO, SHIFT_MOST / SETTLE * delta)

func live() -> bool:
	return roll != 0.0 or shift != Vector2.ZERO
