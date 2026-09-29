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
