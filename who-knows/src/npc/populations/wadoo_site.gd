class_name WadooSite
extends NpcSite

## Wadoo, the oasis town (docs/superpowers/specs/2026-11-16-wadoo-design.md §4, §5,
## §12), as its people know it: the place's frame, its ground, where they can walk
## (WadooPaths), the spots where each job is done, who holds which spot, who is
## talking with whom, and who is indoors out of sight.
##
## Points are site-local: the place's frame, x = east, z = -north, y up at the
## place's origin. A spot is {key, kind, at: Vector3, face: Vector3, action}.
## The paths and the spots come from the layout alone; the ground from a Callable
## (east, north) -> Vector3, as PlaceField.ground_fn gives, cached on a 1 m grid.

const SPOT_KINDS: Array[StringName] = [&"garden", &"dry", &"pump", &"glass", &"breach", &"memorial",
	&"shade", &"bank", &"wash", &"post", &"court"]
## How far out from what is worked a worker stands, m.
const GARDEN_OUT := 0.7
const PUMP_OUT := 1.5
const MEMORIAL_OUT := 1.0
const BANK_OUT := 1.1
const BANK_SPOTS := 12
## A sitter stands this far in front of a bench's middle line before sitting.
const SIT_OUT := 0.38
const SEAT_APART := 0.6
## The last stretch to a spot may cross the margins the paths keep (to a bench).
const LAST_STRETCH := 1.2
## Talking: partners within this, and wanting company over this, stand this apart.
const PAIR_REACH := 20.0
const PAIR_WANTS := 0.45
const PAIR_APART := 1.1
## Others counted near, m.
const NEAR := 3.0
const GROUND_CELL := 1.0
const GRAVITY := 9.8

## The paths of each place's layout, built once (a grid of a few hundred thousand
## cells is not built again each time the place loads).
static var _paths_of := {}

var node: Node3D
var layout: Dictionary
var pool_radius := 0.0
var paths: WadooPaths
## The ground of a layout point (east, north) -> Vector3, site-local.
var ground_of: Callable
## The world's middle, site-local: up is away from it.
var centre := Vector3(0.0, -1.0e9, 0.0)
var director: NpcDirector
## You, when you are near: they keep a little room from you too.
var avatar: Node3D

var _spots := {}   # kind -> Array[Dictionary]
var _claims := {}  # spot key -> who (a record id)
var _held := {}    # who -> spot key
var _pairs := {}   # who -> {partner, at, face}
var _hidden := {}  # who -> true
var _state := {}   # who -> &"seated"
var _heights := {}  # Vector2i -> Vector3
var _near_frame := -1
var _near := {}    # Npc -> Vector2, this physics frame's

func _init(p_node: Node3D, p_layout: Dictionary, p_pool_radius: float, p_ground: Callable,
		p_centre := Vector3(0.0, -1.0e9, 0.0), place_id := &"oasis") -> void:
	id = WadooCast.SITE
	node = p_node
	layout = p_layout
	pool_radius = p_pool_radius
	ground_of = p_ground
	centre = p_centre
	var key := "%s:%.2f" % [place_id, pool_radius]
	if not _paths_of.has(key):
		_paths_of[key] = WadooPaths.build(layout, pool_radius)
	paths = _paths_of[key]
	_make_spots()

func frame() -> Transform3D:
	return node.global_transform if is_instance_valid(node) and node.is_inside_tree() else Transform3D.IDENTITY

func alive() -> bool:
	return is_instance_valid(node) and node.is_inside_tree()

func gravity(local: Vector3) -> Vector3:
	return frame().basis * (-up_at(local) * GRAVITY)

## Up at a site-local point: away from the world's middle.
func up_at(local: Vector3) -> Vector3:
	return (local - centre).normalized()

## The ground at [east, north] `p`, site-local: bilinear between the corners of
## its GROUND_CELL square.
func ground(p: Vector2) -> Vector3:
	var g := p / GROUND_CELL
	var c := Vector2i(floori(g.x), floori(g.y))
	var t := g - Vector2(c)
	var a := _corner(c)
	var b := _corner(c + Vector2i(1, 0))
	var d := _corner(c + Vector2i(0, 1))
	var e := _corner(c + Vector2i(1, 1))
	return a.lerp(b, t.x).lerp(d.lerp(e, t.x), t.y)

func _corner(c: Vector2i) -> Vector3:
	if not _heights.has(c):
		_heights[c] = ground_of.call(c.x * GROUND_CELL, c.y * GROUND_CELL)
	return _heights[c]


static func flat(local_point: Vector3) -> Vector2:
	return Vector2(local_point.x, -local_point.z)

# --- walking ------------------------------------------------------------------

## The way from `from` to `to`, [east, north]: the paths' route, and the last
## stretch to `to` itself when it lies within a margin the paths keep (a seat).
func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	var r := paths.route(from, to)
	if not r.is_empty() and r[r.size() - 1].distance_to(to) > 0.01 and r[r.size() - 1].distance_to(to) < LAST_STRETCH:
		r.append(to)
	return r

func open(p: Vector2) -> bool:
	return paths.is_open(p)

## Others near `npc`, [east, north]: the town's live people and you.
func neighbours(npc: Npc) -> PackedVector2Array:
	_refresh_near(npc)
	var out := PackedVector2Array()
	var here: Vector2 = _near.get(npc, flat(npc.local_position()))
	for other: Npc in _near:
		if other == npc:
			continue
		var p: Vector2 = _near[other]
		if p.distance_squared_to(here) < NEAR * NEAR:
			out.append(p)
	if is_instance_valid(avatar) and avatar.is_inside_tree():
		var you := flat(frame().affine_inverse() * avatar.global_position)
		if you.distance_squared_to(here) < NEAR * NEAR:
			out.append(you)
	return out

## Every live person's place, once a physics frame.
func _refresh_near(npc: Npc) -> void:
	var f := Engine.get_physics_frames()
	if f == _near_frame:
		return
	_near_frame = f
	_near.clear()
	var inverse := frame().affine_inverse()
	for other: Npc in _town(npc):
		if is_instance_valid(other) and not _hidden.has(other.record.id):
			_near[other] = flat(inverse * other.global_position)

## The live people of the town.
func _town(npc: Npc) -> Array:
	if director != null:
		return director.herd_of(npc)
	return [npc]

# --- who they are -------------------------------------------------------------

func person(record: NpcRecord) -> Dictionary:
	var n := WadooCast.index_of(record.id)
	return WadooCast.person(n) if n >= 0 else {}

func group_seed(record: NpcRecord) -> int:
	return record.seed

## Where `record` is when it wakes at `time`: a Sunguard at their post, the queen
## before her hall, anyone else somewhere their day takes them, by seed and the
## hour, a little off it so no two wake on one spot.
func start_pose(record: NpcRecord, time: float) -> Transform3D:
	# asked only of those not live: whatever they held or were doing is over
	release(record.id)
	end_pair(record.id)
	_hidden.erase(record.id)
	_state.erase(record.id)
	var n := WadooCast.index_of(record.id)
	var who := WadooCast.person(n) if n >= 0 else {}
	var p := flat(record.home)
	var face_at: Variant = null
	var rng := RandomNumberGenerator.new()
	rng.seed = record.seed + int(time / 60.0)
	match who.get("role", &"villager"):
		&"sunguard":
			var post := spot(&"post", "post:%s" % who.get("post", "gate"))
			if post.is_empty():
				post = spot(&"post", "post:%s:0" % who.get("post", "gate"))
			if not post.is_empty():
				p = flat(post["at"])
				face_at = flat(post["face"])
		&"queen":
			var court := spot(&"court", "court:queen")
			if not court.is_empty():
				p = flat(court["at"])
				face_at = flat(court["face"])
		_:
			var choices: Array = []
			var door := door_of(str(who.get("home", "")))
			if not door.is_empty():
				choices.append(flat(door["at"]))
			for kind: String in who.get("jobs", []):
				for s: Dictionary in _spots.get(StringName(kind), []):
					choices.append(flat(s["at"]))
			for s: Dictionary in _spots.get(&"bank", []):
				choices.append(flat(s["at"]))
			if not choices.is_empty():
				p = choices[rng.randi() % choices.size()]
				p = paths.nearest_open(p + Vector2(rng.randf_range(-2.5, 2.5), rng.randf_range(-2.5, 2.5)))
	var at := ground(p)
	var heading := Vector2.from_angle(rng.randf() * TAU) if face_at == null else ((face_at as Vector2) - p).normalized()
	if heading.length() < 0.5:
		heading = Vector2(0.0, 1.0)
	var up := up_at(at)
	var fwd := Vector3(heading.x, 0.0, -heading.y)
	return Transform3D(Basis.looking_at((fwd - up * fwd.dot(up)).normalized(), up), at)

## Fills in the town, who they are, and the open ground about them.
func fill(ctx: NpcContext, npc: Npc) -> void:
	ctx.extra[&"town"] = self
	ctx.extra[&"person"] = person(npc.record)
	ctx.extra[&"pair"] = pair_of(npc.record.id)
	ctx.extra[&"state"] = _state.get(npc.record.id, &"")
	if _hidden.has(npc.record.id):
		# indoors: they neither see you nor step aside for you
		ctx.extra[&"indoors"] = true
		ctx.player = null
	var here := flat(ctx.position)
	var nearby: Array[Vector3] = []
	for k in 8:
		var p := here + Vector2.from_angle(TAU * k / 8.0) * 2.0
		if paths.is_open(p) and paths.clear_line(here, p):
			nearby.append(ground(p))
	ctx.extra[&"nearby"] = nearby

func died(npc: Npc) -> void:
	release(npc.record.id)
	end_pair(npc.record.id)
	_hidden.erase(npc.record.id)
	_state.erase(npc.record.id)

# --- spots --------------------------------------------------------------------

## Every spot of `kind`.
func spots(kind: StringName) -> Array:
	return _spots.get(kind, [])

## The spot of `kind` called `key`, or {}.
func spot(kind: StringName, key: String) -> Dictionary:
	for s: Dictionary in _spots.get(kind, []):
		if s["key"] == key:
			return s
	return {}

## Takes the spot called `key` for `who`, letting go of any other they held.
## False if someone else holds it.
func claim(key: String, who: StringName) -> bool:
	var holder: Variant = _claims.get(key)
	if holder != null and holder != who:
		return false
	release(who)
	_claims[key] = who
	_held[who] = key
	return true

func release(who: StringName) -> void:
	if _held.has(who):
		_claims.erase(_held[who])
		_held.erase(who)

func holder_of(key: String) -> Variant:
	return _claims.get(key)

## A free spot of `kind` for `who`, claimed: the nearest to `near`, give or take
## a few metres by `salt`, so the same person does not always pick the same. {} if
## every one is held.
func take_spot(kind: StringName, who: StringName, near: Vector3, salt: int) -> Dictionary:
	var best := {}
	var best_score := INF
	var list: Array = _spots.get(kind, [])
	for k in list.size():
		var s: Dictionary = list[k]
		var holder: Variant = _claims.get(s["key"])
		if holder != null and holder != who:
			continue
		var jitter := float(posmod(hash(salt + k * 7919), 1000)) / 1000.0 * 12.0
		var score := flat(s["at"]).distance_to(flat(near)) + jitter
		if score < best_score:
			best = s
			best_score = score
	if not best.is_empty():
		claim(best["key"], who)
	return best

## The door of the shell `home`: {at (where to stand, outside), door (its middle),
## out}, site-local; {} if it has none.
func door_of(home: String) -> Dictionary:
	var list: Array = paths.doors.get(home, [])
	if list.is_empty():
		return {}
	var d: Dictionary = list[0]
	return {"at": ground(d["at"]), "door": ground(d["door"]), "out": d["out"]}

func _make_spots() -> void:
	_spots.clear()
	var pool_at := WadooPaths._v2(layout.get("pool", {}).get("at", [0, 0]))
	for g: Dictionary in layout.get("gardens", []):
		var c := WadooPaths._v2(g["at"])
		var size: Array = g.get("size", [4.0, 3.0])
		var half := Vector2(float(size[0]), float(size[1])) * 0.5
		var dried := bool(g.get("dried", false))
		var kind := &"dry" if dried else &"garden"
		var sides := [Vector2(half.x + GARDEN_OUT, 0.0), Vector2(-half.x - GARDEN_OUT, 0.0),
			Vector2(0.0, half.y + GARDEN_OUT), Vector2(0.0, -half.y - GARDEN_OUT)]
		var actions := [&"kneel", &"kneel", &"kneel", &"kneel"] if dried else [&"water", &"harvest", &"plant", &"water"]
		for k in sides.size():
			_add(kind, "%s:%d" % [g["id"], k], c + sides[k], c, actions[k])
	if layout.has("pump"):
		var c := WadooPaths._v2(layout["pump"]["at"])
		var k := 0
		for dir: Vector2 in [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0)]:
			_add(&"pump", "pump:%d" % k, c + dir * PUMP_OUT, c, &"interact")
			k += 1
	var works: Array = paths.doors.get("workshop", [])
	if not works.is_empty():
		var d: Dictionary = works[0]
		var out: Vector2 = d["out"]
		var side := Vector2(out.y, -out.x)
		var k := 0
		for at: Vector2 in [d["at"] + side * 1.4, d["at"] - side * 1.4, d["at"] + out * 1.2]:
			_add(&"glass", "glass:%d" % k, at, d["door"], [&"kneel", &"interact", &"kneel"][k])
			k += 1
	if paths.breach != Vector2.ZERO:
		var b := paths.breach
		var inward := (pool_at - b).normalized()
		var side := Vector2(inward.y, -inward.x)
		var k := 0
		for s: float in [-2.5, 0.0, 2.5]:
			_add(&"breach", "breach:%d" % k, b + inward * 3.0 + side * s, b + side * s, [&"lift", &"kneel", &"lift"][k])
			k += 1
		_add(&"post", "post:breach", b + inward * 5.0 + side * 3.5, b + side * 3.5, &"watch")
		_add(&"post", "post:breach_walk:0", b + inward * 2.2 + side * 4.5, b, &"watch")
		_add(&"post", "post:breach_walk:1", b + inward * 2.2 - side * 4.5, b, &"watch")
	if paths.gate != Vector2.ZERO:
		var inward := (pool_at - paths.gate).normalized()
		_add(&"post", "post:gate", paths.gate + inward * 3.0, paths.gate, &"watch")
	if layout.has("memorial"):
		var m: Dictionary = layout["memorial"]
		var c := WadooPaths._v2(m["at"])
		var r := float(m.get("radius", 2.4)) + MEMORIAL_OUT
		var stones := int(m.get("stones", 6))
		for k in stones:
			# before stone k (OasisLooks.memorial_dir), beside its lamp
			var d := OasisLooks.memorial_dir(k, stones)
			_add(&"memorial", "memorial:%d" % k, c + Vector2(d.x, -d.z) * r, c, &"kneel")
	var benches: Array = layout.get("benches", [])
	for b in benches.size():
		var bench: Dictionary = benches[b]
		var c := WadooPaths._v2(bench["at"])
		var yaw := float(bench.get("yaw", 0.0))
		var ahead := WadooPaths.local_to_place(Vector2(0.0, 1.0), yaw)
		for k in 2:
			var at := c + WadooPaths.local_to_place(Vector2((k - 0.5) * 2.0 * SEAT_APART, SIT_OUT), yaw)
			_add(&"shade", "shade:%d:%d" % [b, k], at, at + ahead * 2.0, &"sit", false)
	if pool_radius > 0.0:
		for k in BANK_SPOTS:
			var dir := Vector2.from_angle(TAU * k / BANK_SPOTS)
			var at := pool_at + dir * (pool_radius + BANK_OUT)
			if paths.is_open(at):
				_add(&"bank", "bank:%d" % k, at, pool_at, &"drink", false)
		for k in 4:
			var dir := Vector2.from_angle(TAU * k / 4.0 + 0.4)
			var at := pool_at + dir * (pool_radius + BANK_OUT)
			if paths.is_open(at):
				_add(&"wash", "wash:%d" % k, at, pool_at, &"kneel", false)
		_add(&"post", "post:pool", pool_at + Vector2(0.0, pool_radius + 2.4), pool_at, &"watch")
	var hall := door_of("house_b")
	if not hall.is_empty():
		var out: Vector2 = hall["out"]
		var side := Vector2(out.y, -out.x)
		var at := flat(hall["at"])
		_add(&"post", "post:queen_door", at + side * 1.3, at + side * 1.3 + out * 3.0, &"watch")
		_add(&"court", "court:queen", at + out * 1.2, at + out * 6.0, &"")

## A spot of `kind`, its point snapped to open ground unless `snap` is false (a
## seat is reached by the last stretch).
func _add(kind: StringName, key: String, at: Vector2, face: Vector2, action: StringName, snap := true) -> void:
	if snap and not paths.is_open(at):
		at = paths.nearest_open(at)
	_spots.get_or_add(kind, []).append({"key": key, "kind": kind, "at": ground(at), "face": ground(face),
		"action": action})

# --- talking ------------------------------------------------------------------

## Who `who` is talking with: {partner, at, face}, or {}.
func pair_of(who: StringName) -> Dictionary:
	var p: Dictionary = _pairs.get(who, {})
	if p.is_empty():
		return p
	if director != null and not director.live.has(p["partner"]):
		end_pair(who)
		return {}
	return p

## Finds `who` someone to talk with: the nearest live villager who wants company,
## is not talking, sitting or indoors; meets them halfway. The pair, or {}.
func ask_pair(who: StringName) -> Dictionary:
	var me := who
	if _pairs.has(me):
		return pair_of(me)
	var npc: Npc = director.live.get(who) if director != null else null
	if npc == null:
		return {}
	var here := flat(npc.local_position())
	var best: Npc = null
	var best_d := PAIR_REACH
	for other: Npc in _town(npc):
		if other == npc or not is_instance_valid(other) or other.record == null:
			continue
		var them := other.record.id
		if _pairs.has(them) or _hidden.has(them) or _state.has(them) or other.down \
				or other.species.id != &"wadee_villager":
			continue
		if other.brain == null or float(other.brain.needs.get(&"company", 0.0)) < PAIR_WANTS:
			continue
		var d := flat(other.local_position()).distance_to(here)
		if d < best_d:
			best = other
			best_d = d
	if best == null:
		return {}
	var there := flat(best.local_position())
	var mid := paths.nearest_open((here + there) * 0.5)
	var dir := (there - here).normalized() if there.distance_to(here) > 0.01 else Vector2(1, 0)
	var a := mid - dir * PAIR_APART * 0.5
	var b := mid + dir * PAIR_APART * 0.5
	if not paths.is_open(a) or not paths.is_open(b):
		dir = Vector2(dir.y, -dir.x)
		a = paths.nearest_open(mid - dir * PAIR_APART * 0.5)
		b = paths.nearest_open(mid + dir * PAIR_APART * 0.5)
	release(me)
	release(best.record.id)
	_pairs[me] = {"partner": best.record.id, "at": ground(a), "face": ground(b)}
	_pairs[best.record.id] = {"partner": me, "at": ground(b), "face": ground(a)}
	return _pairs[me]

## Ends `who`'s talk, for both.
func end_pair(who: StringName) -> void:
	var p: Dictionary = _pairs.get(who, {})
	_pairs.erase(who)
	if not p.is_empty() and _pairs.has(p["partner"]) and _pairs[p["partner"]]["partner"] == who:
		_pairs.erase(p["partner"])

# --- indoors ------------------------------------------------------------------

## `who` indoors (out of sight, not solid) or out again.
func hide(who: StringName, on: bool) -> void:
	if on:
		_hidden[who] = true
	else:
		_hidden.erase(who)
	var npc: Npc = director.live.get(who) if director != null else null
	if npc == null:
		return
	if npc.look != null:
		npc.look.visible = not on
	npc.set_solid(not on)

## How `who` is placed, for what others may ask of them: &"seated", or &"" for
## nothing special.
func mark(who: StringName, state: StringName) -> void:
	if state == &"":
		_state.erase(who)
	else:
		_state[who] = state

func hidden(who: StringName) -> bool:
	return _hidden.has(who)
