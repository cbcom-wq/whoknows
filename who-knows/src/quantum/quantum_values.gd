class_name QuantumValues
extends RefCounted

## Constants that price the quantum economy (quantum energy spec §3.3, §4,
## §8). make_cost() reads ItemDefinition.quantum_value, which does not exist
## until Task 5 -- reading it now would error, so it is not defined here
## (controller ruling R3). Task 5 adds it alongside the property.

## Boost's running cost, QE per second (spec §8.2).
const BOOST_COST := 5.0
## Making costs this many times an item's value (spec §3.3, §4.3).
const MAKE_MARKUP := 2
## The share of every thruster's force and every torque the core still
## delivers in low power (spec §8.3).
const LOW_POWER_AUTHORITY := 0.5
