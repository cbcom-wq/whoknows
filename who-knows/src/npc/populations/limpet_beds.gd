class_name LimpetBeds
extends RefCounted

## Beds of limpets on the big rocks (docs/superpowers/specs/
## 2026-10-10-rock-creatures-design.md §3.1, §6): from a rock and its detail,
## the same beds every time -- how many, where each lies, and who is on it.
## A bed lies on the crystal vein of a veined rock and on a crater's rim
## otherwise, and keeps 30 m clear of every other group's home. Pure: no
## nodes. Found by RockLife by class name.
##
## Directions are unit vectors from the rock's centre in its own frame, as
## RockDetail's are; RockDetail.surface_point turns one into a point on the
## surface.

const SPECIES := &"limpet"
## Salt for the beds' generator, apart from the rock's other seeds (Glinter 13,
## Delver 17).
const SALT := 19
const MOST := 2
## Limpets to a bed, least and most.
const MEMBERS := Vector2i(8, 12)
## Members lie within this of their bed's home, metres.
const SPREAD := 2.5
## Tries at a place for each bed before it is given up.
const TRIES := 40

## The rock's beds, after the groups already `taken` (their homes, directions)
## and numbered on from `first_index`: {index, species, home_dir, count, seed}
## and, on a crater's rim, its `crater`.
static func groups(rock: AsteroidRock, data: RockDetail, world_seed: int, taken: Array[Vector3],
		first_index: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = AsteroidRecipe.cell_seed(world_seed, SALT, rock.cell) ^ rock.index
	var veined := rock.shape == RockMesh.Shape.VEINED
	var n := rng.randi_range(0, MOST)
	if not veined:
		n = mini(n, data.craters.size())
	var homes: Array[Vector3] = taken.duplicate()
	var craters := range(data.craters.size())
	for i in n:
		var home := Vector3.ZERO
		var crater := -1
		var found := false
		if veined:
			for t in TRIES:
				home = _random_dir(rng)
				if RockMesh.in_vein(home) and RockLife.clear_of(data, home, homes):
					found = true
					break
		elif not craters.is_empty():
			crater = craters.pop_at(rng.randi_range(0, craters.size() - 1))
			var centre: Vector3 = data.craters[crater][0]
			var angular: float = data.craters[crater][1]
			for t in TRIES:
				home = RockHerds.tilted(centre, angular, rng.randf() * TAU)
				if RockLife.clear_of(data, home, homes):
					found = true
					break
		# A bed with no clear place is simply not made.
		var count := rng.randi_range(MEMBERS.x, MEMBERS.y)
		var bed_seed := rng.randi()
		if not found:
			continue
		homes.append(home)
		var g := {"index": first_index + out.size(), "species": SPECIES, "home_dir": home,
			"count": count, "seed": bed_seed}
		if crater >= 0:
			g["crater"] = crater
		out.append(g)
	return out

## Where each member of bed `g` lives, as directions from the rock's centre: a
## scatter round the bed's home. (A point's own direction from the centre is
## not the direction it was made from: the rock is stretched.)
static func member_dirs(g: Dictionary, data: RockDetail) -> Array[Vector3]:
	var rng := RandomNumberGenerator.new()
	rng.seed = g["seed"]
	var home: Vector3 = g["home_dir"]
	var metres := data.surface_point(home).length()
	var out: Array[Vector3] = []
	for m in int(g["count"]):
		out.append(RockHerds.tilted(home, sqrt(rng.randf()) * SPREAD / maxf(metres, 1.0), rng.randf() * TAU))
	return out

static func _random_dir(rng: RandomNumberGenerator) -> Vector3:
	var z := rng.randf_range(-1.0, 1.0)
	var a := rng.randf() * TAU
	var r := sqrt(1.0 - z * z)
	return Vector3(r * cos(a), z, r * sin(a))
