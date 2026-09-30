class_name WarpPanel
extends HudElement

## The warp on the HUD (docs/superpowers/specs/2026-09-28-warp-design.md
## §7.3): while a warp is charted, what the plan says -- WARP READY · J,
## ALIGN · 23°, BLOCKED BY ZESU -- and its stage while it spools and travels;
## beneath, a toast for TOAST_TIME when you cross a warp limit. Seated only.
##
## Children are built in code, like EnergyPanel (CLAUDE.md on the text-scene
## parser).

const TOAST_TIME := 3.0
## The toast fades out over its last FADE seconds.
const FADE := 0.5

var drive: WarpDrive
var line_label: Label
var toast_label: Label
var _toast_left := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(250.0, 44.0)
	line_label = _label(16, Vector2.ZERO)
	toast_label = _label(11, Vector2(0.0, 24.0))

func _label(font: int, at: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", HudPalette.READOUT)
	l.position = at
	add_child(l)
	return l

func toast(text: String) -> void:
	toast_label.text = text
	_toast_left = TOAST_TIME

func _process(delta: float) -> void:
	_toast_left = maxf(_toast_left - delta, 0.0)

func render(telemetry: VehicleTelemetry) -> void:
	if telemetry == null or telemetry.has_beacon or drive == null:
		visible = false
		return
	var text := line_text(drive)
	line_label.text = text
	line_label.add_theme_color_override("font_color", colour_for(drive))
	toast_label.visible = _toast_left > 0.0
	toast_label.modulate.a = clampf(_toast_left / FADE, 0.0, 1.0)
	visible = text != "" or _toast_left > 0.0

## What the panel's first line says.
static func line_text(d: WarpDrive) -> String:
	match d.stage:
		WarpDrive.Stage.SPOOLING:
			return "WARP · SPOOLING %d" % ceili(d.spool_left)
		WarpDrive.Stage.TRAVELLING:
			var t := d.target()
			return "WARP · %s · %d S" % [t.name if t != null else "", ceili(d.time_left())]
	if d.charted == &"" or d.plan == null:
		return ""
	return d.plan.text()

## GO when ready, WARNING when it cannot go or would drop you into low power,
## the readout otherwise.
static func colour_for(d: WarpDrive) -> Color:
	if d.stage != WarpDrive.Stage.IDLE or d.plan == null:
		return HudPalette.READOUT
	match d.plan.status:
		WarpPlan.Status.READY:
			return HudPalette.WARNING if d.plan.into_low_power else HudPalette.GO
		WarpPlan.Status.CREW, WarpPlan.Status.AIRLOCK, WarpPlan.Status.BLOCKED, \
				WarpPlan.Status.LOW_POWER, WarpPlan.Status.NO_QE:
			return HudPalette.WARNING
	return HudPalette.READOUT
