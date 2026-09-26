class_name Perception
extends RefCounted

## An NPC's senses (docs/superpowers/specs/2026-09-26-npc-foundation-design.md
## §6.2): what it sees in its cone, whether a light is on it, what it feels
## through the rock it stands on, what it hears through air, a shake of the
## whole ship, and what touched it. Each think it puts what it sensed into the
## NPC's memory and the think's context; the brain reads those, never this.

## Percept kinds.
const PLAYER := &"player"
const LIGHT := &"light"
const FLARE := &"flare"
const MATE_BOLTED := &"mate_bolted"
## Too faint to notice.
const FAINT := 0.05
## A light this near the player means they carry it: they are lit.
const CARRIED := 2.0
## Moved this far since the last think: moving.
const MOVED := 0.3
## A mate running this behaviour has bolted.
const BOLTING := &"scatter"

var _last_think := -1.0
var _player_was: Variant = null
var _lights_were := {}   # instance id -> Vector3 (engine)
## Touches since the last think: [engine position, strength, source id].
var _touches: Array = []

## Something touched it: noticed at its next think.
func touched(at: Vector3, strength: float, source_id: int) -> void:
	_touches.append([at, strength, source_id])

## One think's senses, into `ctx` and the NPC's memory.
func sense(npc: Npc, ctx: NpcContext, bus: StimulusBus, time: float) -> void:
	var memory := ctx.memory
	var to_local := npc.site.frame().affine_inverse()
	var lights: Array[Node3D] = bus.lights() if bus != null else ([] as Array[Node3D])
	_feel_lights(npc, ctx, lights, to_local, time)
	_look(npc, ctx, lights, to_local, time)
	if bus != null:
		var since := _last_think if _last_think >= 0.0 else bus.now - ctx.dt
		for s in bus.since(since):
			var felt := feel(npc.species, s, npc.global_position, npc.site.id, ctx.grounded)
			if felt > FAINT:
				memory.note(s.kind, s.source.get_instance_id() if is_instance_valid(s.source) else 0,
					to_local * s.position, felt, time)
		_last_think = bus.now
	for t: Array in _touches:
		memory.note(Stimulus.TOUCH, t[2], to_local * (t[0] as Vector3), t[1], time)
	_touches.clear()
	memory.forget_faded(time)

## How strongly `species` feels stimulus `s` at `at`, standing on `site`
## (`grounded`), 0-1. Pure.
static func feel(species: NpcSpecies, s: Stimulus, at: Vector3, site: StringName, grounded: bool) -> float:
	match s.kind:
		Stimulus.VIBRATION:
			if species.feels_vibration <= 0.0 or not grounded or s.site != site:
				return 0.0
			return s.felt_at(at) * species.feels_vibration
		Stimulus.SOUND:
			return s.felt_at(at) * species.hears
		Stimulus.SHAKE:
			return s.felt_at(at) * species.feels_shake
	return 0.0

## True if `to` lies within `cone_deg` (its whole width) of `forward`. Pure.
static func in_cone(forward: Vector3, to: Vector3, cone_deg: float) -> bool:
	if to.length() < 0.0001:
		return true
	if cone_deg >= 360.0:
		return true
	return forward.normalized().angle_to(to.normalized()) <= deg_to_rad(cone_deg) * 0.5

## How far it sees: inside the ship is lit; outside, a dark thing is seen at
## dark_sight of the range, a lit one at all of it. Pure.
static func sight_range(species: NpcSpecies, lit: bool, inside: bool) -> float:
	if inside or lit:
		return species.sight_range
	return species.sight_range * species.dark_sight

## Whether `light` shines on `point` with nothing in the way.
static func lights_up(light: Node3D, point: Vector3, space: PhysicsDirectSpaceState3D, mask: int,
		exclude: Array[RID]) -> bool:
	var origin: Transform3D = light.call(&"light_origin")
	var reach := float(light.call(&"light_reach"))
	var to := point - origin.origin
	if to.length() > reach:
		return false
	if not in_cone(-origin.basis.z, to, float(light.call(&"light_cone_deg"))):
		return false
	return _clear(space, origin.origin, point, mask, exclude)

func _feel_lights(npc: Npc, ctx: NpcContext, lights: Array[Node3D], to_local: Transform3D, time: float) -> void:
	ctx.lit = false
	var space := npc.get_world_3d().direct_space_state
	var mask := _sight_mask(npc)
	var here := npc.global_position + npc.global_basis.y * npc.species.height * 0.5
	var moved := {}
	for light in lights:
		var at: Vector3 = (light.call(&"light_origin") as Transform3D).origin
		var id := light.get_instance_id()
		var was: Variant = _lights_were.get(id)
		var moving := was != null and (was as Vector3).distance_to(at) > MOVED
		moved[id] = at
		if light.call(&"light_kind") == &"flare":
			ctx.memory.note(FLARE, id, to_local * at, 1.0, time)
			ctx.extra[&"flare_moving"] = moving
		if lights_up(light, here, space, mask, [npc.get_rid()]):
			ctx.lit = true
			ctx.memory.note(LIGHT, id, to_local * at, 1.0, time)
	_lights_were = moved

func _look(npc: Npc, ctx: NpcContext, lights: Array[Node3D], to_local: Transform3D, time: float) -> void:
	ctx.player = null
	ctx.player_moving = false
	var space := npc.get_world_3d().direct_space_state
	var mask := _sight_mask(npc)
	var eye := npc.global_position + npc.global_basis.y * npc.species.height * 0.8
	var forward := -npc.global_basis.z
	for node in npc.get_tree().get_nodes_in_group(Avatar.GROUP):
		var avatar := node as Node3D
		if avatar == null or StimulusBus.for_node(avatar) != StimulusBus.for_node(npc):
			continue
		var head := avatar.get(&"head") as Node3D
		var at := head.global_position if head != null else avatar.global_position
		var lit := false
		for light in lights:
			var origin: Vector3 = (light.call(&"light_origin") as Transform3D).origin
			if origin.distance_to(avatar.global_position) < CARRIED or lights_up(light, at, space, mask, [npc.get_rid()]):
				lit = true
				break
		var to := at - eye
		var near := to.length() <= npc.species.near_sense
		if not near and to.length() > sight_range(npc.species, lit, npc.inside):
			continue
		if not near and not in_cone(forward, to, npc.species.sight_cone_deg):
			continue
		var exclude: Array[RID] = [npc.get_rid()]
		if avatar is CollisionObject3D:
			exclude.append((avatar as CollisionObject3D).get_rid())
		if not _clear(space, eye, at, mask, exclude):
			continue
		var local := to_local * avatar.global_position
		ctx.player = local
		ctx.player_moving = _player_was != null and (_player_was as Vector3).distance_to(local) > MOVED
		_player_was = local
		ctx.memory.note(PLAYER, avatar.get_instance_id(), local, 1.0, time)
	if ctx.player == null:
		_player_was = null
	# Herd mates that bolted, in sight: panic spreads by sight (spec §7.3).
	if npc.record.herd < 0 or npc.director == null:
		return
	for other in npc.director.call(&"live_npcs"):
		var mate := other as Npc
		if mate == null or mate == npc or mate.record.herd != npc.record.herd or mate.site != npc.site:
			continue
		if mate.brain == null or mate.brain.current == null or mate.brain.current.id != BOLTING:
			continue
		var to := mate.global_position - eye
		if to.length() <= npc.species.sight_range and in_cone(forward, to, npc.species.sight_cone_deg):
			ctx.memory.note(MATE_BOLTED, mate.get_instance_id(), to_local * mate.global_position, 0.8, time)

static func _sight_mask(npc: Npc) -> int:
	return 2 if npc.inside else AsteroidBody.LAYER

static func _clear(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, mask: int, exclude: Array[RID]) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	return space.intersect_ray(query).is_empty()
