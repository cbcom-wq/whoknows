class_name ComputerContext
extends RefCounted

## What a bridge computer's pages may read
## (docs/superpowers/specs/2026-09-25-bridge-computer-design.md §3.5): the
## ship binds one to each table after every rebuild. Any field may be null in
## a test, and a page shows dashes rather than fail.

var sensors: ShipSensors
var store: QuantumStore
var stats: ShipStats
var hull: Node3D
var exterior_builder: ExteriorBuilder
## Whoever last pressed one of the table's buttons.
var operator: Node
var time := 0.0

## Where `point` is from the hull, in the hull's own axes: the map's frame
## (spec §5.1). The floating origin moves the hull and the universe's origin
## together, so a shift changes nothing here.
func relative(point: UniversePoint) -> Vector3:
	return relative_in(map_frame(), point)

## From the engine into the map's frame: the hull's transform, undone. Work
## it out once a frame and pass it to relative_in for each contact.
func map_frame() -> Transform3D:
	if hull == null:
		return Transform3D.IDENTITY
	return hull.global_transform.orthonormalized().affine_inverse()

func relative_in(frame: Transform3D, point: UniversePoint) -> Vector3:
	if sensors == null or sensors.universe == null or hull == null or point == null:
		return Vector3.ZERO
	return frame * sensors.universe.to_engine(point)
