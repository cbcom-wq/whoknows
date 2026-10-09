class_name BaseExterior
extends Node3D

## A base's outside beyond its hull (habitat modules spec §8.1, §5.3): each
## module's shell, a rounded drum round its cells, and its four chunky legs
## down to the rock; and, while a module unfolds, its case flying in, its legs
## punching down and its shell growing out of the case, all by transform. In
## the base's frame, under its Exterior. Built from the site's leg lengths,
## never from the rock, so a waking base needs no ground to stand. Colours from
## HullPalette (and the module's band from InteriorPalette.MODULE_COLOURS, as
## its package wears it); no new shader.
##
## The shell: in plan, the module's footprint with its two short ends bulged
## out into arcs through its corners, so the legs at the corners stay under
## it; flat roof and floor with a chamfered rim; the hull's livery plating;
## chunky PANEL_LINE ribs up every cell boundary, at the ends and round every
## storey line; the module's colour band near the roof; a porthole wherever
## the interior has one. Where an airlock opens, the shell leaves the hatch
## face (the AirlockAlcove's) bare. The box hull ExteriorBuilder makes is
## hidden for a base (Base.rebuild) and kept for collision.

const LEG_RADIUS := 0.09
## The leg's outer sleeve, round its top part: the strut telescopes out of it.
const SLEEVE_RADIUS := 0.16
const SLEEVE_LENGTH := 0.45
const PAD_RADIUS := 0.28
const PAD_THICK := 0.08
const CASE_SIZE := Vector3(0.5, 0.35, 0.5)
const LAYER := 1

## How far the shell stands outside the cells: as far as the hatch face's
## plating does, so the two are flush.
const SHELL_OUT := AirlockAlcove.PLATE_OUT
## The chamfer round the roof and the floor.
const SHELL_BEVEL := 0.3
## How far each short end bulges out, as a fraction of the half width.
const END_BULGE := 0.4
const END_SEGMENTS := 8
## Ribs: width and how far they stand proud.
const RIB_WIDTH := 0.16
const RIB_PROUD := 0.07
## The colour band: its height, how far proud, and its centre below the roof's chamfer.
const BAND_HEIGHT := 0.24
const BAND_PROUD := 0.035
const BAND_DROP := 0.5

var _legs: Array[MeshInstance3D] = []
var _shell: Node3D
var _show: Node3D
var _leg_count := 0

## Every module's shell and legs, from the site. `windows` are the hull
## layout's (HullLayout.windows, base frame), each given a porthole on the
## shell; `openings` are the airlocks' hatch faces, [cell, outward normal],
## which the shell leaves bare.
func build(site: BaseSite, windows: Array = [], openings: Array = []) -> void:
	for leg in _legs:
		leg.queue_free()
	_legs.clear()
	if _shell != null:
		_shell.queue_free()
		_shell = null
	var kit := InteriorKit.new(self)
	kit.layer = LAYER
	var count := 0
	for i in site.modules.size():
		count += _add_legs(kit, site, i, 1.0)
	if count > 0:
		_legs.assign(kit.commit())
	_leg_count = count
	if site.modules.is_empty():
		return
	_shell = Node3D.new()
	_shell.name = "Shell"
	add_child(_shell)
	var shell := InteriorKit.new(_shell)
	# Drawn as the hull's skin is: on the own-hull layer (GridHome._apply_own
	# moves it to layer 1 when the base is not yours), so the canopy camera
	# inside never sees its inside.
	shell.layer = ExteriorBuilder.OWN_HULL_LAYER
	shell.light_mask = 1 | ExteriorBuilder.OWN_HULL_LAYER
	shell.materials = {InteriorKit.Batch.HULL: HullMaterials.livery(), InteriorKit.Batch.SOLID: HullMaterials.trim(),
		InteriorKit.Batch.GLASS: HullMaterials.window_glass(),
		InteriorKit.Batch.GLOW: HullMaterials.glow_instance(HullMaterials.WINDOW_ENERGY)}
	for i in site.modules.size():
		var box := _box(site, i)
		var plan := _plan(box)
		_draw_shell(shell, box, plan, _size(site, i), _band_colour(site, i), openings)
		for w: Dictionary in windows:
			if w["round"] and _holds(box, w["frame"].origin - w["frame"].basis.z * 0.2):
				_porthole(shell, plan, w)
	for mi in shell.commit():
		if mi.name != InteriorKit.BATCH_NAMES[InteriorKit.Batch.GLOW]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func leg_count() -> int:
	return _leg_count

## Module `index` at `t` of its unfolding (0..1): the case flies in and
## settles, the legs punch down, the shell grows from the case. At 1 the show
## is gone and the shell the rebuild made stands in its place.
func unfold(index: int, t: float, site: BaseSite) -> void:
	if _show != null:
		_show.queue_free()
		_show = null
	if t >= 1.0:
		return
	_show = Node3D.new()
	_show.name = "Unfolding"
	add_child(_show)
	var u := HabitatValues
	var at := t * u.UNFOLD
	var centre := site.centre_of(index)
	var full := Vector3(_size(site, index)) * ShipGrid.CELL_SIZE
	var kit := InteriorKit.new(_show)
	kit.layer = LAYER
	kit.materials = {InteriorKit.Batch.HULL: HullMaterials.livery(), InteriorKit.Batch.SOLID: HullMaterials.trim()}
	var fly := clampf(at / (u.FLY + u.SETTLE), 0.0, 1.0)
	var grow := clampf((at - u.FLY - u.SETTLE - u.LEGS) / u.WALLS, 0.0, 1.0)
	var size := CASE_SIZE.lerp(full, grow * grow * (3.0 - 2.0 * grow))
	var drop := Vector3.UP * (1.0 - fly) * 6.0
	var mid := centre + drop - Vector3.UP * (full.y - size.y) * 0.5
	if grow <= 0.0:
		kit.bevel_box(InteriorKit.Batch.SOLID, InteriorKit.at(mid), size, minf(0.1, size.x * 0.1),
			InteriorKit.solid(HullPalette.TRIM))
	else:
		var box := AABB(mid - size * 0.5, size)
		_draw_shell(kit, box, _plan(box), _size(site, index), _band_colour(site, index), [])
	var legs := clampf((at - u.FLY - u.SETTLE) / u.LEGS, 0.0, 1.0)
	if legs > 0.0:
		_add_legs(kit, site, index, legs)
	kit.commit()

## The four legs of module `index`, `reach` of the way down. Returns how many.
func _add_legs(kit: InteriorKit, site: BaseSite, index: int, reach: float) -> int:
	var m: Dictionary = site.modules[index]
	var legs: PackedFloat32Array = m["legs"]
	var size := _size(site, index)
	var at := ShipGrid.cell_center(m["cell"])
	var tops := Planting.corners(size)
	var made := 0
	for k in mini(legs.size(), tops.size()):
		var top: Vector3 = at + tops[k]
		var foot := top - Vector3.UP * legs[k] * reach
		var sleeve := minf(SLEEVE_LENGTH, legs[k] * 0.5) + SHELL_OUT
		kit.tube_between(InteriorKit.Batch.SOLID, top, top - Vector3.UP * minf(sleeve, legs[k] * reach),
			SLEEVE_RADIUS, InteriorKit.solid(HullPalette.TRIM))
		kit.tube_between(InteriorKit.Batch.SOLID, top, foot, LEG_RADIUS, InteriorKit.solid(HullPalette.TRIM))
		kit.tube_between(InteriorKit.Batch.SOLID, foot, foot + Vector3.UP * PAD_THICK, PAD_RADIUS,
			InteriorKit.solid(HullPalette.PANEL_LINE))
		kit.disc(InteriorKit.Batch.SOLID, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), foot + Vector3.UP * PAD_THICK),
			PAD_RADIUS, InteriorKit.solid(HullPalette.PANEL_LINE))
		made += 1
	return made

static func _size(site: BaseSite, index: int) -> Vector3i:
	var m: Dictionary = site.modules[index]
	return ModuleCatalog.get_def(m["kind"]).turned_size(m["turns"])

static func _band_colour(site: BaseSite, index: int) -> Color:
	return InteriorPalette.MODULE_COLOURS.get(site.modules[index]["kind"], HullPalette.TRIM)

## Module `index`'s cells, base frame.
static func _box(site: BaseSite, index: int) -> AABB:
	var full := Vector3(_size(site, index)) * ShipGrid.CELL_SIZE
	return AABB(site.centre_of(index) - full * 0.5, full)

static func _holds(box: AABB, p: Vector3) -> bool:
	return box.grow(0.05).has_point(p)

## The shell's outline in plan, round `box` (grown by SHELL_OUT): a closed
## loop of points (x, z) going round, the long sides straight and split at
## every cell boundary, each short end an arc through its two corners. Also
## each segment's outward normal, whether each point carries a rib, and the
## inset loop for the roof and floor.
static func _plan(box: AABB) -> Dictionary:
	var along_x := box.size.x >= box.size.z
	var c := box.get_center()
	var cu := c.x if along_x else c.z
	var cv := c.z if along_x else c.x
	var hu := (box.size.x if along_x else box.size.z) * 0.5 + SHELL_OUT
	var hv := (box.size.z if along_x else box.size.x) * 0.5 + SHELL_OUT
	var cells := maxi(roundi((hu - SHELL_OUT) * 2.0 / ShipGrid.CELL_SIZE), 1)
	var bulge := END_BULGE * hv
	var radius := (hv * hv + bulge * bulge) / (2.0 * bulge)
	var arc_c := hu + bulge - radius
	var half_angle := atan2(hv, hu - arc_c)
	var uv: Array[Vector2] = []
	var ribs: Array[bool] = []
	# The +v side, -u to +u, split at each cell boundary.
	var hu0 := hu - SHELL_OUT
	for k in cells:
		uv.append(Vector2(-hu0 + (2.0 * hu0) * k / cells if k > 0 else -hu, hv))
		ribs.append(true)
	# The +u end: an arc from +v round to -v.
	for k in END_SEGMENTS:
		var a := half_angle - 2.0 * half_angle * k / END_SEGMENTS
		uv.append(Vector2(arc_c + cos(a) * radius, sin(a) * radius) if k > 0 else Vector2(hu, hv))
		ribs.append(k == 0 or k * 2 == END_SEGMENTS)
	# The -v side, +u to -u.
	for k in cells:
		uv.append(Vector2(hu0 - (2.0 * hu0) * k / cells if k > 0 else hu, -hv))
		ribs.append(true)
	# The -u end, from -v round to +v.
	for k in END_SEGMENTS:
		var a := half_angle - 2.0 * half_angle * k / END_SEGMENTS
		uv.append(Vector2(-arc_c - cos(a) * radius, -sin(a) * radius) if k > 0 else Vector2(-hu, -hv))
		ribs.append(k == 0 or k * 2 == END_SEGMENTS)
	var pts := PackedVector2Array()
	for p in uv:
		pts.append(Vector2(cu + p.x, cv + p.y) if along_x else Vector2(cv + p.y, cu + p.x))
	# Outward normals: the loop runs the same way round either way, so pick
	# the side away from the centre.
	var normals := PackedVector2Array()
	var n_pts := pts.size()
	var centre := Vector2(c.x, c.z)
	for i in n_pts:
		var d := pts[(i + 1) % n_pts] - pts[i]
		var n := Vector2(d.y, -d.x).normalized()
		if n.dot((pts[i] + pts[(i + 1) % n_pts]) * 0.5 - centre) < 0.0:
			n = -n
		normals.append(n)
	# Each point's normal (between its two segments), and the loop inset by
	# the bevel, mitred.
	var corner_normals := PackedVector2Array()
	var inset := PackedVector2Array()
	for i in n_pts:
		var a := normals[(i - 1 + n_pts) % n_pts]
		var b := normals[i]
		var m := (a + b).normalized()
		corner_normals.append(m)
		inset.append(pts[i] - m * SHELL_BEVEL / maxf(m.dot(b), 0.5))
	return {"points": pts, "normals": normals, "corner_normals": corner_normals, "inset": inset,
		"ribs": ribs, "centre": centre}

static func _v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)

static func _n3(n: Vector2) -> Vector3:
	return Vector3(n.x, 0.0, n.y)

## True if the shell at `p` (base frame), facing `n`, would cover a hatch face.
static func _at_opening(p: Vector3, n: Vector3, openings: Array) -> bool:
	for o: Array in openings:
		var normal := Vector3(o[1] as Vector3i)
		if n.dot(normal) < 0.9:
			continue
		var face := ShipGrid.cell_center(o[0]) + normal * ShipGrid.CELL_SIZE * 0.5
		var off := p - face
		var across := Vector3.UP.cross(normal)
		var half := ShipGrid.CELL_SIZE * 0.5
		if absf(off.dot(normal)) < 0.5 and absf(off.dot(across)) < half and absf(off.y) < half:
			return true
	return false

## One module's shell round `box` (base frame), from its `plan`: `cells` says
## where its storeys and cell boundaries fall.
static func _draw_shell(kit: InteriorKit, box: AABB, plan: Dictionary, cells: Vector3i, band: Color,
		openings: Array) -> void:
	var pts: PackedVector2Array = plan["points"]
	var normals: PackedVector2Array = plan["normals"]
	var inset: PackedVector2Array = plan["inset"]
	var n_pts := pts.size()
	var plate := InteriorKit.solid(HullPalette.UNHURT)
	var rib := InteriorKit.solid(HullPalette.PANEL_LINE)
	var bevel := minf(SHELL_BEVEL, box.size.y * 0.15)
	var y0 := box.position.y - SHELL_OUT
	var y1 := box.end.y + SHELL_OUT
	# The wall in bands: the bottom chamfer, each storey, the top chamfer.
	var lines: Array[float] = [y0, y0 + bevel]
	for k in range(1, cells.y):
		lines.append(box.position.y + box.size.y * k / cells.y)
	lines.append(y1 - bevel)
	lines.append(y1)
	var band_y := y1 - bevel - BAND_DROP
	for i in n_pts:
		var a := pts[i]
		var b := pts[(i + 1) % n_pts]
		var n := _n3(normals[i])
		if a.distance_to(b) < 0.001:
			continue
		var mid2 := (a + b) * 0.5
		for k in lines.size() - 1:
			var ya := lines[k]
			var yb := lines[k + 1]
			var low := k == 0
			var high := k == lines.size() - 2
			# A chamfer covers what the storey next to it does, at a hatch.
			var probe_y := (lines[1] + lines[2]) * 0.5 if low else ((lines[k - 1] + lines[k]) * 0.5 if high else (ya + yb) * 0.5)
			if _at_opening(_v3(mid2, probe_y), n, openings):
				continue
			if low:
				var ia := inset[i]
				var ib := inset[(i + 1) % n_pts]
				kit.quad(InteriorKit.Batch.HULL, _v3(ia, ya), _v3(ib, ya), _v3(b, yb), _v3(a, yb),
					(n - Vector3.UP).normalized(), plate)
			elif high:
				var ia := inset[i]
				var ib := inset[(i + 1) % n_pts]
				kit.quad(InteriorKit.Batch.HULL, _v3(a, ya), _v3(b, ya), _v3(ib, yb), _v3(ia, yb),
					(n + Vector3.UP).normalized(), plate)
			else:
				kit.quad(InteriorKit.Batch.HULL, _v3(a, ya), _v3(b, ya), _v3(b, yb), _v3(a, yb), n, plate)
		# A rib round each storey line, and the module's band near the roof.
		var seg := b - a
		var basis := Basis(_n3(seg.normalized()), Vector3.UP, n)
		for k in range(2, lines.size() - 2):
			if not _at_opening(_v3(mid2, lines[k] - 0.3), n, openings):
				kit.box(InteriorKit.Batch.SOLID, Transform3D(basis, _v3(mid2, lines[k]) + n * RIB_PROUD * 0.5),
					Vector3(seg.length() + RIB_WIDTH * 0.5, RIB_WIDTH, RIB_PROUD), rib)
		if band_y > y0 + bevel and not _at_opening(_v3(mid2, band_y), n, openings):
			kit.box(InteriorKit.Batch.SOLID, Transform3D(basis, _v3(mid2, band_y) + n * BAND_PROUD * 0.5),
				Vector3(seg.length() + 0.02, BAND_HEIGHT, BAND_PROUD), InteriorKit.solid(band))
	# Ribs up the cell boundaries and the ends, from chamfer to chamfer.
	var ribs: Array = plan["ribs"]
	var corner_normals: PackedVector2Array = plan["corner_normals"]
	var rib_lo := y0 + bevel
	var rib_hi := y1 - bevel
	for i in n_pts:
		if not ribs[i]:
			continue
		var n := _n3(corner_normals[i])
		var basis := Basis(Vector3.UP.cross(n), Vector3.UP, n)
		kit.bevel_box(InteriorKit.Batch.SOLID,
			Transform3D(basis, _v3(pts[i], (rib_lo + rib_hi) * 0.5) + n * RIB_PROUD * 0.5),
			Vector3(RIB_WIDTH, rib_hi - rib_lo, RIB_PROUD * 2.0), 0.03, rib)
	# Roof and floor: fans over the inset loop.
	var centre: Vector2 = plan["centre"]
	for i in n_pts:
		var a := inset[i]
		var b := inset[(i + 1) % n_pts]
		kit.tri(InteriorKit.Batch.HULL, _v3(centre, y1), _v3(a, y1), _v3(b, y1), Vector3.UP, plate)
		kit.tri(InteriorKit.Batch.HULL, _v3(centre, y0), _v3(a, y0), _v3(b, y0), Vector3.DOWN, plate)

## A porthole on the shell where window `w` (HullLayout's, on the box's
## face) looks out: the shell's point straight out from it.
static func _porthole(kit: InteriorKit, plan: Dictionary, w: Dictionary) -> void:
	var f: Transform3D = w["frame"]
	var out := Vector2(f.basis.z.x, f.basis.z.z).normalized()
	var from := Vector2(f.origin.x, f.origin.z) - out * 10.0
	var pts: PackedVector2Array = plan["points"]
	var normals: PackedVector2Array = plan["normals"]
	var best := -INF
	var hit := Vector2.ZERO
	var hit_n := out
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var at: Variant = Geometry2D.segment_intersects_segment(from, from + out * 30.0, a, b)
		if at == null:
			continue
		var d := ((at as Vector2) - from).dot(out)
		if d > best:
			best = d
			hit = at
			hit_n = normals[i]
	if best == -INF:
		return
	var n := _n3(hit_n)
	var frame := Transform3D(Basis(Vector3.UP.cross(n), Vector3.UP, n), _v3(hit, f.origin.y))
	HullProps.window_porthole(kit, frame, w["size"].x * 0.5)
