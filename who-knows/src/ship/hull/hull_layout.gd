class_name HullLayout
extends RefCounted

## Decides what the hull's outside is, once (docs/superpowers/specs/
## 2026-09-28-ship-exterior-design.md §3.1, §5, §6.1), for HullDressing to
## draw:
## - the skin over every occupied cell -- a plate per exposed face of a cube,
##   a chamfer on each convex edge, a facet where three chamfers meet, and
##   the exposed faces of shaped blocks;
## - the nozzles on engines and RCS;
## - the windows and pods, which match the interior's (Task 7);
## - the light mounts (Task 8).
##
## Pure: reads the grid and the interior's own layout, touches no nodes. The
## same grid always yields the same layout.

## A cell whose airlock can cycle: AirlockAlcove draws it, not the skin.
const ALCOVE := &"alcove"
const CHAMFER := HullProps.CHAMFER
const HALF_CELL := ShipGrid.CELL_SIZE * 0.5
## Light groups (spec §6).
const FLOOD := &"flood"
const FORWARD := &"forward"
## Floods: tilt out from the belly's centre, keel spacing, how far above the
## lowest a downward face still counts as belly (so a keel does not pull every
## flood onto the centreline).
const FLOOD_TILT_DEG := 25.0
const FLOOD_SPACING := 6.0
const BELLY_BAND := 1.5
## Forward lights: how nearly forward a face must look (normal . forward), how
## close to the bow, how far below a window, and the aim's drop and toe-out.
const FORWARD_MIN_DOT := 0.7
const FORWARD_BOW_BAND := 2.5
const FORWARD_BELOW_WINDOW := 0.3
const FORWARD_DROP_DEG := 5.0
const FORWARD_TOE_DEG := 3.0
## A bridge band's window outside (ship bridge spec §4.3): from the pane's sill
## up to where a shoulder's stops, the canopy slope's top edge (tuned at the
## final review: to the pane's own 2.3 m it lay over the blocks above), and
## its frame within the cell, a gap between neighbours' frames (they crossed
## at the corners).
const BAND_WINDOW_TOP := InteriorProps.SHOULDER_WINDOW_HIGH
const BAND_WINDOW_WIDTH := ShipGrid.CELL_SIZE - 2.0 * HullProps.FRAME - 0.06

var plates: Array[Dictionary] = []
var edges: Array[Dictionary] = []
var corners: Array[Dictionary] = []
var facets: Array[Dictionary] = []
var nozzles: Array[Dictionary] = []
var windows: Array[Dictionary] = []
var pods: Array[Dictionary] = []
var mounts: Array[Dictionary] = []
## Interior window faces with no place for a window outside. Empty on any
## ship we give the player; the probe prints it.
var unmatched: Array[Dictionary] = []
## How many interior windows there are, matched or not.
var wanted := 0
## The open faces of every cube cell: Vector3i -> {Vector3i normal: true}.
var skin: Dictionary = {}

var _grid: ShipGrid
var _alcoves: Dictionary = {}
var _pod_cells: Dictionary = {}

static func plan(grid: ShipGrid, _catalog: BlockCatalog, interior: InteriorLayout) -> HullLayout:
	var l := HullLayout.new()
	l._grid = grid
	for coord: Vector3i in grid.coords():
		if AirlockSite.hatch_normal(grid, coord) != Vector3i.ZERO:
			l._alcoves[coord] = true
	if interior != null:
		l._plan_pods(interior)
	l._plan_skin()
	l._plan_nozzles()
	if interior != null:
		l._plan_windows(interior)
	l._plan_mounts()
	l._mark_running()
	return l

func is_pod_cell(coord: Vector3i) -> bool:
	return _pod_cells.has(coord)

## Each cockpit pod (spec §5.2): the pod shell in the interior's own pod frame,
## brought down from its storey into hull space. The skin leaves its canopy
## cell to the shell.
func _plan_pods(interior: InteriorLayout) -> void:
	for pod in interior.pods():
		var coord: Vector3i = pod["coord"]
		var f := InteriorDressing.pod_frame(coord, pod["normal"])
		f.origin.y -= InteriorBuilder.storey_offset(coord.y)
		pods.append({"frame": f, "cell": coord + pod["normal"]})
		_pod_cells[coord + pod["normal"]] = true

## Every window inside gets one outside (spec §5.1): portholes, the
## shoulders beside a pod, and a nose's windows.
func _plan_windows(interior: InteriorLayout) -> void:
	var r := InteriorProps.PORTHOLE_RADIUS
	for face in interior.faces():
		if face["kind"] != InteriorLayout.Kind.WALL or not face["porthole"]:
			continue
		wanted += 1
		var coord: Vector3i = face["coord"]
		var normal: Vector3i = face["normal"]
		var skin_cell := coord
		if _grid.has_block(coord + normal):
			skin_cell = coord + normal
			if _grid.has_block(coord + normal * 2):
				unmatched.append({"coord": coord, "normal": normal})
				continue
		_window_on(skin_cell, coord, normal, InteriorProps.PORTHOLE_HEIGHT - r, InteriorProps.PORTHOLE_HEIGHT + r,
			r * 2.0, true, 0.0)
	for group in interior.canopy_groups():
		var normal: Vector3i = group["normal"]
		var group_pods: Array = group["pods"]
		# A bridge's band (ship bridge spec §4.3): a window outside every pane,
		# on its canopy's own face: up to the slope's top edge, as a shoulder's,
		# and narrow enough that its frame fits the cell.
		if group.get("band", false):
			for coord: Vector3i in group["coords"]:
				wanted += 1
				_window_on(coord + normal, coord, normal, InteriorProps.BAND_SILL, BAND_WINDOW_TOP,
					BAND_WINDOW_WIDTH, false, 0.0)
			continue
		if group_pods.is_empty():
			_nose_windows(group)
			continue
		for coord: Vector3i in group["coords"]:
			if group_pods.has(coord):
				continue
			wanted += 1
			_window_on(coord + normal, coord, normal, InteriorProps.SHOULDER_WINDOW_LOW,
				InteriorProps.SHOULDER_WINDOW_HIGH, InteriorProps.SHOULDER_WINDOW_HALF * 2.0, false, 0.0)

## A nose's windows (InteriorProps.NOSE_WINDOWS: across, height, half width,
## half height), each on the canopy cell it falls across.
func _nose_windows(group: Dictionary) -> void:
	var normal: Vector3i = group["normal"]
	var across := Vector3.UP.cross(-Vector3(normal))
	var coords: Array = group["coords"]
	var lo := INF
	var hi := -INF
	for c: Vector3i in coords:
		var a := ShipGrid.cell_center(c).dot(across)
		lo = minf(lo, a - HALF_CELL)
		hi = maxf(hi, a + HALF_CELL)
	for w: Vector4 in InteriorProps.NOSE_WINDOWS:
		wanted += 1
		var at := (lo + hi) * 0.5 + w.x
		var placed := false
		for c: Vector3i in coords:
			var a := ShipGrid.cell_center(c).dot(across)
			if absf(at - a) <= HALF_CELL:
				_window_on(c + normal, c, normal, w.y - w.w, w.y + w.w, w.z * 2.0, false, at - a)
				placed = true
				break
		if not placed:
			unmatched.append({"coord": coords[0], "normal": normal})

## One window on `skin_cell`'s face toward `normal`, between `lo` and `hi`
## above `interior_cell`'s floor, `width` across, `shift` along the interior's
## across from the face's centre line. The face may slope: the window's frame
## lies in it, and its size runs up the slope.
func _window_on(skin_cell: Vector3i, interior_cell: Vector3i, normal: Vector3i, lo: float, hi: float,
		width: float, is_round: bool, shift: float) -> void:
	var face := _outer_face(skin_cell, normal)
	if face.is_empty():
		unmatched.append({"coord": interior_cell, "normal": normal})
		return
	var n: Vector3 = face["normal"]
	var up := (Vector3.UP - n * Vector3.UP.dot(n)).normalized()
	var fl := InteriorBuilder.floor_y(interior_cell) - InteriorBuilder.storey_offset(interior_cell.y)
	var mid := fl + (lo + hi) * 0.5
	var p0: Vector3 = face["centre"]
	var centre := p0 + up * ((mid - p0.y) / up.y) + Vector3.UP.cross(-Vector3(normal)) * shift
	windows.append({"frame": Transform3D(Basis(up.cross(n), up, n), centre),
		"size": Vector2(width, (hi - lo) / up.y), "round": is_round, "coord": skin_cell})

## The skin face of `cell` that looks most along `normal`: a cube's own face,
## or the shaped block's face nearest that way. Empty if none shows.
func _outer_face(cell: Vector3i, normal: Vector3i) -> Dictionary:
	if skin.has(cell):
		if skin[cell].has(normal):
			return {"centre": ShipGrid.cell_center(cell) + Vector3(normal) * HALF_CELL, "normal": Vector3(normal)}
		return {}
	var best := {}
	var best_dot := 0.5
	for fc in facets:
		if fc["coord"] != cell:
			continue
		var n := facet_normal(fc)
		var d := n.dot(Vector3(normal))
		if d > best_dot:
			best_dot = d
			best = {"centre": facet_centre(fc), "normal": n}
	return best

## Every face of the skin that shows: {centre, normal, coord}, in hull space.
func _open_faces() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cubes := skin.keys()
	cubes.sort()
	for coord: Vector3i in cubes:
		for n: Vector3i in ShipGrid.FACE_OFFSETS:
			if skin[coord].has(n):
				out.append({"centre": ShipGrid.cell_center(coord) + Vector3(n) * HALF_CELL, "normal": Vector3(n),
					"coord": coord})
	for fc in facets:
		out.append({"centre": facet_centre(fc), "normal": facet_normal(fc), "coord": fc["coord"]})
	return out

func _plan_mounts() -> void:
	var faces := _open_faces()
	_plan_floods(faces.filter(func(f): return f["normal"].dot(Vector3.DOWN) > 0.99))
	_plan_forward(faces)

## Floods (spec §6.1): one at each corner of the belly, then along the keel
## every FLOOD_SPACING between the bow and stern corners.
func _plan_floods(down: Array) -> void:
	if down.is_empty():
		return
	var lowest := INF
	for f in down:
		lowest = minf(lowest, f["centre"].y)
	var belly := down.filter(func(f): return f["centre"].y <= lowest + BELLY_BAND)
	var cell_of := {}   # a belly face's centre -> its cell
	for f in belly:
		cell_of[f["centre"]] = f["coord"]
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for f in belly:
		var c: Vector3 = f["centre"]
		lo = Vector2(minf(lo.x, c.x), minf(lo.y, c.z))
		hi = Vector2(maxf(hi.x, c.x), maxf(hi.y, c.z))
	var middle := (lo + hi) * 0.5
	var chosen: Array[Vector3] = []
	for corner in [Vector2(lo.x, lo.y), Vector2(hi.x, lo.y), Vector2(lo.x, hi.y), Vector2(hi.x, hi.y)]:
		var best: Vector3 = belly[0]["centre"]
		var best_d := INF
		for f in belly:
			var c: Vector3 = f["centre"]
			var d := Vector2(c.x, c.z).distance_to(corner)
			if d < best_d - 0.001 or (absf(d - best_d) <= 0.001 and _before(c, best)):
				best = c
				best_d = d
		if not chosen.has(best):
			chosen.append(best)
	for c in chosen:
		_add_flood(c, Vector3(c.x - middle.x, 0, c.z - middle.y), cell_of[c])
	var fore := INF
	var aft := -INF
	for c in chosen:
		fore = minf(fore, c.z)
		aft = maxf(aft, c.z)
	var keel_x := INF
	for f in belly:
		keel_x = minf(keel_x, absf(f["centre"].x))
	var keel := belly.filter(func(f): return is_equal_approx(absf(f["centre"].x), keel_x))
	var count := floori((aft - fore) / FLOOD_SPACING)
	for i in count:
		var z := fore + (aft - fore) * float(i + 1) / float(count + 1)
		var best: Vector3 = keel[0]["centre"]
		for f in keel:
			var c: Vector3 = f["centre"]
			if absf(c.z - z) < absf(best.z - z) - 0.001:
				best = c
		if not chosen.has(best):
			chosen.append(best)
			_add_flood(best, Vector3(0, 0, signf(best.z - middle.y)), cell_of[best])

func _add_flood(at: Vector3, out: Vector3, coord: Vector3i) -> void:
	var t := deg_to_rad(FLOOD_TILT_DEG)
	var aim := Vector3.DOWN
	if out.length() > 0.01:
		aim = (Vector3.DOWN * cos(t) + out.normalized() * sin(t)).normalized()
	mounts.append({"group": FLOOD, "position": at, "normal": Vector3.DOWN, "aim": aim, "coord": coord})

## Ties go toward the centreline, then the bow.
static func _before(a: Vector3, b: Vector3) -> bool:
	if not is_equal_approx(absf(a.x), absf(b.x)):
		return absf(a.x) < absf(b.x)
	return a.z < b.z

## Forward lights (spec §6.1): of the faces looking within 45 deg of forward,
## on the pod's row (or the lowest row with any), near the bow, and not the
## pod's cell, the outermost to port and starboard.
func _plan_forward(faces: Array[Dictionary]) -> void:
	var fwd := faces.filter(func(f): return f["normal"].dot(Vector3.FORWARD) >= FORWARD_MIN_DOT and not _pod_cells.has(f["coord"]))
	if fwd.is_empty():
		return
	var row: int = pods[0]["cell"].y if not pods.is_empty() else 1 << 30
	if pods.is_empty():
		for f in fwd:
			row = mini(row, f["coord"].y)
	fwd = fwd.filter(func(f): return f["coord"].y == row)
	if fwd.is_empty():
		return
	var front := INF
	for f in fwd:
		front = minf(front, f["centre"].z)
	fwd = fwd.filter(func(f): return f["centre"].z <= front + FORWARD_BOW_BAND)
	var port: Dictionary = fwd[0]
	var starboard: Dictionary = fwd[0]
	for f in fwd:
		if f["centre"].x < port["centre"].x - 0.001:
			port = f
		if f["centre"].x > starboard["centre"].x + 0.001:
			starboard = f
	_add_forward(port)
	if starboard != port:
		_add_forward(starboard)

func _add_forward(face: Dictionary) -> void:
	var n: Vector3 = face["normal"]
	var centre: Vector3 = face["centre"]
	var up := (Vector3.UP - n * Vector3.UP.dot(n)).normalized()
	var y := centre.y
	for w in windows:
		if w["coord"] == face["coord"]:
			var wf: Transform3D = w["frame"]
			y = minf(y, wf.origin.y - w["size"].y * 0.5 * wf.basis.y.y - FORWARD_BELOW_WINDOW)
	var at := centre + up * ((y - centre.y) / up.y)
	var drop := deg_to_rad(FORWARD_DROP_DEG)
	var side := signf(centre.x) if not is_zero_approx(centre.x) else 1.0
	var aim := Vector3(0, -sin(drop), -cos(drop)).rotated(Vector3.UP, -side * deg_to_rad(FORWARD_TOE_DEG))
	mounts.append({"group": FORWARD, "position": at, "normal": n, "aim": aim.normalized(),
		"coord": face["coord"]})

## Cyan strips (spec §5.4): along the top chamfers, fore and aft, at the
## highest roof, and up the bow's vertical chamfers.
func _mark_running() -> void:
	var top := -(1 << 30)
	var bow := 1 << 30
	for e in edges:
		var ups: bool = e["a"] == Vector3i.UP or e["b"] == Vector3i.UP
		if ups and absi(e["axis"].z) == 1:
			top = maxi(top, e["coord"].y)
		var fwd: bool = e["a"] == Vector3i.FORWARD or e["b"] == Vector3i.FORWARD
		if fwd and absi(e["axis"].y) == 1:
			bow = mini(bow, e["coord"].z)
	for e in edges:
		var ups: bool = e["a"] == Vector3i.UP or e["b"] == Vector3i.UP
		var fwd: bool = e["a"] == Vector3i.FORWARD or e["b"] == Vector3i.FORWARD
		e["running"] = (ups and absi(e["axis"].z) == 1 and e["coord"].y == top) \
			or (fwd and absi(e["axis"].y) == 1 and e["coord"].z == bow)

## The skin frame of a face (spec §3.3): +z out of the hull, +y up the face,
## or toward the bow on a roof or belly, +x across.
static func face_basis(n: Vector3i) -> Basis:
	var z := Vector3(n)
	var y := Vector3.UP if n.y == 0 else Vector3.FORWARD
	return Basis(y.cross(z), y, z)

static func face_frame(coord: Vector3i, n: Vector3i) -> Transform3D:
	return Transform3D(face_basis(n), ShipGrid.cell_center(coord) + Vector3(n) * HALF_CELL)

## A chamfer's frame: origin on the cube's edge at its middle, +x along the
## edge, +y and +z the two faces' normals, so the cube is where y and z are
## negative.
static func edge_frame(e: Dictionary) -> Transform3D:
	var a: Vector3i = e["a"]
	var b: Vector3i = e["b"]
	var axis: Vector3i = e["axis"]
	return Transform3D(Basis(Vector3(axis), Vector3(a), Vector3(b)),
		ShipGrid.cell_center(e["coord"]) + Vector3(a + b) * HALF_CELL)

## Where a chamfer starts and ends along its frame's x: short of a corner by
## the chamfer, else the cell's own end.
static func edge_span(e: Dictionary) -> Vector2:
	var ends: Array = e["ends"]
	return Vector2(-HALF_CELL + (CHAMFER if ends[0] == &"corner" else 0.0),
		HALF_CELL - (CHAMFER if ends[1] == &"corner" else 0.0))

## A corner facet's frame: origin on the cube's corner, each axis along one of
## the three open faces' normals, so the cube is where all three are negative.
static func corner_frame(c: Dictionary) -> Transform3D:
	var s: Vector3i = c["sign"]
	return Transform3D(Basis(Vector3(s.x, 0, 0), Vector3(0, s.y, 0), Vector3(0, 0, s.z)),
		ShipGrid.cell_center(c["coord"]) + Vector3(s) * HALF_CELL)

static func cell_frame(coord: Vector3i, orientation: int) -> Transform3D:
	return Transform3D(BlockOrientation.basis_for(orientation), ShipGrid.cell_center(coord))

static func facet_face(f: Dictionary) -> Dictionary:
	return HullShapes.faces(f["shape"])[f["face"]]

static func facet_points(f: Dictionary) -> PackedVector3Array:
	var frame := cell_frame(f["coord"], f["orientation"])
	var out := PackedVector3Array()
	for p: Vector3 in facet_face(f)["points"]:
		out.append(frame * p)
	return out

static func facet_normal(f: Dictionary) -> Vector3:
	return (BlockOrientation.basis_for(f["orientation"]) * facet_face(f)["normal"]).normalized()

static func facet_centre(f: Dictionary) -> Vector3:
	var pts := facet_points(f)
	var c := Vector3.ZERO
	for p in pts:
		c += p
	return c / pts.size()

## What occupies a cell: its HullShapes shape, ALCOVE, or &"" when empty.
func shape_at(coord: Vector3i) -> StringName:
	var inst := _grid.get_block(coord)
	if inst == null:
		return &""
	if _alcoves.has(coord):
		return ALCOVE
	return HullShapes.shape_of(inst.block_id)

## Whether a point in hull space is inside any block's solid.
func inside(p: Vector3) -> bool:
	var coord := Vector3i((p / ShipGrid.CELL_SIZE).round())
	var shape := shape_at(coord)
	if shape == &"":
		return false
	if shape == ALCOVE:
		return true
	var inst := _grid.get_block(coord)
	var local := BlockOrientation.basis_for(inst.orientation).inverse() * (p - ShipGrid.cell_center(coord))
	return HullShapes.contains(shape, local)

## Whether the neighbour across `coord`'s face toward `normal` fills that whole
## face, hiding it.
func _covered(coord: Vector3i, normal: Vector3i) -> bool:
	var other := coord + normal
	var shape := shape_at(other)
	if shape == &"":
		return false
	if shape == HullShapes.CUBE or shape == ALCOVE:
		return true
	return HullShapes.covers(shape, _grid.get_block(other).orientation, -normal)

func _sorted_cells() -> Array:
	var cells := _grid.coords()
	cells.sort()
	return cells

func _plan_skin() -> void:
	for coord: Vector3i in _sorted_cells():
		var shape := shape_at(coord)
		if shape == ALCOVE or _pod_cells.has(coord):
			continue
		if shape == HullShapes.CUBE:
			var open := {}
			for n: Vector3i in ShipGrid.FACE_OFFSETS:
				if not _covered(coord, n):
					open[n] = true
			if not open.is_empty():
				skin[coord] = open
			continue
		var inst := _grid.get_block(coord)
		var basis := BlockOrientation.basis_for(inst.orientation)
		var faces := HullShapes.faces(shape)
		for i in faces.size():
			var side: Vector3i = faces[i]["side"]
			if side != Vector3i.ZERO:
				var hull_side := _round(basis * Vector3(side))
				if _covered(coord, hull_side):
					continue
			facets.append({"coord": coord, "shape": shape, "orientation": inst.orientation, "face": i})
	var cubes := skin.keys()
	cubes.sort()
	for coord: Vector3i in cubes:
		_plan_cube(coord, skin[coord])

## One cube's plates, chamfers and corner facets. A side of a plate is cut
## back by the chamfer where the face beside it, on the same cube, is open
## too: that edge is convex.
func _plan_cube(coord: Vector3i, open: Dictionary) -> void:
	for n: Vector3i in ShipGrid.FACE_OFFSETS:
		if not open.has(n):
			continue
		var b := face_basis(n)
		var x := _round(b.x)
		var y := _round(b.y)
		var lo := Vector2(-HALF_CELL, -HALF_CELL)
		var hi := Vector2(HALF_CELL, HALF_CELL)
		if open.has(-x):
			lo.x += CHAMFER
		if open.has(x):
			hi.x -= CHAMFER
		if open.has(-y):
			lo.y += CHAMFER
		if open.has(y):
			hi.y -= CHAMFER
		plates.append({"coord": coord, "normal": n, "lo": lo, "hi": hi})
	var faces := ShipGrid.FACE_OFFSETS
	for i in faces.size():
		for j in range(i + 1, faces.size()):
			var a: Vector3i = faces[i]
			var b: Vector3i = faces[j]
			if a + b == Vector3i.ZERO or not open.has(a) or not open.has(b):
				continue
			var axis := _cross(a, b)
			var ends: Array[StringName] = []
			for s in [-1, 1]:
				var along: Vector3i = axis * s
				if open.has(along):
					ends.append(&"corner")
				elif _edge_continues(coord + along, a, b):
					ends.append(&"through")
				else:
					ends.append(&"cap")
			edges.append({"coord": coord, "a": a, "b": b, "axis": axis, "ends": ends, "running": false})
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for sz in [-1, 1]:
				if open.has(Vector3i(sx, 0, 0)) and open.has(Vector3i(0, sy, 0)) and open.has(Vector3i(0, 0, sz)):
					corners.append({"coord": coord, "sign": Vector3i(sx, sy, sz)})

## A chamfer runs on into the next cell if that cell is a cube with both the
## same faces open.
func _edge_continues(other: Vector3i, a: Vector3i, b: Vector3i) -> bool:
	return skin.has(other) and skin[other].has(a) and skin[other].has(b)

## Engines and RCS get their bell or pod on the face their exhaust leaves by:
## the face opposite their push (RcsShow's convention), if it is open.
func _plan_nozzles() -> void:
	for coord: Vector3i in _sorted_cells():
		var inst := _grid.get_block(coord)
		if inst.block_id != &"thruster" and inst.block_id != RcsShow.BLOCK_ID:
			continue
		var exhaust := _round(BlockOrientation.basis_for(inst.orientation) * Vector3.BACK)
		if skin.has(coord) and skin[coord].has(exhaust):
			nozzles.append({"coord": coord, "normal": exhaust, "kind": inst.block_id})

static func _round(v: Vector3) -> Vector3i:
	return Vector3i(roundi(v.x), roundi(v.y), roundi(v.z))

static func _cross(a: Vector3i, b: Vector3i) -> Vector3i:
	return Vector3i(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
