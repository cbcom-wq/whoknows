class_name WadooSource
extends RefCounted

## The exterior director's source of Wadoo's people (docs/superpowers/specs/
## 2026-11-16-wadoo-design.md §4, §12): the cast, offered while the oasis is loaded
## and an anchor (your ship, you on foot) is within NEAR_ENOUGH of it. The place
## loads 8 km out, far beyond their live radius, so the ground is always there
## before them; the town's site (its paths, a grid of half-metre cells) is made
## when you come near, not at every load.

const PLACE := &"oasis"
const NEAR_ENOUGH := 1500.0

var places: PlaceField
## You: they keep a little room from you.
var avatar: Node3D
var site: WadooSite
var _records: Array[NpcRecord] = []

func _init(p_places: PlaceField) -> void:
	places = p_places

func records(director: NpcDirector) -> Array:
	var out: Array = []
	var node := places.loaded(PLACE) if places != null else null
	if node == null:
		site = null
		return out
	if site == null or site.node != node:
		if not _near(director, node):
			return out
		site = _make_site(node)
		if site == null:
			return out
	site.director = director
	site.avatar = avatar
	if _records.is_empty():
		_records = WadooCast.records(site.layout)
	for r in _records:
		out.append([r, site])
	return out

func _make_site(node: Node3D) -> WadooSite:
	var design := places.design(PLACE)
	var terrain := places.terrain_of_place(PLACE)
	if design == null or terrain == null:
		return null
	_records.clear()
	return WadooSite.new(node, design.layout(), float(node.get_meta(&"water_radius", 0.0)),
		PlaceField.ground_fn(design, terrain), design.frame().inverse() * -PlaceField.origin_of(design, terrain), PLACE)

func _near(director: NpcDirector, node: Node3D) -> bool:
	for a: Node3D in director.anchors():
		if a.global_position.distance_to(node.global_position) < NEAR_ENOUGH:
			return true
	return false
