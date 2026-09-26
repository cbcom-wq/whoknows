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
	if active == null or site == null:
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
	if site == null or not site.alive() or brain == null:
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
	intent = brain.think(ctx)
	last_context = ctx
	if look != null and look.has_method(&"act"):
		look.call(&"act", intent.action)
	if ctx.voice != &"":
		voice(ctx.voice)

## A hit from a bolt or a thrown thing (hands-and-items spec §9.3): a touch,
## and a shove. Nothing takes damage yet.
func receive_hit(hit: Hit) -> void:
	if perception != null:
		perception.touched(hit.position, 1.0, hit.source.get_instance_id() if is_instance_valid(hit.source) else 0)
	shove(hit.impulse)

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
	add_child(look)
