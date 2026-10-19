class_name RockSite
extends NpcSite

## A big rock as a place its creatures live (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §4.2, §4.4, §13; rock creatures spec
## §3.1): its frame is the rock in detail, which is fixed where it is and moved
## only by the floating origin, so a creature's rock-local positions never
## change. There is no gravity: a creature grips. One site holds every species
## on the rock; `fill` does what all share, then hands each species its extras.

## Starting this far off the surface, metres, it settles onto it.
const LIFT := 0.05
## How far either side of the exact surface to look for the solid one.
const FIND_GROUND := 3.0

var detail: AsteroidDetail
var rock: AsteroidRock
var data: RockDetail
## Every group of every species (RockLife), in index order.
var groups: Array[Dictionary] = []
var records: Array[NpcRecord] = []
## record id -> the direction its home was made from.
var dirs := {}
## Every crater's floor, worked out once: the exact surface is costly to ask.
var _floors: Array[Vector3] = []
## group index -> [second, point]: where its round has got to, redone once a
## second.
var _rounds := {}
## record id -> the pose it first woke in: asked every review, and pose_at
## casts a ray.
var _poses := {}
## The director that keeps its creatures, for their group mates.
var director: NpcDirector

## What the body's reports reach the flight scene through, set by the source
## that builds this site. All optional: check is_valid(). Points are engine
## space.
## (cloud_id, centre, entries): where salvage is placed.
var place_salvage: Callable
## (site_id, from) -> a base's place near `from`, or null.
var base_place: Callable
## (site_id, point, qe) -> the QE a base gave up.
var base_sip: Callable
## (kind, at, up, count): drops a stray item.
var drop: Callable
## (kind, at, radius) -> how many of `kind` lie within radius.
var count_near: Callable

func _init(p_detail: AsteroidDetail, world_seed: int) -> void:
	detail = p_detail
	rock = p_detail.rock
	data = p_detail.data
	id = RockHerds.site_of(rock)
	groups = RockLife.groups(rock, data, world_seed)
	records = RockLife.records(rock, data, world_seed, groups)
	# RockLife.records lists each group's members in group order, as
	# member_dirs does (the skitters come first in both), so walking the groups
	# pairs every record with its direction.
	var at := 0
	for g in groups:
		for d in RockLife.member_dirs(g, data):
			dirs[records[at].id] = d
			at += 1
	for c in data.craters:
		_floors.append(data.surface_point(c[0]))

func frame() -> Transform3D:
	return detail.global_transform

func alive() -> bool:
	return is_instance_valid(detail) and detail.is_inside_tree()

## Where a creature wakes. A group on a round (a skitter herd) wakes where its
## round has got to now, in its own place in the huddle; any other wakes at its
## own spot on the surface, worked out once.
func start_pose(record: NpcRecord, time: float) -> Transform3D:
	var g := group_of(record)
	var dir: Vector3 = dirs.get(record.id, data.dir_of(record.home))
	if g.has("round_dirs"):
		var home: Vector3 = g["home_dir"]
		var now := RockHerds.round_dir(g, time)
		dir = (Quaternion(home, now) * dir).normalized() if not home.is_equal_approx(now) else dir
		return pose_at(dir)
	if not _poses.has(record.id):
		_poses[record.id] = pose_at(dir)
	return _poses[record.id]

## Standing on the surface along direction `dir`, up its normal. The solid
## rock is a mesh of the exact surface, a little inside it on the bulges and
## outside it in the hollows, so the ground is found with a ray down onto the
## mesh itself when the rock is in the world.
func pose_at(dir: Vector3) -> Transform3D:
	var n := RockHerds.surface_normal(data, dir)
	var at := data.surface_point(dir)
	if is_instance_valid(detail) and detail.is_inside_tree():
		var f := frame()
		var from := f * (at + n * FIND_GROUND)
		var to := f * (at - n * FIND_GROUND)
		var q := PhysicsRayQueryParameters3D.create(from, to, AsteroidBody.LAYER)
		var hit := detail.get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and hit["collider"] == detail:
			at = f.affine_inverse() * (hit["position"] as Vector3)
			n = (f.basis.inverse() * (hit["normal"] as Vector3)).normalized()
	var forward := n.cross(Vector3.RIGHT if absf(n.x) < 0.9 else Vector3.FORWARD).normalized()
	var basis := Basis(n.cross(forward), n, forward).orthonormalized()
	return Transform3D(basis, at + n * LIFT)

func tint() -> Color:
	return rock.colour

## The group `record` belongs to, or {} if it has none.
func group_of(record: NpcRecord) -> Dictionary:
	for g in groups:
		if int(g["index"]) == record.herd:
			return g
	return {}

func group_seed(record: NpcRecord) -> int:
	var g := group_of(record)
	return int(g["seed"]) if not g.is_empty() else record.seed

## What behaviours may ask of the rock: where the group's mates are and the
## nearest shelter (every species), then each species' own extras.
func fill(ctx: NpcContext, npc: Npc) -> void:
	var to_local := frame().affine_inverse()
	if director != null:
		for other in director.herd_of(npc):
			var mate := other as Npc
			if mate != null and mate != npc and mate.site == self:
				ctx.mates.append(to_local * mate.global_position)
	ctx.places[&"shelter"] = shelter(ctx.position)
	match npc.species.id:
		&"skitter":
			_fill_skitter(ctx, npc)

## A skitter: where its herd's round has got to (where it grazes), company from
## its huddle, and fear easing while nothing has shaken the rock.
func _fill_skitter(ctx: NpcContext, npc: Npc) -> void:
	var h := group_of(npc.record)
	if not h.is_empty():
		ctx.places[&"round"] = round_point(h, ctx.time)
		ctx.extra[&"graze"] = ctx.places[&"round"]
	for m in ctx.mates:
		if m.distance_to(ctx.position) < 3.0:
			ctx.ease(&"company", 0.2)
			break
	var frightened := ctx.recent(Stimulus.VIBRATION, 2.0) != null or ctx.recent(Stimulus.TOUCH, 2.0) != null \
		or ctx.lit
	if not frightened:
		ctx.ease(&"fear", 0.1)

## Where group `h`'s round has got to at `time`, on the surface.
func round_point(h: Dictionary, time: float) -> Vector3:
	var second := int(time)
	var cached: Array = _rounds.get(h["index"], [])
	if cached.is_empty() or cached[0] != second:
		cached = [second, data.surface_point(RockHerds.round_dir(h, float(second)))]
		_rounds[h["index"]] = cached
	return cached[1]

## The floor of the nearest crater to `local`.
func shelter(local: Vector3) -> Vector3:
	var best := local
	var best_d := INF
	for p in _floors:
		var d := p.distance_to(local)
		if d < best_d:
			best = p
			best_d = d
	return best
