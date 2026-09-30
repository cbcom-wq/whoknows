class_name CourseMarker
extends WorldMarker

## The course on the HUD
## (docs/superpowers/specs/2026-09-25-bridge-computer-design.md §6.1): a
## diamond on a big rock, a caret for a ping, a ring round a region, each with
## its distance, pinned to the screen's edge off screen. It follows the
## course's contact as vaguely as the sensors know it. Inside a region it
## hides, because that is where the search begins. When the course clears by
## arriving, the last mark fades out over FADE. Mounted per view, like every
## WorldMarker (spec §8).

const SIZE := 9.0
const LINE_WIDTH := 2.0
const LABEL_SIZE := 12
const BEHIND_ALPHA := 0.5
const FADE := 0.5
const MIN_RING := 12.0

var sensors: ShipSensors
var shown := false
var mode: int = VelocityMarker.Mode.HIDDEN
var reading: StringName = &""
var marker_at := Vector2.ZERO
var ring_px := MIN_RING
var text := ""
var alpha := 1.0
## The warp drive, or null (docs/superpowers/specs/2026-09-28-warp-design.md
## §7.3): while a warp is charted to the course, a ring ALIGN wide sits round
## it, GO once you are lined up and ready.
var warp: WarpDrive
var align_px := 0.0
var align_go := false

var _fading := 0.0

func bind(p_sensors: ShipSensors) -> void:
	sensors = p_sensors
	sensors.course_arrived.connect(func(_id: StringName) -> void: _fading = FADE)

func _process(delta: float) -> void:
	if _fading > 0.0:
		_fading = maxf(_fading - delta, 0.0)

func render(telemetry: VehicleTelemetry) -> void:
	var cam := view_camera(telemetry)
	var c := sensors.course_contact() if sensors != null and sensors.universe != null else null
	if cam == null:
		shown = false
	elif c == null:
		# Arrived: the last mark, fading where it was.
		shown = _fading > 0.0
		alpha = _fading / FADE
	else:
		_fading = 0.0
		alpha = 1.0
		_follow(cam, c)
	queue_redraw()

func _follow(cam: Camera3D, c: Contact) -> void:
	var focus := sensors.focus_point()
	var world := sensors.universe.to_engine(c.point)
	var metres := c.point.minus(focus).length() if focus != null else cam.global_position.distance_to(world)
	reading = c.precision
	if reading == Contact.REGION and metres <= c.radius:
		shown = false
		return
	var state := VelocityMarker.resolve(INF, cam.is_position_behind(world), cam.unproject_position(world), size)
	mode = state["mode"]
	marker_at = state["position"]
	ring_px = MIN_RING
	if reading == Contact.REGION and mode == VelocityMarker.Mode.ON_FRAME:
		var edge := cam.unproject_position(world + cam.global_basis.x * c.radius)
		ring_px = maxf(MIN_RING, edge.distance_to(marker_at))
	text = "COURSE " + ContactText.distance(c, metres)
	shown = true
	align_px = 0.0
	var t: WarpTarget = warp.target() if warp != null else null
	if t != null and c.id == t.contact_id() and mode == VelocityMarker.Mode.ON_FRAME:
		align_px = size.y * 0.5 * tan(WarpPlan.ALIGN) / tan(deg_to_rad(cam.fov) * 0.5)
		align_go = warp.plan.status == WarpPlan.Status.READY

func _draw() -> void:
	if not shown:
		return
	var a := alpha * (BEHIND_ALPHA if mode == VelocityMarker.Mode.CLAMPED_BEHIND else 1.0)
	var colour := Color(HudPalette.COURSE, a)
	var reach := SIZE
	if mode != VelocityMarker.Mode.ON_FRAME:
		_edge_chevron(colour)
	else:
		match reading:
			Contact.REGION:
				reach = ring_px
				draw_arc(marker_at, ring_px, 0.0, TAU, 40, colour, LINE_WIDTH, true)
			Contact.PING:
				_caret(colour)
			_:
				_diamond(colour)
	if align_px > 0.0 and mode == VelocityMarker.Mode.ON_FRAME:
		draw_arc(marker_at, align_px, 0.0, TAU, 48, Color(HudPalette.GO if align_go else HudPalette.COURSE, a),
			LINE_WIDTH * 0.75, true)
	var at := marker_at + Vector2(reach + 6.0, 4.0)
	if at.x > size.x - 130.0:
		at.x = marker_at.x - reach - 120.0
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, colour)

func _diamond(colour: Color) -> void:
	var p := marker_at
	draw_polyline(PackedVector2Array([p + Vector2(0, -SIZE), p + Vector2(SIZE, 0), p + Vector2(0, SIZE),
		p + Vector2(-SIZE, 0), p + Vector2(0, -SIZE)]), colour, LINE_WIDTH, true)

## A ping on screen: an open caret over the pinged direction.
func _caret(colour: Color) -> void:
	var p := marker_at
	draw_polyline(PackedVector2Array([p + Vector2(-SIZE, SIZE * 0.5), p + Vector2(0, -SIZE * 0.5),
		p + Vector2(SIZE, SIZE * 0.5)]), colour, LINE_WIDTH, true)

## Off screen: a chevron on the edge, pointing out toward it.
func _edge_chevron(colour: Color) -> void:
	var out := (marker_at - size * 0.5).normalized()
	var side := Vector2(-out.y, out.x) * SIZE * 0.6
	var tip := marker_at + out * SIZE * 0.5
	var back := marker_at - out * SIZE * 0.5
	draw_polyline(PackedVector2Array([back + side, tip, back - side]), colour, LINE_WIDTH, true)
