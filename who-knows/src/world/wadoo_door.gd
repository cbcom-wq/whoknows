class_name WadooDoor
extends Node3D

## The queen's hall door (docs/superpowers/specs/2026-11-16-wadoo-design.md §8): one
## plank leaf in the doorway of an open shell, hung on its left jamb, studded in
## bronze. Shut, it is solid; once Oru steps aside it swings in over SWING_TIME
## and lies along the wall. Its frame: the hinge's foot, the leaf along +x, the
## room toward +z.

## Its node's name under the place (the flight scene finds it by this).
const NAME := "HallDoor"
const SWING := deg_to_rad(96.0)
const SWING_TIME := 1.4
const STUD := 0.045
const STUDS := Vector2i(3, 4)

var leaf: Node3D
var body: StaticBody3D
var is_open := false
var _tween: Tween

## A door `width` wide and `tall` high, of `variety`'s planks.
static func make(width: float, tall: float, variety: float) -> WadooDoor:
	var door := WadooDoor.new()
	door.name = NAME
	door.leaf = Node3D.new()
	door.leaf.name = "Leaf"
	door.add_child(door.leaf)
	var kit := OasisLooks.kit_under(door.leaf)
	BrickShell.door_leaf(kit, Transform3D.IDENTITY, width, tall, variety, 7)
	var bronze := InteriorKit.solid(OasisPalette.BRONZE)
	for i in STUDS.x:
		for j in STUDS.y:
			var at := Vector3(width * (i + 1) / (STUDS.x + 1), tall * (j + 1) / (STUDS.y + 1), BrickShell.PLANK * 0.5 + 0.03)
			for side: float in [1.0, -1.0]:
				kit.bevel_box(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(at.x, at.y, side * at.z)),
					Vector3.ONE * STUD, 0.015, bronze)
	kit.commit()
	door.body = StaticBody3D.new()
	door.body.collision_layer = BodyProxy.LAYER
	door.body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, tall, BrickShell.PLANK)
	shape.shape = box
	shape.position = Vector3(width * 0.5, tall * 0.5, 0.0)
	door.body.add_child(shape)
	door.leaf.add_child(door.body)
	return door

## Opens or shuts it: swinging, or `at_once` (as the place is built).
func set_open(on: bool, at_once := false) -> void:
	if on == is_open and not at_once:
		return
	is_open = on
	var to := -SWING if on else 0.0
	if _tween != null:
		_tween.kill()
		_tween = null
	if at_once or not is_inside_tree():
		leaf.rotation.y = to
		return
	_tween = create_tween()
	_tween.tween_property(leaf, "rotation:y", to, SWING_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
