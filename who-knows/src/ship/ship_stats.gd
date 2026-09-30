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

## Health and damage spec §4.4: what the ship had with nothing hurt, so that
## "crippled" measures what was lost, whatever the design.
var intact_forward: float = 0.0
var intact_torque: Vector3 = Vector3.ZERO
## Below CRIPPLED_BELOW of its intact forward thrust or of any turning axis it
## had, or with no working quantum core. It still flies on what is left.
var crippled := false
## "no thrust", "can't turn" or "no power"; "" when not crippled.
var crippled_reason := ""

const CRIPPLED_BELOW := 0.25
const QUANTUM_CORE := &"quantum_core"

static func compute(grid: ShipGrid, catalog: BlockCatalog) -> ShipStats:
	var s := ShipStats.new()
	var entries := _gather(grid, catalog)
	s._accumulate_mass(entries)
	s._accumulate_inertia(entries)
	s._accumulate_power(entries)
	s._accumulate_thrust(entries)
	s._accumulate_quantum(entries)
	s._judge_crippled(entries)
	return s

## Returns [{def, coord, center, force, output}] once so each pass can reuse
## it. `output` is the block's share of its function by stage (spec §4.1);
## `force` is at full output, and the passes scale it.
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
			"output": BlockDamage.output_of(BlockDamage.stage_of(inst, def)),
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
		power_gen += e["def"].power_gen * e["output"]
		power_draw += e["def"].power_draw * e["output"]

func _accumulate_quantum(entries: Array) -> void:
	for e in entries:
		quantum_capacity += roundi(e["def"].quantum_capacity * e["output"])

func _accumulate_thrust(entries: Array) -> void:
	var intact := _thrust(entries, false)
	intact_forward = intact[0][&"forward"]
	intact_torque = intact[2]
	var now := _thrust(entries, true)
	thrust_budget = now[0]
	torque_imbalance = now[1]
	torque_budget = now[2]

## [thrust_budget, torque_imbalance, torque_budget], with each block at its
## stage's output when `staged`, or all at full.
func _thrust(entries: Array, staged: bool) -> Array:
	var budget := {&"forward": 0.0, &"reverse": 0.0, &"lateral": 0.0, &"vertical": 0.0}
	var imbalance := Vector3.ZERO
	# Attitude authority, accumulated per axis and per direction so the two
	# can be compared at the end. See torque_budget above.
	var nose_up := Vector3.ZERO
	var nose_down := Vector3.ZERO

	for e in entries:
		var f: Vector3 = e["force"] * (e["output"] if staged else 1.0)
		if f.is_zero_approx():
			continue
		# Bin the force magnitude into the axis it mostly pushes along.
		if f.z < 0.0:
			budget[&"forward"] += absf(f.z)
		else:
			budget[&"reverse"] += absf(f.z)
		budget[&"lateral"] += absf(f.x)
		budget[&"vertical"] += absf(f.y)

		var r: Vector3 = e["center"] - center_of_mass

		# Torque about the centre of mass from a full forward burn.
		if f.z < 0.0:
			imbalance += r.cross(f)

		if is_zero_approx(f.x) and is_zero_approx(f.y):
			continue   # a main engine: thrust, not steering
		var torque := r.cross(f)
		nose_up += Vector3(maxf(torque.x, 0.0), maxf(torque.y, 0.0), maxf(torque.z, 0.0))
		nose_down += Vector3(-minf(torque.x, 0.0), -minf(torque.y, 0.0), -minf(torque.z, 0.0))

	var authority := Vector3(
		minf(nose_up.x, nose_down.x),
		minf(nose_up.y, nose_down.y),
		minf(nose_up.z, nose_down.z)
	)
	return [budget, imbalance, authority]

## Spec §4.4. An axis the ship never had authority on can't be lost; a ship
## with no quantum core at all (a test hull) isn't short of one.
func _judge_crippled(entries: Array) -> void:
	if intact_forward > 0.0 and thrust_budget[&"forward"] < intact_forward * CRIPPLED_BELOW:
		crippled_reason = "no thrust"
	for axis in 3:
		if crippled_reason == "" and intact_torque[axis] > 0.0 \
				and torque_budget[axis] < intact_torque[axis] * CRIPPLED_BELOW:
			crippled_reason = "can't turn"
	var cores := 0
	var working := 0
	for e in entries:
		if e["def"].id == QUANTUM_CORE:
			cores += 1
			if e["output"] > 0.0:
				working += 1
	if crippled_reason == "" and cores > 0 and working == 0:
		crippled_reason = "no power"
	crippled = crippled_reason != ""
