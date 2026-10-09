class_name ModuleCatalog
extends RefCounted

## The modules of Phases B and C (habitat modules spec §6.1-§6.3), in code so
## no hand-written .tres can drop a line (CLAUDE.md). Orientation 0 faces -z;
## 4 faces +z. Storey 1 is the roof: gravity plating and storage live there,
## above the walkable floor.

const HUB := &"hub"
const DRILL := &"drill"
const STORE := &"store"

const O_FORWARD := 0
const O_STERN := 4

static var _defs: Dictionary = {}

static func kinds() -> Array[StringName]:
	return [HUB, DRILL, STORE]

static func get_def(kind: StringName) -> ModuleDefinition:
	if _defs.is_empty():
		_build()
	return _defs.get(kind)

static func _build() -> void:
	# The hub (§6.1): the terminal and the core along the back, the airlock in
	# the middle of the front opening out of +z, a deck either side of it. Its
	# store is one quantum cell (400) in the roof, over the core.
	var hub := ModuleDefinition.new(HUB, "Hub", Vector3i(3, 2, 2), &"hub_package")
	hub.put(Vector3i(0, 0, 0), &"quantum_machine", O_STERN)
	hub.put(Vector3i(1, 0, 0), &"deck")
	hub.put(Vector3i(2, 0, 0), &"quantum_core", O_STERN)
	hub.put(Vector3i(0, 0, 1), &"deck")
	hub.put(Vector3i(1, 0, 1), &"airlock")
	hub.put(Vector3i(2, 0, 1), &"deck")
	hub.put(Vector3i(0, 1, 0), &"hull")
	hub.put(Vector3i(1, 1, 0), &"grav_plating")
	hub.put(Vector3i(2, 1, 0), &"quantum_cell")
	hub.put(Vector3i(0, 1, 1), &"hull")
	hub.put(Vector3i(1, 1, 1), &"hull")
	hub.put(Vector3i(2, 1, 1), &"hull")
	_defs[HUB] = hub
	# The drill (§6.2): a control room of two cells over the drill head.
	var drill := ModuleDefinition.new(DRILL, "Drill", Vector3i(1, 2, 2), &"drill_package")
	drill.put(Vector3i(0, 0, 0), &"deck")
	drill.put(Vector3i(0, 0, 1), &"deck")
	drill.put(Vector3i(0, 1, 0), &"grav_plating")
	drill.put(Vector3i(0, 1, 1), &"hull")
	_defs[DRILL] = drill
	# The store (§6.3): one room, a quantum tank in the roof. Gravity plating
	# sits on storey 1 so the floor gets gravity; the tank sits above it.
	var store := ModuleDefinition.new(STORE, "Store", Vector3i(1, 3, 1), &"store_package")
	store.put(Vector3i(0, 0, 0), &"deck")
	store.put(Vector3i(0, 1, 0), &"grav_plating")
	store.put(Vector3i(0, 2, 0), &"quantum_tank")
	_defs[STORE] = store
