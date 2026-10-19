class_name RockLifeSource
extends RefCounted

## The exterior director's source of rock creatures (docs/superpowers/specs/
## 2026-10-18-rock-creatures-design.md §3.1; foundation spec §4.2, §4.3): the
## creatures of every big rock in detail whose surface comes within reach of
## an anchor. A rock is in detail within 4 km, far beyond any creature's live
## radius, so the ground is always there before its creatures are.

## The populations this source offers.
const POPULATIONS: Array[StringName] = [&"rock_herds", &"glinter_nests", &"delver_burrows", &"limpet_beds"]

var stream: AsteroidStream
var catalog: NpcCatalog
var world_seed := 0
## A rock's creatures are offered while its surface is within this of an
## anchor: the widest live radius of the rock species, and the margin.
var reach := 0.0
## Whether a point on a rock is too near a working drill for a creature that
## shies from drills to keep its home there (habitat modules spec §8.4): a
## Callable (site id, engine point) -> bool, or none. Asked once, when a rock's
## creatures are first offered (it comes into detail), so creatures already out
## are not taken away in view: they have moved away the next time the rock
## loads. Only creatures whose species has `shy_of_drills` are asked about.
var quiet: Callable
## Copied onto every site this source builds (RockSite has what each is for).
var place_salvage: Callable
var base_place: Callable
var base_sip: Callable
var drop: Callable
var count_near: Callable

var _sites := {}   # rock id -> RockSite
var _offered := {}   # rock id -> the site's records that were not quiet when it was built

func _init(p_stream: AsteroidStream, p_catalog: NpcCatalog) -> void:
	stream = p_stream
	catalog = p_catalog
	world_seed = p_stream.seed
	var widest := 0.0
	if catalog != null:
		for id: StringName in catalog.ids():
			var species := catalog.get_def(id)
			if species != null and species.population in POPULATIONS:
				widest = maxf(widest, species.live_radius)
	reach = widest + NpcDirector.DEMOTE_MARGIN

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
				site.place_salvage = place_salvage
				site.base_place = base_place
				site.base_sip = base_sip
				site.drop = drop
				site.count_near = count_near
				site.place_nests()
				_sites[id] = site
				var kept: Array = []
				for r in site.records:
					if quiet.is_valid() and _shy(r) and quiet.call(site.id, site.frame() * r.home):
						continue
					kept.append(r)
				_offered[id] = kept
			site.director = director
			for r in _offered[id]:
				out.append([r, site])
	for id in _sites.keys():
		if not seen.has(id):
			_sites.erase(id)
			_offered.erase(id)
	return out

## The site for a rock, if its creatures are on offer.
func site_for(rock: AsteroidRock) -> RockSite:
	return _sites.get(rock.id())

## Whether `record`'s species keeps away from drills; one the catalog does not
## know is assumed to, as the default is.
func _shy(record: NpcRecord) -> bool:
	var species := catalog.get_def(record.species) if catalog != null else null
	return species == null or species.shy_of_drills

func _near(anchors: Array, detail: AsteroidDetail) -> bool:
	for a: Node3D in anchors:
		if a.global_position.distance_to(detail.global_position) - detail.rock.radius < reach:
			return true
	return false
