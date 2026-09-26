class_name QuantumStore
extends RefCounted

## The ship's quantum energy store (quantum energy spec §3.2): a whole
## number of QE, up to a capacity the ship's quantum cells sum to. Pure --
## knows nothing about ships, cores or flight. QuantumPlant owns one and
## drives the core from it; FlightComputer reads and spends it to run
## boost and low power.
##
## No reserve: every whole-QE spend is all or nothing, and any spend may
## take the store to 0 (§3.2). A continuous cost (boost, and later the
## suit) accrues fractional QE per purpose and debits a whole QE as it
## crosses each threshold.

signal changed(amount: int, capacity: int)
signal low_power_changed(low: bool)

## The low-power line is this fraction of capacity, rounded up (§3.2).
const LOW_POWER_FRACTION := 0.1
## The pilot light never charges the store above this many QE (§3.2).
const PILOT_CAP := 25
## How often the pilot light adds one QE, seconds (§3.2).
const PILOT_PERIOD := 5.0

var amount: int
var capacity: int

## Fractional QE accrued so far, per purpose, toward spend_continuous()'s
## next whole-QE debit.
var _continuous: Dictionary = {}
var _pilot_elapsed := 0.0
var _was_low_power := false

func _init(starting_capacity: int = 0, starting_amount: int = 0) -> void:
	capacity = maxi(starting_capacity, 0)
	amount = clampi(starting_amount, 0, capacity)
	_was_low_power = is_low_power()

## The low-power line, in QE: 10% of capacity, rounded up (120 on the
## starter's 1,200).
func line() -> int:
	return ceili(capacity * LOW_POWER_FRACTION)

## True while the store is below the line. Full power returns exactly at
## the line (§3.2, §8.3) -- never below it.
func is_low_power() -> bool:
	return amount < line()

## How much more the store can hold before it is full.
func room() -> int:
	return capacity - amount

func can_spend(n: int) -> bool:
	return n >= 0 and n <= amount

## Spends `n` whole QE for `purpose`, all or nothing, down to 0. Refuses
## (false) and changes nothing if the store does not hold enough.
func spend(n: int, _purpose: StringName) -> bool:
	if not can_spend(n):
		return false
	if n == 0:
		return true
	amount -= n
	_settle()
	return true

## Accrues `cost` QE toward a whole-QE debit for `purpose`, spending it the
## moment it reaches one -- so a per-second cost like boost's still comes
## out in whole QE (§3.2). Several purposes accrue independently. Refuses
## (false) without losing the accrued fraction if the store does not hold
## enough for the debit.
func spend_continuous(cost: float, purpose: StringName) -> bool:
	var pending: float = _continuous.get(purpose, 0.0) + cost
	var whole := floori(pending)
	if whole <= 0:
		_continuous[purpose] = pending
		return true
	if not spend(whole, purpose):
		_continuous[purpose] = pending
		return false
	_continuous[purpose] = pending - whole
	return true

## Credits `n` whole QE from `source`, refusing (false) an overflow rather
## than wasting the excess (§3.2's *STORE FULL*).
func credit(n: int, _source: StringName) -> bool:
	if n < 0 or n > room():
		return false
	if n == 0:
		return true
	amount += n
	_settle()
	return true

## Removes up to `n` whole QE from `source`, down to 0, and returns how
## much actually came out.
func drain(n: int, _source: StringName) -> int:
	var taken := clampi(n, 0, amount)
	if taken == 0:
		return 0
	amount -= taken
	_settle()
	return taken

## The pilot light (§3.2): below PILOT_CAP, credits one QE every
## PILOT_PERIOD seconds, from &"pilot", and never above PILOT_CAP.
func tick(delta: float) -> void:
	if amount >= PILOT_CAP:
		_pilot_elapsed = 0.0
		return
	_pilot_elapsed += delta
	while _pilot_elapsed >= PILOT_PERIOD and amount < PILOT_CAP:
		_pilot_elapsed -= PILOT_PERIOD
		credit(1, &"pilot")
	if amount >= PILOT_CAP:
		_pilot_elapsed = 0.0

## A new capacity from the ship's blocks (a rebuild, §3.2): clamps the
## amount down if it no longer fits, but never restocks it.
func set_capacity(c: int) -> void:
	capacity = maxi(c, 0)
	amount = clampi(amount, 0, capacity)
	_settle()

func _settle() -> void:
	changed.emit(amount, capacity)
	var low := is_low_power()
	if low != _was_low_power:
		_was_low_power = low
		low_power_changed.emit(low)
