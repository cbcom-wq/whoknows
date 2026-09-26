class_name StrayField
extends Node3D

## Every stray: an item adrift outside that no seed accounts for
## (docs/superpowers/specs/2026-09-26-saving-design.md §7). Salvage in its
## cloud is not one -- SalvageField and its ledger account for it.
##
## Nothing makes strays yet: hands are suspended on a spacewalk and only
## salvage is ever outside. Whatever first puts an item outside -- carrying or
## throwing things out of the airlock -- calls adopt(item), and whatever
## brings one back aboard or swallows it calls let_go(item).
##
## The floating origin (CLAUDE.md): the field sits under Outside at the
## identity and is never moved. Each live stray is a member of
## Universe.EXTERIOR_SPACE of its own, directly under the field, and leaves the
## group before it goes. A stray further than SalvageField.FREE_BEYOND from
## you is unloaded -- its node freed, its last place kept -- and it stands
## still until you come back within SalvageField.LOAD_WITHIN, as the rocks do.

var universe: Universe
var catalog: ItemCatalog
var ledger := StrayLedger.new()

var _live := {}   # int id -> Item
var _hooks := {}  # int id -> the Callable its item's `consumed` calls

func setup(p_universe: Universe, p_catalog: ItemCatalog) -> void:
	universe = p_universe
	catalog = p_catalog

## Takes `item`, already outside and in space (Item.set_space), as a stray:
## under this field, in the shift group, remembered. Returns its id.
func adopt(item: Item) -> int:
	var at := item.global_transform
	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	add_child(item, true)
	item.global_transform = at
	item.add_to_group(Universe.EXTERIOR_SPACE)
	var id := ledger.add(item.definition.id, item.variety(), universe.to_universe(at.origin), at.basis,
		item.linear_velocity, item.angular_velocity, _use_of(item))
	_track(id, item)
	return id

## Lets `item` stop being a stray -- carried back aboard -- out of the shift
## group and the ledger, left in the tree for the caller to move.
func let_go(item: Item) -> void:
	for id: int in _live.keys():
		if _live[id] == item:
			_untrack(id)
			ledger.remove(id)
			item.remove_from_group(Universe.EXTERIOR_SPACE)
			return

## The live stray with id `id`, or null while it is unloaded or gone.
func live(id: int) -> Item:
	var item: Variant = _live.get(id)
	return item if is_instance_valid(item) else null

func count() -> int:
	return ledger.entries.size()

func _physics_process(delta: float) -> void:
	tick(delta)

## Forgets strays you have been far from for long enough, and loads and
## unloads the rest as you come and go. Called every physics tick; tests
## call it directly.
func tick(delta: float) -> void:
	if universe == null or not is_instance_valid(universe.focus):
		return
	sync()
	var focus := universe.to_universe(universe.focus.global_position)
	for id in ledger.tick(delta, focus):
		_unload(id)
	for id: int in ledger.entries:
		var far := (ledger.entries[id]["at"] as UniversePoint).minus(focus).length()
		if not _live.has(id) and far <= SalvageField.LOAD_WITHIN:
			_load(id)
		elif _live.has(id) and far > SalvageField.FREE_BEYOND:
			_unload(id)

## Copies where each live stray is, and how it moves, into the ledger.
func sync() -> void:
	for id: int in _live.keys():
		var item: Variant = _live[id]
		if not is_instance_valid(item) or not ledger.has(id):
			_untrack(id)
			ledger.remove(id)
			continue
		var e: Dictionary = ledger.entries[id]
		e["at"] = universe.to_universe(item.global_position)
		e["turn"] = item.global_basis.orthonormalized()
		e["v"] = item.linear_velocity
		e["w"] = item.angular_velocity
		e["use"] = _use_of(item)

func to_dict() -> Dictionary:
	sync()
	return ledger.to_dict()

## Replaces every stray with the saved ones; those near you load at once.
func from_dict(d: Dictionary) -> void:
	for id: int in _live.keys():
		_unload(id)
	ledger.from_dict(d)
	tick(0.0)

func _load(id: int) -> void:
	var e: Dictionary = ledger.entries[id]
	var item := Item.from_dict({"kind": String(e["kind"]), "variety": e["variety"], "use": e["use"]}, catalog)
	if item == null:
		ledger.remove(id)
		return
	item.set_space(true)
	item.can_sleep = false
	item.transform = Transform3D(e["turn"], universe.to_engine(e["at"]))
	item.linear_velocity = e["v"]
	item.angular_velocity = e["w"]
	add_child(item, true)
	item.add_to_group(Universe.EXTERIOR_SPACE)
	_track(id, item)

## Frees a live stray, out of the group first. Its entry stays unless the
## ledger has already forgotten it.
func _unload(id: int) -> void:
	var item: Variant = _live.get(id)
	_untrack(id)
	if not is_instance_valid(item):
		return
	item.remove_from_group(Universe.EXTERIOR_SPACE)
	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	item.free()

func _track(id: int, item: Item) -> void:
	_live[id] = item
	_hooks[id] = _on_consumed.bind(id)
	item.consumed.connect(_hooks[id])

func _untrack(id: int) -> void:
	var item: Variant = _live.get(id)
	var hook: Variant = _hooks.get(id)
	if is_instance_valid(item) and hook != null and item.consumed.is_connected(hook):
		item.consumed.disconnect(hook)
	_live.erase(id)
	_hooks.erase(id)

func _on_consumed(id: int) -> void:
	var item: Variant = _live.get(id)
	_untrack(id)
	ledger.remove(id)
	if is_instance_valid(item):
		item.remove_from_group(Universe.EXTERIOR_SPACE)

static func _use_of(item: Item) -> Dictionary:
	return item.use_node.save() if item.use_node != null else {}
