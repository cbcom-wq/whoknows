class_name ChangeSite
extends NpcSite

## TEMPLATE: copy to who-knows/src/npc/populations/<place>_site.gd, rename the
## class, replace every CHANGE. A site is the only thing that knows the place:
## its frame, its gravity, where a record wakes, and the helpers behaviours
## read from the context. Pair it with a pure recipe (below) that makes the
## records, and a source the director asks (see RockHerdSource).

## CHANGE: the node whose transform is the place's frame. Outside it must be
## a member of Universe.EXTERIOR_SPACE (moved by the floating origin); inside
## it never moves.
var place: Node3D
var records: Array[NpcRecord] = []
## Anything costly to work out: work it out once here (the exact surface of a
## rock costs ~40 us a call in GDScript).
var _shelters: Array[Vector3] = []

func _init(p_place: Node3D, world_seed: int) -> void:
	place = p_place
	id = StringName("CHANGE:%s" % p_place.name)
	records = make_records(id, world_seed)

## The place's records: pure, the same every time, homes in the site's frame,
## ids stable and unique. Keep anything you need to recompute a home (the
## skitter keeps the direction that made it).
static func make_records(site: StringName, world_seed: int) -> Array[NpcRecord]:
	var out: Array[NpcRecord] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = AsteroidRecipe.mix(world_seed ^ ShipCrew.stable_hash(String(site)))
	for n in rng.randi_range(3, 7):
		out.append(NpcRecord.make(StringName("CHANGE_species:%s:0:%d" % [site, n]), &"CHANGE_species", site,
			Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3)), rng.randi(), 0))
	return out

func frame() -> Transform3D:
	return place.global_transform

func gravity(_local: Vector3) -> Vector3:
	return Vector3.ZERO

func alive() -> bool:
	return is_instance_valid(place) and place.is_inside_tree()

## Feet on real ground: find it with a ray if the collision can differ from
## where the recipe put the home.
func start_pose(record: NpcRecord, _time: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, record.home)

func fill(ctx: NpcContext, npc: Npc) -> void:
	var to_local := frame().affine_inverse()
	var director := npc.director as NpcDirector
	if director != null:
		for other in director.herd_of(npc):
			var mate := other as Npc
			if mate != null and mate != npc:
				ctx.mates.append(to_local * mate.global_position)
	if not _shelters.is_empty():
		ctx.places[&"shelter"] = _shelters[0]
	# Fear fades by itself while nothing frightens it.
	if ctx.recent(Stimulus.TOUCH, 2.0) == null and not ctx.lit:
		ctx.ease(&"fear", 0.1)
