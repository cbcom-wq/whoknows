class_name ShipValidator
extends RefCounted

## The five build rules from spec §6.1. Rules 1-4 are errors and block
## launch; rule 5 is a warning because a power deficit becomes the
## brownout mechanic rather than an invalid ship.

enum Severity { ERROR, WARNING }

const CORE_ID := &"core"
const PILOT_SEAT_ID := &"pilot_seat"

class Issue extends RefCounted:
	var severity: Severity
	var code: StringName
	var message: String
	var coord: Vector3i

	func _init(p_severity: Severity, p_code: StringName, p_message: String,
			p_coord: Vector3i = Vector3i.ZERO) -> void:
		severity = p_severity
		code = p_code
		message = p_message
		coord = p_coord

static func validate(grid: ShipGrid, catalog: BlockCatalog) -> Array:
	var issues: Array = []
	var cores := _find_all(grid, CORE_ID)
	var seats := _find_all(grid, PILOT_SEAT_ID)

	_check_single_core(cores, issues)
	if cores.size() == 1:
		_check_all_connected(grid, cores[0], issues)
	_check_has_pilot_seat(seats, issues)
	if seats.size() >= 1:
		_check_mounts_reachable(grid, catalog, seats[0], issues)
	_check_power_margin(grid, catalog, issues)
	return issues

static func can_launch(issues: Array) -> bool:
	for issue in issues:
		if issue.severity == Severity.ERROR:
			return false
	return true

static func _find_all(grid: ShipGrid, id: StringName) -> Array:
	var out: Array[Vector3i] = []
	for coord in grid.coords():
		if grid.get_block(coord).block_id == id:
			out.append(coord)
	return out

static func _check_single_core(cores: Array, issues: Array) -> void:
	if cores.size() == 1:
		return
	if cores.is_empty():
		issues.append(Issue.new(
			Severity.ERROR, &"SINGLE_CORE", "Ship has no Ship Core."
		))
	else:
		issues.append(Issue.new(
			Severity.ERROR, &"SINGLE_CORE",
			"Ship has %d Ship Cores; exactly one is required." % cores.size(),
			cores[1]
		))

static func _check_all_connected(grid: ShipGrid, core: Vector3i, issues: Array) -> void:
	var reached := {core: true}
	var queue: Array[Vector3i] = [core]
	while not queue.is_empty():
		var coord: Vector3i = queue.pop_back()
		for n in grid.neighbours(coord):
			if grid.has_block(n) and not reached.has(n):
				reached[n] = true
				queue.append(n)
	for coord in grid.coords():
		if not reached.has(coord):
			issues.append(Issue.new(
				Severity.ERROR, &"ALL_CONNECTED",
				"Block at %s is not attached to the Ship Core." % coord, coord
			))
			return   # one report is enough; the editor highlights the set

static func _check_has_pilot_seat(seats: Array, issues: Array) -> void:
	if seats.is_empty():
		issues.append(Issue.new(
			Severity.ERROR, &"HAS_PILOT_SEAT", "Ship has no Pilot Seat."
		))

static func _check_mounts_reachable(grid: ShipGrid, catalog: BlockCatalog,
		seat: Vector3i, issues: Array) -> void:
	var graph := DeckGraph.build(grid, catalog)
	var seat_component := graph.component_of(seat)
	for coord in grid.coords():
		var def := catalog.get_def(grid.get_block(coord).block_id)
		if def == null or def.occupancy != BlockDefinition.Occupancy.MOUNT:
			continue
		if graph.component_of(coord) != seat_component:
			issues.append(Issue.new(
				Severity.ERROR, &"MOUNTS_REACHABLE",
				"%s at %s cannot be reached on foot from the Pilot Seat."
					% [def.display_name, coord],
				coord
			))

static func _check_power_margin(grid: ShipGrid, catalog: BlockCatalog,
		issues: Array) -> void:
	var gen := 0.0
	var draw := 0.0
	for coord in grid.coords():
		var def := catalog.get_def(grid.get_block(coord).block_id)
		if def == null:
			continue
		gen += def.power_gen
		draw += def.power_draw
	if draw > gen:
		issues.append(Issue.new(
			Severity.WARNING, &"POWER_MARGIN",
			"Power draw %.1f MW exceeds generation %.1f MW." % [draw, gen]
		))
