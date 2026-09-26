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

var _shape: CollisionShape3D

func _init() -> void:
	collision_layer = LAYER
	motion_mode = MOTION_MODE_FLOATING
	_shape = CollisionShape3D.new()
	_shape.name = "Body"
	_shape.shape = CapsuleShape3D.new()
	add_child(_shape)

## Becomes `p_record`, at home in `p_site`, standing as `pose` (site-local).
func setup(p_record: NpcRecord, p_species: NpcSpecies, p_site: NpcSite, p_inside: bool,
		pose: Transform3D) -> void:
	record = p_record
	species = p_species
	site = p_site
	inside = p_inside
	name = String(record.id).validate_node_name()
	collision_mask = MASK_INSIDE if inside else MASK_OUTSIDE
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
	intent = Intent.idle()
	velocity = Vector3.ZERO
	global_transform = site.frame() * pose
	if active != null:
		active.enter(self)

## The locomotor called `id`, or null.
static func make_locomotor(id: StringName) -> Locomotor:
	var loco: Locomotor = null
	match id:
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
	active.step(self, intent, delta)
	var next := active.handover(self)
	if next != &"":
		switch_to(next)

## Its position in its site's frame.
func local_position() -> Vector3:
	return site.frame().affine_inverse() * global_position

## Its transform in its site's frame.
func local_transform() -> Transform3D:
	return site.frame().affine_inverse() * global_transform

## Senses, decides, and sets the intent its locomotor follows (spec §7).
## Called by its director a few times a second.
func think(_time: float, _dt: float) -> void:
	pass

## A hit from a bolt or a thrown thing (hands-and-items spec §9.3): a touch,
## and a shove. Nothing takes damage yet.
func receive_hit(hit: Hit) -> void:
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

func _build_look() -> void:
	if look != null:
		remove_child(look)
		look.free()
		look = null
	look = NpcLooks.build(species.look, float(record.seed & 0xFFFF) / 65535.0, inside)
	look.name = "Look"
	add_child(look)
