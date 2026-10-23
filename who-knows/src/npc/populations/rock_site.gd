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
## The first index of a group the dev spawner makes (rock creatures spec §7.2),
## clear of every group a recipe makes.
const DEV_FIRST := 1000
## A dev group's members stand within this of its centre, metres.
const DEV_HUDDLE := 4.0
## A Limpet is drawn to your suit within this of it, metres (rock creatures
## spec §6.2).
const SUIT_DRAW := 20.0
## A bed raids a base whose nearest module is within RAID of its home, while
## something that is not a base (you, your ship) is within RAID_NEAR of the
## bed (§6.3).
const RAID := 100.0
const RAID_NEAR := 300.0
## What a Limpet takes from a base's store, QE a second (§6.1).
const BASE_RATE := 0.05
## A Limpet creeping to a base stops once within the reach Bases.sip allows of
## a module's cell centre, which is less than it can sip a suit from.
const BASE_REACH := Bases.SIP_REACH
## A dead Limpet leaves a husk, and another for each this many QE it had
## sipped, to HUSKS_MAX in all (§6.4).
const HUSK_PER_QE := 40.0
const HUSKS_MAX := 4
## A Delver leaves this many crystal grit, least and most, where it surfaces,
## and about one time in SHARD_ODDS a quantum shard as well (rock creatures
## spec §5.4).
const GRIT := Vector2i(2, 4)
const SHARD_ODDS := 12
## At most GRIT_CAP untaken grit lie about a rock (within its radius and
## CAP_MARGIN, metres, of its centre: cap_radius()), and one shard at a time.
const GRIT_CAP := 8
const CAP_MARGIN := 50.0
## A dead Delver leaves a shard and this much grit.
const DELVER_GRIT := 6
## What a Delver leaves lies this far behind its tail, metres: its 3 m body
## would push the pieces about if they lay under it, and the heap is meant to be
## found where it came up.
const TAIL_CLEAR := 0.5

var detail: AsteroidDetail
var rock: AsteroidRock
var data: RockDetail
## Every group of every species (RockLife), in index order.
var groups: Array[Dictionary] = []
var records: Array[NpcRecord] = []
## record id -> the direction its home was made from.
var dirs := {}
## How many groups F10 has made here: their indices run on from DEV_FIRST.
var _dev_groups := 0
## Every crater's floor, worked out once: the exact surface is costly to ask.
var _floors: Array[Vector3] = []
## group index -> [second, point]: where its round has got to, redone once a
## second.
var _rounds := {}
## record id -> the pose it first woke in: asked every review, and pose_at
## casts a ray.
var _poses := {}
## group index -> a Delver's burrow points, site-local, worked out once: the
## exact surface is costly to ask.
var _burrows := {}
## record id -> how many times that Delver has surfaced, and its cycle.
var _surfacings := {}
var _cycles := {}
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

## Registers the real salvage of the rock's nest, if it has one and the flight
## scene gave a `place_salvage` (rock creatures spec §4.1). The cloud is called
## "nest:<site>:<group>", its centre the nest's own spot on the rock, and each
## item lies where a ray down onto the solid rock finds the ground, at rest and
## the way up the rock's own: the rock never turns, so its poses stay as they
## are. Asked again whenever the rock comes into detail, as it is built again.
func place_nests() -> void:
	if not place_salvage.is_valid() or not alive():
		return
	var f := frame()
	for g in groups:
		if g["species"] != GlinterNests.SPECIES or not g.has("salvage"):
			continue
		var centre := f * pose_at(g["home_dir"]).origin
		var entries: Array[Dictionary] = []
		for e: Dictionary in g["salvage"]:
			var pose := f * pose_at(e["dir"])
			entries.append({"index": e["index"], "kind": e["kind"], "variety": e["variety"],
				"pose": Transform3D(pose.basis, pose.origin - centre)})
		place_salvage.call(StringName("nest:%s:%d" % [id, g["index"]]), centre, entries)

## A group made on the spot by the dev spawner (rock creatures spec §7.2):
## `count` members of `species`, one per id, in a huddle round `dir`, with the
## index DEV_FIRST + k for this site's k-th. The group joins `groups`, so the
## site fills in for its members as for any others; its records are returned,
## not added to `records`, which are the recipes' own. Species that need more
## of their group (a Delver's burrows) add their keys to the returned
## group, which is `groups.back()`.
func add_group(species: StringName, dir: Vector3, count: int, ids: Array[StringName]) -> Array[NpcRecord]:
	var g := {"index": DEV_FIRST + _dev_groups, "species": species, "home_dir": dir, "count": count,
		"seed": hash(String(ids[0])) if not ids.is_empty() else DEV_FIRST + _dev_groups}
	_dev_groups += 1
	if species == RockLife.SKITTER:
		# The skitter's fill reads its herd's round: this one stays where it is.
		g["round_dirs"] = [dir]
		g["period"] = RockHerds.ROUND_MAX
	if species == DelverBurrows.SPECIES:
		# A Delver put down anywhere has a round to go by (the recipe's own are
		# on the vein of a veined rock only).
		var round_rng := RandomNumberGenerator.new()
		round_rng.seed = int(g["seed"])
		g["burrows"] = DelverBurrows.round_near(data, dir, round_rng)
	groups.append(g)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(g["seed"]) ^ 0x5A5A
	var out: Array[NpcRecord] = []
	var members := dev_member_dirs(g, data)
	for m in mini(members.size(), ids.size()):
		var record := NpcRecord.make(ids[m], species, id, data.surface_point(members[m]), rng.randi(), int(g["index"]))
		dirs[record.id] = members[m]
		out.append(record)
	return out

## Where each member of a dev group lives: a huddle round its `home_dir`, the
## first on it, as RockHerds.member_dirs does for a herd.
static func dev_member_dirs(g: Dictionary, data: RockDetail) -> Array[Vector3]:
	var rng := RandomNumberGenerator.new()
	rng.seed = g["seed"]
	var home: Vector3 = g["home_dir"]
	var metres := data.surface_point(home).length()
	var out: Array[Vector3] = []
	for m in int(g["count"]):
		if m == 0:
			out.append(home)
		else:
			out.append(RockHerds.tilted(home, rng.randf() * DEV_HUDDLE / maxf(metres, 1.0), rng.randf() * TAU))
	return out

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
		&"limpet":
			_fill_limpet(ctx, npc)
		&"delver":
			_fill_delver(ctx, npc.record)

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

## A Limpet: the quantum energy it is drawn to (rock creatures spec §6.2). Your
## suit if you are within SUIT_DRAW of it; else a base's module cell, if a base
## is within RAID of its bed and you or your ship are near the bed (§6.3). Both
## site-local. A base is sipped only within BASE_REACH of the module.
func _fill_limpet(ctx: NpcContext, npc: Npc) -> void:
	if ctx.player != null and (ctx.player as Vector3).distance_to(ctx.position) <= SUIT_DRAW:
		ctx.places[&"quantum"] = ctx.player
		return
	if not base_place.is_valid() or director == null:
		return
	var f := frame()
	var home := npc.record.home
	var place: Variant = base_place.call(id, npc.global_position)
	if place == null:
		return
	var local: Vector3 = f.affine_inverse() * (place as Vector3)
	if local.distance_to(home) > RAID:
		return
	var bed := f * home
	for a: Node3D in director.anchors():
		if not a.has_meta(&"base") and a.global_position.distance_to(bed) <= RAID_NEAR:
			ctx.places[&"quantum"] = local
			ctx.extra[&"quantum_reach"] = BASE_REACH
			return

## A Delver: its round (rock creatures spec §5.3). `extra[&"burrows"]` lists its
## burrow points, site-local; `places[&"crystal"]` is the one it is nearest, where
## it feeds; `places[&"burrow"]` the next one round, where it digs to;
## `extra[&"cycle"]` how long it stays up between burrowings, its own in
## DelverBurrows.CYCLE. A Delver with no round (a group the site does not know)
## is offered none of them, and its behaviours score nothing.
func _fill_delver(ctx: NpcContext, record: NpcRecord) -> void:
	var round := burrow_points(group_of(record))
	if round.is_empty():
		return
	var nearest := 0
	var best := INF
	for i in round.size():
		var d := round[i].distance_to(ctx.position)
		if d < best:
			best = d
			nearest = i
	ctx.extra[&"burrows"] = round
	ctx.places[&"crystal"] = round[nearest]
	ctx.places[&"burrow"] = round[(nearest + 1) % round.size()]
	ctx.extra[&"cycle"] = cycle_of(record)

## The burrow points of Delver group `g`, site-local on the surface: its round's
## directions, worked out once. Empty for a group with none.
func burrow_points(g: Dictionary) -> Array[Vector3]:
	if g.is_empty() or not g.has("burrows"):
		return [] as Array[Vector3]
	var index: int = g["index"]
	if not _burrows.has(index):
		var points: Array[Vector3] = []
		for d: Vector3 in g["burrows"]:
			points.append(data.surface_point(d))
		_burrows[index] = points
	return _burrows[index]

## How long `record`'s Delver stays up between burrowings, seconds: a point in
## DelverBurrows.CYCLE its seed picks.
func cycle_of(record: NpcRecord) -> float:
	if not _cycles.has(record.id):
		var rng := RandomNumberGenerator.new()
		rng.seed = record.seed
		_cycles[record.id] = lerpf(DelverBurrows.CYCLE.x, DelverBurrows.CYCLE.y, rng.randf())
	return _cycles[record.id]

## A Limpet's sip from a base: BASE_RATE QE a second, if a base's store is
## within the base's reach of it (Bases.sip), else nothing.
func sip_source(npc: Npc, dt: float) -> float:
	if not base_sip.is_valid():
		return 0.0
	return float(base_sip.call(id, npc.global_position, BASE_RATE * dt))

## What a death on the rock leaves (rock creatures spec §6.4). A Limpet drops
## husks: one, and one more for every HUSK_PER_QE it had sipped, up to HUSKS_MAX
## in all, so killing a fat one gives your QE back.
func died(npc: Npc) -> void:
	if not drop.is_valid():
		return
	match npc.species.id:
		&"limpet":
			var count := 1 + mini(floori(npc.sipped / HUSK_PER_QE), HUSKS_MAX - 1)
			drop.call(&"limpet_husk", npc.global_position, npc.global_basis.y, count)
		&"delver":
			# Following it beats shooting it: all it would have paid, at once, and
			# nothing after (§5.4). The caps do not apply to a windfall.
			drop.call(&"quantum_shard", behind(npc), npc.global_basis.y, 1)
			drop.call(&"crystal_grit", behind(npc), npc.global_basis.y, DELVER_GRIT)

## A Delver has come up out of the ground (rock creatures spec §5.4): it leaves
## 2-4 crystal grit where it surfaces, and one time in SHARD_ODDS a quantum
## shard. Not while GRIT_CAP grit already lie untaken about the rock, nor a
## shard while one does (the caps are counted by the flight scene's
## `count_near`, from the rock's centre to cap_radius()). The dice are the
## Delver's own: its record's seed and how often it has surfaced, so the same
## Delver pays the same luck however the game is played.
func surfaced(npc: Npc) -> void:
	if npc.species.id != DelverBurrows.SPECIES or not drop.is_valid():
		return
	var n: int = _surfacings.get(npc.record.id, 0)
	_surfacings[npc.record.id] = n + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([npc.record.seed, n])
	var grit := rng.randi_range(GRIT.x, GRIT.y)
	var shard := rng.randi_range(0, SHARD_ODDS - 1) == 0
	if count_near.is_valid():
		var centre := frame().origin
		if int(count_near.call(&"crystal_grit", centre, cap_radius())) >= GRIT_CAP:
			grit = 0
		if shard and int(count_near.call(&"quantum_shard", centre, cap_radius())) >= 1:
			shard = false
	var up := npc.global_basis.y
	if grit > 0:
		drop.call(&"crystal_grit", behind(npc), up, grit)
	if shard:
		drop.call(&"quantum_shard", behind(npc), up, 1)

## Just behind `npc`'s tail (a body lies along its z, head to -z).
func behind(npc: Npc) -> Vector3:
	return npc.global_position + npc.global_basis.z * (npc.species.size * 0.5 + TAIL_CLEAR)

## The cap on what a Delver leaves is counted within this of the rock's centre:
## its radius and CAP_MARGIN, metres.
func cap_radius() -> float:
	return rock.radius + CAP_MARGIN

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
