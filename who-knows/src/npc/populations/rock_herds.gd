class_name RockHerds
extends RefCounted

## Herds of skitters on the big rocks (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §4.2, §4.4, §13): from a rock and its
## detail, the same herds every time -- how many, where each lives on a crater
## wall, and the round it walks. Pure: no nodes, so it runs anywhere and is
## tested headless.
##
## Directions are unit vectors from the rock's centre in its own frame, as
## RockDetail's are; RockDetail.surface_point turns one into a point on the
## surface.

const SPECIES := &"skitter"
const MOST_HERDS := 3
const HERD_MIN := 3
const HERD_MAX := 7
## Round: this many stops, within ROUND_SPREAD radians of home, walked once
## every ROUND_MIN to ROUND_MAX seconds.
const STOPS_MIN := 3
const STOPS_MAX := 5
const ROUND_SPREAD := 0.35
const ROUND_MIN := 20.0 * 60.0
const ROUND_MAX := 40.0 * 60.0
## A herd lives this far up its crater's wall, as a share of its radius.
const WALL := 0.8
## Members start within this of their herd's home, metres.
const HUDDLE := 3.0
## Salt for the herds' generator, apart from the rock's other seeds.
const SALT := 11

## A big rock's name as a place: the same rock, the same name, every load.
static func site_of(rock: AsteroidRock) -> StringName:
	var id := rock.id()
	return StringName("rock:%d_%d_%d_%d" % [id.x, id.y, id.z, id.w])

## The rock's herds: {index, home_dir, round_dirs, period, count, seed}.
static func herds(rock: AsteroidRock, data: RockDetail, world_seed: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if data.craters.is_empty():
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = AsteroidRecipe.cell_seed(world_seed, SALT, rock.cell) ^ rock.index
	var across := pow(rock.size.x * rock.size.y * rock.size.z, 1.0 / 3.0)
	var n := rng.randi_range(0, 2)
	if across > 300.0:
		n += 1
	if rock.shape == RockMesh.Shape.VEINED:
		n += 1
	n = mini(mini(n, MOST_HERDS), data.craters.size())
	var craters := range(data.craters.size())
	for i in n:
		var pick: int = craters.pop_at(rng.randi_range(0, craters.size() - 1))
		var centre: Vector3 = data.craters[pick][0]
		var angular: float = data.craters[pick][1]
		var home := tilted(centre, angular * WALL, rng.randf() * TAU)
		var stops: Array[Vector3] = [home]
		for s in rng.randi_range(STOPS_MIN, STOPS_MAX) - 1:
			stops.append(tilted(home, rng.randf_range(0.3, 1.0) * ROUND_SPREAD, rng.randf() * TAU))
		out.append({"index": i, "home_dir": home, "round_dirs": stops,
			"period": rng.randf_range(ROUND_MIN, ROUND_MAX), "count": rng.randi_range(HERD_MIN, HERD_MAX),
			"seed": rng.randi(), "crater": pick})
	return out

## Every skitter of the rock, as records: homes on its surface, in its frame.
static func records(rock: AsteroidRock, data: RockDetail, world_seed: int,
		p_herds: Array[Dictionary] = []) -> Array[NpcRecord]:
	var all := p_herds if not p_herds.is_empty() else herds(rock, data, world_seed)
	var out: Array[NpcRecord] = []
	var site := site_of(rock)
	for h in all:
		var dirs := member_dirs(h, data)
		var rng := RandomNumberGenerator.new()
		rng.seed = int(h["seed"]) ^ 0x5A5A
		for m in dirs.size():
			out.append(NpcRecord.make(StringName("skitter:%s:%d:%d" % [site, h["index"], m]), SPECIES, site,
				data.surface_point(dirs[m]), rng.randi(), h["index"]))
	return out

## Where each member of herd `h` lives, as directions from the rock's centre:
## a huddle round the herd's home. (A point's own direction from the centre is
## not the direction it was made from: the rock is stretched.)
static func member_dirs(h: Dictionary, data: RockDetail) -> Array[Vector3]:
	var rng := RandomNumberGenerator.new()
	rng.seed = h["seed"]
	var home: Vector3 = h["home_dir"]
	var metres := data.surface_point(home).length()
	var out: Array[Vector3] = []
	for m in int(h["count"]):
		out.append(tilted(home, rng.randf() * HUDDLE / maxf(metres, 1.0), rng.randf() * TAU))
	return out

## Where herd `h` is on its round at `time`: a direction from the rock's
## centre, slerped between its stops.
static func round_dir(h: Dictionary, time: float) -> Vector3:
	var stops: Array = h["round_dirs"]
	var along := fposmod(time / float(h["period"]), 1.0) * stops.size()
	var i := int(along) % stops.size()
	var a: Vector3 = stops[i]
	var b: Vector3 = stops[(i + 1) % stops.size()]
	return slerp_dir(a, b, along - floorf(along))

## The surface's outward normal along direction `d`, from its neighbours.
static func surface_normal(data: RockDetail, d: Vector3) -> Vector3:
	var side := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	var up := side.cross(d).normalized()
	var e := 0.004
	var p := data.surface_point(d)
	var a := data.surface_point((d + side * e).normalized()) - p
	var b := data.surface_point((d + up * e).normalized()) - p
	var n := a.cross(b).normalized()
	return n if n.dot(d) > 0.0 else -n

## A direction `angle` radians from `d`, toward `bearing` around it.
static func tilted(d: Vector3, angle: float, bearing: float) -> Vector3:
	var side := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	side = side.rotated(d, bearing)
	return d.rotated(side, angle).normalized()

static func slerp_dir(a: Vector3, b: Vector3, t: float) -> Vector3:
	if a.is_equal_approx(b):
		return a
	return a.slerp(b, t).normalized()
