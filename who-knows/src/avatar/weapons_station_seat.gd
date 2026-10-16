class_name WeaponsStation
extends Seat

## The weapons station (ship weapons spec §3.5, §7): a crew station whose job
## is the guns (WeaponsJob). Its console's screen is the target board.

## The board on the console's face, in the seat's frame: the face InteriorProps
## draws, a hair proud of it.
const BOARD_AT := Vector3(0, 0.72, -0.61)
const BOARD_TILT := -55.0

var board: Label3D

func prompt_text() -> String:
	return "Man the weapons"

func _ready() -> void:
	super()
	board = ReadoutPanel.make_readout(InteriorKit.LAYER, 300.0)
	board.name = "Board"
	board.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(BOARD_TILT)), BOARD_AT)
	add_child(board)

func _process(_delta: float) -> void:
	if board == null:
		return
	board.text = "WEAPONS"