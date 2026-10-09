class_name BaseValidator
extends RefCounted

## A base's rules (habitat modules spec §9.1): the ship validator's structural
## ones, none of its flight ones. Until corridors (Phase D), each module is
## checked on its own, and modules stand at least a cell apart so their
## interiors never merge without a corridor.

static func validate(site: BaseSite, catalog: BlockCatalog) -> Array:
	var issues: Array = []
	if site.hubs().is_empty():
		issues.append(ShipValidator.Issue.new(ShipValidator.Severity.ERROR, &"HAS_HUB", "A base needs a hub."))
	var owner := site.occupied()
	for i in site.modules.size():
		var cells := site.cells_of(i)
		_check_connected(cells, issues)
		for c in cells:
			for n: Vector3i in ShipGrid.FACE_OFFSETS:
				if owner.has(c + n) and owner[c + n] != i:
					issues.append(ShipValidator.Issue.new(ShipValidator.Severity.ERROR, &"APART",
						"Modules %d and %d touch at %s." % [i, owner[c + n], c], c))
					break
	var g := site.grid()
	for h in site.hubs():
		_check_hub(g, site.cells_of(h), catalog, issues)
	return issues

static func ok(issues: Array) -> bool:
	return ShipValidator.can_launch(issues)

static func _check_connected(cells: Array[Vector3i], issues: Array) -> void:
	if cells.is_empty():
		return
	var mine := {}
	for c in cells:
		mine[c] = true
	var reached := {cells[0]: true}
	var queue: Array[Vector3i] = [cells[0]]
	while not queue.is_empty():
		var c: Vector3i = queue.pop_back()
		for n: Vector3i in ShipGrid.FACE_OFFSETS:
			if mine.has(c + n) and not reached.has(c + n):
				reached[c + n] = true
				queue.append(c + n)
	if reached.size() != cells.size():
		issues.append(ShipValidator.Issue.new(ShipValidator.Severity.ERROR, &"MODULE_CONNECTED",
			"A module is in pieces.", cells[0]))

## The hub's airlock cycles, and every walkable cell of it is reachable on
## foot from the airlock.
static func _check_hub(g: ShipGrid, cells: Array[Vector3i], catalog: BlockCatalog, issues: Array) -> void:
	var lock := Vector3i.ZERO
	var found := false
	for c in cells:
		if g.get_block(c).block_id == AirlockSite.AIRLOCK_ID:
			lock = c
			found = true
	if not found or AirlockSite.hatch_normal(g, lock) == Vector3i.ZERO:
		issues.append(ShipValidator.Issue.new(ShipValidator.Severity.ERROR, &"AIRLOCK_HATCH",
			"The hub's airlock needs exactly one side onto open space.", lock))
		return
	var graph := DeckGraph.build(g, catalog)
	var home := graph.component_of(lock)
	for c in cells:
		if graph.is_walkable(c) and graph.component_of(c) != home:
			issues.append(ShipValidator.Issue.new(ShipValidator.Severity.ERROR, &"REACHABLE",
				"%s cannot be reached from the hub's airlock." % c, c))
			return
