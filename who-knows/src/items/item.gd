class_name Item
extends RigidBody3D

## A thing you can pick up (docs/superpowers/specs/
## 2026-09-23-hands-and-items-design.md §4.4): a rigid body built from an
## ItemDefinition, with one box collider and a look from ItemLooks.
##
## STOWED: frozen at a StowPoint, deaf to the felt-gravity field. LOOSE:
## dynamic; it falls, slides and can be shot across a room. HELD: a wielded
## item is frozen into a hand and leaves the physics world; a carried one
## stays dynamic, so it still bumps into walls.
##
## Knows nothing about avatars. Whoever interacts with it is an actor that may
## implement take_item(item) and can_take_item(item) -> bool; that is the whole
## contract.

## Converted at the quantum machine or swallowed by the hose (quantum energy
## spec §7.1, §11.4, §14): emitted once, while the item is still whole and in
## the tree, just before it is freed. Whoever cares -- the salvage ledger --
## listens; the item never knows who converted it. Item.consume() is the one
## way it is done.
signal consumed

enum State { STOWED, LOOSE, HELD }

## Every item joins this group, so anything looking for items can find them.
const GROUP := &"item"
## What one person can lift.
const LIFT_LIMIT_KG := 40.0
## project.godot 3d_physics/layer_6 "items", as a bit.
const LAYER := 32
## interior_geometry | avatar | items.
const MASK := 2 | 4 | 32
## Outside (quantum energy spec §10.1, §14.2): exterior_hull | avatar | items |
## asteroids -- AsteroidBody's own mask, which already takes items.
const SPACE_MASK := 1 | 4 | 32 | 64
## project.godot 3d_render/layer_1 "exterior": drawn in the world, lit by the
## sun.
const SPACE_LAYER := 1
const FRICTION := 0.5
const BOUNCE := 0.15

static var _material: PhysicsMaterial

var definition: ItemDefinition
var state: State = State.LOOSE
## The point securing it, while STOWED.
var stow_point: StowPoint = null
## Its use behaviour, if the definition has one.
var use_node: ItemUse = null
## Out in the world rather than aboard (set_space).
var in_space := false

var _shape: BoxShape3D
var _variety := 0.0

## Builds the look, the collider and the use. Call once, before the item
## enters the tree.
func setup(def: ItemDefinition, variety := 0.0) -> void:
	definition = def
	_variety = variety
	name = String(def.id).to_pascal_case() if def.id != &"" else "Item"
	mass = def.mass_kg
	collision_layer = LAYER
	collision_mask = MASK
	continuous_cd = true
	physics_material_override = _physics_material()
	_shape = BoxShape3D.new()
	_shape.size = def.size
	var collider := CollisionShape3D.new()
	collider.name = "Collider"
	collider.shape = _shape
	add_child(collider)
	_build_look()
	if def.use != null:
		use_node = def.use.new() as ItemUse
		use_node.name = "Use"
		add_child(use_node)
	add_to_group(&"interactable")
	add_to_group(GROUP)

func shape() -> BoxShape3D:
	return _shape

## Out in the world, or back aboard (quantum energy spec §10.1, §14.2).
## Outside, its look is rebuilt on the world's render layer, lit by the sun --
## with a glint, if it is salvage -- and it meets the hull, you, other items
## and rocks. Aboard, the interior's layer and mask again. A held item stays
## out of the physics world until it is let go.
##
## It never touches floating-origin groups: a member must never sit under
## another member, so whoever parents an item outside decides how it follows
## the origin (§10.1) -- SalvageField makes its salvage members, and the hose
## nozzle lives under a reel or a hand that are already shifted.
func set_space(outside: bool) -> void:
	in_space = outside
	_build_look()
	if state != State.HELD:
		collision_mask = _mask()

## Secured at `point`: frozen static, so it ignores the felt-gravity field.
func set_stowed(point: StowPoint) -> void:
	state = State.STOWED
	stow_point = point
	collision_layer = LAYER
	collision_mask = _mask()
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true

func set_loose() -> void:
	state = State.LOOSE
	stow_point = null
	collision_layer = LAYER
	collision_mask = _mask()
	freeze = false

## In someone's hands: frozen and out of the physics world, so it can never
## shove anything from inside a hand, and it goes wherever the hand goes.
## Static rather than kinematic: the engine steps a kinematic body and writes
## its position back a frame behind the hand's, so a held item lagged and
## drifted off its grip.
func set_held() -> void:
	state = State.HELD
	stow_point = null
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	collision_layer = 0
	collision_mask = 0

func prompt_text() -> String:
	if definition.mass_kg > LIFT_LIMIT_KG:
		return "Too heavy"
	var label := definition.display_name
	var status := use_node.status() if use_node != null else ""
	if status != "":
		label = "%s (%s)" % [label, status]
	if state == State.STOWED:
		return "Take %s" % label
	return "Pick up %s" % label

func can_interact(actor: Node) -> bool:
	if state == State.HELD:
		return false
	if actor != null and actor.has_method(&"can_take_item"):
		return actor.can_take_item(self)
	return true

func interact(actor: Node) -> void:
	if actor != null and actor.has_method(&"take_item"):
		actor.take_item(self)

func use(aim: Transform3D, world: Node3D, holder: CollisionObject3D) -> bool:
	return use_node != null and use_node.use(self, aim, world, holder)

## Uses `item` up: `consumed`, once, then out of the tree and freed at once --
## remove_child() then free(), never queue_free(), which would leave its
## collider registered until the engine flushes its queue (SLICE-1-STATUS).
## Static, so nothing runs on an item after it is gone.
static func consume(item: Item) -> void:
	item.consumed.emit()
	var parent := item.get_parent()
	if parent != null:
		parent.remove_child(item)
	item.free()

func _mask() -> int:
	return SPACE_MASK if in_space else MASK

## The look, from ItemLooks, on the layer for where the item is: built afresh,
## so the kit's merged meshes and any glint match it.
func _build_look() -> void:
	var at := -1
	var old := get_node_or_null(^"Look")
	if old != null:
		at = old.get_index()
		remove_child(old)
		old.free()
	var look := Node3D.new()
	look.name = "Look"
	add_child(look)
	if at >= 0:
		move_child(look, at)
	var kit := InteriorKit.new(look)
	kit.layer = SPACE_LAYER if in_space else InteriorKit.LAYER
	kit.light_mask = kit.layer
	ItemLooks.build(kit, definition.look, definition.size, _variety)
	kit.commit()
	if in_space and ItemLooks.has_glint(definition.look):
		ItemLooks.glint(look, _variety)

static func _physics_material() -> PhysicsMaterial:
	if _material == null:
		_material = PhysicsMaterial.new()
		_material.friction = FRICTION
		_material.bounce = BOUNCE
	return _material
