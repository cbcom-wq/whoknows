class_name TargetBrackets
extends WorldMarker

## A numbered bracket on each target you marked (ship weapons spec §9.2), with
## its distance: dashed while no turret can bear, solid once one can; the
## hostile red for a hostile. Mounted per view, like every WorldMarker. Off
## screen or behind, it is not drawn: the board lists it.

const CORNER := 10.0
const HALF := 18.0
const LINE_WIDTH := 2.0
const LABEL_SIZE := 12

var fire_control: FireControl
## What was drawn this frame, for tests: {index, position, solid, hostile, text}.
var marks: Array[Dictionary] = []

func render(telemetry: VehicleTelemetry) -> void:
	marks.clear()
	var cam := view_camera(telemetry)
	if cam == null or fire_control == null:
		queue_redraw()
		return
	for i in fire_control.entries.size():
		var e: Dictionary = fire_control.entries[i]
		var raw = e["node"]
		if raw == null or not is_instance_valid(raw):
			continue
		var node := raw as Node3D
		if node == null or not node.is_inside_tree():
			continue
		var at := Weapons.point_of(node)
		if cam.is_position_behind(at):
			continue
		var d: float = e["distance"]
		marks.append({"index": i + 1, "position": cam.unproject_position(at), "solid": e["bearing"],
			"hostile": Weapons.is_hostile(fire_control.ship, node),
			"text": "%d · %s" % [i + 1, ("%.1f KM" % (d / 1000.0)) if d >= 1000.0 else ("%d M" % roundi(d))]})
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for m in marks:
		var colour: Color = HudPalette.HOSTILE if m["hostile"] else HudPalette.TARGET
		var c: Vector2 = m["position"]
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var corner := c + Vector2(sx, sy) * HALF
				_edge(corner, corner - Vector2(sx, 0) * CORNER, colour, m["solid"])
				_edge(corner, corner - Vector2(0, sy) * CORNER, colour, m["solid"])
		draw_string(font, c + Vector2(-HALF, HALF + LABEL_SIZE + 2.0), m["text"], HORIZONTAL_ALIGNMENT_LEFT, -1,
			LABEL_SIZE, colour)

func _edge(a: Vector2, b: Vector2, colour: Color, solid: bool) -> void:
	if solid:
		draw_line(a, b, colour, LINE_WIDTH)
	else:
		draw_dashed_line(a, b, colour, LINE_WIDTH, 3.0)
