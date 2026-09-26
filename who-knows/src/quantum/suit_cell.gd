class_name SuitCell
extends RefCounted

## The spacewalk suit's quantum cell (docs/superpowers/specs/
## 2026-09-24-quantum-energy-design.md §9): a charge of 0 to CAPACITY QE,
## spent at COST_PER_DV for every m/s of Δv the suit's thrusters deliver,
## assist included, and filled at the quantum machine's charge plate (§7.3).
## It starts empty.
##
## Its level drives the suit's HUD and its warning chime (§9, §12): low below
## LOW, critical below GO_OUT_MIN -- where the airlock's room panel will not
## let you out -- and dry at 0, when the suit's emergency cell takes over and
## brings you home (Suit.home_step). Pure: it knows nothing about avatars,
## ships or stores.

const CAPACITY := 100.0
## QE per m/s of Δv (§9): 2.5 QE a second at the suit's full thrust.
const COST_PER_DV := 1.0
## Below this the suit is low: the HUD turns amber and the chime sounds.
const LOW := 25.0
## Below this the suit is critical, and the room panel refuses to
## depressurize (§9).
const GO_OUT_MIN := 10.0

var charge := 0.0

## Spends `dv` m/s of Δv, down to 0. Refuses (false, spending nothing) only
## when the cell is already dry: the step that empties it goes ahead in full,
## so the thrusters never stutter on the last fraction of a QE.
func spend_dv(dv: float) -> bool:
	if is_dry():
		return false
	charge = maxf(charge - maxf(dv, 0.0) * COST_PER_DV, 0.0)
	return true

## Adds up to `n` QE, never above CAPACITY, and returns how much went in.
func add(n: float) -> float:
	var before := charge
	charge = minf(charge + maxf(n, 0.0), CAPACITY)
	return charge - before

## How much more it can take.
func room() -> float:
	return CAPACITY - charge

func is_dry() -> bool:
	return charge <= 0.0

## &"ok"; &"low" below LOW; &"critical" below GO_OUT_MIN; &"dry" at 0.
func level() -> StringName:
	if is_dry():
		return &"dry"
	if charge < GO_OUT_MIN:
		return &"critical"
	if charge < LOW:
		return &"low"
	return &"ok"
