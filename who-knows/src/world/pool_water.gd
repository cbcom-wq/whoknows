class_name PoolWater
extends Area3D

## A pool's water as something you wade through: an Area3D over the pool that
## tells the avatar standing in it how deep the water is at its feet
## (Avatar.wade_depth), and 0 as it leaves. No swimming: a pool is never deeper
## than you can stand.
##
## Everything is measured in this node's own frame (a place's, which a floating
## origin shift never changes), never in engine positions.

## The avatar's collision layer (scenes/avatar.tscn), which the area watches.
const AVATAR_LAYER := 4
## How far the watched volume reaches under the water's level and over it, m:
## enough to take in a standing avatar wherever its feet are in the pool.
const BELOW := 2.0
const ABOVE := 1.6

## The water's level, y in this node's frame.
var level_y := 0.0
## Frame-local ground height: Callable(Vector2 x_z) -> float.
var floor_of: Callable
var _wader: Avatar

## A pool of `radius` round `centre` (x, z in this frame), its water at `level`.
static func make(centre: Vector2, radius: float, level: float, ground: Callable) -> PoolWater:
	var pool := PoolWater.new()
	pool.name = "PoolWater"
	pool.level_y = level
	pool.floor_of = ground
	pool.collision_layer = 0
	pool.collision_mask = AVATAR_LAYER
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = BELOW + ABOVE
	var shape := CollisionShape3D.new()
	shape.shape = cylinder
	shape.position = Vector3(centre.x, level - BELOW * 0.5 + ABOVE * 0.5, centre.y)
	pool.add_child(shape)
	return pool

## How deep the water is at `local` (in this frame), clamped at 0.
func depth_at(local: Vector3) -> float:
	return maxf(level_y - float(floor_of.call(Vector2(local.x, local.z))), 0.0)

func _physics_process(_delta: float) -> void:
	var here: Avatar = null
	for body in get_overlapping_bodies():
		if body is Avatar:
			here = body
			break
	if _wader != null and _wader != here and is_instance_valid(_wader):
		_wader.wade_depth = 0.0
	_wader = here
	if here != null:
		here.wade_depth = depth_at(global_transform.affine_inverse() * here.global_position)

func _exit_tree() -> void:
	if _wader != null and is_instance_valid(_wader):
		_wader.wade_depth = 0.0
	_wader = null
