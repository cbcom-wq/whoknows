class_name RockLife
extends RefCounted

## One rock, one ecology (docs/superpowers/specs/2026-10-18-rock-creatures-design.md
## §3.1): every group of every species on a big rock, from one recipe. The
## skitters are RockHerds' herds exactly as they were; each later species has a
## recipe class of its own, found by name, and is skipped until that class
## exists. Pure: no nodes, so it runs anywhere and is tested headless.
##
## A recipe is a class with
##   static func groups(rock, data, world_seed, taken: Array[Vector3], first_index: int) -> Array[Dictionary]
##   static func member_dirs(g: Dictionary, data: RockDetail) -> Array[Vector3]
## Directions are unit vectors from the rock's centre in its own frame, as
## RockDetail's are.

const SKITTER := &"skitter"
## Species in the order they take their homes; group numbers run on across them.
const ORDER: Array[StringName] = [&"skitter", &"glinter", &"delver", &"limpet"]
## Each recipe keeps its homes this far clear (surface point to surface point)
## of every home already taken, metres.
const SPACING := 30.0
## Recipe class of each species that has one besides the skitter.
const RECIPES := {
	&"glinter": "GlinterNests",
	&"delver": "DelverBurrows",
	&"limpet": "LimpetBeds",
}

## species -> the recipe's script, or null while the class does not exist yet.
## Built once, from the project's global class list.
static var _recipes := {}

## Every group of the rock: {index, species, home_dir, count, seed, ...} (the
## skitters' carry RockHerds' own keys too). Indices run 0, 1, 2... across the
## species in ORDER.
static func groups(rock: AsteroidRock, data: RockDetail, world_seed: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var taken: Array[Vector3] = []
	for species in ORDER:
		var made: Array[Dictionary] = []
		if species == SKITTER:
			made = RockHerds.herds(rock, data, world_seed)
			for g in made:
				g["species"] = SKITTER
		else:
			var recipe := _recipe(species)
			if recipe == null:
				continue
			for g: Dictionary in recipe.call(&"groups", rock, data, world_seed, taken, out.size()):
				made.append(g)
		for g in made:
			taken.append(g["home_dir"])
			out.append(g)
	return out

## Every creature of the rock, as records: homes on its surface, in its frame.
## The skitters' are exactly RockHerds' own; the rest are
## "<species>:<site>:<group>:<n>" with `herd` the group's index.
static func records(rock: AsteroidRock, data: RockDetail, world_seed: int,
		p_groups: Array[Dictionary] = []) -> Array[NpcRecord]:
	var all := p_groups if not p_groups.is_empty() else groups(rock, data, world_seed)
	var out: Array[NpcRecord] = []
	var herds: Array[Dictionary] = []
	for g in all:
		if g["species"] == SKITTER:
			herds.append(g)
	if not herds.is_empty():
		out.append_array(RockHerds.records(rock, data, world_seed, herds))
	var site := RockHerds.site_of(rock)
	for g in all:
		if g["species"] == SKITTER:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = int(g["seed"]) ^ 0x5A5A
		var dirs := member_dirs(g, data)
		for m in dirs.size():
			out.append(NpcRecord.make(StringName("%s:%s:%d:%d" % [g["species"], site, g["index"], m]),
				g["species"], site, data.surface_point(dirs[m]), rng.randi(), g["index"]))
	return out

## Where each member of group `g` lives, as directions from the rock's centre.
static func member_dirs(g: Dictionary, data: RockDetail) -> Array[Vector3]:
	if g["species"] == SKITTER:
		return RockHerds.member_dirs(g, data)
	var recipe := _recipe(g["species"])
	var out: Array[Vector3] = []
	if recipe == null:
		return out
	out.assign(recipe.call(&"member_dirs", g, data))
	return out

## Whether direction `dir`'s surface point is at least `metres` from the surface
## point of every direction in `taken`.
static func clear_of(data: RockDetail, dir: Vector3, taken: Array[Vector3], metres := SPACING) -> bool:
	var p := data.surface_point(dir)
	for t in taken:
		if p.distance_to(data.surface_point(t)) < metres:
			return false
	return true

## The recipe script of `species`, or null if its class is not in the project yet.
static func _recipe(species: StringName) -> Script:
	if _recipes.is_empty():
		var found := {}
		for entry in ProjectSettings.get_global_class_list():
			found[String(entry["class"])] = String(entry["path"])
		for s: StringName in RECIPES:
			var path: String = found.get(String(RECIPES[s]), "")
			_recipes[s] = load(path) as Script if path != "" else null
	return _recipes.get(species)