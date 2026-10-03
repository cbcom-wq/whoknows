class_name CanopyCracks
extends HudElement

## Cracks over the pilot's view of a hurt cockpit (ship damage sections spec
## §7): flat lines in a palette colour, no new shader, on the HUD's screen
## (HudRoot adds one), so the seated view through the pod's glass shows them.
## `level` 1 (damaged) draws a few from the edges; 2 (wrecked) more. The same
## cracks every time: they are seeded.

const COLOUR := Color(HudPalette.READOUT, 0.55)
const SHADOW := Color(HudPalette.BLACKOUT, 0.45)
const CRACKS := [0, 3, 7]
const WIDTH := 2.0

var level := 0:
	set(n):
		if n != level:
			level = n
			queue_redraw()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func render(telemetry: VehicleTelemetry) -> void:
	level = telemetry.cockpit_cracks if telemetry != null else 0

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7341
	var area := size
	for i in CRACKS[clampi(level, 0, CRACKS.size() - 1)]:
		var from := Vector2(rng.randf_range(0.0, 1.0) * area.x, (0.0 if i % 2 == 0 else 1.0) * area.y)
		if i % 3 == 2:
			from = Vector2((0.0 if i % 2 == 0 else 1.0) * area.x, rng.randf_range(0.2, 0.8) * area.y)
		var heading := (area * 0.5 - from).normalized().rotated(rng.randf_range(-0.6, 0.6))
		_crack(from, heading, area.length() * rng.randf_range(0.15, 0.3), rng, 2)

func _crack(from: Vector2, heading: Vector2, length: float, rng: RandomNumberGenerator, branches: int) -> void:
	var points := PackedVector2Array([from])
	var at := from
	var steps := 6
	for s in steps:
		heading = heading.rotated(rng.randf_range(-0.5, 0.5))
		at += heading * length / steps
		points.append(at)
		if branches > 0 and rng.randf() < 0.3:
			_crack(at, heading.rotated(rng.randf_range(-1.2, 1.2)), length * 0.4, rng, branches - 1)
	draw_polyline(points, SHADOW, WIDTH + 2.0, true)
	draw_polyline(points, COLOUR, WIDTH, true)
