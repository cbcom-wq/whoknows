class_name WeaponsStation
extends Seat

## The weapons station (ship weapons spec §3.5, §7): a crew station whose job
## is the guns (WeaponsJob). Its console's screen is the target board.

## How far the board stands out of the console's face, m: clear of the dark
## panel's front (InteriorProps.STATION_PANEL_FRONT), so the text is not
## hidden in it.
const BOARD_OUT := 0.045

## The console's dark screen (InteriorProps.weapons_station), m: the board's
## text must stay inside it.
const SCREEN_SIZE := Vector2(1.2, 0.24)
## The board's text size: a pixel's size in metres, and the font's. The label is
## given the screen's width less a margin, and WeaponsPage.BOARD_COLUMNS is
## chosen so a full line measures under it (the tests measure).
const BOARD_PIXEL := 0.0011
const BOARD_FONT := 24
const BOARD_MARGIN := 0.08

var board: Label3D

func prompt_text() -> String:
	return "Man the weapons"

func _ready() -> void:
	super()
	board = make_board()
	board.transform = board_frame()
	add_child(board)

## The board's label, sized to the screen.
static func make_board() -> Label3D:
	var label := ReadoutPanel.make_readout(InteriorKit.LAYER, (SCREEN_SIZE.x - BOARD_MARGIN) / BOARD_PIXEL)
	label.name = "Board"
	label.pixel_size = BOARD_PIXEL
	label.font_size = BOARD_FONT
	return label

## The board's place in the seat's frame: the face InteriorProps draws, out
## along its normal.
static func board_frame() -> Transform3D:
	return InteriorProps.STATION_FACE * Transform3D(Basis.IDENTITY, Vector3(0, 0, BOARD_OUT))

func _process(_delta: float) -> void:
	if board == null:
		return
	var weapons := job as WeaponsJob
	board.text = "\n".join(WeaponsPage.board_lines(weapons.fire_control if weapons != null else null, -1,
		WeaponsPage.BOARD_COLUMNS))