class_name AirlockAlcove
extends Node3D

## The hull's copy of an airlock room (docs/superpowers/specs/
## 2026-09-24-airlock-design.md §7.2): the same walls, props and hatches, in
## the same frames, built in hull space on the own-hull layer, so that looking
## back in from space -- and crossing the threshold either way -- shows the
## room you just left. Outside it is a hatch face in hull plate with a cyan
## running-light arch and the hull panel, and any face of the cell open to
## space is plated.
##
## ExteriorBuilder builds one for each airlock that can cycle, instead of the
## block's mesh and box collider. Hull-local and interior-local coordinates are
## the same numbers on storey 0; above it they differ by the storey offset
## (InteriorBuilder.storey_offset), which is taken off here.

const LAYER := ExteriorBuilder.OWN_HULL_LAYER
## Lights here light the hull layer and anything of the world's on layer 1 --
## a spacewalker's gloves.
const LIGHT_MASK := 1 | ExteriorBuilder.OWN_HULL_LAYER
## The room light, stronger out here: there is no warm interior ambient to
## help it, and the two rooms must read the same at the threshold.
const LIGHT_BOOST := 1.6
## How far the hatch face's plating stands proud of the cell face.
const PLATE_OUT := 0.06
const _HORIZONTAL: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]
const _ALL: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

var coord := Vector3i.ZERO
var hatch_normal := Vector3i.ZERO
var door_normal := Vector3i.ZERO
## As AirlockRoom's, in hull space.
var room_frame := Transform3D.IDENTITY
var outer_frame := Transform3D.IDENTITY
var outer_hatch: AirlockHatch
## Shown shut: nothing is behind it out here.
var inner_hatch: AirlockHatch
var hull_panel: AirlockPanel
var show: AirlockShow
## Every collider this alcove put on the hull body, for whoever clears it.
var colliders: Array[CollisionShape3D] = []

var _body: CollisionObject3D

## Builds the alcove for the airlock at `at` under `parent`, which must share
## `body`'s frame, with its colliders on `body`.
static func build(parent: Node3D, body: CollisionObject3D, grid: ShipGrid, catalog: BlockCatalog,
		at: Vector3i) -> AirlockAlcove:
	var alcove := AirlockAlcove.new()
	alcove.coord = at
	alcove.name = "Alcove_%d_%d_%d" % [at.x, at.y, at.z]
	alcove.hatch_normal = AirlockSite.hatch_normal(grid, at)
	alcove.door_normal = AirlockSite.door_normal(grid, catalog, at)
	parent.add_child(alcove)
	alcove._build(body, grid)
	return alcove

## A wall's frame (InteriorDressing.wall_frame's convention) in hull space.
func wall(normal: Vector3i) -> Transform3D:
	var f := InteriorDressing.wall_frame(coord, normal)
	f.origin.y -= InteriorBuilder.storey_offset(coord.y)
	return f

func _build(body: CollisionObject3D, grid: ShipGrid) -> void:
	_body = body
	var n := Vector3(hatch_normal)
	var centre := ShipGrid.cell_center(coord)
	var fl := InteriorBuilder.floor_y(coord) - InteriorBuilder.storey_offset(coord.y)
	room_frame = Transform3D(Basis(Vector3.UP.cross(-n), Vector3.UP, -n), Vector3(centre.x, fl, centre.z))
	var mid := InteriorKit.at(Vector3(0, 0, -InteriorProps.WALL_THICKNESS * 0.5))
	outer_frame = wall(hatch_normal) * mid

	var kit := InteriorKit.new(self, body)
	kit.layer = LAYER
	kit.light_mask = LIGHT_MASK
	_structure(centre, fl)

	# Inside: the room, as InteriorDressing dresses it.
	for normal in _HORIZONTAL:
		if normal == hatch_normal:
			continue
		if normal == door_normal:
			var inner_frame := wall(normal) * mid
			InteriorProps.hatch_frame(kit, inner_frame)
			inner_hatch = _hatch(inner_frame, "Inner")
			continue
		var side := normal.x * hatch_normal.x + normal.z * hatch_normal.z == 0
		InteriorProps.airlock_wall(kit, wall(normal), 0.5, side)
	InteriorProps.hatch_frame(kit, outer_frame)
	outer_hatch = _hatch(outer_frame, "Outer")
	var light := InteriorProps.airlock_ceiling(kit, room_frame * InteriorKit.at(Vector3(0, InteriorProps.AIRLOCK_CLEAR, 0)))
	light.light_energy *= LIGHT_BOOST

	# Outside: the hatch face, the hull panel, and plate on any exposed face.
	var face := outer_frame * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	_hatch_face(kit, face)
	hull_panel = AirlockPanel.new()
	hull_panel.setup(&"outer", 16, LAYER)
	hull_panel.transform = face * InteriorKit.at(Vector3(0.84, 1.2, PLATE_OUT))
	add_child(hull_panel)
	for normal in _ALL:
		if normal != hatch_normal and not grid.has_block(coord + normal):
			_plate_face(centre, normal)

	show = AirlockShow.new()
	add_child(show)
	var none: Array[Transform3D] = []
	show.setup(room_frame, none, null, LAYER, true)
	kit.commit()

## Floor, ceiling and walls: boxes and colliders like InteriorBuilder's, cut to
## the grid cell's own height, with openings for both hatches.
func _structure(centre: Vector3, fl: float) -> void:
	var cell := ShipGrid.CELL_SIZE
	var slab := InteriorBuilder.FLOOR_THICKNESS
	var bottom := centre.y - cell * 0.5
	_box(Vector3(cell, slab, cell), Vector3(centre.x, fl - slab * 0.5, centre.z), InteriorPalette.FLOOR)
	_box(Vector3(cell, slab, cell), Vector3(centre.x, fl + InteriorProps.AIRLOCK_CLEAR + slab * 0.5, centre.z),
		InteriorPalette.CEILING)
	for normal in _HORIZONTAL:
		var at := centre + Vector3(normal) * cell * 0.5
		at.y = centre.y
		var along := Vector3(absi(normal.z), 0, absi(normal.x))
		var thick := Vector3(absi(normal.x), 0, absi(normal.z)) * slab
		if normal != hatch_normal and normal != door_normal:
			_box(thick + along * cell + Vector3.UP * cell, at, InteriorPalette.WALL)
			continue
		var jamb := (cell - InteriorProps.DOOR_WIDTH) * 0.5
		for s in [-1.0, 1.0]:
			_box(thick + along * jamb + Vector3.UP * cell, at + along * s * (InteriorProps.DOOR_WIDTH + jamb) * 0.5,
				InteriorPalette.WALL)
		var top := bottom + cell
		var lintel := top - (fl + InteriorProps.HATCH_HEIGHT)
		_box(thick + along * InteriorProps.DOOR_WIDTH + Vector3.UP * lintel,
			Vector3(at.x, top - lintel * 0.5, at.z), InteriorPalette.WALL)

func _box(size: Vector3, at: Vector3, colour: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.layers = LAYER
	mi.material_override = InteriorMaterials.flat(colour)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var shape := BoxShape3D.new()
	shape.size = size
	var c := CollisionShape3D.new()
	c.shape = shape
	c.position = at
	_body.add_child(c)
	colliders.append(c)

func _hatch(f: Transform3D, hatch_name: String) -> AirlockHatch:
	var hatch := AirlockHatch.new()
	hatch.name = hatch_name + "Hatch"
	hatch.render_layer = LAYER
	hatch.setup(InteriorProps.DOOR_WIDTH, InteriorProps.HATCH_HEIGHT, _body, f, false)
	add_child(hatch)
	colliders.append(hatch.collider)
	return hatch

## The hatch face from outside, in `f` (on the face at floor level, +z out into
## space): plate round the opening in the hull's livery, two panel seams, and
## the cyan running-light arch over the hatch.
func _hatch_face(kit: InteriorKit, f: Transform3D) -> void:
	var half := ShipGrid.CELL_SIZE * 0.5
	var w := InteriorProps.DOOR_WIDTH * 0.5
	var h := InteriorProps.HATCH_HEIGHT
	var low := -InteriorBuilder.FLOOR_THICKNESS * 0.5
	var high := ShipGrid.CELL_SIZE + low
	var z := PLATE_OUT
	var out := (f.basis * Vector3.BACK).normalized()
	for piece: Array in [[-half, -w, low, high], [w, half, low, high], [-w, w, h, high]]:
		_plate(f, Vector3(piece[0], piece[2], z), Vector3(piece[1], piece[2], z), Vector3(piece[1], piece[3], z),
			Vector3(piece[0], piece[3], z), out)
	for y in [0.6, 1.3]:
		for s in [-1.0, 1.0]:
			kit.box(InteriorKit.Batch.SOLID, f * InteriorKit.at(Vector3(s * (half + w) * 0.5, y, z + 0.005)),
				Vector3(half - w - 0.04, 0.025, 0.01), InteriorKit.solid(HullPalette.PANEL_LINE))
	var arch := InteriorKit.lit(HullPalette.RUNNING_LIGHT, 2.5)
	var arch_w := InteriorProps.DOOR_WIDTH + 0.44
	kit.box(InteriorKit.Batch.GLOW, f * InteriorKit.at(Vector3(0, h + 0.07, 0.17)), Vector3(arch_w, 0.04, 0.03), arch)
	for s in [-1.0, 1.0]:
		kit.box(InteriorKit.Batch.GLOW, f * InteriorKit.at(Vector3(s * arch_w * 0.5, h - 0.1, 0.17)),
			Vector3(0.04, 0.36, 0.03), arch)

## One exposed face of the cell, plated in the hull's livery.
func _plate_face(centre: Vector3, normal: Vector3i) -> void:
	var n := Vector3(normal)
	var u := Vector3(absi(normal.y) + absi(normal.z), absi(normal.x), 0).normalized()
	if normal.z != 0:
		u = Vector3(1, 0, 0)
	var v := n.cross(u).normalized()
	var half := ShipGrid.CELL_SIZE * 0.5
	var o := centre + n * (half + 0.002)
	_plate(Transform3D.IDENTITY, o - u * half - v * half, o + u * half - v * half, o + u * half + v * half,
		o - u * half + v * half, n)

## A quad in the hull's livery material, facing `normal`, as its own mesh.
func _plate(f: Transform3D, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri in [[f * a, f * b, f * c], [f * a, f * c, f * d]]:
		var p0: Vector3 = tri[0]
		var p1: Vector3 = tri[1]
		var p2: Vector3 = tri[2]
		# Godot's front face is clockwise seen from the front (InteriorKit.tri).
		if (p1 - p0).cross(p2 - p0).dot(normal) > 0.0:
			var t := p1
			p1 = p2
			p2 = t
		for p in [p0, p1, p2]:
			st.set_normal(normal)
			st.add_vertex(p)
	var mi := MeshInstance3D.new()
	mi.name = "Plate"
	mi.mesh = st.commit()
	mi.material_override = Ship.HULL_LIVERY_MATERIAL
	mi.layers = LAYER
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
