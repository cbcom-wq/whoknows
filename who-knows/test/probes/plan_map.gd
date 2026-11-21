extends SceneTree

# A map of WADIS's world plan (docs/superpowers/specs/2026-11-19-wadis-land-design.md
# §11, Checkpoint 1): the whole world at once, equirectangular, MAP_W x MAP_H,
# north up, longitude 0 in the middle. Each Land is a flat colour; the canyons
# (every path, branches too) are drawn over it, and the ranges' spines; the
# sites are marked by kind; Wadoo and its kept disc are ringed, and the arrival
# point (a warp is dropped over Wadoo, WarpPlan.arrival_dir) is crossed. A
# legend sits in a corner so the picture reads alone. This is a probe's output,
# not game art, so the colours are plain and the lettering is a 5x7 bitmap font
# of the probe's own (a headless run draws no text).
#
# Run headless, from who-knows:
#
#   godot --headless --path . --script res://test/probes/plan_map.gd -- [<abs out dir>]
#
# Writes plan_map.png to the directory, else to user://, and prints each
# Land's share of the sphere's area.

const MAP_W := 2048
const MAP_H := 1024
const SEED := 1337
const BODY := &"p3"

const SEA := Color8(46, 98, 176)
const DUNES := Color8(236, 202, 124)
const PLAINS := Color8(176, 156, 118)
const PLATEAU := Color8(204, 112, 62)
const MOUNTAINS := Color8(120, 118, 126)
const CANYON := Color8(240, 20, 200)
const SPINE := Color8(255, 255, 255)
const OASIS := Color8(20, 220, 60)
const SHORE := Color8(20, 230, 230)
const KEPT := Color8(255, 40, 40)
const ARRIVAL := Color8(255, 240, 20)
const INK := Color8(255, 255, 255)
const PAPER := Color8(10, 10, 14)

## The 5x7 letters the legend uses; a missing glyph is blank.
const FONT := {
	"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
	"B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
	"C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
	"D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
	"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
	"F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
	"G": ["01110", "10001", "10000", "10111", "10001", "10001", "01111"],
	"H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
	"I": ["01110", "00100", "00100", "00100", "00100", "00100", "01110"],
	"K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
	"L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
	"M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
	"N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
	"O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
	"P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
	"R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
	"S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
	"T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
	"U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
	"V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
	"W": ["10001", "10001", "10001", "10101", "10101", "11011", "10001"],
	"X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
	"Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
	"0": ["01110", "10011", "10101", "10101", "10101", "11001", "01110"],
	"1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
	"2": ["01110", "10001", "00001", "00110", "01000", "10000", "11111"],
	"3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
	"4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
	"5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
	"6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
	"7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
	"8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
	"9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
	"-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
	".": ["00000", "00000", "00000", "00000", "00000", "01100", "01100"],
	"(": ["00010", "00100", "01000", "01000", "01000", "00100", "00010"],
	")": ["01000", "00100", "00010", "00010", "00010", "00100", "01000"],
}

var _image: Image
var _radius := 0.0

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var recipe := SystemRecipe.from_seed(SEED).body(BODY).recipe
	var plan := recipe.plan()
	var radius := recipe.radius_m
	_radius = radius
	_image = Image.create(MAP_W, MAP_H, false, Image.FORMAT_RGB8)
	var t0 := Time.get_ticks_msec()
	var share := {}
	var colours := {WorldPlan.Land.SEA: SEA, WorldPlan.Land.DUNES: DUNES, WorldPlan.Land.PLAINS: PLAINS,
		WorldPlan.Land.PLATEAU: PLATEAU, WorldPlan.Land.MOUNTAINS: MOUNTAINS}
	var total := 0.0
	var f := PackedFloat64Array()
	f.resize(WorldPlan.LAND_FIELDS)
	for y in MAP_H:
		var lat := 90.0 - (y + 0.5) * 180.0 / MAP_H
		var area := cos(deg_to_rad(lat))
		for x in MAP_W:
			var lon := -180.0 + (x + 0.5) * 360.0 / MAP_W
			plan.map.sample(SystemDesign.dir_of(lat, lon), f, WorldPlan.LAND_FIELDS)
			var land := WorldPlan.land_in(f)
			_image.set_pixel(x, y, colours[land])
			share[land] = share.get(land, 0.0) + area
			total += area
	print("map     painted in %d ms; %.0f km round, %.2f km a pixel along the equator" % [
		Time.get_ticks_msec() - t0, TAU * radius / 1000.0, TAU * radius / 1000.0 / MAP_W])
	for land: WorldPlan.Land in share:
		print("share   %-9s %5.1f%% of the sphere" % [WorldPlan.Land.keys()[land], 100.0 * share[land] / total])
	for r: Dictionary in plan.shapes.ranges:
		_line(r.spine, SPINE, 0)
	for c: Dictionary in plan.shapes.canyons:
		_line(c.path, CANYON, 1)
	var counts := {}
	for s in plan.sites:
		counts[s.kind] = counts.get(s.kind, 0) + 1
		match s.kind:
			PlanSite.Kind.OASIS:
				_disc(s.dir, 4, OASIS)
			PlanSite.Kind.SHORE:
				_square(s.dir, 3, SHORE)
			PlanSite.Kind.KEPT:
				_ring(s.dir, maxi(10, int(ceil((s.radius + 1500.0) / (TAU * radius / MAP_W)))), KEPT)
	print("sites   %d oasis, %d shore, %d kept" % [counts.get(PlanSite.Kind.OASIS, 0),
		counts.get(PlanSite.Kind.SHORE, 0), counts.get(PlanSite.Kind.KEPT, 0)])
	var arrive := Vector3.ZERO
	for s in plan.sites:
		if s.kind == PlanSite.Kind.KEPT:
			arrive = s.dir
	_cross(arrive, 16, ARRIVAL)
	_legend(plan)
	var dir_path := args[0] if not args.is_empty() else "user:/"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file := dir_path + "/plan_map.png"
	_image.save_png(file)
	print("map     %s" % ProjectSettings.globalize_path(file))
	quit()

# --- drawing ---------------------------------------------------------------------

## Pixel of a direction: x from longitude, y from latitude.
func _px(d: Vector3) -> Vector2i:
	var u := d.normalized()
	var lat := rad_to_deg(asin(clampf(u.y, -1.0, 1.0)))
	var lon := rad_to_deg(atan2(-u.z, u.x))
	return Vector2i(int((lon + 180.0) / 360.0 * MAP_W) % MAP_W, clampi(int((90.0 - lat) / 180.0 * MAP_H), 0, MAP_H - 1))

func _dot(x: int, y: int, c: Color) -> void:
	if y >= 0 and y < MAP_H:
		_image.set_pixel(posmod(x, MAP_W), y, c)

## A path of directions, joined segment by segment along the great circle (so
## a line never jumps across the map), `thick` pixels either side.
func _line(path: PackedVector3Array, c: Color, thick: int) -> void:
	for i in path.size():
		var a := path[i]
		var b := path[mini(i + 1, path.size() - 1)]
		var steps := maxi(2, int(a.angle_to(b) * _radius / 1000.0 * 2.0))
		for s in steps + 1:
			var p := _px(a.slerp(b, float(s) / steps) if a != b else a)
			for dx in range(-thick, thick + 1):
				for dy in range(-thick, thick + 1):
					_dot(p.x + dx, p.y + dy, c)

func _disc(d: Vector3, r: int, c: Color) -> void:
	var p := _px(d)
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r:
				_dot(p.x + dx, p.y + dy, c)
			elif dx * dx + dy * dy <= (r + 1) * (r + 1):
				_dot(p.x + dx, p.y + dy, PAPER)

func _square(d: Vector3, r: int, c: Color) -> void:
	var p := _px(d)
	for dx in range(-r - 1, r + 2):
		for dy in range(-r - 1, r + 2):
			_dot(p.x + dx, p.y + dy, c if absi(dx) <= r and absi(dy) <= r else PAPER)

func _ring(d: Vector3, r: int, c: Color) -> void:
	var p := _px(d)
	for k in r * 12:
		var a := TAU * k / (r * 12.0)
		_dot(p.x + roundi(cos(a) * r), p.y + roundi(sin(a) * r), c)
		_dot(p.x + roundi(cos(a) * (r + 1)), p.y + roundi(sin(a) * (r + 1)), c)

func _cross(d: Vector3, r: int, c: Color) -> void:
	var p := _px(d)
	for k in range(-r, r + 1):
		for w in range(-1, 2):
			_dot(p.x + k, p.y + w, c)
			_dot(p.x + w, p.y + k, c)

func _text(x: int, y: int, text: String, scale: int, c: Color) -> void:
	for ch in text:
		if FONT.has(ch):
			var rows: Array = FONT[ch]
			for ry in 7:
				for rx in 5:
					if String(rows[ry])[rx] == "1":
						for sx in scale:
							for sy in scale:
								_dot(x + rx * scale + sx, y + ry * scale + sy, c)
		x += 6 * scale

func _swatch(x: int, y: int, c: Color) -> void:
	for dx in 12:
		for dy in 12:
			_dot(x + dx, y + dy, c)

## The legend, bottom left over the sea of the map's far south, on its own
## dark panel.
func _legend(plan: WorldPlan) -> void:
	var rows := [
		["SEA", SEA, "box"], ["DUNES", DUNES, "box"], ["PLAINS", PLAINS, "box"],
		["PLATEAU", PLATEAU, "box"], ["MOUNTAINS", MOUNTAINS, "box"],
		["CANYON", CANYON, "line"], ["RANGE SPINE", SPINE, "line"],
		["OASIS SITE", OASIS, "dot"], ["SHORE SITE", SHORE, "box"],
		["WADOO AND KEPT DISC", KEPT, "ring"], ["ARRIVAL (OVER WADOO)", ARRIVAL, "cross"],
	]
	var x0 := 12
	var h := rows.size() * 20 + 40
	var y0 := MAP_H - h - 12
	for dx in 330:
		for dy in h:
			_dot(x0 + dx, y0 + dy, PAPER)
	_text(x0 + 10, y0 + 8, "WADIS PLAN - %.0f KM ROUND, %.2f KM A PIXEL" % [TAU * _radius / 1000.0, TAU * _radius / 1000.0 / MAP_W], 1, INK)
	for i in rows.size():
		var row: Array = rows[i]
		var y := y0 + 28 + i * 20
		var c: Color = row[1]
		match row[2]:
			"box":
				_swatch(x0 + 10, y, c)
			"line":
				for dx in 12:
					for dy in 3:
						_dot(x0 + 10 + dx, y + 4 + dy, c)
			"dot":
				for dx in 12:
					for dy in 12:
						if (dx - 5.5) * (dx - 5.5) + (dy - 5.5) * (dy - 5.5) <= 30.0:
							_dot(x0 + 10 + dx, y + dy, c)
			"ring":
				for k in 40:
					var a := TAU * k / 40.0
					_dot(x0 + 16 + roundi(cos(a) * 5.0), y + 6 + roundi(sin(a) * 5.0), c)
			"cross":
				for k in 12:
					_dot(x0 + 10 + k, y + 6, c)
					_dot(x0 + 16, y + k, c)
		_text(x0 + 32, y + 2, row[0], 2, INK)
