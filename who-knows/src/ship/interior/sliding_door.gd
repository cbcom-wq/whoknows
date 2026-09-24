class_name SlidingDoor
extends Node3D

## A door that slides open for whoever walks up to it and closes behind them
## (docs/superpowers/specs/2026-09-23-ship-interior-redesign-design.md §7.3).
## Two leaves part along local x into the wall on either side; an Area3D
## straddling the doorway decides when. The leaves are only a picture -- the
## doorway itself never has a collider -- so the door can never trap anyone,
## whatever its timing.
##
## Knows nothing about ships. The origin is the doorway's centre at floor
## level on the wall's mid-plane; +z faces either room.

const OPEN_TIME := 0.25
const LEAF_THICKNESS := 0.06
## How deep the trigger reaches into the rooms on both sides.
const TRIGGER_DEPTH := 2.4
## The avatar's physics layer (project.godot 3d_physics/layer_3) as a mask.
const AVATAR_MASK := 4

var is_open := false

var _width := 1.0
var _leaves: Array[Node3D] = []
var _inside := 0
var _tween: Tween

## Builds the leaves and the trigger for an opening `opening_width` wide and
## `opening_height` high. Call once, before the door enters the tree.
func setup(opening_width: float, opening_height: float) -> void:
	_width = opening_width
	for side in [-1.0, 1.0]:
		var leaf := Node3D.new()
		leaf.name = "LeafPort" if side < 0.0 else "LeafStarboard"
		add_child(leaf)
		var kit := InteriorKit.new(leaf)
		var w := _width * 0.5
		kit.bevel_box(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(0, opening_height * 0.5, 0)),
			Vector3(w, opening_height - 0.02, LEAF_THICKNESS), 0.025, InteriorKit.solid(InteriorPalette.WALL_LOW))
		kit.bevel_box(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(0, 1.0, 0)),
			Vector3(w - 0.04, 0.08, LEAF_THICKNESS + 0.02), 0.01, InteriorKit.solid(InteriorPalette.BELT))
		kit.commit()
		_leaves.append(leaf)

	var shape := BoxShape3D.new()
	shape.size = Vector3(_width, opening_height, TRIGGER_DEPTH)
	var trigger_shape := CollisionShape3D.new()
	trigger_shape.shape = shape
	trigger_shape.position = Vector3(0, opening_height * 0.5, 0)
	var trigger := Area3D.new()
	trigger.name = "Trigger"
	trigger.collision_layer = 0
	trigger.collision_mask = AVATAR_MASK
	trigger.add_child(trigger_shape)
	add_child(trigger)
	trigger.body_entered.connect(_on_body_entered)
	trigger.body_exited.connect(_on_body_exited)
	set_open(false, false)

## Opens or closes the door; animated when in the tree, instant otherwise.
func set_open(open: bool, animate := true) -> void:
	is_open = open
	if _tween != null:
		_tween.kill()
		_tween = null
	var slide := 0.75 if open else 0.25
	for i in _leaves.size():
		var side := -1.0 if i == 0 else 1.0
		var target := Vector3(side * _width * slide, 0, 0)
		if animate and is_inside_tree():
			if _tween == null:
				_tween = create_tween().set_parallel(true)
			_tween.tween_property(_leaves[i], "position", target, OPEN_TIME)
		else:
			_leaves[i].position = target

## Where the leaves are right now, port then starboard.
func leaf_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for leaf in _leaves:
		out.append(leaf.position)
	return out

func _on_body_entered(_body: Node3D) -> void:
	_inside += 1
	if not is_open:
		set_open(true)

func _on_body_exited(_body: Node3D) -> void:
	_inside = maxi(_inside - 1, 0)
	if _inside == 0 and is_open:
		set_open(false)
