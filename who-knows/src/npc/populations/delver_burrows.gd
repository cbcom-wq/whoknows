class_name DelverBurrows
extends RefCounted

## Delver burrows on the veined rocks (docs/superpowers/specs/
## 2026-10-10-rock-creatures-design.md §3.1, §5.1): from a rock and its detail,
## the same Delver every time. Only a veined rock has one -- the rocks a drill
## pays double on -- a single Delver living on the crystal vein with a round of
## six to ten burrow points along it, fifteen metres apart, which it feeds at
## and travels between under the surface. Its home keeps 30 m clear of every
## other group's. Pure: no nodes. Found by RockLife by class name.
##
## Directions are unit vectors from the rock's centre in its own frame, as
## RockDetail's are; RockDetail.surface_point turns one into a point on the
## surface.

const SPECIES := &"delver"
## Salt for the burrows' generator, apart from the rock's other seeds (Glinter
## 13, Limpet 19).
const SALT := 17
## Burrow points to a round, least and most.
const POINTS := Vector2i(6, 10)
## How long a Delver stays up between burrowings, seconds of its rock's live
## time (§5.3): each Delver picks its own in this range.
const CYCLE := Vector2(180.0, 360.0)
## Burrow points keep this far apart, metres, surface point to surface point.
const GAP := 15.0
## A round lies within this angle of its first point, radians. It widens a
## quarter after TRIES failures in a row, so a round always has room.
const REACH := 0.5
## Tries at a point before the reach widens, and at a home before the rock
## is given up.
const TRIES := 40
## The reach never widens past this, radians: all the way round.
const WIDEST := PI

## The rock's Delver, after the groups already `taken` (their homes,
## directions) and numbered on from `first_index`: none or one of {index,
## species, home_dir, count, seed, burrows}. `burrows` lists the round's
## directions, the first being the home.
static func groups(rock: AsteroidRock, data: RockDetail, world_seed: int, taken: Array[Vector3],
		first_index: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if rock.shape != RockMesh.Shape.VEINED:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = AsteroidRecipe.cell_seed(world_seed, SALT, rock.cell) ^ rock.index
	var delver_seed := rng.randi()
	var home := Vector3.ZERO
	var found := false
	for t in TRIES:
		home = _random_dir(rng)
		if RockMesh.in_vein(home) and RockLife.clear_of(data, home, taken):
			found = true
			break
	if not found:
		return out
	var round_rng := RandomNumberGenerator.new()
	round_rng.seed = delver_seed
	var burrows := _round(data, home, round_rng, true)
	if burrows.size() < POINTS.x:
		return out
	out.append({"index": first_index, "species": SPECIES, "home_dir": home, "count": 1,
		"seed": delver_seed, "burrows": burrows})
	return out

## Where each member of group `g` lives, as directions from the rock's centre:
## the one Delver, at the first of its burrows.
static func member_dirs(g: Dictionary, _data: RockDetail) -> Array[Vector3]:
	return [g["home_dir"]] as Array[Vector3]

## A round of burrow points about `dir`, vein or not: 6 to 10 directions within
## REACH of it (more only if there is no room), GAP apart, the first `dir`
## itself. For a Delver the dev spawner puts down anywhere (RockSite.add_group).
static func round_near(data: RockDetail, dir: Vector3, rng: RandomNumberGenerator) -> Array[Vector3]:
	return _round(data, dir, rng, false)

## The round about `home`. `vein` keeps every point on the crystal vein.
static func _round(data: RockDetail, home: Vector3, rng: RandomNumberGenerator, vein: bool) -> Array[Vector3]:
	var want := rng.randi_range(POINTS.x, POINTS.y)
	var out: Array[Vector3] = [home]
	var reach := REACH
	var tries := 0
	while out.size() < want and reach <= WIDEST:
		var dir := RockHerds.tilted(home, sqrt(rng.randf()) * reach, rng.randf() * TAU)
		if (not vein or RockMesh.in_vein(dir)) and RockLife.clear_of(data, dir, out, GAP):
			out.append(dir)
			tries = 0
			continue
		tries += 1
		if tries >= TRIES:
			tries = 0
			if out.size() >= POINTS.x:
				break
			# Too few on the rock's face this size: look further round.
			reach *= 1.25
	return out

static func _random_dir(rng: RandomNumberGenerator) -> Vector3:
	var z := rng.randf_range(-1.0, 1.0)
	var a := rng.randf() * TAU
	var r := sqrt(1.0 - z * z)
	return Vector3(r * cos(a), z, r * sin(a))
