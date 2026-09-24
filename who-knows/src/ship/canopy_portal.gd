class_name CanopyPortal
extends Node

## Makes every window in the ship a true window (cockpit pod spec §3). Each
## frame, once the cameras have moved, it stands the canopy camera where the
## viewing camera would be if the interior were inside the hull -- the same
## pose relative to the ship, the same field of view -- and sizes the canopy
## view to the screen. Window glass shows that view at its own screen position
## (canopy_window.gdshader), so every window of any shape lines up with the
## world outside, wherever the player stands or sits.
##
## When the viewer is outside the interior (the chase camera) no window is on
## screen, and the canopy view stops rendering.

@export var viewport_path: NodePath
@export var camera_path: NodePath
@export var hull_path: NodePath
@export var interior_path: NodePath

@onready var _viewport: SubViewport = get_node(viewport_path)
@onready var _camera: Camera3D = get_node(camera_path)
@onready var _hull: Node3D = get_node(hull_path)
@onready var _interior: Node3D = get_node(interior_path)

func _ready() -> void:
	# After the avatar, the seat transition and the hull have moved this frame.
	process_priority = 1000

func _process(_delta: float) -> void:
	sync(get_viewport().get_camera_3d())

## Aligns the canopy camera with `viewer` when it is inside the interior.
func sync(viewer: Camera3D) -> void:
	if viewer == null or not _interior.is_ancestor_of(viewer):
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var screen := Vector2i(get_viewport().get_visible_rect().size)
	if _viewport.size != screen:
		_viewport.size = screen
	_camera.fov = viewer.fov
	_camera.near = viewer.near
	_camera.global_transform = _hull.global_transform * _interior.global_transform.affine_inverse() \
		* viewer.global_transform
