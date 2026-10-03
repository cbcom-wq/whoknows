class_name BlockDamage
extends RefCounted

## A block's stage from the damage it has taken (docs/superpowers/specs/
## 2026-09-29-health-and-damage-design.md §4), and the only code that writes
## BlockInstance.damage. Pure: grids and the catalog in, removals out.
##
## Intact under half its hp; damaged to its full hp, working at half; wrecked
## to one and a half, working not at all; gone past that, removed through
## ShipGrid.remove_many with any piece that no longer reaches the core.

enum Stage { INTACT, DAMAGED, WRECKED, GONE }

const DAMAGED_AT := 0.5
const WRECKED_AT := 1.0
const GONE_AT := 1.5
const OUTPUT := {Stage.INTACT: 1.0, Stage.DAMAGED: 0.5, Stage.WRECKED: 0.0, Stage.GONE: 0.0}
## Wrecked but never removed (spec §4.5): without the core there is no ship,
## without the seat no flying, and without an airlock no way back aboard. The
## ship does not know which airlock you came in by, so every one is kept.
const KEEP: Array[StringName] = [&"core", &"pilot_seat", &"airlock"]
const CORE := &"core"

static func stage_at(damage: float, hp: float) -> Stage:
	if hp <= 0.0:
		return Stage.INTACT
	var share := damage / hp
	if share >= GONE_AT:
		return Stage.GONE
	if share >= WRECKED_AT:
		return Stage.WRECKED
	if share >= DAMAGED_AT:
		return Stage.DAMAGED
	return Stage.INTACT

## A ceiling light under a block this hurt flickers (health and damage spec
## §9, the owner's call on 2026-10-03): under 20% of its health left, so late
## in damaged and all through wrecked.
const FLICKER_AT := 0.8

static func flickers(inst: BlockInstance, def: BlockDefinition) -> bool:
	if inst == null or def == null or def.hp <= 0:
		return false
	return inst.damage > float(def.hp) * FLICKER_AT

static func stage_of(inst: BlockInstance, def: BlockDefinition) -> Stage:
	if inst == null or def == null:
		return Stage.INTACT
	return stage_at(inst.damage, float(def.hp))

static func output_of(stage: Stage) -> float:
	return OUTPUT[stage]

## Deals `amount` to the block at `coord`. Returns every coord it removed:
## the block, if it is gone, and any piece cut off from the core with it.
static func apply(grid: ShipGrid, catalog: BlockCatalog, coord: Vector3i, amount: float,
		held: Dictionary = {}) -> Array[Vector3i]:
	return apply_many(grid, catalog, {coord: amount}, held)

## Deals every hit in `hits` (coord -> amount) at once: a crash lands on a
## cell and its neighbours together. Everything gone, and anything cut off by
## it, is removed in one remove_many, so the lot costs one rebuild.
##
## `held` (coord -> true) is the cabin's shell (health and damage spec §4.5,
## as amended 2026-10-02): those cells, like KEEP blocks, are wrecked but
## never knocked off, so the inside keeps its shape. A block whose loss would
## cut any of them off from the core stays wrecked too.
static func apply_many(grid: ShipGrid, catalog: BlockCatalog, hits: Dictionary,
		held: Dictionary = {}) -> Array[Vector3i]:
	var gone: Array[Vector3i] = []
	var before := {}
	for coord: Vector3i in hits:
		var inst := grid.get_block(coord)
		var def := catalog.get_def(inst.block_id) if inst != null else null
		var amount := float(hits[coord])
		if def == null or amount <= 0.0:
			continue
		var hp := float(def.hp)
		before[coord] = stage_at(inst.damage, hp)
		inst.damage += amount
		if KEEP.has(def.id) or held.has(coord):
			_hold_wrecked(inst, hp)
		var after := stage_at(inst.damage, hp)
		if after == Stage.GONE:
			gone.append(coord)
		elif after != before[coord]:
			grid.note_staged(coord, after)
	# One at a time, so a loss that would cut the cabin off is refused alone.
	var going: Array[Vector3i] = []
	for coord in gone:
		var trial := going.duplicate()
		trial.append(coord)
		if _cuts_any(cut_off(grid, trial), held):
			var inst := grid.get_block(coord)
			_hold_wrecked(inst, float(catalog.get_def(inst.block_id).hp))
			if before[coord] != Stage.WRECKED:
				grid.note_staged(coord, Stage.WRECKED)
		else:
			going.append(coord)
	if going.is_empty():
		return going
	var removed: Array[Vector3i] = going.duplicate()
	removed.append_array(cut_off(grid, going))
	grid.remove_many(removed)
	return removed

## Just short of gone: a kept block's wreck soaks everything after.
static func _hold_wrecked(inst: BlockInstance, hp: float) -> void:
	inst.damage = minf(inst.damage, hp * GONE_AT - 1.0)

static func _cuts_any(cut: Array[Vector3i], held: Dictionary) -> bool:
	for coord in cut:
		if held.has(coord):
			return true
	return false

## Mends up to `hp` of the block at `coord`; returns what it used.
static func repair(grid: ShipGrid, catalog: BlockCatalog, coord: Vector3i, hp: float) -> float:
	var inst := grid.get_block(coord)
	var def := catalog.get_def(inst.block_id) if inst != null else null
	if def == null or hp <= 0.0:
		return 0.0
	var before := stage_at(inst.damage, float(def.hp))
	var used := minf(hp, inst.damage)
	inst.damage -= used
	var after := stage_at(inst.damage, float(def.hp))
	if after != before:
		grid.note_staged(coord, after)
	return used

## Puts a block back at `coord`, wrecked (spec §8.2): the torch then welds it up.
static func rebuild(grid: ShipGrid, catalog: BlockCatalog, coord: Vector3i, block_id: StringName,
		orientation: int) -> void:
	var def := catalog.get_def(block_id)
	if def == null:
		return
	var inst := BlockInstance.new()
	inst.block_id = block_id
	inst.orientation = orientation
	inst.damage = float(def.hp) * WRECKED_AT
	grid.set_block(coord, inst)

## The blocks that would no longer reach the core once every cell in `gone`
## is removed. None when the grid has no core: nothing to be cut off from.
static func cut_off(grid: ShipGrid, gone: Array[Vector3i]) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var core = null
	for coord in grid.coords():
		if grid.get_block(coord).block_id == CORE:
			core = coord
			break
	if core == null or gone.has(core):
		return out
	var reached := {core: true}
	for coord in gone:
		reached[coord] = true
	var queue: Array[Vector3i] = [core]
	while not queue.is_empty():
		var at: Vector3i = queue.pop_back()
		for n in grid.neighbours(at):
			if grid.has_block(n) and not reached.has(n):
				reached[n] = true
				queue.append(n)
	for coord in grid.coords():
		if not reached.has(coord):
			out.append(coord)
	return out
