class_name SalvageField
extends Node3D

## Every salvage cloud (docs/superpowers/specs/2026-09-24-quantum-energy-design.md
## §10.1-§10.3, §14): where each is, what is in it, and loading and freeing its
## items as the focus comes and goes. The only thing that knows where salvage
## is.
##
## A cloud has an id, a centre as a UniversePoint and a list of items, each
## with an index, a kind, a pose and a tumble. Everything about a cloud comes
## from the world seed and its id, through AsteroidRecipe's integer hash, so it
## is the same every time it loads, on any machine.
##
## The floating origin (asteroids spec §4, CLAUDE.md): the field lives under
## Outside at the identity and is never moved and never a member itself. Each
## item it spawns is a member of Universe.EXTERIOR_SPACE of its own, directly
## under the field, and leaves the group before it is freed -- a member must
## never sit under another member, which would shift it twice.
##
## What is taken -- an item that says it was consumed, swallowed by the hose
## -- goes in the ledger, and a cloud that loads again leaves it out.

## The near cloud's id: 12 items out of the starter's airlock, behind its
## stern, so the first spacewalk has something to gather (spec §10.2).
const NEAR := &"near"
const NEAR_COUNT := 12
## The near cloud's centre, this far aft of the stern along the airlock's line,
## and its items within NEAR_SPREAD of it: every one 14-38 m aft, inside the
## spec's 12-40 m and the 80 m the start keeps clear of rocks.
const NEAR_AFT := 26.0
const NEAR_SPREAD := 12.0
## A cloud's items are spawned when the focus comes within LOAD_WITHIN of its
## centre, and freed when it goes beyond FREE_BEYOND (spec §10.2).
const LOAD_WITHIN := 3000.0
const FREE_BEYOND := 4000.0
## Each item tumbles in place, between these rates, and never drifts.
const TUMBLE_MIN := deg_to_rad(4.0)
const TUMBLE_MAX := deg_to_rad(20.0)
## No two items of a cloud closer than this, centre to centre, so no two
## bodies start overlapping and fly apart.
const MIN_GAP := 1.5
## The mix, by weight (spec §10.2).
const MIX := [[&"rock_chunk", 4], [&"scrap_plate", 3], [&"ice_chunk", 3], [&"wire_coil", 2],
	[&"broken_module", 1]]
## Keeps salvage's seeds apart from the rocks' cell seeds.
const _SALT := 0x5A1FA6E

var universe: Universe
var catalog: ItemCatalog
var world_seed := 0
## What has been taken, for the session (spec §10.3).
var ledger := SalvageLedger.new()

var _centres := {}   # StringName cloud id -> UniversePoint
var _loaded := {}    # StringName cloud id -> {int index: Item}, in index order

func setup(p_universe: Universe, p_catalog: ItemCatalog, p_world_seed: int) -> void:
	universe = p_universe
	catalog = p_catalog
	world_seed = p_world_seed

## Fixes the near cloud's centre, NEAR_AFT behind `stern` -- a frame on the
## stern at the airlock's line, its +z pointing aft, out of the hatch -- as a
## universe point, so it stays put however far the origin moves. Loads it at
## once if the focus is near.
func add_near_cloud(stern: Transform3D) -> void:
	_centres[NEAR] = universe.to_universe(stern * Vector3(0, 0, NEAR_AFT))
	update()

func centre(cloud_id: StringName) -> UniversePoint:
	return _centres.get(cloud_id)

## A cloud's items, from the seed and its id alone: {index, kind, pose (from
## the centre), tumble (an angular velocity), variety (0..1, for the look and
## its glint)}, in index order.
func cloud_items(cloud_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if cloud_id != NEAR:
		push_error("SalvageField: no cloud called %s" % cloud_id)
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = cloud_seed(world_seed, cloud_id)
	for i in NEAR_COUNT:
		var kind := _kind(rng.randi_range(0, _mix_total() - 1))
		var at := _place(rng, NEAR_SPREAD, out)
		var turn := Basis.from_euler(Vector3(rng.randf_range(-PI, PI), rng.randf_range(-PI, PI),
			rng.randf_range(-PI, PI)))
		var axis := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		if axis.length_squared() < 0.0001:
			axis = Vector3.UP
		var spin := axis.normalized() * rng.randf_range(TUMBLE_MIN, TUMBLE_MAX)
		out.append({"index": i, "kind": kind, "pose": Transform3D(turn, at), "tumble": spin,
			"variety": rng.randf()})
	return out

func is_loaded(cloud_id: StringName) -> bool:
	return _loaded.has(cloud_id)

## The cloud's items now in the world, in index order: none if it is not
## loaded, and none that were taken. One freed some other way than
## Item.consume is simply gone, and comes back when its cloud next loads.
func loaded_items(cloud_id: StringName) -> Array[Item]:
	var out: Array[Item] = []
	for item in _loaded.get(cloud_id, {}).values():
		if is_instance_valid(item):
			out.append(item)
	return out

## A cloud's seed: splitmix64 over the world seed and the id's bytes, written
## out like AsteroidRecipe.cell_seed rather than the engine's hash(), which is
## not promised to stay the same between engine versions.
static func cloud_seed(p_world_seed: int, cloud_id: StringName) -> int:
	var h := AsteroidRecipe.mix(p_world_seed ^ _SALT)
	for b in String(cloud_id).to_utf8_buffer():
		h = AsteroidRecipe.mix(h ^ AsteroidRecipe.mix(b + _SALT))
	return h

func _physics_process(_delta: float) -> void:
	update()

## Loads every cloud the focus has come within LOAD_WITHIN of, and frees every
## one it has gone beyond FREE_BEYOND of.
func update() -> void:
	if universe == null or not is_instance_valid(universe.focus):
		return
	var focus := universe.to_universe(universe.focus.global_position)
	for id: StringName in _centres:
		var far := (_centres[id] as UniversePoint).minus(focus).length()
		if not is_loaded(id) and far <= LOAD_WITHIN:
			_load(id)
		elif is_loaded(id) and far > FREE_BEYOND:
			_free(id)

func _load(cloud_id: StringName) -> void:
	var items := {}
	_loaded[cloud_id] = items
	var at := universe.to_engine(_centres[cloud_id])
	for e in cloud_items(cloud_id):
		var index: int = e["index"]
		if ledger.is_taken(cloud_id, index):
			continue
		var def := catalog.get_def(e["kind"])
		if def == null:
			push_error("SalvageField: no item called %s" % e["kind"])
			continue
		var item := Item.new()
		item.setup(def, e["variety"])
		item.set_space(true)
		var pose: Transform3D = e["pose"]
		item.transform = Transform3D(pose.basis, at + pose.origin)
		item.angular_velocity = e["tumble"]
		# Tumbling slower than the engine's sleep threshold, it would stop.
		item.can_sleep = false
		item.consumed.connect(_on_consumed.bind(cloud_id, index))
		add_child(item, true)
		item.add_to_group(Universe.EXTERIOR_SPACE)
		items[index] = item

## Frees what is left of a cloud, each item out of the group first.
func _free(cloud_id: StringName) -> void:
	for entry in _loaded[cloud_id].values():
		if not is_instance_valid(entry) or entry.get_parent() != self:
			continue
		var item: Item = entry
		item.remove_from_group(Universe.EXTERIOR_SPACE)
		remove_child(item)
		item.free()
	_loaded.erase(cloud_id)

## Swallowed (Item.consume): into the ledger once, and out of the group before
## Item.consume frees it.
func _on_consumed(cloud_id: StringName, index: int) -> void:
	ledger.take(cloud_id, index)
	var items: Dictionary = _loaded.get(cloud_id, {})
	var item: Variant = items.get(index)
	items.erase(index)
	if is_instance_valid(item):
		(item as Item).remove_from_group(Universe.EXTERIOR_SPACE)

static func _mix_total() -> int:
	var total := 0
	for m in MIX:
		total += m[1]
	return total

## The kind a roll of 0 to _mix_total() - 1 lands on.
static func _kind(roll: int) -> StringName:
	for m in MIX:
		roll -= m[1]
		if roll < 0:
			return m[0]
	return MIX[0][0]

## A seeded place within `spread` of the centre, MIN_GAP clear of every item
## placed so far. Candidates are drawn until one fits: a 12 m ball holds a
## dozen items with room to spare, so one always does long before the cap.
static func _place(rng: RandomNumberGenerator, spread: float, placed: Array[Dictionary]) -> Vector3:
	var at := Vector3.ZERO
	for attempt in 256:
		at = Vector3(rng.randf_range(-spread, spread), rng.randf_range(-spread, spread),
			rng.randf_range(-spread, spread))
		if at.length() <= spread and _clear_of(at, placed):
			return at
	push_error("SalvageField: no room for another item within %.0f m" % spread)
	return at

static func _clear_of(at: Vector3, placed: Array[Dictionary]) -> bool:
	for e in placed:
		if (e["pose"] as Transform3D).origin.distance_to(at) < MIN_GAP:
			return false
	return true
