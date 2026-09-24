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

enum State { STOWED, LOOSE, HELD }

## Every item joins this group, so anything looking for items can find them.
const GROUP := &"item"
## What one person can lift.
const LIFT_LIMIT_KG := 40.0
## project.godot 3d_physics/layer_6 "items", as a bit.
const LAYER := 32
## interior_geometry | avatar | items.
const MASK := 2 | 4 | 32
const FRICTION := 0.5
const BOUNCE := 0.15

static var _material: PhysicsMaterial

var definition: ItemDefinition
var state: State = State.LOOSE
## The point securing it, while STOWED.
var stow_point: StowPoint = null
## Its use behaviour, if the definition has one.
var use_node: ItemUse = null

var _shape: BoxShape3D

## Builds the look, the collider and the use. Call once, before the item
## enters the tree.
func setup(def: ItemDefinition, variety := 0.0) -> void:
	definition = def
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
	var look := Node3D.new()
	look.name = "Look"
	add_child(look)
	var kit := InteriorKit.new(look)
	ItemLooks.build(kit, def.look, def.size, variety)
	kit.commit()
	if def.use != null:
		use_node = def.use.new() as ItemUse
		use_node.name = "Use"
		add_child(use_node)
	add_to_group(&"interactable")
	add_to_group(GROUP)

func shape() -> BoxShape3D:
	return _shape

## Secured at `point`: frozen static, so it ignores the felt-gravity field.
func set_stowed(point: StowPoint) -> void:
	state = State.STOWED
	stow_point = point
	collision_layer = LAYER
	collision_mask = MASK
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true

func set_loose() -> void:
	state = State.LOOSE
	stow_point = null
	collision_layer = LAYER
	collision_mask = MASK
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
	if state == State.STOWED:
		return "Take %s" % definition.display_name
	return "Pick up %s" % definition.display_name

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

static func _physics_material() -> PhysicsMaterial:
	if _material == null:
		_material = PhysicsMaterial.new()
		_material.friction = FRICTION
		_material.bounce = BOUNCE
	return _material
