class_name LifeContacts
extends RefCounted

## Signs of life, for the ship's sensors (NPC foundation spec §22.1): one
## contact per herd on every big rock held in detail within reach, read by
## SenseProfile.life() -- a vague ping far off, a region 30 m across close by.
## A herd asleep is where its round has got to; awake, where its members
## actually are, so a region follows a herd that bolts or hides.

var stream: AsteroidStream
## The exterior's director: its clock drives the herds' rounds, and it knows
## which herds are awake.
var director: NpcDirector
var universe: Universe
var profile := SenseProfile.life()

var _herds := {}   # rock id -> [AsteroidDetail, Array[Dictionary], site id]

func _init(p_stream: AsteroidStream, p_director: NpcDirector, p_universe: Universe) -> void:
	stream = p_stream
	director = p_director
	universe = p_universe

func contacts(focus: UniversePoint, range_m: float, time: float) -> Array[Contact]:
	var out: Array[Contact] = []
	var reach := minf(range_m, profile.reach)
	for entry in _entries():
		for h: Dictionary in entry[1]:
			var at := herd_point(entry[0], h, entry[2])
			var c := Sense.read(profile, focus, universe.to_universe(at), herd_id(entry[2], h), time)
			if c != null and c.point.minus(focus).length() <= reach + c.radius:
				out.append(c)
	return out

func contact(id: StringName, focus: UniversePoint, time: float) -> Contact:
	for entry in _entries():
		for h: Dictionary in entry[1]:
			if herd_id(entry[2], h) == id:
				return Sense.read(profile, focus, universe.to_universe(herd_point(entry[0], h, entry[2])), id, time)
	return null

static func herd_id(site: StringName, h: Dictionary) -> StringName:
	return StringName("life:%s:%d" % [site, h["index"]])

## Where herd `h` is, engine space: its awake members' middle, or where its
## round has got to.
func herd_point(detail: AsteroidDetail, h: Dictionary, site: StringName) -> Vector3:
	if director != null:
		var sum := Vector3.ZERO
		var n := 0
		for npc: Npc in director.live_npcs():
			if npc.site != null and npc.site.id == site and npc.record.herd == int(h["index"]):
				sum += npc.global_position
				n += 1
		if n > 0:
			return sum / n
	var time := director.time if director != null else 0.0
	return detail.global_transform * detail.data.surface_point(RockHerds.round_dir(h, time))

## Every big rock in detail, with its herds, worked out once per rock.
func _entries() -> Array:
	var out: Array = []
	if stream == null or stream.details == null:
		return out
	var seen := {}
	for id: Vector4i in stream.details.live:
		var detail: AsteroidDetail = stream.details.live[id]
		if not is_instance_valid(detail) or not detail.is_inside_tree():
			continue
		seen[id] = true
		var entry: Array = _herds.get(id, [])
		if entry.is_empty() or entry[0] != detail:
			entry = [detail, RockHerds.herds(detail.rock, detail.data, stream.seed), RockHerds.site_of(detail.rock)]
			_herds[id] = entry
		out.append(entry)
	for id in _herds.keys():
		if not seen.has(id):
			_herds.erase(id)
	return out
