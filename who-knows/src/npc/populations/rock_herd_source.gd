class_name RockHerdSource
extends RefCounted

## The exterior director's source of skitters (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §4.2, §4.3): the herds of every big
## rock in detail whose surface comes within reach of an anchor. A rock is in
## detail within 4 km, far beyond a skitter's 350 m, so the ground is always
## there before its herds are.

var stream: AsteroidStream
var world_seed := 0
## A rock's herds are offered while its surface is within this of an anchor.
var reach := 350.0 + NpcDirector.DEMOTE_MARGIN
## Whether a point on a rock is too near a working drill for a herd to keep
## its home there (habitat modules spec §8.4): a Callable (site id, engine
## point) -> bool, or none.
var quiet: Callable

var _sites := {}   # rock id -> RockSite

func _init(p_stream: AsteroidStream) -> void:
	stream = p_stream
	world_seed = p_stream.seed

func records(director: NpcDirector) -> Array:
	var out: Array = []
	var anchors := director.anchors()
	var seen := {}
	if stream.details != null:
		for id: Vector4i in stream.details.live:
			var detail: AsteroidDetail = stream.details.live[id]
			if not is_instance_valid(detail) or not detail.is_inside_tree() or not _near(anchors, detail):
				continue
			seen[id] = true
			var site: RockSite = _sites.get(id)
			if site == null or site.detail != detail:
				site = RockSite.new(detail, world_seed)
				_sites[id] = site
			site.director = director
			for r in site.records:
				if quiet.is_valid() and quiet.call(site.id, site.frame() * r.home):
					continue
				out.append([r, site])
	for id in _sites.keys():
		if not seen.has(id):
			_sites.erase(id)
	return out

## The site for a rock, if its herds are on offer.
func site_for(rock: AsteroidRock) -> RockSite:
	return _sites.get(rock.id())

func _near(anchors: Array, detail: AsteroidDetail) -> bool:
	for a: Node3D in anchors:
		if a.global_position.distance_to(detail.global_position) - detail.rock.radius < reach:
			return true
	return false
