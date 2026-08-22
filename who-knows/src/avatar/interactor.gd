class_name Interactor
extends RayCast3D

## Points where the avatar looks. Anything in group "interactable" that
## implements `interact(avatar)` and `prompt_text()` can be used.

signal prompt_changed(text: String)

var _current: Node = null

func _ready() -> void:
	target_position = Vector3(0, 0, -2.5)
	collide_with_areas = true
	# RayCast3D defaults to mask 1 (exterior_hull). Interactables live on
	# interior_geometry, so without this the ray finds nothing, forever.
	collision_mask = 2   # interior_geometry

func _physics_process(_delta: float) -> void:
	var hit: Node = get_collider() if is_colliding() else null
	if hit != null and not hit.is_in_group("interactable"):
		hit = null
	if hit != _current:
		_current = hit
		prompt_changed.emit("" if _current == null else "[F] %s" % _current.prompt_text())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _current != null:
		_current.interact(owner)
