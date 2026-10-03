class_name HoloVolume
extends Node3D

## The holo over the bridge computer's table
## (docs/superpowers/specs/2026-09-25-bridge-computer-design.md §5, §7): small
## glowing marks for what the ship's sensors know, a chevron for the ship,
## stalks for height, a bracket round the selected mark, and on the status
## page a miniature of the ship itself.
##
## Every mark is glowing kit geometry with its colour baked in, one MultiMesh
## per shape and colour, so a few hundred cost a handful of draws and the glow
## shader needs no instance colours. Nothing changes a shared material: marks
## grow, shrink and pulse by scale.
##
## Knows nothing about ships or sensors: it is given shapes, colours, places
## and sizes. Its own frame is the map's: origin at the volume's centre, axes
## the ship's, so the table places it unrotated. No collider: you can put your
## hand into it.

const RADIUS := 0.5
const HALF_HEIGHT := 0.3
## Marks of one shape and colour a group starts with room for. A busy system
## needs more -- seed 2's 31 worlds draw about 840 faint ticks on the system
## range -- so a group doubles as it fills, up to MAX_CAPACITY; past that,
## marks are dropped, counted (dropped()) and warned of, never silently.
const CAPACITY := 512
const MAX_CAPACITY := 4096
## The miniature's longest side, metres (spec §7.1), and how fast it turns.
const MINIATURE_SIZE := 0.8
const SPIN := deg_to_rad(10.0)
## How strongly the holo glows, against the glow batch's other pieces: bright
## enough that a pip a centimetre across still reads at arm's length.
const ENERGY := 2.0
## The bracket's corner ticks, metres across whatever the size of what they
## close round: the selection must show even on the smallest pip.
const BRACKET_TICK := 0.007
const BRACKET_PULSE_HZ := 1.5
## A faceted ball (a rock), a diamond (a ping), three rings round a sphere (a
## region), a hollow ring facing out (a pin on the edge), a stalk down or up to
## the ship's level, and the tick at its foot. Each is unit-sized: a mark's
## size scales it.
const SHAPES: Array[StringName] = [&"ball", &"diamond", &"sphere", &"pin", &"stalk", &"tick"]
const _GLOW := InteriorKit.Batch.GLOW

var layer := InteriorKit.LAYER
## Whether marks dropped past MAX_CAPACITY are warned of (once). A test that
## means to overflow turns it off to keep its output clean.
var warn_on_drop := true
var _dropped := 0
var _warned := false
var _groups: Dictionary = {}   # StringName shape -> {Color: MultiMeshInstance3D}
## What each group was given this time. Kept here too: the renderer owns a
## MultiMesh's own copy, and a headless run keeps none to read back.
var _placed: Dictionary = {}   # MultiMeshInstance3D -> Array[Transform3D]
var _frame_parts: Array[MeshInstance3D] = []
var _bracket: MultiMeshInstance3D
var _bracket_at := Vector3.ZERO
var _bracket_size := 0.0
var _pivot: Node3D
## The marks and the bracket, turned as a whole by set_turn.
var _marks_root: Node3D
## Turned by the operator at a computer station (computer mode spec §4.4): the
## marks, the bracket and the chevron, on top of the ship's turn.
var _spin_root: Node3D
var _chevron_parts: Array[MeshInstance3D] = []
var _chevron_wanted := true
var _frame_wanted := true
var _mini_meshes: Array[Mesh] = []
var _time := 0.0

## Builds the chevron, the edge ring and the bracket. Call once, before it
## enters the tree.
func setup(render_layer := InteriorKit.LAYER) -> void:
	layer = render_layer
	var kit := _kit()
	_edge_ring(kit)
	_frame_parts = kit.commit()
	for part in _frame_parts:
		part.name = "MapFrame"
	_spin_root = Node3D.new()
	_spin_root.name = "Spin"
	add_child(_spin_root)
	var chevron_kit := _kit(_spin_root)
	_chevron(chevron_kit)
	_chevron_parts = chevron_kit.commit()
	for part in _chevron_parts:
		part.name = "Chevron"
	_marks_root = Node3D.new()
	_marks_root.name = "Marks"
	_spin_root.add_child(_marks_root)
	var bracket_kit := _kit()
	bracket_kit.bevel_box(_GLOW, Transform3D.IDENTITY, Vector3.ONE, 0.25, InteriorKit.lit(InteriorPalette.AMBER, ENERGY))
	var corners := MultiMesh.new()
	corners.transform_format = MultiMesh.TRANSFORM_3D
	corners.mesh = bracket_kit.mesh(_GLOW)
	corners.instance_count = 8
	_bracket = MultiMeshInstance3D.new()
	_bracket.name = "Bracket"
	_bracket.multimesh = corners
	_bracket.material_override = InteriorMaterials.glow()
	_bracket.layers = layer
	_bracket.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bracket.visible = false
	_marks_root.add_child(_bracket)
	_pivot = Node3D.new()
	_pivot.name = "Miniature"
	add_child(_pivot)

## Where a contact `relative` metres from the ship, in the ship's axes, sits in
## the holo at `range_m`. Beyond the range, or above or below the volume, it is
## pulled back along its own direction onto the volume's surface: pinned.
static func place(relative: Vector3, range_m: float) -> Dictionary:
	var p := relative * (RADIUS / range_m)
	var t := 1.0
	var flat := Vector2(p.x, p.z).length()
	if flat > RADIUS:
		t = minf(t, RADIUS / flat)
	if absf(p.y) > HALF_HEIGHT:
		t = minf(t, HALF_HEIGHT / absf(p.y))
	return {"position": p * t, "pinned": t < 1.0}

## Whether a point already in the holo's metres lies inside the volume: what
## place() leaves unpinned. For the map's ticks, which are never drawn pinned
## and are too many to make a Dictionary each.
static func inside(p: Vector3) -> bool:
	return p.x * p.x + p.z * p.z <= RADIUS * RADIUS and absf(p.y) <= HALF_HEIGHT

## Draws `marks`, each {shape, colour, position, size}; a shape and colour
## with none this time is emptied. For &"stalk", `position` is the top of the
## stalk, and it runs from there to the ship's level.
func show_marks(marks: Array) -> void:
	begin_marks()
	for m in marks:
		add_mark(m["shape"], m["colour"], m["position"], m["size"])
	end_marks()

## The same, a mark at a time, with nothing allocated per mark: begin, add
## each, end. For the map, which draws hundreds every frame.
func begin_marks() -> void:
	_dropped = 0
	for mmi in _placed:
		(_placed[mmi] as Array).clear()

func add_mark(shape: StringName, colour: Color, position: Vector3, size: float) -> void:
	var placed: Array = _placed[_group(shape, colour)]
	if placed.size() < MAX_CAPACITY:
		placed.append(_transform(shape, position, size))
	else:
		_dropped += 1

## Many ticks of one colour and size at once, as add_mark would place them:
## the map's rings, belts and limits, hundreds a placing, for one group looked
## up and one basis made.
func add_ticks(colour: Color, positions: PackedVector3Array, size: float) -> void:
	if positions.is_empty():
		return
	var placed: Array = _placed[_group(&"tick", colour)]
	var b := Basis.from_scale(Vector3.ONE * size)
	for at in positions:
		if placed.size() >= MAX_CAPACITY:
			_dropped += 1
			continue
		placed.append(Transform3D(b, at))

## Hands each group its transforms in one buffer, 12 floats apiece as
## MultiMesh.buffer lays them out: one call, not one per mark. A group with
## more marks than room doubles first.
func end_marks() -> void:
	if _dropped > 0 and warn_on_drop and not _warned:
		push_warning("HoloVolume: %d marks past MAX_CAPACITY (%d) dropped" % [_dropped, MAX_CAPACITY])
		_warned = true
	for mmi: MultiMeshInstance3D in _placed:
		var placed: Array = _placed[mmi]
		var room := mmi.multimesh.instance_count
		if placed.size() > room:
			while room < placed.size():
				room *= 2
			mmi.multimesh.instance_count = mini(room, MAX_CAPACITY)
		var buf := PackedFloat32Array()
		buf.resize(mmi.multimesh.instance_count * 12)
		var i := 0
		for xf: Transform3D in placed:
			var b := xf.basis
			buf[i] = b.x.x
			buf[i + 1] = b.y.x
			buf[i + 2] = b.z.x
			buf[i + 3] = xf.origin.x
			buf[i + 4] = b.x.y
			buf[i + 5] = b.y.y
			buf[i + 6] = b.z.y
			buf[i + 7] = xf.origin.y
			buf[i + 8] = b.x.z
			buf[i + 9] = b.y.z
			buf[i + 10] = b.z.z
			buf[i + 11] = xf.origin.z
			i += 12
		mmi.multimesh.buffer = buf
		mmi.multimesh.visible_instance_count = placed.size()

## How many marks the last begin..end could not hold (past MAX_CAPACITY).
func dropped() -> int:
	return _dropped

## How many marks of `shape` are drawn, in any colour or in `colour` alone.
func mark_count(shape: StringName, colour: Variant = null) -> int:
	var n := 0
	for c: Color in _groups.get(shape, {}):
		if colour == null or c == colour:
			n += (_placed[_groups[shape][c]] as Array).size()
	return n

## The `index`th mark of `shape` drawn, counting through its colours in the
## order they were first drawn. For tests.
func mark_transform(shape: StringName, index: int, colour: Variant = null) -> Transform3D:
	for c: Color in _groups.get(shape, {}):
		if colour != null and c != colour:
			continue
		var placed: Array = _placed[_groups[shape][c]]
		if index < placed.size():
			return placed[index]
		index -= placed.size()
	return Transform3D()

func show_bracket(position: Vector3, size: float, shown: bool) -> void:
	_bracket_at = position
	_bracket_size = size
	_bracket.visible = shown and size > 0.0
	_place_bracket()

func bracket_shown() -> bool:
	return _bracket.visible

func bracket_position() -> Vector3:
	return _bracket_at

## Turns every mark and the bracket together: for a map placed a moment ago,
## brought round to the way the ship faces now, without placing each mark
## again. The chevron spins with the marks but never turns with the ship.
func set_turn(turn: Basis) -> void:
	_marks_root.basis = turn

func turn() -> Basis:
	return _marks_root.basis

## The ship's chevron and the edge ring, which the map shows and the status
## page doesn't.
func show_map_frame(shown: bool) -> void:
	_frame_wanted = shown
	for part in _frame_parts:
		part.visible = shown
	_show_chevron_parts()

func map_frame_shown() -> bool:
	return not _frame_parts.is_empty() and _frame_parts[0].visible

## The chevron alone: the map hides it once its centre has left the ship, and
## draws the ship as a pip instead (computer mode spec §4.2).
func show_chevron(shown: bool) -> void:
	_chevron_wanted = shown
	_show_chevron_parts()

func chevron_shown() -> bool:
	return not _chevron_parts.is_empty() and _chevron_parts[0].visible

func _show_chevron_parts() -> void:
	for part in _chevron_parts:
		part.visible = _frame_wanted and _chevron_wanted

func set_spin(angle: float) -> void:
	_spin_root.basis = Basis(Vector3.UP, angle)

func spin() -> float:
	return _spin_root.basis.get_euler().y

## A mark's place in the world, from where it was placed: through the ship's
## turn and the operator's spin. For picking marks with the mouse.
func marks_to_global(position: Vector3) -> Vector3:
	return _marks_root.global_transform * position

## The ship in miniature (spec §7.1), from `meshes` shared as they are, and
## `bounds`, everything they draw in their own frame.
func show_miniature(meshes: Array[Mesh], bounds: AABB) -> void:
	clear_miniature()
	var longest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if meshes.is_empty() or longest <= 0.0:
		return
	var model := Node3D.new()
	model.name = "Model"
	var s := MINIATURE_SIZE / longest
	model.transform = Transform3D(Basis.from_scale(Vector3.ONE * s), -bounds.get_center() * s)
	_pivot.add_child(model)
	for mesh in meshes:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = InteriorMaterials.holo()
		mi.layers = layer
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		model.add_child(mi)
	_mini_meshes = meshes.duplicate()

func clear_miniature() -> void:
	if _mini_meshes.is_empty():
		return
	for child in _pivot.get_children():
		_pivot.remove_child(child)
		child.free()
	_mini_meshes.clear()

func miniature_shown() -> bool:
	return not _mini_meshes.is_empty()

func miniature_meshes() -> Array[Mesh]:
	return _mini_meshes

func _process(delta: float) -> void:
	_time += delta
	_pivot.rotate_y(SPIN * delta)
	_place_bracket()

## Eight corner ticks round the selected mark, breathing gently in and out.
func _place_bracket() -> void:
	if not _bracket.visible:
		return
	var half := _bracket_size * 0.5 * (1.0 + 0.12 * sin(TAU * BRACKET_PULSE_HZ * _time))
	var i := 0
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_bracket.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * BRACKET_TICK),
					_bracket_at + Vector3(sx, sy, sz) * half))
				i += 1

## The MultiMesh for marks of `shape` in `colour`, made the first time.
func _group(shape: StringName, colour: Color) -> MultiMeshInstance3D:
	if not _groups.has(shape):
		_groups[shape] = {}
	var by_colour: Dictionary = _groups[shape]
	if by_colour.has(colour):
		return by_colour[colour]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _mesh_for(shape, colour)
	mm.instance_count = CAPACITY
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Marks_%s_%s" % [shape, colour.to_html(false)]
	mmi.multimesh = mm
	mmi.material_override = InteriorMaterials.glow()
	mmi.layers = layer
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marks_root.add_child(mmi)
	by_colour[colour] = mmi
	_placed[mmi] = []
	return mmi

static func _transform(shape: StringName, at: Vector3, size: float) -> Transform3D:
	match shape:
		&"stalk":
			# A centred unit stalk, scaled to the drop: never a negative
			# scale, which would turn it inside out.
			return Transform3D(Basis.from_scale(Vector3(1.0, maxf(absf(at.y), 0.0001), 1.0)),
				Vector3(at.x, at.y * 0.5, at.z))
		&"pin":
			var out := at.normalized() if at.length() > 0.0001 else Vector3.BACK
			var up := Vector3.RIGHT if absf(out.y) > 0.99 else Vector3.UP
			return Transform3D(Basis.looking_at(-out, up).scaled(Vector3.ONE * size), at)
	return Transform3D(Basis.from_scale(Vector3.ONE * size), at)

func _mesh_for(shape: StringName, colour: Color) -> ArrayMesh:
	var kit := _kit()
	var lit := InteriorKit.lit(colour, ENERGY)
	match shape:
		&"ball":
			_icosahedron(kit, lit)
		&"diamond":
			_octahedron(kit, lit)
		&"sphere":
			# Three rings round the sphere, each two-sided.
			for b in [Basis.IDENTITY, Basis(Vector3.UP, PI * 0.5), Basis(Vector3.RIGHT, PI * 0.5)]:
				_two_sided_ring(kit, b, 0.44, 0.5, InteriorKit.lit(colour, ENERGY * 0.6))
		&"pin":
			_two_sided_ring(kit, Basis.IDENTITY, 0.3, 0.5, lit)
		&"stalk":
			kit.box(_GLOW, Transform3D.IDENTITY, Vector3(0.004, 1.0, 0.004), InteriorKit.lit(colour, ENERGY * 0.5))
		&"tick":
			kit.bevel_box(_GLOW, Transform3D.IDENTITY, Vector3(1.0, 0.15, 1.0), 0.05, InteriorKit.lit(colour, ENERGY * 0.45))
	return kit.mesh(_GLOW)

## A faceted ball, 1 across: an icosahedron, flat-shaded, chunky.
static func _icosahedron(kit: InteriorKit, colour: Color) -> void:
	var g := (1.0 + sqrt(5.0)) * 0.5
	var v: Array[Vector3] = []
	for p in [Vector3(-1, g, 0), Vector3(1, g, 0), Vector3(-1, -g, 0), Vector3(1, -g, 0),
			Vector3(0, -1, g), Vector3(0, 1, g), Vector3(0, -1, -g), Vector3(0, 1, -g),
			Vector3(g, 0, -1), Vector3(g, 0, 1), Vector3(-g, 0, -1), Vector3(-g, 0, 1)]:
		v.append((p as Vector3).normalized() * 0.5)
	for f in [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4],
			[11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
			[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]:
		_facet(kit, v[f[0]], v[f[1]], v[f[2]], colour)

## A diamond, 1 tall: an octahedron.
static func _octahedron(kit: InteriorKit, colour: Color) -> void:
	var ring: Array[Vector3] = [Vector3(0.35, 0, 0), Vector3(0, 0, 0.35), Vector3(-0.35, 0, 0), Vector3(0, 0, -0.35)]
	for i in 4:
		var a := ring[i]
		var b := ring[(i + 1) % 4]
		_facet(kit, Vector3(0, 0.5, 0), b, a, colour)
		_facet(kit, Vector3(0, -0.5, 0), a, b, colour)

## One outward-facing triangle of a solid centred on the origin.
static func _facet(kit: InteriorKit, a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.dot(a + b + c) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	kit.tri(_GLOW, a, b, c, n, colour)

static func _two_sided_ring(kit: InteriorKit, b: Basis, r_in: float, r_out: float, colour: Color) -> void:
	kit.annulus(_GLOW, Transform3D(b, Vector3.ZERO), r_in, r_out, colour)
	kit.annulus(_GLOW, Transform3D(b * Basis(Vector3.UP, PI), Vector3.ZERO), r_in, r_out, colour)

## The ship: a small warm arrow at the centre, pointing forward (-z), 4 cm
## long.
static func _chevron(kit: InteriorKit) -> void:
	var warm := InteriorKit.lit(InteriorPalette.LIGHT_WARM, ENERGY)
	var tip := Vector3(0, 0, -0.02)
	for side in [-1.0, 1.0]:
		var back := Basis(Vector3.UP, side * deg_to_rad(28.0))
		kit.bevel_box(_GLOW, Transform3D(back, tip + back * Vector3(0, 0, 0.022)), Vector3(0.012, 0.018, 0.046),
			0.003, warm)

## A faint ring round the volume's edge at the ship's level, both faces.
static func _edge_ring(kit: InteriorKit) -> void:
	var dim := InteriorKit.lit(InteriorPalette.LIGHT_WARM, ENERGY * 0.3)
	kit.annulus(_GLOW, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO), RADIUS - 0.006, RADIUS, dim)
	kit.annulus(_GLOW, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), RADIUS - 0.006, RADIUS, dim)

func _kit(root: Node3D = null) -> InteriorKit:
	var kit := InteriorKit.new(root if root != null else self)
	kit.layer = layer
	kit.light_mask = layer
	return kit
