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

static func stage_of(inst: BlockInstance, def: BlockDefinition) -> Stage:
	if inst == null or def == null:
		return Stage.INTACT
	return stage_at(inst.damage, float(def.hp))

static func output_of(stage: Stage) -> float:
	return OUTPUT[stage]

## Deals `amount` to the block at `coord`. Returns every coord it removed:
## the block, if it is gone, and any piece cut off from the core with it.
static func apply(grid: ShipGrid, catalog: BlockCatalog, coord: Vector3i, amount: float) -> Array[Vector3i]:
	return apply_many(grid, catalog, {coord: amount})

## Deals every hit in `hits` (coord -> amount) at once: a crash lands on a
## cell and its neighbours together. Everything gone, and anything cut off by
## it, is removed in one remove_many, so the lot costs one rebuild.
static func apply_many(grid: ShipGrid, catalog: BlockCatalog, hits: Dictionary) -> Array[Vector3i]:
	var gone: Array[Vector3i] = []
	for coord: Vector3i in hits:
		var inst := grid.get_block(coord)
		var def := catalog.get_def(inst.block_id) if inst != null else null
		var amount := float(hits[coord])
		if def == null or amount <= 0.0:
			continue
		var hp := float(def.hp)
		var before := stage_at(inst.damage, hp)
		inst.damage += amount
		if KEEP.has(def.id):
			# Just short of gone: a kept block's wreck soaks everything after.
			inst.damage = minf(inst.damage, hp * GONE_AT - 1.0)
		var after := stage_at(inst.damage, hp)
		if after == Stage.GONE:
			gone.append(coord)
		elif after != before:
			grid.note_staged(coord, after)
	if gone.is_empty():
		return gone
	var removed: Array[Vector3i] = gone.duplicate()
	removed.append_array(cut_off(grid, gone))
	grid.remove_many(removed)
	return removed

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
