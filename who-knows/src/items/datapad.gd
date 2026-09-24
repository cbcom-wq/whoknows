class_name Datapad
extends ItemUse

## A datapad (docs/superpowers/specs/2026-09-23-hands-and-items-design.md
## §4.2, as amended 2026-09-24): use turns its screen on and off. The screen is
## set dressing that moves (visual style guide §2.4): it shows one of the
## animated screen modes and reads no game state.

## The screen's size and where it sits on the pad's face, item-local.
const SCREEN_SIZE := Vector2(0.13, 0.19)
const SCREEN_AT := Vector3(0.0, 0.0105, -0.01)

var on := false

var _screen: Node3D

func _ready() -> void:
	_screen = Node3D.new()
	_screen.name = "Screen"
	add_child(_screen)
	var kit := InteriorKit.new(_screen)
	# The kit's screens face +z; this one faces up off the pad, its top toward
	# the pad's far end.
	var variety := fposmod(float(get_instance_id() % 997) / 997.0, 1.0)
	kit.screen(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), SCREEN_AT), SCREEN_SIZE,
		InteriorKit.Screen.WAVE if variety < 0.5 else InteriorKit.Screen.BARS, variety)
	kit.commit()
	_screen.visible = on

func use(_item: Item, _aim: Transform3D, _world: Node3D, _holder: CollisionObject3D) -> bool:
	on = not on
	_screen.visible = on
	return true
