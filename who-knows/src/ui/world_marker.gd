class_name WorldMarker
extends HudElement

## The base of every HUD mark on a place in the world
## (docs/superpowers/specs/2026-09-25-bridge-computer-design.md §8). Seated in
## the cockpit the main camera is in interior space, so a mark projected
## through it would point nowhere. Each world mark is mounted once per view:
## in the canopy overlay with CanopyCam, and on the HUD screen with
## ChaseCamera, each shown while its camera is current; and on the HUD screen
## with no camera of its own, for a spacewalk, projected through the
## viewport's camera and shown only while the telemetry is the suit's
## (has_beacon).

@export var camera_path: NodePath

var _camera: Camera3D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not camera_path.is_empty():
		_camera = get_node_or_null(camera_path) as Camera3D

func set_camera(cam: Camera3D) -> void:
	_camera = cam

## The camera it projects through, or null when it should not show.
func view_camera(telemetry: VehicleTelemetry) -> Camera3D:
	if telemetry == null:
		return null
	if _camera != null:
		return _camera if _camera.current and _camera.is_inside_tree() else null
	if not telemetry.has_beacon:
		return null
	return get_viewport().get_camera_3d() if is_inside_tree() else null
