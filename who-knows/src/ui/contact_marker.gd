class_name ContactMarker
extends WorldMarker

## What the ship's sensors pick up, on the HUD (NPC foundation spec §22.4;
## quantum energy spec §10.4): the nearest few contacts, each in its kind's
## colour. A ping is a small diamond in the rough direction, fading until the
## next one, labelled *LIFE? ~3 KM*; a region is a ring round the sphere it
## is somewhere inside, labelled *LIFE? 640 M*; inside the region the mark
## fades out, and you look. Off-screen or behind, it pins to the edge with a
## chevron, by the velocity marker's rule (VelocityMarker.resolve).
##
## Mounted per view, like every WorldMarker. The course's own contact is left
## to the CourseMarker (bridge computer spec §6.1), so it is never drawn twice.

## How many contacts it shows: the nearest.
const MOST := 3
## How far the sensors are asked to look, metres.
const RANGE := 10000.0
const DIAMOND := 7.0
const CHEVRON_SIZE := 10.0
const LINE_WIDTH := 2.0
const LABEL_SIZE := 12
const BEHIND_ALPHA := 0.5
## A ring never shrinks below this on screen, pixels.
const RING_MIN := 10.0
## A ping fades to this share of its brightness before the next.
const PING_LOW := 0.3
## Inside a region it fades over this share of the radius.
const INSIDE_FADE := 0.25

var sensors: ShipSensors
## What was drawn this frame, for tests: one per contact shown,
## {kind, precision, mode, position, radius, alpha, text}.
var marks: Array[Dictionary] = []

func render(telemetry: VehicleTelemetry) -> void:
	marks.clear()
	var cam := view_camera(telemetry)
	if cam == null or sensors == null or sensors.universe == null:
		queue_redraw()
		return
	var focus := sensors.focus_point()
	if focus == null:
		queue_redraw()
		return
	var shown := 0
	for c: Contact in sensors.contacts(RANGE):
		if shown >= MOST:
			break
		if not marks_kind(c.kind) or c.id == sensors.course:
			continue
		var mark := mark_for(c, cam, focus, sensors.time, size)
		if not mark.is_empty():
			marks.append(mark)
		shown += 1
	queue_redraw()

## Whether it marks contacts of `kind`. Not the big rocks: you see those
## through the canopy, and the bridge computer's map is where they are named
## (bridge computer spec §8).
static func marks_kind(kind: StringName) -> bool:
	return kind != RockContacts.KIND

## How contact `c` is drawn through `cam`: empty when it is not drawn at all.
func mark_for(c: Contact, cam: Camera3D, focus: UniversePoint, time: float, view: Vector2) -> Dictionary:
	var at := sensors.universe.to_engine(c.point)
	var colour := HudPalette.for_kind(c.kind)
	var alpha := 1.0
	var radius := 0.0
	var text := ""
	var from_cam := cam.global_position.distance_to(at)
	if c.precision == Contact.PING:
		var age := clampf((time - c.taken) / maxf(c.fresh_for, 0.001), 0.0, 1.0)
		alpha = lerpf(1.0, PING_LOW, age)
		text = "%s ~%d KM" % [c.label, c.km]
	elif c.precision == Contact.REGION:
		var inside := c.point.minus(focus).length()
		if inside < c.radius:
			var deep := c.radius * (1.0 - INSIDE_FADE)
			alpha = clampf((inside - deep) / (c.radius * INSIDE_FADE), 0.0, 1.0)
			if alpha <= 0.01:
				return {}
		text = "%s %d M" % [c.label, roundi(maxf(from_cam - c.radius, 0.0))]
		if not cam.is_position_behind(at):
			var edge := at + cam.global_basis.x * c.radius
			radius = maxf(cam.unproject_position(edge).distance_to(cam.unproject_position(at)), RING_MIN)
	else:
		text = "%s %d M" % [c.label, roundi(from_cam)]
	var state := VelocityMarker.resolve(INF, cam.is_position_behind(at), cam.unproject_position(at), view)
	if state["mode"] == VelocityMarker.Mode.CLAMPED_BEHIND:
		alpha *= BEHIND_ALPHA
	colour.a *= alpha
	return {"kind": c.kind, "precision": c.precision, "mode": state["mode"], "position": state["position"],
		"radius": radius, "alpha": alpha, "colour": colour, "text": text}

func _draw() -> void:
	for m in marks:
		var p: Vector2 = m["position"]
		var colour: Color = m["colour"]
		var reach := DIAMOND
		if m["mode"] != VelocityMarker.Mode.ON_FRAME:
			var out := (p - size * 0.5).normalized()
			var side := Vector2(-out.y, out.x) * CHEVRON_SIZE * 0.6
			var tip := p + out * CHEVRON_SIZE * 0.5
			var back := p - out * CHEVRON_SIZE * 0.5
			draw_polyline(PackedVector2Array([back + side, tip, back - side]), colour, LINE_WIDTH, true)
		elif m["precision"] == Contact.REGION:
			reach = float(m["radius"])
			draw_arc(p, reach, 0.0, TAU, 40, colour, LINE_WIDTH, true)
		else:
			draw_polyline(PackedVector2Array([p + Vector2(0, -DIAMOND), p + Vector2(DIAMOND, 0), p + Vector2(0, DIAMOND),
				p + Vector2(-DIAMOND, 0), p + Vector2(0, -DIAMOND)]), colour, LINE_WIDTH, true)
		var at := p + Vector2(reach + 6.0, 4.0)
		if at.x > size.x - 130.0:
			at.x = p.x - reach - 120.0
		draw_string(ThemeDB.fallback_font, at, m["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, colour)
