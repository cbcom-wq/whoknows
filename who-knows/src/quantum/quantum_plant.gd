class_name QuantumPlant
extends Node

## Owns the ship's quantum store and drives its core(s) from it (quantum
## energy spec §3.2, §8): the one place live QE state lives, at Ship/Quantum.
## A rebuild frees every QuantumCore and QuantumMachine (Task 3's dressing)
## and builds new ones, so the plant outlives them all -- bind() again with
## whatever the rebuild produced and the store carries on unbothered.
##
## `flight_computer` is polled each physics tick for whether boost is
## actually applying right now, exactly the way RcsShow polls
## FlightComputer's commanded_force_local rather than being told about it
## (spec §8's "the core's state follows the store and boost"). Ship wires
## it once, in _ready(), alongside creating this node.

signal low_power_changed(low: bool)
## A credit landed: how much, and from where (spec §3.2's sources). Task 4
## only ever fires this from the pilot light; later tasks add converting,
## the hose and the suit charge.
signal credited(amount: int, source: StringName)

var store: QuantumStore
var cores: Array[QuantumCore] = []
var machines: Array[QuantumMachine] = []
var flight_computer: FlightComputer

var _last_state: StringName = &""

## Sets the capacity from the ship's blocks, drives every core from the
## result, and -- on the very first bind only -- starts the store at half
## capacity (spec §3.2). Later binds (a rebuild, or a capacity change) keep
## the same store and its amount, merely clamped to the new capacity.
func bind(new_cores: Array[QuantumCore], new_machines: Array[QuantumMachine], stats: ShipStats) -> void:
	cores = new_cores
	machines = new_machines
	if store == null:
		store = QuantumStore.new(stats.quantum_capacity, stats.quantum_capacity / 2)
		store.changed.connect(_on_store_changed)
		store.low_power_changed.connect(func(low: bool) -> void: low_power_changed.emit(low))
	else:
		store.set_capacity(stats.quantum_capacity)
	_drive_cores()

func _physics_process(delta: float) -> void:
	if store == null:
		return
	var before := store.amount
	store.tick(delta)
	if store.amount != before:
		credited.emit(store.amount - before, &"pilot")
	_drive_cores()

func _on_store_changed(_amount: int, _capacity: int) -> void:
	_drive_cores()

## The gauge follows the store every tick; the state (full/boost/low_power)
## only when it actually changes, so an unchanging state never re-triggers
## QuantumCore.set_state()'s per-call bookkeeping (spec §8; until Task 11
## this is the whole of it -- no dimming, no restore show).
func _drive_cores() -> void:
	if store == null or store.capacity <= 0:
		return
	var fraction := float(store.amount) / float(store.capacity)
	var line_fraction := float(store.line()) / float(store.capacity)
	for core in cores:
		core.set_fill(fraction, line_fraction)
	var boosting := flight_computer != null and flight_computer.boosting
	var state: StringName = &"boost" if boosting else (&"low_power" if store.is_low_power() else &"full")
	if state != _last_state:
		_last_state = state
		for core in cores:
			core.set_state(state)
