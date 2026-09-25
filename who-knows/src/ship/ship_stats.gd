class_name ShipStats
extends RefCounted

## Everything derived from the grid. Recomputed once per mutation on
## `cell_changed`, never per frame — at 150 blocks this is trivial.

const KG_PER_TONNE := 1000.0
const N_PER_KN := 1000.0

var total_mass_kg: float = 0.0
## Centre of mass in grid-local metres, relative to the grid origin.
var center_of_mass: Vector3 = Vector3.ZERO
## Moment of inertia about each local axis, kg·m².
var inertia: Vector3 = Vector3.ZERO
## Newtons available along each axis.
var thrust_budget: Dictionary = {
	&"forward": 0.0, &"reverse": 0.0, &"lateral": 0.0, &"vertical": 0.0,
}
## Newton-metres the pilot can command about (pitch, yaw, roll), in either
## direction. Only RCS -- thrust along local X or Y -- counts: the main
## engines fire along the axis the pilot is translating on, so they are not
## available to steer with. Each axis takes the *smaller* of its two
## directions, because authority you only have one way is not authority:
## a lone nose-up thruster cannot pitch back down.
var torque_budget: Vector3 = Vector3.ZERO
## Net torque induced by a full forward burn. Non-zero means the ship
## fights itself under acceleration.
var torque_imbalance: Vector3 = Vector3.ZERO
var power_gen: float = 0.0
var power_draw: float = 0.0
## QE the ship's quantum cells can hold, summed like power.
var quantum_capacity: int = 0

static func compute(grid: ShipGrid, catalog: BlockCatalog) -> ShipStats:
	var s := ShipStats.new()
	var entries := _gather(grid, catalog)
	s._accumulate_mass(entries)
	s._accumulate_inertia(entries)
	s._accumulate_power(entries)
	s._accumulate_thrust(entries)
	s._accumulate_quantum(entries)
	return s

## Returns [{def, coord, center, force}] once so each pass can reuse it.
static func _gather(grid: ShipGrid, catalog: BlockCatalog) -> Array:
	var out: Array = []
	for coord in grid.coords():
		var inst := grid.get_block(coord)
		var def := catalog.get_def(inst.block_id)
		if def == null:
			continue
		var force := Vector3.ZERO
		if def.thrust_kn > 0.0:
			var basis := BlockOrientation.basis_for(inst.orientation)
			force = basis * Vector3(0, 0, -1) * def.thrust_kn * N_PER_KN
		out.append({
			"def": def,
			"coord": coord,
			"center": ShipGrid.cell_center(coord),
			"force": force,
		})
	return out

func _accumulate_mass(entries: Array) -> void:
	var weighted := Vector3.ZERO
	for e in entries:
		var kg: float = e["def"].mass_t * KG_PER_TONNE
		total_mass_kg += kg
		weighted += e["center"] * kg
	if total_mass_kg > 0.0:
		center_of_mass = weighted / total_mass_kg

func _accumulate_inertia(entries: Array) -> void:
	# Each block is a solid cube (self term m·s²/6) displaced from the
	# centre of mass (parallel axis term). Accurate enough to make turn
	# rates feel right, and cheap.
	var self_factor := (ShipGrid.CELL_SIZE * ShipGrid.CELL_SIZE) / 6.0
	for e in entries:
		var kg: float = e["def"].mass_t * KG_PER_TONNE
		var r: Vector3 = e["center"] - center_of_mass
		inertia.x += kg * (self_factor + r.y * r.y + r.z * r.z)
		inertia.y += kg * (self_factor + r.x * r.x + r.z * r.z)
		inertia.z += kg * (self_factor + r.x * r.x + r.y * r.y)

func _accumulate_power(entries: Array) -> void:
	for e in entries:
		power_gen += e["def"].power_gen
		power_draw += e["def"].power_draw

func _accumulate_quantum(entries: Array) -> void:
	for e in entries:
		quantum_capacity += e["def"].quantum_capacity

func _accumulate_thrust(entries: Array) -> void:
	# Attitude authority, accumulated per axis and per direction so the two
	# can be compared at the end. See torque_budget above.
	var nose_up := Vector3.ZERO
	var nose_down := Vector3.ZERO

	for e in entries:
		var f: Vector3 = e["force"]
		if f.is_zero_approx():
			continue
		# Bin the force magnitude into the axis it mostly pushes along.
		if f.z < 0.0:
			thrust_budget[&"forward"] += absf(f.z)
		else:
			thrust_budget[&"reverse"] += absf(f.z)
		thrust_budget[&"lateral"] += absf(f.x)
		thrust_budget[&"vertical"] += absf(f.y)

		var r: Vector3 = e["center"] - center_of_mass

		# Torque about the centre of mass from a full forward burn.
		if f.z < 0.0:
			torque_imbalance += r.cross(f)

		if is_zero_approx(f.x) and is_zero_approx(f.y):
			continue   # a main engine: thrust, not steering
		var torque := r.cross(f)
		nose_up += Vector3(maxf(torque.x, 0.0), maxf(torque.y, 0.0), maxf(torque.z, 0.0))
		nose_down += Vector3(-minf(torque.x, 0.0), -minf(torque.y, 0.0), -minf(torque.z, 0.0))

	torque_budget = Vector3(
		minf(nose_up.x, nose_down.x),
		minf(nose_up.y, nose_down.y),
		minf(nose_up.z, nose_down.z)
	)
