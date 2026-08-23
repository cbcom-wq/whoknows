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
## Newton-metres available about (pitch, yaw, roll) from RCS and main engines.
var torque_budget: Vector3 = Vector3.ZERO
## Net torque induced by a full forward burn. Non-zero means the ship
## fights itself under acceleration.
var torque_imbalance: Vector3 = Vector3.ZERO
var power_gen: float = 0.0
var power_draw: float = 0.0

static func compute(grid: ShipGrid, catalog: BlockCatalog) -> ShipStats:
	var s := ShipStats.new()
	var entries := _gather(grid, catalog)
	s._accumulate_mass(entries)
	s._accumulate_inertia(entries)
	s._accumulate_power(entries)
	s._accumulate_thrust(entries)
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

func _accumulate_thrust(entries: Array) -> void:
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

		# Torque about the centre of mass from a full forward burn.
		if f.z < 0.0:
			var r: Vector3 = e["center"] - center_of_mass
			torque_imbalance += r.cross(f)

	torque_budget = Vector3(
		thrust_budget[&"vertical"], thrust_budget[&"lateral"], thrust_budget[&"lateral"]
	) * ShipGrid.CELL_SIZE
