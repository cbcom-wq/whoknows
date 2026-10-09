class_name Npc
extends CharacterBody3D

## One live NPC (docs/superpowers/specs/2026-09-26-npc-foundation-design.md
## §5): a body, its look, its locomotors, and -- from Tasks 5 and 6 -- its
## senses and its brain. Pooled: a director hands one node record after
## record, and setup() makes it that NPC.
##
## Its origin is at its feet, on the ground it stands on; its up is its local
## +y. Outside it is moved by the floating origin itself (it is a member of
## Universe.EXTERIOR_SPACE, under a holder that never moves); inside it is
## under the interior, which never moves at all.

const LAYER := 128
## The hull, the avatar, items and rocks.
const MASK_OUTSIDE := 1 | 4 | 32 | 64
## The interior's geometry, the avatar and items.
const MASK_INSIDE := 2 | 4 | 32
## A body this much longer than it is tall lies along its z.
const LONG := 1.3

var record: NpcRecord
var species: NpcSpecies
var site: NpcSite
var inside := false
## The director that made it live, and its space's stimulus bus.
var director: Node
var bus: Node
var intent: Intent = Intent.idle()
## id -> Locomotor, and the one in charge.
var locomotors := {}
var active: Locomotor
var look: Node3D
## Its mind, its senses and what they remember (spec §6, §7). Plain objects,
## so each can be tested without a scene.
var brain: Brain
var perception: Perception
var memory: NpcMemory
## Feels touches: a kinematic body is never pushed by a rigid one, so this is
## how it knows something ran into it (spec §6.1).
var skin: Area3D
## The last think's context, for the overlay.
var last_context: NpcContext
## Level of detail, set by its director from how near a camera is: it moves
## every `move_every` physics ticks (with their time added up) and thinks on
## one in `think_every` of its turns. 1 near a camera.
var move_every := 1
var think_every := 1
## Which physics tick of its director's round it thinks on (NpcDirector).
var think_group := 0
var _move_tick := 0
var _move_time := 0.0
var _think_turn := 0

var _shape: CollisionShape3D
var _skin_shape: CollisionShape3D
## Its voice and its wheels' whir, aboard only: outside is silent (style
## guide §2.9).
var _voice: AudioStreamPlayer3D
var _whir: AudioStreamPlayer3D
## Moving faster than this, m/s, its whir plays.
const WHIRS_OVER := 0.1
## A thing moving at least this fast against it is a touch, m/s.
const TOUCH_SPEED := 1.0
## Health and damage (docs/superpowers/specs/
## 2026-09-29-health-and-damage-design.md §6): a live NPC heals this, hp/s,
## once calm for HEAL_AFTER; a dead one lies still for CORPSE_FOR, shrinking
## away over its last CORPSE_SHRINK, then goes.
const HEAL_RATE := 0.1
const HEAL_AFTER := 10.0
const CORPSE_FOR := 20.0
const CORPSE_SHRINK := 1.0
## How far a knocked-out NPC slumps, and a flinch's squash and length.
const SLUMP := deg_to_rad(70.0)
const FLINCH := 0.8
const FLINCH_FOR := 0.15
## A bite (health and damage spec §5.4): its hp, its shove, N·s, and how far
## from the middle of it you can be and still be bitten, m.
const BITE_DAMAGE := 15.0
const BITE_PUSH := 40.0
const BITE_REACH := 1.6

## How hurt it is. Made from its species on setup; its director gives it the
## ledger's value for its record.
var health: Health
## Down: dead, or knocked out until `down_left` runs out.
var down := false
var down_left := 0.0
var _flinch_left := 0.0
## The look's scale as built, which its pose keeps.
var _look_scale := 1.0

func _init() -> void:
	collision_layer = LAYER
	motion_mode = MOTION_MODE_FLOATING
	_shape = CollisionShape3D.new()
	_shape.name = "Body"
	_shape.shape = CapsuleShape3D.new()
	add_child(_shape)
	skin = Area3D.new()
	skin.name = "Skin"
	skin.collision_layer = 0
	skin.monitorable = false
	_skin_shape = CollisionShape3D.new()
	_skin_shape.shape = CapsuleShape3D.new()
	skin.add_child(_skin_shape)
	add_child(skin)
	skin.body_entered.connect(_on_skin_touched)

## Becomes `p_record`, at home in `p_site`, standing as `pose` (site-local).
func setup(p_record: NpcRecord, p_species: NpcSpecies, p_site: NpcSite, p_inside: bool,
		pose: Transform3D) -> void:
	record = p_record
	species = p_species
	site = p_site
	inside = p_inside
	name = String(record.id).validate_node_name()
	collision_mask = MASK_INSIDE if inside else MASK_OUTSIDE
	skin.collision_mask = (4 | 32) if inside else (4 | 32 | 64)
	if inside:
		if is_in_group(Universe.EXTERIOR_SPACE):
			remove_from_group(Universe.EXTERIOR_SPACE)
	else:
		add_to_group(Universe.EXTERIOR_SPACE)
	_fit_body()
	if active != null:
		active.exit(self)
	active = null
	locomotors.clear()
	for id: StringName in species.locomotors:
		var loco := make_locomotor(id)
		if loco != null:
			locomotors[id] = loco
	if not species.locomotors.is_empty() and locomotors.has(species.locomotors[0]):
		active = locomotors[species.locomotors[0]]
	_build_look()
	_set_up_sound()
	var rng := RandomNumberGenerator.new()
	rng.seed = record.seed
	brain = Brain.new()
	brain.setup(species, rng)
	perception = Perception.new()
	memory = NpcMemory.new()
	last_context = null
	intent = Intent.idle()
	velocity = Vector3.ZERO
	global_transform = site.frame() * pose
	health = Health.make(species.max_health, HEAL_AFTER, HEAL_RATE)
	health.emptied.connect(_go_down)
	down = false
	down_left = 0.0
	_flinch_left = 0.0
	_pose_look()
	if active != null:
		active.enter(self)

## The locomotor called `id`, or null.
static func make_locomotor(id: StringName) -> Locomotor:
	var loco: Locomotor = null
	match id:
		&"deck_walker":
			loco = DeckWalker.new()
		&"surface_crawler":
			loco = SurfaceCrawler.new()
		&"zero_g_drift":
			loco = ZeroGDrift.new()
		_:
			loco = null
	if loco == null:
		push_error("Npc: no locomotor called %s" % id)
		return null
	loco.id = id
	return loco

## Hands over from the active locomotor to the one called `id`.
func switch_to(id: StringName) -> void:
	if not locomotors.has(id) or locomotors[id] == active:
		return
	if active != null:
		active.exit(self)
	active = locomotors[id]
	active.enter(self)

func _physics_process(delta: float) -> void:
	if health != null:
		health.tick(delta)
	if _flinch_left > 0.0:
		_flinch_left = maxf(_flinch_left - delta, 0.0)
		_pose_look()
	if down:
		_tick_down(delta)
		return
	# A place gone all at once (a rock out of detail after a jump) waits on the
	# director's next review to demote its NPCs: until then nothing steps on it.
	if active == null or site == null or not site.alive():
		return
	_move_time += delta
	_move_tick += 1
	if _move_tick < move_every:
		return
	var step_time := _move_time
	_move_tick = 0
	_move_time = 0.0
	active.step(self, intent, step_time)
	var next := active.handover(self)
	if next != &"":
		switch_to(next)

## Says `sound` (a Synth sound: &"droid_chirp", &"droid_beep"), if it can be
## heard where it is.
func voice(sound: StringName) -> void:
	if _voice == null or not inside:
		return
	var s := Synth.sound(sound)
	if s == null:
		return
	_voice.stream = s
	_voice.play()

func _process(_delta: float) -> void:
	if _whir == null:
		return
	var moving := inside and species.move_sound != &"" and Vector2(velocity.x, velocity.z).length() > WHIRS_OVER
	if moving and not _whir.playing:
		var s := Synth.sound(species.move_sound)
		if s != null:
			_whir.stream = s
			_whir.play()
	elif not moving and _whir.playing:
		_whir.stop()

func _set_up_sound() -> void:
	if not inside:
		for p in [_voice, _whir]:
			if p != null:
				p.stop()
		return
	if _voice == null:
		_voice = _player("Voice", -8.0)
		_whir = _player("Whir", -20.0)

func _player(label: String, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = label
	p.bus = AudioBuses.SHIP
	p.volume_db = db
	p.unit_size = 2.0
	p.position = Vector3(0, species.height * 0.6, 0)
	add_child(p)
	return p

## Its position in its site's frame.
func local_position() -> Vector3:
	return site.frame().affine_inverse() * global_position

## Its transform in its site's frame.
func local_transform() -> Transform3D:
	return site.frame().affine_inverse() * global_transform

## Senses, decides, and sets the intent its locomotor follows (spec §7).
## Called by its director a few times a second.
func think(time: float, dt: float) -> void:
	if site == null or not site.alive() or brain == null or down:
		return
	_think_turn += 1
	if _think_turn < think_every:
		return
	dt *= _think_turn
	_think_turn = 0
	var ctx := NpcContext.new()
	ctx.record = record
	ctx.species = species
	ctx.memory = memory
	ctx.time = time
	ctx.dt = dt
	var local := local_transform()
	ctx.position = local.origin
	ctx.forward = -local.basis.z.normalized()
	ctx.up = local.basis.y.normalized()
	ctx.grounded = active.grounded() if active != null else true
	perception.sense(self, ctx, bus as StimulusBus, time)
	site.fill(ctx, self)
	ctx.extra[&"hurt_ago"] = health.since_hurt if health != null else INF
	intent = brain.think(ctx)
	if intent.action == &"bite":
		bite()
	last_context = ctx
	if look != null and look.has_method(&"act"):
		look.call(&"act", intent.action)
	if ctx.voice != &"":
		voice(ctx.voice)

## A hit from a bolt or a thrown thing (hands-and-items spec §9.3): a touch,
## a shove, and the damage (health and damage spec §6): it flinches, and its
## fear rises by the share of its health it lost.
func receive_hit(hit: Hit) -> void:
	if perception != null:
		perception.touched(hit.position, 1.0, hit.source.get_instance_id() if is_instance_valid(hit.source) else 0)
	shove(hit.impulse)
	take_damage(hit.damage)

## Takes `amount` hp; returns what it took. Nothing more happens to it down.
func take_damage(amount: float) -> float:
	if down or health == null or amount <= 0.0:
		return 0.0
	var taken := health.take(amount)
	if taken > 0.0:
		if brain != null and brain.needs.has(&"fear"):
			brain.needs[&"fear"] = clampf(brain.needs[&"fear"] + taken / health.max, 0.0, 1.0)
		_flinch_left = FLINCH_FOR
		_pose_look()
	return taken

## Bites whoever is within BITE_REACH (the defend behaviour asks for it):
## a hit that hurts and shoves them away. Returns whether it landed.
func bite() -> bool:
	if not is_inside_tree():
		return false
	var avatar := get_tree().get_first_node_in_group(Avatar.GROUP) as Node3D
	if avatar == null:
		return false
	var middle := global_position + global_basis.y * species.height * 0.5
	var to := avatar.global_position - middle
	if to.length() > BITE_REACH:
		return false
	var dir := to.normalized() if to.length() > 0.01 else -global_basis.z
	var hit := Hit.make(avatar.global_position, -dir, dir, dir * BITE_PUSH, self)
	hit.damage = BITE_DAMAGE
	hit.kind = &"bite"
	Hit.deliver(avatar, hit)
	if look != null and look.has_method(&"act"):
		look.call(&"act", &"bite")
	return true

func is_dead() -> bool:
	return down and species != null and species.knocked_out_for <= 0.0

## Gets up now, at `fraction` of its health (the torch, health and damage
## spec §8.2). Only one knocked out can; the dead stay dead.
func revive(fraction := -1.0) -> void:
	if not down or is_dead():
		return
	down = false
	down_left = 0.0
	health.current = health.max * (species.wake_health if fraction < 0.0 else fraction)
	health.since_hurt = 0.0
	_pose_look()

## At 0 hp: knocked out for its species' while, or dead for good.
func _go_down() -> void:
	down = true
	intent = Intent.idle()
	velocity = Vector3.ZERO
	if species.knocked_out_for > 0.0:
		down_left = species.knocked_out_for
		if look != null and look.has_method(&"act"):
			look.call(&"act", &"knocked_out")
	else:
		down_left = CORPSE_FOR
		if director != null and director.get(&"ledger") != null:
			director.ledger.mark_dead(record.id)
		if look != null and look.has_method(&"act"):
			look.call(&"act", &"dead")
	_pose_look()

func _tick_down(delta: float) -> void:
	down_left -= delta
	if is_dead():
		_pose_look()
		if down_left <= 0.0 and director != null and director.has_method(&"demote"):
			director.demote(self)
	elif down_left <= 0.0:
		revive()

## The look's pose for how it is: slumped on its side knocked out, on its
## back dead (shrinking away at the end), squashed for a moment in a flinch.
func _pose_look() -> void:
	if look == null:
		return
	var basis := Basis.IDENTITY
	var lift := 0.0
	var scale := _look_scale
	if down:
		if is_dead():
			# On its back, lifted by its height so it lies on the ground.
			basis = Basis(Vector3.BACK, PI)
			lift = species.height
			scale *= clampf(down_left / CORPSE_SHRINK, 0.0, 1.0)
		else:
			basis = Basis(Vector3.BACK, SLUMP)
	var squash := Vector3.ONE
	if _flinch_left > 0.0 and not down:
		squash = Vector3(1.0 / FLINCH, FLINCH, 1.0 / FLINCH)
	look.transform = Transform3D(basis * Basis.from_scale(squash * maxf(scale, 0.001)),
		Vector3(0.0, lift, 0.0))

## An impulse, N·s: each locomotor decides what it does to its grip.
func shove(impulse: Vector3) -> void:
	var dv := impulse / maxf(species.mass, 0.1) if species != null else impulse
	if active != null:
		active.shoved(self, dv)
	else:
		velocity += dv

## The interaction seam (spec §12.4): the Interactor's contract, routed to
## the species' interactions. There are none in this build, so nothing is
## offered, and the node is not in group "interactable".
func can_interact(_actor: Node) -> bool:
	return species != null and not species.interactions.is_empty()

func prompt_text() -> String:
	return ""

func interact(_actor: Node) -> void:
	pass

## Sizes the collider to the species: upright if it is about as tall as it is
## long, lying along z if it is longer.
func _fit_body() -> void:
	var capsule := _shape.shape as CapsuleShape3D
	if species.size > species.height * LONG:
		capsule.radius = species.height * 0.5
		capsule.height = maxf(species.size, species.height)
		_shape.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, capsule.radius, 0))
	else:
		capsule.radius = species.width * 0.5
		capsule.height = maxf(species.height, species.width)
		_shape.transform = Transform3D(Basis.IDENTITY, Vector3(0, capsule.height * 0.5, 0))
	var around := _skin_shape.shape as CapsuleShape3D
	around.radius = capsule.radius + 0.12
	around.height = capsule.height + 0.24
	_skin_shape.transform = _shape.transform

## Something ran into it: the avatar, or a thing moving against it fast
## enough to count.
func _on_skin_touched(body: Node3D) -> void:
	if body == self or perception == null:
		return
	var strength := 0.0
	if body.is_in_group(Avatar.GROUP):
		strength = 0.7
	elif body is RigidBody3D:
		var rel := ((body as RigidBody3D).linear_velocity - velocity).length()
		if rel >= TOUCH_SPEED:
			strength = clampf(rel / 4.0, 0.3, 1.0)
	if strength > 0.0:
		perception.touched(body.global_position, strength, body.get_instance_id())

func _build_look() -> void:
	if look != null:
		remove_child(look)
		look.free()
		look = null
	look = NpcLooks.build(species.look, float(record.seed & 0xFFFF) / 65535.0, inside, site.tint(), species.fade)
	look.name = "Look"
	var built := NpcLooks.built_size(species.look)
	_look_scale = species.size / built if built > 0.0 else 1.0
	look.scale = Vector3.ONE * _look_scale
	add_child(look)
