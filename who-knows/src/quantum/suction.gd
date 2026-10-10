class_name Suction
extends RefCounted

## What the hose's trigger does (docs/superpowers/specs/
## 2026-09-24-quantum-energy-design.md §11.4), as pure maths: which things lie
## in the cone, how hard each is pulled, and which are refused for size.

const RANGE := 8.0
const HALF_ANGLE := deg_to_rad(15.0)
## The pull, m/s^2, and the most force it may be: a 40 kg item comes at 3.
const MAX_ACCEL := 6.0
const MAX_FORCE := 120.0
## An item is pulled no faster than this, m/s.
const MAX_SPEED := 5.0
## How hard sideways drift is damped, per second, so things funnel in.
const FUNNEL := 3.0
## Within this of the mouth an item is swallowed, and it shrinks over SHRINK.
const SWALLOW := 0.35
const SHRINK := 0.25
## Bigger or heavier than this is not pulled (*Too big*).
const BIGGEST := 0.6
const HEAVIEST := 40.0
## A Vector3 holds float32, so a side authored as 0.6 reads back as 0.6000000238: without this, an item exactly at the limit would be refused.
const SIZE_EPSILON := 0.0001

static func largest_side(def: ItemDefinition) -> float:
	return maxf(def.size.x, maxf(def.size.y, def.size.z))

static func too_big(def: ItemDefinition) -> bool:
	return largest_side(def) > BIGGEST + SIZE_EPSILON or def.mass_kg > HEAVIEST

## Whether a point `to` away from the mouth lies in the cone along unit `dir`,
## widened by `half_size` -- half the item's largest side (the forgiving-aim
## rule, hands-and-items spec §7.2).
static func in_cone(to: Vector3, dir: Vector3, half_size: float) -> bool:
	var along := to.dot(dir)
	if along < 0.0 or along > RANGE:
		return false
	var off := (to - dir * along).length()
	return off <= along * tan(HALF_ANGLE) + half_size

## The force on an item of `mass` at `to_mouth` from it, moving at `vel`: toward
## the mouth at up to MAX_ACCEL but never over MAX_FORCE, sideways drift
## opposed, and none toward the mouth once it is going MAX_SPEED.
static func pull(to_mouth: Vector3, vel: Vector3, mass: float) -> Vector3:
	var distance := to_mouth.length()
	if distance < 0.0001:
		return Vector3.ZERO
	var dir := to_mouth / distance
	var accel := minf(MAX_ACCEL, MAX_FORCE / maxf(mass, 0.001))
	var force := dir * accel * mass
	var side := vel - dir * vel.dot(dir)
	force -= side * FUNNEL * mass
	if vel.dot(dir) >= MAX_SPEED:
		force -= dir * maxf(force.dot(dir), 0.0)
	return force.limit_length(MAX_FORCE)
