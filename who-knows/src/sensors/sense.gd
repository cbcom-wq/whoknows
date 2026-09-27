class_name Sense
extends RefCounted

## What the sensors say about one thing (NPC foundation spec §22.2): a pure
## function from where you are, where it is, who it is and the time, to a
## Contact -- a ping with a seeded error, a region with a seeded offset -- or
## null when it is out of reach. The same inputs always give the same answer,
## so the HUD and a future map agree.

## A reading of the thing called `id` at `target`, seen from `focus`, at
## `time` (the sensors' clock), by `profile`. Null beyond reach.
static func read(profile: SenseProfile, focus: UniversePoint, target: UniversePoint, id: StringName,
		time: float) -> Contact:
	var to := target.minus(focus)
	var distance := to.length()
	if distance > profile.reach:
		return null
	var c := Contact.new()
	c.id = id
	c.kind = profile.kind
	c.label = profile.label
	if distance > profile.region_within:
		var tick := floori(time / profile.ping_period)
		c.precision = Contact.PING
		c.taken = tick * profile.ping_period
		c.fresh_for = profile.ping_period
		c.km = maxi(1, roundi(distance / 1000.0))
		var dir := to / maxf(distance, 0.001)
		c.point = focus.plus(off_by(dir, id, tick, profile.ping_error_deg) * distance)
		return c
	c.precision = Contact.REGION
	c.taken = time
	c.radius = profile.region_radius
	c.point = target.plus(region_offset(id, profile.region_offset))
	return c

## `dir` turned by up to `max_deg` degrees, the same for `id` in one `tick`.
static func off_by(dir: Vector3, id: StringName, tick: int, max_deg: float) -> Vector3:
	var h := stable_hash(String(id)) ^ AsteroidRecipe.mix(tick + 0x51ED)
	var angle := deg_to_rad(max_deg) * _unit(AsteroidRecipe.mix(h))
	var bearing := TAU * _unit(AsteroidRecipe.mix(h ^ 0x7F4A7C15))
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized().rotated(dir, bearing)
	return dir.rotated(side, angle).normalized()

## Where a region's centre sits from the thing: fixed per id, at most `most`.
static func region_offset(id: StringName, most: float) -> Vector3:
	var h := stable_hash(String(id))
	var v := Vector3(_unit(AsteroidRecipe.mix(h)) * 2.0 - 1.0, _unit(AsteroidRecipe.mix(h ^ 0x9E37)) * 2.0 - 1.0,
		_unit(AsteroidRecipe.mix(h ^ 0x85EB)) * 2.0 - 1.0)
	if v.length() < 0.001:
		return Vector3.ZERO
	return v.normalized() * most * _unit(AsteroidRecipe.mix(h ^ 0xC2B2))

## A hash of a string that never changes between engine versions.
static func stable_hash(s: String) -> int:
	var h := 0
	for b in s.to_utf8_buffer():
		h = AsteroidRecipe.mix(h ^ b)
	return h

static func _unit(h: int) -> float:
	return float(h & 0xFFFFFF) / float(0xFFFFFF)
