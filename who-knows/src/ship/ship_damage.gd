class_name ShipDamage
extends RefCounted

## A ship's damage as six hull sections and four components (docs/superpowers/
## specs/2026-10-03-ship-damage-sections-design.md). The sections and the
## components are the truth; each block's `damage` in the grid is a view of
## them (shown_damage(), present()), which the ship writes back after every
## change. Pure: built from the launch layout, it never sees a node.
##
## Sections: the launch layout's z span in thirds (bow, middle, stern; the bow
## and then the stern take a row that does not divide), each split port and
## starboard about the layout's centre line. A block on the centre line is in
## both sections of its third. Components: the engines (every main thruster,
## as one), the quantum core, the bridge computer and the cockpit (the helm and
## the canopy glass). Everything else is a hull block.

const SECTIONS: Array[StringName] = [&"port_bow", &"starboard_bow", &"port_mid", &"starboard_mid",
	&"port_stern", &"starboard_stern"]
const SECTION_LABELS := {
	&"port_bow": "PORT BOW", &"starboard_bow": "STARBOARD BOW",
	&"port_mid": "PORT MIDSHIP", &"starboard_mid": "STARBOARD MIDSHIP",
	&"port_stern": "PORT STERN", &"starboard_stern": "STARBOARD STERN",
}
## Component id -> the block ids it is made of.
const COMPONENTS := {
	&"engines": [&"thruster"],
	&"quantum_core": [&"quantum_core"],
	&"computer": [&"computer"],
	&"cockpit": [&"pilot_seat", &"canopy"],
}
const COMPONENT_LABELS := {
	&"engines": "ENGINES", &"quantum_core": "QUANTUM CORE", &"computer": "COMPUTER",
	&"cockpit": "COCKPIT",
}
## The least hp a component has, whatever its blocks add up to: one stray bolt
## must not wreck the computer (spec §2.2).
const COMPONENT_HP_MIN := {&"computer": 300.0, &"cockpit": 300.0}
## The blocks that break away from a section (spec §4): plating and fairings,
## never anything that does something.
const STRUCTURE: Array[StringName] = [&"hull", &"hull_wedge", &"armour", &"fairing_half",
	&"fairing_slope", &"fairing_slope_long_low", &"fairing_slope_long_high", &"fairing_corner_out",
	&"fairing_corner_in"]
## A section starts losing pieces below this health, and has lost them all at 0.
const BREAK_BELOW := 0.5
## How much more an exposed block shows of its section's damage than a
## sheltered one: shown share = section share × (1 + EXPOSED × exposure).
const EXPOSED := 1.8
## A shown share never reaches gone: a piece is lost by present(), not by its
## own damage.
const SHOWN_MOST := BlockDamage.GONE_AT - 0.01

var section_hp := {}         # StringName -> float
var section_damage := {}     # StringName -> float
var component_hp := {}       # StringName -> float
var component_damage := {}   # StringName -> float
## coord -> Array of the section ids it is in (two on the centre line).
var sections_of := {}
## coord -> the component id it is part of.
var component_of := {}
## coord -> 0..1, how open to space a hull block is in the launch layout.
var exposure := {}
## Section id -> its pieces that can break away, most exposed first.
var pieces := {}
## coord -> [block id, orientation, hp], the launch layout.
var launch := {}
var _layout: ShipGrid

## The model for a ship that launched as `layout`. `held` (coord -> true) is
## the cabin's shell, which never breaks away.
static func build(layout: ShipGrid, catalog: BlockCatalog, held: Dictionary = {}) -> ShipDamage:
	var d := ShipDamage.new()
	for id in SECTIONS:
		d.section_hp[id] = 0.0
		d.section_damage[id] = 0.0
	var by_block := {}
	for comp: StringName in COMPONENTS:
		for block_id: StringName in COMPONENTS[comp]:
			by_block[block_id] = comp
	var lo := Vector3i(1 << 20, 1 << 20, 1 << 20)
	var hi := -lo
	for coord: Vector3i in layout.coords():
		lo = Vector3i(mini(lo.x, coord.x), mini(lo.y, coord.y), mini(lo.z, coord.z))
		hi = Vector3i(maxi(hi.x, coord.x), maxi(hi.y, coord.y), maxi(hi.z, coord.z))
	var thirds := _thirds(lo.z, hi.z)
	var centre := (lo.x + hi.x) * 0.5
	for coord: Vector3i in layout.coords():
		var inst := layout.get_block(coord)
		var def := catalog.get_def(inst.block_id)
		var hp := float(def.hp) if def != null else 0.0
		d.launch[coord] = [inst.block_id, inst.orientation, hp]
		if by_block.has(inst.block_id):
			var comp: StringName = by_block[inst.block_id]
			d.component_of[coord] = comp
			d.component_hp[comp] = d.component_hp.get(comp, 0.0) + hp
			continue
		var third: String = thirds[coord.z]
		var sides: Array[StringName] = []
		if coord.x < centre:
			sides.append(StringName("port_" + third))
		elif coord.x > centre:
			sides.append(StringName("starboard_" + third))
		else:
			sides.append(StringName("port_" + third))
			sides.append(StringName("starboard_" + third))
		d.sections_of[coord] = sides
		for side in sides:
			d.section_hp[side] += hp / sides.size()
		var open := 0
		for n in ShipGrid.FACE_OFFSETS:
			if not layout.has_block(coord + n):
				open += 1
		d.exposure[coord] = clampf(open / 4.0 + _jitter(coord) * 0.05, 0.0, 1.0)
	for comp: StringName in d.component_hp:
		d.component_hp[comp] = maxf(d.component_hp[comp], COMPONENT_HP_MIN.get(comp, 0.0))
		d.component_damage[comp] = 0.0
	d._layout = layout
	d._find_pieces(layout, held)
	return d

## z -> "bow", "mid" or "stern" for the span lo..hi (−z is the bow).
static func _thirds(lo: int, hi: int) -> Dictionary:
	var n := hi - lo + 1
	var base := n / 3
	var rem := n % 3
	var sizes := [base + (1 if rem >= 1 else 0), base, base + (1 if rem >= 2 else 0)]
	var names := ["bow", "mid", "stern"]
	var out := {}
	var z := lo
	for i in 3:
		for k in sizes[i]:
			out[z] = names[i]
			z += 1
	return out

static func _jitter(coord: Vector3i) -> float:
	return fposmod(sin(coord.x * 12.9898 + coord.y * 78.233 + coord.z * 37.719) * 43758.5453, 1.0)

## The pieces that can break away: structural blocks outside the shell whose
## loss, with every piece found so far gone too, cuts nothing off. Taken most
## exposed first, so a section sheds its outermost plating first.
func _find_pieces(layout: ShipGrid, held: Dictionary) -> void:
	var candidates: Array[Vector3i] = []
	for coord: Vector3i in sections_of:
		var id: StringName = launch[coord][0]
		if STRUCTURE.has(id) and not held.has(coord) and not BlockDamage.KEEP.has(id):
			candidates.append(coord)
	candidates.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return exposure[a] > exposure[b] if exposure[a] != exposure[b] else _key(a) < _key(b))
	var gone: Array[Vector3i] = []
	for coord in candidates:
		var trial := gone.duplicate()
		trial.append(coord)
		if BlockDamage.cut_off(layout, trial).is_empty():
			gone.append(coord)
	for id in SECTIONS:
		pieces[id] = [] as Array[Vector3i]
	for coord in gone:
		for side: StringName in sections_of[coord]:
			pieces[side].append(coord)

static func _key(c: Vector3i) -> int:
	return (c.x + 512) * 1048576 + (c.y + 512) * 1024 + (c.z + 512)

# --- health ---------------------------------------------------------------------

## A section's health, 1 whole to 0.
func health(section: StringName) -> float:
	var hp: float = section_hp.get(section, 0.0)
	return 1.0 if hp <= 0.0 else clampf(1.0 - section_damage[section] / hp, 0.0, 1.0)

## A component's health, 1 whole to 0; 1 for one the ship does not have.
func component_health(comp: StringName) -> float:
	var hp: float = component_hp.get(comp, 0.0)
	return 1.0 if hp <= 0.0 else clampf(1.0 - component_damage[comp] / hp, 0.0, 1.0)

## A component's stage: intact, damaged under half its health, wrecked at 0.
func component_stage(comp: StringName) -> BlockDamage.Stage:
	if not component_hp.has(comp):
		return BlockDamage.Stage.INTACT
	return BlockDamage.stage_at(component_damage[comp], component_hp[comp])

## HULL %, 0..1: the sections' health weighted by their hp.
func hull_whole() -> float:
	var total := 0.0
	var lost := 0.0
	for id in SECTIONS:
		total += section_hp[id]
		lost += minf(section_damage[id], section_hp[id])
	return 1.0 if total <= 0.0 else 1.0 - lost / total

func has_component(comp: StringName) -> bool:
	return component_hp.has(comp)

# --- hits -----------------------------------------------------------------------

## Deals `amount` to whatever the block at `coord` belongs to: its component,
## or its section. A centre-line block's hit goes to the side `side_x` says
## (the hit's offset across the ship from the cell's centre, < 0 port), half to
## each when it is 0. Returns false if `coord` is no block of this ship.
func hit(coord: Vector3i, amount: float, side_x := 0.0) -> bool:
	if amount <= 0.0:
		return false
	if component_of.has(coord):
		var comp: StringName = component_of[coord]
		component_damage[comp] = minf(component_damage[comp] + amount, component_hp[comp])
		return true
	if not sections_of.has(coord):
		return false
	var sides: Array = sections_of[coord]
	if sides.size() == 1:
		_hurt(sides[0], amount)
	elif side_x < 0.0:
		_hurt(sides[0], amount)
	elif side_x > 0.0:
		_hurt(sides[1], amount)
	else:
		_hurt(sides[0], amount * 0.5)
		_hurt(sides[1], amount * 0.5)
	return true

func _hurt(section: StringName, amount: float) -> void:
	section_damage[section] = minf(section_damage[section] + amount, section_hp[section])

## Mends `share` (0..1) of a section's hp; returns the share it used.
func repair_section(section: StringName, share: float) -> float:
	var hp: float = section_hp.get(section, 0.0)
	if hp <= 0.0 or share <= 0.0:
		return 0.0
	var used := minf(share * hp, section_damage[section])
	section_damage[section] -= used
	return used / hp

## Mends up to `hp` of a component; returns what it used.
func repair_component(comp: StringName, hp: float) -> float:
	if not component_hp.has(comp) or hp <= 0.0:
		return 0.0
	var used := minf(hp, component_damage[comp])
	component_damage[comp] -= used
	return used

## What the block at `coord` is part of: a component id, or the section a hit
## from `side_x` would go to, or &"" if none.
func part_of(coord: Vector3i, side_x := 0.0) -> StringName:
	if component_of.has(coord):
		return component_of[coord]
	if not sections_of.has(coord):
		return &""
	var sides: Array = sections_of[coord]
	if sides.size() == 2 and side_x > 0.0:
		return sides[1]
	if sides.size() == 2 and side_x == 0.0:
		return sides[0] if health(sides[0]) <= health(sides[1]) else sides[1]
	return sides[0]

func is_section(part: StringName) -> bool:
	return section_hp.has(part)

func label(part: StringName) -> String:
	return SECTION_LABELS.get(part, COMPONENT_LABELS.get(part, ""))

## The share of a part lost, 0..1: what its health lacks.
func part_health(part: StringName) -> float:
	return health(part) if is_section(part) else component_health(part)

# --- the view -------------------------------------------------------------------

## The damage the block at `coord` shows, in its own hp: a component's blocks
## its share; a hull block its section's share, more if it is exposed, the
## worse of two sections on the centre line.
func shown_damage(coord: Vector3i) -> float:
	if not launch.has(coord):
		return 0.0
	var hp: float = launch[coord][2]
	if component_of.has(coord):
		var comp: StringName = component_of[coord]
		return hp * minf(component_damage[comp] / component_hp[comp], SHOWN_MOST)
	var share := 0.0
	for side: StringName in sections_of[coord]:
		share = maxf(share, 1.0 - health(side))
	return hp * minf(share * (1.0 + EXPOSED * exposure[coord]), SHOWN_MOST)

## Whether the block at `coord` is there now (lost()).
func present(coord: Vector3i) -> bool:
	return launch.has(coord) and not lost().has(coord)

## The pieces lost at the sections' health now, coord -> true: below
## BREAK_BELOW a section loses its pieces most exposed first, all at 0; a
## centre-line piece is lost if either side has lost it. Pieces whose loss
## together would leave anything hanging are kept, last lost first.
func lost() -> Dictionary:
	var order: Array[Vector3i] = []
	var out := {}
	for id in SECTIONS:
		var list: Array = pieces[id]
		for i in lost_count(id):
			if not out.has(list[i]):
				out[list[i]] = true
				order.append(list[i])
	while not order.is_empty() and not BlockDamage.cut_off(_layout, order).is_empty():
		out.erase(order.pop_back())
	return out

## How many of a section's pieces are lost at its health now.
func lost_count(section: StringName) -> int:
	var h := health(section)
	if h >= BREAK_BELOW:
		return 0
	return ceili(pieces[section].size() * (BREAK_BELOW - h) / BREAK_BELOW)

# --- saving (spec §8) ----------------------------------------------------------------

func to_dict() -> Dictionary:
	var s := {}
	for id in SECTIONS:
		s[String(id)] = section_damage[id]
	var c := {}
	for comp: StringName in component_damage:
		c[String(comp)] = component_damage[comp]
	return {"sections": s, "components": c}

## Takes saved damage, each clamped to its part's hp. Parts the save does not
## name keep what they have.
func from_dict(d: Dictionary) -> void:
	var s: Dictionary = d.get("sections", {})
	for key in s:
		var id := StringName(key)
		if section_hp.has(id):
			section_damage[id] = clampf(float(s[key]), 0.0, section_hp[id])
	var c: Dictionary = d.get("components", {})
	for key in c:
		var id := StringName(key)
		if component_hp.has(id):
			component_damage[id] = clampf(float(c[key]), 0.0, component_hp[id])

## Damage read off a grid's blocks (a save from before sections, spec §8): a
## section takes what its blocks had taken, each up to its hp, and all of a
## block that is missing; a component the same share of its own hp.
func infer(grid: ShipGrid) -> void:
	var comp_lost := {}
	var comp_total := {}
	for id in SECTIONS:
		section_damage[id] = 0.0
	for coord: Vector3i in launch:
		var hp: float = launch[coord][2]
		var inst := grid.get_block(coord)
		var lost := hp if inst == null else minf(inst.damage, hp)
		if component_of.has(coord):
			var comp: StringName = component_of[coord]
			comp_lost[comp] = comp_lost.get(comp, 0.0) + lost
			comp_total[comp] = comp_total.get(comp, 0.0) + hp
			continue
		var sides: Array = sections_of[coord]
		for side: StringName in sides:
			section_damage[side] += lost / sides.size()
	for id in SECTIONS:
		section_damage[id] = minf(section_damage[id], section_hp[id])
	for comp: StringName in component_hp:
		var total: float = comp_total.get(comp, 0.0)
		component_damage[comp] = 0.0 if total <= 0.0 else component_hp[comp] * comp_lost[comp] / total
