class_name BodyMarker
extends WorldMarker

## Every warp target in view, bracketed and named with its distance
## (docs/superpowers/specs/2026-09-28-warp-design.md §7.3): KORVA-7 · 82 KM,
## so you can see where things are and how far. Dim, so it never competes
## with the course. The charted one is the course's, drawn by CourseMarker,
## so it is left out; nothing here pins to the screen's edge. Mounted per
## view, like every WorldMarker.

const BRACKET := 7.0
const LINE_WIDTH := 1.5
const LABEL_SIZE := 11

var sensors: ShipSensors
## What was drawn this frame, for tests: {id, position, text}.
var marks: Array[Dictionary] = []

func render(telemetry: VehicleTelemetry) -> void:
	marks.clear()
	var cam := view_camera(telemetry)
	var focus: UniversePoint = sensors.focus_point() if sensors != null and sensors.universe != null else null
	if cam == null or focus == null:
		queue_redraw()
		return
	var view := Rect2(Vector2.ZERO, size)
	for source in sensors.sources():
		if not source is BodyContacts:
			continue
		for c: Contact in (source as BodyContacts).contacts(focus, BodyContacts.RANGE, 0.0):
			if c.kind == BodyContacts.MOON or c.id == sensors.course:
				continue
			# Inside a cluster's reach you are there: nothing to point at.
			var metres := c.point.minus(focus).length()
			if metres <= c.radius:
				continue
			var at := sensors.universe.to_engine(c.point)
			if cam.is_position_behind(at):
				continue
			var p := cam.unproject_position(at)
			if not view.has_point(p):
				continue
			marks.append({"id": c.id, "position": p,
				"text": "%s · %s" % [c.label, distance_text(metres)]})
	queue_redraw()

static func distance_text(metres: float) -> String:
	if metres >= 10000.0:
		return "%d KM" % roundi(metres / 1000.0)
	return "%.1f KM" % (metres / 1000.0)

func _draw() -> void:
	var colour := HudPalette.DIM
	for m in marks:
		var p: Vector2 = m["position"]
		var b := BRACKET
		for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var corner := p + s * b
			draw_line(corner, corner - Vector2(s.x * b * 0.5, 0.0), colour, LINE_WIDTH, true)
			draw_line(corner, corner - Vector2(0.0, s.y * b * 0.5), colour, LINE_WIDTH, true)
		var at := p + Vector2(b + 6.0, 4.0)
		if at.x > size.x - 150.0:
			at.x = p.x - b - 140.0
		draw_string(ThemeDB.fallback_font, at, m["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, colour)
