class_name SystemRecipe
extends RefCounted

## A whole star system from one seed (the system skeleton spec §4): the star at
## the universe's origin, slots round it that are each a planet or a belt,
## moons round planets, and rings on some. Pure: no nodes, any thread, the
## same on every machine.
##
## Each concern draws from its own sub-seed (WorldSeed): the star, the slots,
## and for slot i its world, its orbit, its moons and its ring. Tuning one
## never reshuffles another. The system is a flattened disc, y up, in the
## plane y = PLANE_Y: the middle of a layer of the asteroids' 5 km giant cells,
## so a belt lies inside one layer where its big rocks can sit.
##
## The rules it keeps (§4.3): no two neighbourhoods overlap, a moon's lies
## inside its planet's, moons are clear of each other's wells and of their
## planet's ring, and belts are clear of every neighbourhood. `problems()`
## checks them.
##
## It also lists the warp targets (docs/superpowers/specs/2026-09-28-warp-design.md
## §3): the star, the planets and the belts' clusters, each with a warp limit,
## and a disc of orbital debris round every planet.

## Bumped whenever a seed's system changes: a save made by another version
## starts over (saving spec §8.1).
const VERSION := 2

## The height of the system's disc, and of the star's centre.
const PLANE_Y := 2500

const STAR_RADIUS := Vector2(2500.0, 4000.0)
## The star's neighbourhood reaches this far past its well.
const STAR_ROOM := 4000.0
## The first slot, give or take FIRST_SLOT_JITTER; each next one this many
## times further out; none past LAST_SLOT; never more than MOST_SLOTS.
const FIRST_SLOT := 30000.0
const FIRST_SLOT_JITTER := 0.1
const SLOT_RATIO := Vector2(1.18, 1.30)
const LAST_SLOT := 150000.0
const MOST_SLOTS := 10
## A planet sits up to this share of its slot's radius off the disc.
const TILT := 0.03
## Tries at an angle round the star before giving up the moons, and again
## before leaving the slot empty.
const PLACE_TRIES := 32
## A planet's neighbourhood reaches at least this far past its well.
const PLANET_ROOM := 2000.0
## Everything keeps this far from whatever it must be clear of.
const CLEAR := 1000.0
## A moon's neighbourhood reaches this far past its well.
const MOON_ROOM := 500.0
const MOST_MOONS := 3
## A moon is this far from its planet's centre, at most.
const MOON_FAR := 14000.0
## ... and at least this far.
const MOON_NEAR := 6000.0
const MOON_TRIES := 16
## Rings: on planets this big, this often.
const RING_MIN_RADIUS := 600.0
const RING_CHANCE := 0.25
const RING_INNER := Vector2(1.6, 2.0)
const RING_WIDTH := Vector2(1000.0, 2500.0)
const RING_HALF_THICKNESS := 40.0
const RING_TILT := deg_to_rad(30.0)
## Belts: this many, never slot 0, never side by side.
const BELTS := Vector2i(1, 2)
## A belt's cross-section. One big rock per 5 km cell at most, so a belt needs
## about 25 km2 of cross-section to hold a group every 5 km along it.
const BELT_HALF_WIDTH := Vector2(4000.0, 7000.0)
const BELT_HALF_THICKNESS := Vector2(1500.0, 2000.0)
## A belt squeezed below this half-width is dropped; planets beside a belt
## leave it at least this.
const BELT_MIN_HALF_WIDTH := 3000.0
## A belt goes only where both gaps to its neighbouring slots are this wide:
## room for its narrowest self and the biggest moonless planet beside it.
const BELT_GAP := 12000.0
## A warp may start this far past a body's edge (the warp spec §3.2): about
## two minutes of flying at 120 m/s.
const WARP_CLEAR := 14000.0
## A belt cluster's reach from its centre (§3.1).
const CLUSTER_RADIUS := 4000.0
## Clusters per belt, and tries at a seeded angle for each.
const CLUSTERS := Vector2i(3, 6)
const CLUSTER_TRIES := 24
## Orbital debris (§3.3): a disc from a planet's well to this far inside its
## warp limit, this thick, tilted up to this much off the system's plane when
## there is no ring to follow.
const DEBRIS_INSIDE := 1000.0
const DEBRIS_HALF_THICKNESS := 3000.0
const DEBRIS_TILT := deg_to_rad(20.0)

var seed: int
var name: String
var star: SystemBody
## The star first, then each planet followed by its moons.
var bodies: Array[SystemBody] = []
var belts: Array[AsteroidShapes.Belt] = []
## Each slot's radius from the star, inner first.
var slots: PackedFloat64Array = []
## Which slots are belts.
var belt_slots: PackedInt32Array = []
## Slots that should have held a planet but had no room (§4.3).
var empty_slots: PackedInt32Array = []
## Why each empty slot is empty, in the same order.
var empty_why: PackedStringArray = []
## The belts' clusters, belt by belt (the warp spec §3.1).
var clusters: Array[WarpTarget] = []
## One debris disc per planet, in planets() order (§3.3).
var debris: Array[AsteroidShapes.Debris] = []

var _by_id := {}
var _entry: UniversePoint
var _targets: Array[WarpTarget] = []
var _target_by_id := {}

static func from_seed(p_seed: int) -> SystemRecipe:
	var s := SystemRecipe.new()
	s.seed = p_seed
	s._make_star()
	s._make_slots()
	for i in s.slots.size():
		if not s.belt_slots.has(i):
			s._make_planet(i)
	for i in s.belt_slots:
		s._make_belt(i)
	s._make_debris()
	s._make_clusters()
	s._make_targets()
	return s

func body(id: StringName) -> SystemBody:
	return _by_id.get(id)

## The planets, in slot order.
func planets() -> Array[SystemBody]:
	var out: Array[SystemBody] = []
	for b in bodies:
		if b.kind == SystemBody.Kind.PLANET:
			out.append(b)
	return out

## The moons of `planet`.
func moons_of(planet: SystemBody) -> Array[SystemBody]:
	var out: Array[SystemBody] = []
	for b in bodies:
		if b.parent_id == planet.id:
			out.append(b)
	return out

## Where the flight starts, and where jumps between stars will arrive (§4.4):
## 700 m off the first belt's first group. Found without the clusters' lift,
## since the first cluster is centred here (the warp spec §3.1).
func entry() -> UniversePoint:
	if _entry == null:
		_entry = AsteroidRecipe.new(seed, null, asteroid_shapes(false)).find_start()
	return _entry

## Where the rocks are, for AsteroidRecipe (§6; the warp spec §3): belts,
## rings, debris and bodies, and the clusters unless `with_clusters` is false.
func asteroid_shapes(with_clusters := true) -> AsteroidShapes:
	var shapes := AsteroidShapes.new()
	shapes.belts = belts.duplicate()
	shapes.debris = debris.duplicate()
	for b in bodies:
		if b.ring != null:
			shapes.rings.append(b.ring)
		var blocker := AsteroidShapes.Blocker.new()
		blocker.centre = b.point
		blocker.radius = b.radius
		shapes.blockers.append(blocker)
	if with_clusters:
		for c in clusters:
			var lift := AsteroidShapes.Cluster.new()
			lift.centre = c.point
			lift.radius = c.radius
			shapes.clusters.append(lift)
	return shapes

## Every place a warp can take you (the warp spec §3.1): the star, the planets
## in slot order, then the clusters.
func warp_targets() -> Array[WarpTarget]:
	return _targets

func warp_target(id: StringName) -> WarpTarget:
	return _target_by_id.get(id)

## Every broken rule of §4.3, as text; empty when all hold.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	var tops: Array[SystemBody] = [star]
	tops.append_array(planets())
	for i in tops.size():
		for j in range(i + 1, tops.size()):
			var a := tops[i]
			var b := tops[j]
			if a.point.minus(b.point).length() < a.neighbourhood + b.neighbourhood:
				out.append("%s and %s overlap" % [a.id, b.id])
	for p in planets():
		var moons := moons_of(p)
		for m in moons:
			var d := m.point.minus(p.point).length()
			if d + m.neighbourhood > p.neighbourhood:
				out.append("%s pokes out of %s" % [m.id, p.id])
			if d - m.well_radius < p.well_radius + CLEAR:
				out.append("%s is in %s's well" % [m.id, p.id])
			if p.ring != null and d - m.well_radius < p.ring.outer + CLEAR:
				out.append("%s is in %s's ring" % [m.id, p.id])
		for i in moons.size():
			for j in range(i + 1, moons.size()):
				var gap := moons[i].point.minus(moons[j].point).length()
				if gap < moons[i].well_radius + moons[j].well_radius + CLEAR:
					out.append("%s and %s are too close" % [moons[i].id, moons[j].id])
	for k in belts.size():
		for b in tops:
			if _belt_room(belts[k], b) < maxf(belts[k].half_width, belts[k].half_thickness) - 0.01:
				out.append("belt %d crosses %s" % [k, b.id])
	for b in tops:
		if b.warp_limit < b.neighbourhood + CLEAR - 0.01:
			out.append("%s's warp limit is inside its neighbourhood" % b.id)
	for i in clusters.size():
		for j in range(i + 1, clusters.size()):
			var a := clusters[i]
			var c := clusters[j]
			if a.belt == c.belt and a.point.minus(c.point).length() < a.limit + c.limit - 0.01:
				out.append("%s and %s are too close" % [a.id, c.id])
	var ps := planets()
	for k in debris.size():
		if debris[k].inner < ps[k].well_radius - 0.01 or debris[k].outer > ps[k].warp_limit - DEBRIS_INSIDE + 0.01:
			out.append("%s's debris leaves its place" % ps[k].id)
	return out

## The system as plain text, for tests and for the owner.
func describe() -> String:
	var lines := PackedStringArray(["%s (seed %d)" % [name, seed]])
	for b in bodies:
		var u := b.point
		var line := "  %-6s %-16s r %5.0f m  at (%.1f, %.1f, %.1f) km  room %.1f km" % [
			b.id, b.name, b.radius, u.x / 1000.0, u.y / 1000.0, u.z / 1000.0, b.neighbourhood / 1000.0]
		if b.ring != null:
			line += "  ring %.1f-%.1f km" % [b.ring.inner / 1000.0, b.ring.outer / 1000.0]
		if b.warp_limit > 0.0:
			line += "  limit %.1f km" % (b.warp_limit / 1000.0)
		lines.append(line)
	for k in belts.size():
		var belt := belts[k]
		lines.append("  belt %d  %.1f km, half-width %.1f km" % [k, belt.radius / 1000.0, belt.half_width / 1000.0])
	for c in clusters:
		lines.append("  %-9s %-16s at (%.1f, %.1f, %.1f) km  limit %.1f km" % [c.id, c.name,
			c.point.x / 1000.0, c.point.y / 1000.0, c.point.z / 1000.0, c.limit / 1000.0])
	for k in empty_slots.size():
		lines.append("  slot %d empty: %s" % [empty_slots[k], empty_why[k]])
	return "\n".join(lines)

func _make_star() -> void:
	var rng := WorldSeed.rng(seed, &"star")
	star = SystemBody.new()
	star.id = &"star"
	star.kind = SystemBody.Kind.STAR
	star.seed = WorldSeed.sub(seed, &"star")
	star.name = WorldNames.star(rng)
	star.radius = rng.randf_range(STAR_RADIUS.x, STAR_RADIUS.y)
	star.star_palette = rng.randi_range(0, SpacePalette.STARS.size() - 1)
	star.point = UniversePoint.at(0, PLANE_Y, 0)
	star.well_radius = star.radius * WorldRecipe.WELL_RADII
	star.neighbourhood = star.well_radius + STAR_ROOM
	star.warp_limit = star.well_radius + WARP_CLEAR
	name = star.name
	_add(star)

func _make_slots() -> void:
	var rng := WorldSeed.rng(seed, &"slots")
	var a := FIRST_SLOT * rng.randf_range(1.0 - FIRST_SLOT_JITTER, 1.0 + FIRST_SLOT_JITTER)
	while a <= LAST_SLOT and slots.size() < MOST_SLOTS:
		slots.append(a)
		a *= rng.randf_range(SLOT_RATIO.x, SLOT_RATIO.y)
	var want := rng.randi_range(BELTS.x, BELTS.y)
	var choices := range(1, slots.size())
	for k in want:
		var open := choices.filter(func(i: int) -> bool:
			return not belt_slots.has(i) and not belt_slots.has(i - 1) and not belt_slots.has(i + 1))
		if open.is_empty():
			break
		# Only where both gaps leave a belt and its neighbours room; failing
		# that, the roomiest, so a system always has its belt.
		var roomy := open.filter(func(i: int) -> bool: return _gap(i) >= BELT_GAP)
		if roomy.is_empty():
			if k > 0:
				break
			open.sort_custom(func(a: int, b: int) -> bool: return _gap(a) > _gap(b))
			roomy = [open[0]]
		belt_slots.append(roomy[rng.randi_range(0, roomy.size() - 1)])
	belt_slots.sort()

## The narrower gap between slot `i` and its neighbours.
func _gap(i: int) -> float:
	var gap := slots[i] - slots[i - 1]
	if i + 1 < slots.size():
		gap = minf(gap, slots[i + 1] - slots[i])
	return gap

## The most a planet in slot `i` may claim, so every belt beside it keeps its
## narrowest width.
func _room_beside_belts(i: int) -> float:
	var room := INF
	for j in belt_slots:
		room = minf(room, absf(slots[i] - slots[j]) - BELT_MIN_HALF_WIDTH - CLEAR)
	return room

func _make_planet(i: int) -> void:
	var p := SystemBody.new()
	p.id = StringName("p%d" % i)
	p.kind = SystemBody.Kind.PLANET
	p.seed = WorldSeed.sub(seed, StringName("slot_%d" % i))
	p.recipe = WorldRecipe.from_seed(p.seed, WorldRecipe.Kind.PLANET)
	p.name = p.recipe.name
	p.radius = p.recipe.radius_m
	p.well_radius = p.recipe.well_radius()
	var room := _room_beside_belts(i)
	p.ring = _make_ring(i, p)
	var bare := maxf(p.well_radius + PLANET_ROOM, 0.0 if p.ring == null else p.ring.outer + CLEAR)
	if bare > room:
		p.ring = null
		bare = p.well_radius + PLANET_ROOM
		if bare > room:
			_leave_empty(i, "no room beside a belt")
			return
	var moons := _make_moons(i, p, room)
	p.neighbourhood = bare
	for m in moons:
		p.neighbourhood = maxf(p.neighbourhood, m[1].length() + m[0].neighbourhood + MOON_ROOM)
	# Round the star: first with its moons, then without.
	var orbit := WorldSeed.rng(seed, StringName("orbit_%d" % i))
	var at: Variant = _find_place(orbit, slots[i], p.neighbourhood)
	if at == null and not moons.is_empty():
		moons.clear()
		p.neighbourhood = bare
		at = _find_place(orbit, slots[i], p.neighbourhood)
	if at == null:
		_leave_empty(i, "no clear angle")
		return
	p.point = at
	p.warp_limit = maxf(p.well_radius + WARP_CLEAR, p.neighbourhood + CLEAR)
	if p.ring != null:
		p.ring.centre = p.point
	_add(p)
	for m: Array in moons:
		var moon: SystemBody = m[0]
		moon.point = p.point.plus(m[1])
		_add(moon)

## A place for a neighbourhood of `room` on the slot of `radius`, clear of
## every one placed so far, or null.
func _find_place(rng: RandomNumberGenerator, radius: float, room: float) -> Variant:
	for t in PLACE_TRIES:
		var angle := rng.randf() * TAU
		var y := radius * rng.randf_range(-TILT, TILT)
		var at := star.point.plus(Vector3(radius * cos(angle), y, radius * sin(angle)))
		var clear := true
		for other in bodies:
			if other.kind == SystemBody.Kind.MOON:
				continue
			if at.minus(other.point).length() < room + other.neighbourhood:
				clear = false
				break
		if clear:
			return at
	return null

func _make_ring(i: int, p: SystemBody) -> AsteroidShapes.Ring:
	var rng := WorldSeed.rng(seed, StringName("ring_%d" % i))
	if p.radius < RING_MIN_RADIUS or rng.randf() >= RING_CHANCE:
		return null
	var ring := AsteroidShapes.Ring.new()
	ring.inner = p.radius * rng.randf_range(RING_INNER.x, RING_INNER.y)
	ring.outer = ring.inner + rng.randf_range(RING_WIDTH.x, RING_WIDTH.y)
	ring.half_thickness = RING_HALF_THICKNESS
	var axis := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
	if axis.is_zero_approx():
		axis = Vector3.RIGHT
	ring.normal = Vector3.UP.rotated(axis.normalized(), rng.randf_range(0.0, RING_TILT))
	return ring

## [moon, offset from the planet's centre] for each moon, within `room` of the
## planet's centre, all told.
func _make_moons(i: int, p: SystemBody, room: float) -> Array:
	var rng := WorldSeed.rng(seed, StringName("moons_%d" % i))
	var t := inverse_lerp(WorldRecipe.RADIUS[0].x, WorldRecipe.RADIUS[0].y, p.radius)
	var count := mini(MOST_MOONS, floori(rng.randf_range(0.0, 1.5 + 2.5 * t)))
	var out := []
	for k in count:
		var m := SystemBody.new()
		m.id = StringName("p%d.m%d" % [i, k + 1])
		m.kind = SystemBody.Kind.MOON
		m.parent_id = p.id
		m.seed = WorldSeed.sub(seed, StringName("moon_%d_%d" % [i, k + 1]))
		m.recipe = WorldRecipe.from_seed(m.seed, WorldRecipe.Kind.MOON)
		m.name = WorldNames.moon(p.name, out.size())
		m.radius = m.recipe.radius_m
		m.well_radius = m.recipe.well_radius()
		m.neighbourhood = m.well_radius + MOON_ROOM
		var near := maxf(MOON_NEAR, p.well_radius + m.well_radius + CLEAR)
		if p.ring != null:
			near = maxf(near, p.ring.outer + m.well_radius + CLEAR)
		var far := minf(MOON_FAR, room - m.neighbourhood - MOON_ROOM)
		# The same draws whether or not it fits, so one that fails never
		# reshuffles the next.
		for t2 in MOON_TRIES:
			var dir := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
			var d := rng.randf_range(near, maxf(near, far))
			if near > far or dir.length() < 0.1:
				continue
			var offset := dir.normalized() * d
			var clear := true
			for o: Array in out:
				var other: SystemBody = o[0]
				if offset.distance_to(o[1]) < m.well_radius + other.well_radius + CLEAR:
					clear = false
					break
			if clear:
				out.append([m, offset])
				break
	return out

func _make_belt(i: int) -> void:
	var rng := WorldSeed.rng(seed, StringName("belt_%d" % i))
	var belt := AsteroidShapes.Belt.new()
	belt.centre = star.point
	belt.normal = Vector3.UP
	belt.radius = slots[i]
	belt.half_width = rng.randf_range(BELT_HALF_WIDTH.x, BELT_HALF_WIDTH.y)
	belt.half_thickness = rng.randf_range(BELT_HALF_THICKNESS.x, BELT_HALF_THICKNESS.y)
	for b in bodies:
		if b.kind == SystemBody.Kind.MOON:
			continue
		var room := _belt_room(belt, b)
		belt.half_width = minf(belt.half_width, room)
		belt.half_thickness = minf(belt.half_thickness, room)
	if belt.half_width < BELT_MIN_HALF_WIDTH:
		return
	belts.append(belt)

## A debris disc round every planet (the warp spec §3.3), in its ring's plane
## or a seeded one, with a hole at every other body's well it reaches.
func _make_debris() -> void:
	for p in planets():
		var d := AsteroidShapes.Debris.new()
		d.centre = p.point
		d.inner = p.well_radius
		d.outer = p.warp_limit - DEBRIS_INSIDE
		d.half_thickness = DEBRIS_HALF_THICKNESS
		if p.ring != null:
			d.normal = p.ring.normal
		else:
			var rng := WorldSeed.rng(seed, StringName("debris_%s" % p.id))
			var axis := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
			if axis.is_zero_approx():
				axis = Vector3.RIGHT
			d.normal = Vector3.UP.rotated(axis.normalized(), rng.randf_range(0.0, DEBRIS_TILT))
		for b in bodies:
			if b == p:
				continue
			var off := b.point.minus(p.point)
			if off.length() - b.well_radius < d.outer + d.half_thickness:
				d.holes.append([off, b.well_radius])
		debris.append(d)

## 3-6 clusters on each belt (the warp spec §3.1), their limits apart. The
## first belt's first is centred on the start.
func _make_clusters() -> void:
	var limit := CLUSTER_RADIUS + WARP_CLEAR
	for k in belts.size():
		var belt := belts[k]
		var rng := WorldSeed.rng(seed, StringName("clusters_%d" % k))
		var want := rng.randi_range(CLUSTERS.x, CLUSTERS.y)
		var across := belt.normal.cross(Vector3.RIGHT)
		if across.length() < 0.1:
			across = belt.normal.cross(Vector3.FORWARD)
		across = across.normalized()
		var sideways := belt.normal.cross(across)
		var mine: Array[WarpTarget] = []
		if k == 0:
			mine.append(_cluster(k, 1, entry(), rng))
		for t in CLUSTER_TRIES * want:
			if mine.size() >= want:
				break
			var angle := rng.randf() * TAU
			var at := belt.centre.plus((across * cos(angle) + sideways * sin(angle)) * belt.radius)
			if mine.any(func(c: WarpTarget) -> bool: return c.point.minus(at).length() < 2.0 * limit):
				continue
			mine.append(_cluster(k, mine.size() + 1, at, rng))
		clusters.append_array(mine)

func _cluster(belt: int, k: int, at: UniversePoint, rng: RandomNumberGenerator) -> WarpTarget:
	var c := WarpTarget.new()
	c.id = StringName("belt_%d.c%d" % [belt, k])
	c.kind = WarpTarget.Kind.CLUSTER
	c.name = WorldNames.cluster(rng)
	c.point = at
	c.radius = CLUSTER_RADIUS
	c.edge = CLUSTER_RADIUS
	c.limit = CLUSTER_RADIUS + WARP_CLEAR
	c.belt = belt
	return c

func _make_targets() -> void:
	for b in bodies:
		if b.kind == SystemBody.Kind.MOON:
			continue
		var t := WarpTarget.new()
		t.id = b.id
		t.kind = WarpTarget.Kind.STAR if b.kind == SystemBody.Kind.STAR else WarpTarget.Kind.PLANET
		t.name = b.name
		t.point = b.point
		t.radius = b.radius
		t.edge = b.well_radius
		t.limit = b.warp_limit
		_targets.append(t)
	_targets.append_array(clusters)
	for t in _targets:
		_target_by_id[t.id] = t

## How far a belt's cross-section may reach from its centre circle and stay
## CLEAR of `b`'s neighbourhood.
func _belt_room(belt: AsteroidShapes.Belt, b: SystemBody) -> float:
	var p := b.point.minus(belt.centre)
	var h := p.dot(belt.normal)
	var r := (p - belt.normal * h).length()
	var to_circle := Vector2(r - belt.radius, h).length()
	return to_circle - b.neighbourhood - CLEAR

func _leave_empty(i: int, why: String) -> void:
	empty_slots.append(i)
	empty_why.append(why)

func _add(b: SystemBody) -> void:
	bodies.append(b)
	_by_id[b.id] = b
