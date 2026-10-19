class_name GlinterNests
extends RefCounted

## Glinter nests on the big rocks (docs/superpowers/specs/
## 2026-10-10-rock-creatures-design.md §3.1, §4.1): from a rock and its detail,
## the same nest every time -- whether the rock has one, which crater floor it
## lies on, who is in it and the real salvage lying with them. About a third
## of rocks have one, and it keeps 30 m clear of every other group's home.
## Pure: no nodes. Found by RockLife by class name.
##
## Directions are unit vectors from the rock's centre in its own frame, as
## RockDetail's are; RockDetail.surface_point turns one into a point on the
## surface.

const SPECIES := &"glinter"
## Salt for the nests' generator, apart from the rock's other seeds (Delver 17,
## Limpet 19).
const SALT := 13
## The chance that a rock has a nest.
const CHANCE := 1.0 / 3.0
## Glinters to a nest, least and most.
const MEMBERS := Vector2i(3, 5)
## Real salvage items lying with them, least and most.
const SALVAGE := Vector2i(2, 4)
## Everything lies within this of the nest's home, metres (more only if there
## is no room: see TRIES).
const SPREAD := 3.0
## Every Glinter and item keeps this far from every other, metres, surface
## point to surface point.
const GAP := 1.0
## Tries at a place for each thing before the nest's spread widens.
const TRIES := 30
## Keeps the salvage's draws apart from the Glinters'.
const _SALVAGE_SALT := 0x5A17

## The rock's nest, after the groups already `taken` (their homes, directions)
## and numbered from `first_index`: none or one of {index, species, home_dir,
## count, seed, crater, salvage}. `salvage` lists {index, kind, variety, dir}
## for each item, the kind drawn by SalvageField.MIX's weights.
static func groups(rock: AsteroidRock, data: RockDetail, world_seed: int, taken: Array[Vector3],
		first_index: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if data.craters.is_empty():
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = AsteroidRecipe.cell_seed(world_seed, SALT, rock.cell) ^ rock.index
	var has_nest := rng.randf() < CHANCE
	var count := rng.randi_range(MEMBERS.x, MEMBERS.y)
	var items := rng.randi_range(SALVAGE.x, SALVAGE.y)
	var nest_seed := rng.randi()
	# The crater is picked whether or not there is a nest, so a rock's other
	# draws never depend on it.
	var craters := range(data.craters.size())
	var order: Array[int] = []
	while not craters.is_empty():
		order.append(craters.pop_at(rng.randi_range(0, craters.size() - 1)))
	if not has_nest:
		return out
	for crater in order:
		var home: Vector3 = data.craters[crater][0]
		if not RockLife.clear_of(data, home, taken):
			continue
		var g := {"index": first_index, "species": SPECIES, "home_dir": home, "count": count,
			"seed": nest_seed, "crater": crater}
		g["salvage"] = _salvage(g, items, data)
		out.append(g)
		break
	return out

## Where each Glinter of nest `g` lives, as directions from the rock's centre:
## a scatter about the nest's home, GAP apart.
static func member_dirs(g: Dictionary, data: RockDetail) -> Array[Vector3]:
	var rng := RandomNumberGenerator.new()
	rng.seed = g["seed"]
	var kept: Array[Vector3] = []
	return _scatter(rng, g["home_dir"], int(g["count"]), data, kept)

## The nest's `count` items: spread about its home, GAP from each other and
## from its Glinters.
static func _salvage(g: Dictionary, count: int, data: RockDetail) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(g["seed"]) ^ _SALVAGE_SALT
	var kept: Array[Vector3] = member_dirs(g, data)
	var dirs := _scatter(rng, g["home_dir"], count, data, kept)
	var total := 0
	for m in SalvageField.MIX:
		total += int(m[1])
	var out: Array[Dictionary] = []
	for i in dirs.size():
		var pick := rng.randi_range(0, total - 1)
		var kind: StringName = SalvageField.MIX[0][0]
		for m in SalvageField.MIX:
			if pick < int(m[1]):
				kind = m[0]
				break
			pick -= int(m[1])
		out.append({"index": i, "kind": kind, "variety": rng.randf(), "dir": dirs[i]})
	return out

## `count` directions about `home`, each at least GAP (surface point to surface
## point) from every one already in `kept` and from each other. The scatter
## is a disc of SPREAD metres across the rock, which widens a quarter after TRIES failures
## in a row: a nest always has room for all it holds. `kept` gains them.
static func _scatter(rng: RandomNumberGenerator, home: Vector3, count: int, data: RockDetail,
		kept: Array[Vector3]) -> Array[Vector3]:
	var centre := data.surface_point(home)
	var metres := maxf(centre.length(), 1.0)
	var out: Array[Vector3] = []
	var spread := SPREAD
	for i in count:
		var tries := 0
		while true:
			var dir := RockHerds.tilted(home, sqrt(rng.randf()) * spread / metres, rng.randf() * TAU)
			# (The rock is stretched and the crater a bowl: the angle is a guess at
			# SPREAD metres, so the metres are checked.)
			if data.surface_point(dir).distance_to(centre) <= spread and RockLife.clear_of(data, dir, kept, GAP):
				out.append(dir)
				kept.append(dir)
				break
			tries += 1
			if tries >= TRIES:
				tries = 0
				spread *= 1.25
	return out
