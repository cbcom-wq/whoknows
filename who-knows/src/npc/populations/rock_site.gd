class_name RockSite
extends NpcSite

## A big rock as a place skitters live (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §4.2, §4.4, §13): its frame is the rock
## in detail, which is fixed where it is and moved only by the floating origin,
## so a skitter's rock-local positions never change. There is no gravity: a
## skitter grips.

## Starting this far off the surface, metres, it settles onto it.
const LIFT := 0.05
## How far either side of the exact surface to look for the solid one.
const FIND_GROUND := 3.0

var detail: AsteroidDetail
var rock: AsteroidRock
var data: RockDetail
var herds: Array[Dictionary] = []
var records: Array[NpcRecord] = []
## record id -> the direction its home was made from.
var dirs := {}
## The director that keeps its skitters, for their herd mates.
var director: NpcDirector

func _init(p_detail: AsteroidDetail, world_seed: int) -> void:
	detail = p_detail
	rock = p_detail.rock
	data = p_detail.data
	id = RockHerds.site_of(rock)
	herds = RockHerds.herds(rock, data, world_seed)
	records = RockHerds.records(rock, data, world_seed, herds)
	for h in herds:
		var made := RockHerds.member_dirs(h, data)
		for m in made.size():
			dirs[StringName("skitter:%s:%d:%d" % [id, h["index"], m])] = made[m]

func frame() -> Transform3D:
	return detail.global_transform

func alive() -> bool:
	return is_instance_valid(detail) and detail.is_inside_tree()

## Where a skitter wakes: its herd's place on its round now, and its own
## place in the huddle, standing on the surface.
func start_pose(record: NpcRecord, time: float) -> Transform3D:
	var h := herd_of(record)
	var dir: Vector3 = dirs.get(record.id, record.home.normalized())
	if not h.is_empty():
		var home: Vector3 = h["home_dir"]
		var now := RockHerds.round_dir(h, time)
		dir = (Quaternion(home, now) * dir).normalized() if not home.is_equal_approx(now) else dir
	return pose_at(dir)

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

func herd_of(record: NpcRecord) -> Dictionary:
	for h in herds:
		if int(h["index"]) == record.herd:
			return h
	return {}

## What skitter behaviours may ask of the rock: where its herd mates are, where
## its herd's round has got to (where it grazes), and the nearest shelter.
func fill(ctx: NpcContext, npc: Npc) -> void:
	var to_local := frame().affine_inverse()
	if director != null:
		for other in director.live_npcs():
			var mate := other as Npc
			if mate != null and mate != npc and mate.site == self and mate.record.herd == npc.record.herd:
				ctx.mates.append(to_local * mate.global_position)
	var h := herd_of(npc.record)
	if not h.is_empty():
		ctx.places[&"round"] = data.surface_point(RockHerds.round_dir(h, ctx.time))
		ctx.extra[&"graze"] = ctx.places[&"round"]
	ctx.places[&"shelter"] = shelter(ctx.position)
	for m in ctx.mates:
		if m.distance_to(ctx.position) < 3.0:
			ctx.ease(&"company", 0.2)
			break
	var frightened := ctx.recent(Stimulus.VIBRATION, 2.0) != null or ctx.recent(Stimulus.TOUCH, 2.0) != null \
		or ctx.lit
	if not frightened:
		ctx.ease(&"fear", 0.1)

## The floor of the nearest crater to `local`.
func shelter(local: Vector3) -> Vector3:
	var best := local
	var best_d := INF
	for c in data.craters:
		var p := data.surface_point(c[0])
		var d := p.distance_to(local)
		if d < best_d:
			best = p
			best_d = d
	return best
