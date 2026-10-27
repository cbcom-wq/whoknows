class_name TargetBrackets
extends WorldMarker

## A numbered bracket on each target you marked (ship weapons spec §9.2), with
## its distance: dashed while no turret can bear, solid once one can; the
## hostile red for a hostile. A hostile in contact is bracketed unnumbered when
## not listed, so you see it coming, and a ship's bracket shows its HULL %
## under the distance (hostile ships spec §4.3). Mounted per view, like every
## WorldMarker. Off screen or behind, it is not drawn: the board lists it.

const CORNER := 10.0
const HALF := 18.0
const LINE_WIDTH := 2.0
const LABEL_SIZE := 12

var fire_control: FireControl
## The hostile hulls in contact with the ship you are aboard: returns
## Array[Node3D]. Given by the flight scene.
var hostiles: Callable
## What was drawn this frame, for tests: {index (0 unlisted), position, solid,
## hostile, text}.
var marks: Array[Dictionary] = []

func render(telemetry: VehicleTelemetry) -> void:
	marks.clear()
	var cam := view_camera(telemetry)
	if cam == null or fire_control == null:
		queue_redraw()
		return
	var drawn := {}
	for i in fire_control.entries.size():
		var e: Dictionary = fire_control.entries[i]
		var node := _shown(e["node"])
		if node == null:
			continue
		drawn[node] = true
		_mark(cam, node, i + 1, e["bearing"], e["distance"])
	if hostiles.is_valid():
		for raw in hostiles.call():
			var node := _shown(raw)
			if node != null and not drawn.has(node):
				drawn[node] = true
				_mark(cam, node, 0, _bears(node), _distance_to(node))
	queue_redraw()

## `raw` as a node to bracket, or null when it is gone or out of the tree.
static func _shown(raw) -> Node3D:
	if raw == null or not is_instance_valid(raw):
		return null
	var node := raw as Node3D
	return node if node != null and node.is_inside_tree() else null

func _mark(cam: Camera3D, node: Node3D, index: int, solid: bool, d: float) -> void:
	var at := Weapons.point_of(node)
	if cam.is_position_behind(at):
		return
	var text := ("%.1f KM" % (d / 1000.0)) if d >= 1000.0 else ("%d M" % roundi(d))
	if index > 0:
		text = "%d · %s" % [index, text]
	var ship: Object = node.get_meta(&"ship") if node.has_meta(&"ship") else null
	if ship != null and ship.has_method("hull_whole"):
		text += "\nHULL %d%%" % roundi(float(ship.hull_whole()) * 100.0)
	marks.append({"index": index, "position": cam.unproject_position(at), "solid": solid,
		"hostile": Weapons.is_hostile(fire_control.ship, node), "text": text})

## Whether any of your turrets can bear on `node`, as for a listed target.
func _bears(node: Node3D) -> bool:
	for t in fire_control.turrets:
		if is_instance_valid(t) and t.can_engage(node):
			return true
	return false

## From the hull of the ship you are aboard, as fire control measures a listed target.
func _distance_to(node: Node3D) -> float:
	var own: Node = fire_control.ship
	var hull: Node3D = own.get("exterior") if own != null and "exterior" in own else own as Node3D
	return hull.global_position.distance_to(Weapons.point_of(node)) if hull != null and hull.is_inside_tree() else -1.0

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
		draw_multiline_string(font, c + Vector2(-HALF, HALF + LABEL_SIZE + 2.0), m["text"], HORIZONTAL_ALIGNMENT_LEFT,
			-1, LABEL_SIZE, -1, colour)

func _edge(a: Vector2, b: Vector2, colour: Color, solid: bool) -> void:
	if solid:
		draw_line(a, b, colour, LINE_WIDTH)
	else:
		draw_dashed_line(a, b, colour, LINE_WIDTH, 3.0)
