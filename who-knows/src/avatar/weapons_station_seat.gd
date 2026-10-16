class_name WeaponsStation
extends Seat

## The weapons station (ship weapons spec §3.5, §7): a crew station whose job
## is the guns (WeaponsJob). Its console's screen is the target board.

## How far the board stands out of the console's face, m: clear of the dark
## panel's front (InteriorProps.STATION_PANEL_FRONT), so the text is not
## hidden in it.
const BOARD_OUT := 0.045

var board: Label3D

func prompt_text() -> String:
	return "Man the weapons"

func _ready() -> void:
	super()
	board = ReadoutPanel.make_readout(InteriorKit.LAYER, 300.0)
	board.name = "Board"
	board.transform = board_frame()
	add_child(board)

## The board's place in the seat's frame: the face InteriorProps draws, out
## along its normal.
static func board_frame() -> Transform3D:
	return InteriorProps.STATION_FACE * Transform3D(Basis.IDENTITY, Vector3(0, 0, BOARD_OUT))

func _process(_delta: float) -> void:
	if board == null:
		return
	board.text = "WEAPONS"