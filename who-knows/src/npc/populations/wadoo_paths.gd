class_name WadooPaths
extends RefCounted

## Where a Wadee can walk in Wadoo (docs/superpowers/specs/2026-11-16-wadoo-design.md
## §12): a grid of CELL-metre cells over the town, each open or solid, built from
## the place's layout alone (data/places/oasis.json), and routes over it. Pure:
## it never reads the scene, so a test builds it from the layout. Points are
## [east, north] m in the place's frame (x = east, z = -north).
##
## Solid: outside the ring wall (but near its gate and its breach), the wall and
## its piers, the yards' walls, the shells, the pool, the garden beds, the
## pump, the sails' poles and benches, the palms, the items and the memorial, each with a
## margin a body needs to pass it.

const CELL := 0.5
## The grid reaches this many cells either side of the place's origin.
const REACH := 116
## Outside the ring, the ground within this of the gate or the breach is open.
const OUTSIDE_GATES := 9.0
## Margins, m, from a solid's edge (or its line, for a wall) to an open cell's middle.
const WALL_CLEAR := 0.55
const SHELL_CLEAR := 0.45
const POOL_CLEAR := 0.6
const BED_CLEAR := 0.3
const PUMP_CLEAR := 1.0
const POLE_CLEAR := 0.4
const PALM_CLEAR := 0.55
const ITEM_CLEAR := 0.6
const MEMORIAL_CLEAR := 0.5
const BENCH_CLEAR := 0.2
## An open shell with a room (the queen's hall): its inside is open this far in
## from its walls, its doorway this far in from its jambs, and the room's solid
## pieces (WadooRooms.solids) are kept this far off.
const ROOM_CLEAR := 0.3
const DOORWAY_CLEAR := 0.25
const ROOM_SOLID_CLEAR := 0.25
## Where a door's spot stands: this far out from the door's middle.
const DOOR_OUT := 1.0
## Line of sight is tested every this far along a leg, m.
const LINE_STEP := 0.35

var _grid := AStarGrid2D.new()
## Door spots of every shell by id: [{at: Vector2, out: Vector2 (the way out)}].
var doors := {}
## The ring wall's corners, [east, north], closed.
var ring := PackedVector2Array()
## The gate's and the breach's middles, [east, north].
var gate := Vector2.ZERO
var breach := Vector2.ZERO
## The open shells with rooms: [{at, size, yaw, room}].
var rooms := []

## The paths of `layout` (a place's layout), whose pool's water reaches
## `pool_radius` m from its middle.
static func build(layout: Dictionary, pool_radius: float) -> WadooPaths:
	var paths := WadooPaths.new()
	paths._build(layout, pool_radius)
	return paths

func _build(layout: Dictionary, pool_radius: float) -> void:
	_grid.region = Rect2i(-REACH, -REACH, 2 * REACH + 1, 2 * REACH + 1)
	_grid.cell_size = Vector2.ONE * CELL
	_grid.offset = Vector2.ZERO
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()
	var wall: Dictionary = layout.get("wall", {})
	for p: Array in wall.get("ring", []):
		ring.append(Vector2(float(p[0]), float(p[1])))
	if wall.has("gate"):
		gate = _v2(wall["gate"]["at"])
	if wall.has("breach"):
		breach = _v2(wall["breach"]["at"])
	# Outside the ring, all but the ground before the gate and the breach.
	if ring.size() >= 3:
		# row by row: inside lies between pairs of the ring's crossings of the row
		for j in range(-REACH, REACH + 1):
			var y := j * CELL
			var xs: Array[float] = []
			for k in ring.size():
				var a := ring[k]
				var b := ring[(k + 1) % ring.size()]
				if (a.y <= y) != (b.y <= y):
					xs.append(a.x + (y - a.y) / (b.y - a.y) * (b.x - a.x))
			for i in range(-REACH, REACH + 1):
				var p := cell_middle(Vector2i(i, j))
				var crossed := 0
				for x in xs:
					if x < p.x:
						crossed += 1
				if crossed % 2 == 0 and p.distance_to(gate) > OUTSIDE_GATES and p.distance_to(breach) > OUTSIDE_GATES:
					_grid.set_point_solid(Vector2i(i, j))
		var cut := PlaceField.ring_wall(wall)
		for run: PackedVector2Array in cut["runs"]:
			for k in run.size() - 1:
				_solid_segment(run[k], run[k + 1], WALL_CLEAR)
		var pier: Array = wall.get("gate", {}).get("pier", [1.2, 3.4])
		for p: Array in cut["piers"]:
			_solid_disc(p[0], float(pier[0]) * 0.7 + WALL_CLEAR * 0.5)
	for y: Dictionary in layout.get("yards", []):
		var pts: Array = y["points"]
		for k in pts.size() - 1:
			_solid_segment(_v2(pts[k]), _v2(pts[k + 1]), WALL_CLEAR)
	for s: Dictionary in layout.get("shells", []):
		_shell(s)
	if layout.has("pool"):
		_solid_disc(_v2(layout["pool"].get("at", [0, 0])), pool_radius + POOL_CLEAR)
	for g: Dictionary in layout.get("gardens", []):
		var size: Array = g.get("size", [4.0, 3.0])
		_solid_box(_v2(g["at"]), Vector2(float(size[0]), float(size[1])) * 0.5, 0.0, BED_CLEAR)
	if layout.has("pump"):
		_solid_disc(_v2(layout["pump"]["at"]), PUMP_CLEAR)
	for s: Dictionary in layout.get("sails", []):
		var sz: Array = s.get("size", [4.5, 3.5])
		var yaw := float(s.get("yaw", 0.0))
		for cx in [-0.5, 0.5]:
			for cz in [-0.5, 0.5]:
				_solid_disc(_v2(s["at"]) + local_to_place(Vector2(cx * float(sz[0]), cz * float(sz[1])), yaw), POLE_CLEAR)
	for p: Array in layout.get("palms", []):
		_solid_disc(_v2(p), PALM_CLEAR)
	for it: Dictionary in layout.get("items", []):
		_solid_disc(_v2(it["at"]), ITEM_CLEAR)
	for bench: Dictionary in layout.get("benches", []):
		_solid_box(_v2(bench["at"]), Vector2(float(bench.get("length", 2.4)), BrickShell.BENCH_DEPTH) * 0.5,
			float(bench.get("yaw", 0.0)), BENCH_CLEAR)
	if layout.has("memorial"):
		var m: Dictionary = layout["memorial"]
		_solid_disc(_v2(m["at"]), float(m.get("radius", 2.4)) + MEMORIAL_CLEAR)

## A shell's footprint, solid, and its door's spot.
func _shell(s: Dictionary) -> void:
	var at := _v2(s["at"])
	var yaw := float(s.get("yaw", 0.0))
	var variety := float(s.get("variety", 0.5))
	var spots := []
	if str(s["kind"]) == "round":
		var radius := float(s["radius"])
		_solid_disc(at, radius + SHELL_CLEAR)
		spots = BrickShell.door_spots([], radius)
	else:
		var sz: Array = s["size"]
		var size := Vector3(float(sz[0]), float(sz[1]), float(sz[2]))
		_solid_box(at, Vector2(size.x, size.z) * 0.5, yaw, SHELL_CLEAR)
		if str(s["kind"]) == "crushed":
			spots = BrickShell.door_spots([], 0.0, size)
		else:
			spots = BrickShell.door_spots(BrickShell.openings_for(size, variety,
				float(s.get("door_width", BrickShell.DOOR.x))))
			if bool(s.get("open", false)) and s.has("room"):
				_open_room(at, size, yaw, spots, StringName(str(s["room"])))
	var list := []
	for d: Array in spots:
		var c: Vector3 = d[0]
		var way: Vector3 = d[1]
		var spot := at + local_to_place(Vector2(c.x, c.z) + Vector2(way.x, way.z) * DOOR_OUT, yaw)
		list.append({"at": spot, "out": local_to_place(Vector2(way.x, way.z), yaw).normalized(),
			"door": at + local_to_place(Vector2(c.x, c.z), yaw)})
	doors[str(s["id"])] = list

## The inside of an open shell (its room) walkable: the floor clear of the walls,
## its doorway, and the room's pieces solid again.
func _open_room(at: Vector2, size: Vector3, yaw: float, spots: Array, room: StringName) -> void:
	var inner := Vector2(size.x, size.z) * 0.5 - Vector2.ONE * (BrickShell.WALL + ROOM_CLEAR)
	_set_box(at, inner, yaw, false)
	for d: Array in spots:
		# from just inside the wall to past the shell's margin outside, a door wide
		var c: Vector3 = d[0]
		var way: Vector3 = d[1]
		var inside := BrickShell.WALL * 0.5 + ROOM_CLEAR + CELL
		var outside := BrickShell.WALL * 0.5 + SHELL_CLEAR + CELL
		var mid := Vector2(c.x, c.z) + Vector2(way.x, way.z) * (outside - inside) * 0.5
		var across := maxf(float(d[2]) * 0.5 - DOORWAY_CLEAR, CELL * 0.75)
		var half := Vector2(across, (inside + outside) * 0.5)
		if absf(way.x) > 0.5:
			half = Vector2(half.y, half.x)
		_set_box(at + local_to_place(mid, yaw), half, yaw, false)
	for sol: Array in WadooRooms.solids(room):
		_solid_box(at + local_to_place(sol[0], yaw), sol[1], yaw, ROOM_SOLID_CLEAR)
	rooms.append({"at": at, "size": size, "yaw": yaw, "room": room})

## Sets every cell of a box of half-size `half` (its own x by z) at `c`, turned
## by `yaw_deg`, solid or open.
func _set_box(c: Vector2, half: Vector2, yaw_deg: float, solid: bool) -> void:
	for cell in _cells_near(c, Vector2.ONE * half.length()):
		var l := place_to_local(cell_middle(cell) - c, yaw_deg)
		if absf(l.x) <= half.x and absf(l.y) <= half.y:
			_grid.set_point_solid(cell, solid)

## A point `local` (x, z in a piece's own frame) turned by the piece's `yaw_deg`
## as PlaceField turns it, as [east, north] from the piece's middle.
static func local_to_place(local: Vector2, yaw_deg: float) -> Vector2:
	var p := Basis(Vector3.UP, -deg_to_rad(yaw_deg)) * Vector3(local.x, 0.0, local.y)
	return Vector2(p.x, -p.z)

## The reverse: an [east, north] offset from a piece's middle in its own frame.
static func place_to_local(offset: Vector2, yaw_deg: float) -> Vector2:
	var p := Basis(Vector3.UP, -deg_to_rad(yaw_deg)).inverse() * Vector3(offset.x, 0.0, -offset.y)
	return Vector2(p.x, p.z)

func _solid_disc(c: Vector2, r: float) -> void:
	for cell in _cells_near(c, Vector2(r, r)):
		if cell_middle(cell).distance_to(c) <= r:
			_grid.set_point_solid(cell)

func _solid_segment(a: Vector2, b: Vector2, r: float) -> void:
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(r, r)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(r, r)
	for cell in _cells_near((lo + hi) * 0.5, (hi - lo) * 0.5):
		var p := cell_middle(cell)
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) <= r:
			_grid.set_point_solid(cell)

## A box of half-size `half` (its own x by z) at `c`, turned by `yaw_deg`, grown by `clear`.
func _solid_box(c: Vector2, half: Vector2, yaw_deg: float, clear: float) -> void:
	var reach := half.length() + clear
	for cell in _cells_near(c, Vector2(reach, reach)):
		var l := place_to_local(cell_middle(cell) - c, yaw_deg)
		if absf(l.x) <= half.x + clear and absf(l.y) <= half.y + clear:
			_grid.set_point_solid(cell)

func _cells_near(c: Vector2, half: Vector2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var lo := cell_of(c - half)
	var hi := cell_of(c + half)
	for i in range(maxi(lo.x, -REACH), mini(hi.x, REACH) + 1):
		for j in range(maxi(lo.y, -REACH), mini(hi.y, REACH) + 1):
			out.append(Vector2i(i, j))
	return out

## The cell holding [east, north] `p`.
static func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x / CELL), roundi(p.y / CELL))

static func cell_middle(cell: Vector2i) -> Vector2:
	return Vector2(cell) * CELL

static func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))

func _in_grid(cell: Vector2i) -> bool:
	return absi(cell.x) <= REACH and absi(cell.y) <= REACH

## Whether a body can stand at `p`.
func is_open(p: Vector2) -> bool:
	var cell := cell_of(p)
	return _in_grid(cell) and not _grid.is_point_solid(cell)

## The open point nearest `p`: itself if open, else the middle of the nearest open cell.
func nearest_open(p: Vector2) -> Vector2:
	if is_open(p):
		return p
	var c := cell_of(p)
	for r in range(1, 2 * REACH):
		var best := Vector2.INF
		for i in range(c.x - r, c.x + r + 1):
			for j in range(c.y - r, c.y + r + 1):
				if maxi(absi(i - c.x), absi(j - c.y)) != r:
					continue
				var cell := Vector2i(i, j)
				if _in_grid(cell) and not _grid.is_point_solid(cell):
					var m := cell_middle(cell)
					if m.distance_to(p) < best.distance_to(p):
						best = m
		if best != Vector2.INF:
			return best
	return p

## Whether the straight leg from `a` to `b` crosses no solid cell.
func clear_line(a: Vector2, b: Vector2) -> bool:
	var n := maxi(1, ceili(a.distance_to(b) / LINE_STEP))
	for k in n + 1:
		if not is_open(a.lerp(b, float(k) / n)):
			return false
	return true

## The way from `from` to `to`: the points to walk through, `from` first and
## `to` (or the open point nearest it) last, each leg clear. Empty when there is
## no way.
func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start := nearest_open(from)
	var end := nearest_open(to)
	if clear_line(start, end):
		return PackedVector2Array([from, end]) if start == from else PackedVector2Array([from, start, end])
	var cells := _grid.get_id_path(cell_of(start), cell_of(end))
	if cells.is_empty():
		return PackedVector2Array()
	var raw := PackedVector2Array([start])
	for k in range(1, cells.size() - 1):
		raw.append(cell_middle(cells[k]))
	raw.append(end)
	# Pulled tight: from each point on as far along the cells as a clear line goes
	# (the first blocked one ends the leg, so it costs a line a cell, not every pair).
	var out := PackedVector2Array([from]) if start == from else PackedVector2Array([from, start])
	var i := 0
	while i < raw.size() - 1:
		var j := i + 1
		while j + 1 < raw.size() and clear_line(raw[i], raw[j + 1]):
			j += 1
		out.append(raw[j])
		i = j
	return out
