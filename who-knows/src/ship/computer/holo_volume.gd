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
## Marks of one shape and colour it can draw at once.
const CAPACITY := 512
## The miniature's longest side, metres (spec §7.1), and how fast it turns.
const MINIATURE_SIZE := 0.8
const SPIN := deg_to_rad(10.0)
## How strongly the holo glows, against the glow batch's other pieces.
const ENERGY := 1.4
const BRACKET_PULSE_HZ := 1.5
## A faceted ball (a rock), a diamond (a ping), three rings round a sphere (a
## region), a hollow ring facing out (a pin on the edge), a stalk down or up to
## the ship's level, and the tick at its foot. Each is unit-sized: a mark's
## size scales it.
const SHAPES: Array[StringName] = [&"ball", &"diamond", &"sphere", &"pin", &"stalk", &"tick"]
const _GLOW := InteriorKit.Batch.GLOW

var layer := InteriorKit.LAYER
var _groups: Dictionary = {}   # "shape|colour" -> MultiMeshInstance3D, in the order first drawn
## What each group was last given, kept here too: the renderer owns a
## MultiMesh's transforms, and a headless run's keeps none to read back.
var _placed: Dictionary = {}   # "shape|colour" -> Array[Transform3D]
var _frame_parts: Array[MeshInstance3D] = []
var _bracket: MeshInstance3D
var _bracket_at := Vector3.ZERO
var _bracket_size := 0.0
var _pivot: Node3D
var _mini_meshes: Array[MultiMesh] = []
var _time := 0.0

## Builds the chevron, the edge ring and the bracket. Call once, before it
## enters the tree.
func setup(render_layer := InteriorKit.LAYER) -> void:
	layer = render_layer
	var kit := _kit()
	_chevron(kit)
	_edge_ring(kit)
	_frame_parts = kit.commit()
	for part in _frame_parts:
		part.name = "MapFrame"
	var bracket_kit := _kit()
	var amber := InteriorKit.lit(InteriorPalette.AMBER, ENERGY)
	for sx in [-0.5, 0.5]:
		for sy in [-0.5, 0.5]:
			for sz in [-0.5, 0.5]:
				bracket_kit.bevel_box(_GLOW, InteriorKit.at(Vector3(sx, sy, sz)), Vector3.ONE * 0.18, 0.05, amber)
	_bracket = bracket_kit.commit()[0]
	_bracket.name = "Bracket"
	_bracket.visible = false
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

## Draws `marks`, each {shape, colour, position, size}; a shape and colour
## with none this time is emptied. For &"stalk", `position` is the top of the
## stalk, and it runs from there to the ship's level.
func show_marks(marks: Array) -> void:
	var by_key := {}
	for m in marks:
		var key := _key(m["shape"], m["colour"])
		if not by_key.has(key):
			by_key[key] = []
		by_key[key].append(m)
	for key: String in by_key:
		if not _groups.has(key):
			var first: Dictionary = by_key[key][0]
			_groups[key] = _group(first["shape"], first["colour"])
	for key: String in _groups:
		var list: Array = by_key.get(key, [])
		var mm: MultiMesh = _groups[key].multimesh
		var n := mini(list.size(), CAPACITY)
		var placed: Array[Transform3D] = []
		for i in n:
			var xf := _transform(list[i])
			mm.set_instance_transform(i, xf)
			placed.append(xf)
		mm.visible_instance_count = n
		_placed[key] = placed

## How many marks of `shape` are drawn, in any colour or in `colour` alone.
func mark_count(shape: StringName, colour: Variant = null) -> int:
	var n := 0
	for key: String in _placed:
		if _matches(key, shape, colour):
			n += (_placed[key] as Array).size()
	return n

## The `index`th mark of `shape` drawn, counting through its colours in the
## order they were first drawn. For tests.
func mark_transform(shape: StringName, index: int, colour: Variant = null) -> Transform3D:
	for key: String in _placed:
		if not _matches(key, shape, colour):
			continue
		var placed: Array = _placed[key]
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

## The ship's chevron and the edge ring, which the map shows and the status
## page doesn't.
func show_map_frame(shown: bool) -> void:
	for part in _frame_parts:
		part.visible = shown

func map_frame_shown() -> bool:
	return not _frame_parts.is_empty() and _frame_parts[0].visible

## The ship in miniature (spec §7.1), from `meshes` shared as they are, and
## `bounds`, everything they draw in their own frame.
func show_miniature(meshes: Array[MultiMesh], bounds: AABB) -> void:
	clear_miniature()
	var longest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if meshes.is_empty() or longest <= 0.0:
		return
	var model := Node3D.new()
	model.name = "Model"
	var s := MINIATURE_SIZE / longest
	model.transform = Transform3D(Basis.from_scale(Vector3.ONE * s), -bounds.get_center() * s)
	_pivot.add_child(model)
	for mm in meshes:
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = InteriorMaterials.holo()
		mmi.layers = layer
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		model.add_child(mmi)
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

func miniature_meshes() -> Array[MultiMesh]:
	return _mini_meshes

func _process(delta: float) -> void:
	_time += delta
	_pivot.rotate_y(SPIN * delta)
	_place_bracket()

func _place_bracket() -> void:
	if _bracket.visible:
		var pulse := 1.0 + 0.1 * sin(TAU * BRACKET_PULSE_HZ * _time)
		_bracket.transform = Transform3D(Basis.from_scale(Vector3.ONE * _bracket_size * pulse), _bracket_at)

static func _key(shape: StringName, colour: Color) -> String:
	return "%s|%s" % [shape, colour.to_html()]

static func _matches(key: String, shape: StringName, colour: Variant) -> bool:
	if colour == null:
		return key.begins_with("%s|" % shape)
	return key == _key(shape, colour)

func _group(shape: StringName, colour: Color) -> MultiMeshInstance3D:
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
	add_child(mmi)
	return mmi

func _transform(m: Dictionary) -> Transform3D:
	var at: Vector3 = m["position"]
	var size: float = m["size"]
	match m["shape"]:
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
			kit.box(_GLOW, Transform3D.IDENTITY, Vector3(0.003, 1.0, 0.003), InteriorKit.lit(colour, ENERGY * 0.45))
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

## The ship: a small warm arrow at the centre, pointing forward (-z).
static func _chevron(kit: InteriorKit) -> void:
	var warm := InteriorKit.lit(InteriorPalette.LIGHT_WARM, ENERGY)
	var tip := Vector3(0, 0, -0.012)
	for side in [-1.0, 1.0]:
		var back := Basis(Vector3.UP, side * deg_to_rad(30.0))
		kit.bevel_box(_GLOW, Transform3D(back, tip + back * Vector3(0, 0, 0.015)), Vector3(0.006, 0.006, 0.03),
			0.002, warm)

## A faint ring round the volume's edge at the ship's level, both faces.
static func _edge_ring(kit: InteriorKit) -> void:
	var dim := InteriorKit.lit(InteriorPalette.LIGHT_WARM, ENERGY * 0.3)
	kit.annulus(_GLOW, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO), RADIUS - 0.006, RADIUS, dim)
	kit.annulus(_GLOW, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), RADIUS - 0.006, RADIUS, dim)

func _kit() -> InteriorKit:
	var kit := InteriorKit.new(self)
	kit.layer = layer
	kit.light_mask = layer
	return kit
