class_name InteriorDressing
extends RefCounted

## Turns an InteriorLayout into props (docs/superpowers/specs/
## 2026-09-23-ship-interior-redesign-design.md §4): works out each face's
## frame and asks InteriorProps for the piece its record names. The only
## place that decides which prop goes where -- the props themselves never see
## a grid, which is what lets other generators reuse them.

## Builds everything under one `Dressing` node inside `body`, so the builder's
## single remove_child() + free() clears it with the rest of the interior.
static func build(layout: InteriorLayout, body: StaticBody3D, canopy_material: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "Dressing"
	body.add_child(root)
	var kit := InteriorKit.new(root, body)
	for face in layout.faces():
		_dress(kit, face)
	for group in layout.canopy_groups():
		_nose(kit, group, canopy_material)
	kit.commit()
	return root

## A wall's frame, as InteriorProps expects it: origin on the wall's inner
## surface at floor level, centred along the wall; +x along the wall, +y up,
## +z into the room.
static func wall_frame(coord: Vector3i, normal: Vector3i) -> Transform3D:
	var n := Vector3(normal)
	var inward := -n
	var along := Vector3.UP.cross(inward)
	var origin := ShipGrid.cell_center(coord) + n * (ShipGrid.CELL_SIZE - InteriorBuilder.FLOOR_THICKNESS) * 0.5
	origin.y = floor_y(coord)
	return Transform3D(Basis(along, Vector3.UP, inward), origin)

## The top of a walkable cell's deck slab.
static func floor_y(coord: Vector3i) -> float:
	return ShipGrid.cell_center(coord).y - (ShipGrid.CELL_SIZE - InteriorBuilder.FLOOR_THICKNESS) * 0.5

## A face's stable 0..1 variety, for what its props show.
static func face_variety(face: Dictionary) -> float:
	return float(InteriorLayout.face_hash(face["coord"], face["normal"]) % 1000) / 1000.0

## One rounded nose over a windshield group, in a frame on the canopy plane at
## floor level: +x across the group, +y up, +z back into the room.
static func _nose(kit: InteriorKit, group: Dictionary, material: Material) -> void:
	var normal: Vector3i = group["normal"]
	var n := Vector3(normal)
	var across := Vector3.UP.cross(-n)
	var coords: Array = group["coords"]
	var lo := INF
	var hi := -INF
	for coord: Vector3i in coords:
		var c := ShipGrid.cell_center(coord).dot(across)
		lo = minf(lo, c - ShipGrid.CELL_SIZE * 0.5)
		hi = maxf(hi, c + ShipGrid.CELL_SIZE * 0.5)
	var first: Vector3i = coords[0]
	var plane := (ShipGrid.cell_center(first) + n * ShipGrid.CELL_SIZE * 0.5).dot(n)
	var origin := across * ((lo + hi) * 0.5) + n * plane + Vector3.UP * floor_y(first)
	InteriorProps.nose(kit, Transform3D(Basis(across, Vector3.UP, -n), origin), hi - lo, material)

static func _dress(kit: InteriorKit, face: Dictionary) -> void:
	var coord: Vector3i = face["coord"]
	match face["kind"]:
		InteriorLayout.Kind.CEILING:
			var centre := ShipGrid.cell_center(coord)
			centre.y = floor_y(coord) + InteriorProps.HEADROOM
			InteriorProps.ceiling_light(kit, centre)
		InteriorLayout.Kind.WALL:
			var f := wall_frame(coord, face["normal"])
			InteriorProps.wall_trim(kit, f)
			_wall_piece(kit, f, face)

static func _wall_piece(kit: InteriorKit, f: Transform3D, face: Dictionary) -> void:
	var variety := face_variety(face)
	match face["variant"]:
		InteriorLayout.WallVariant.HATCH:
			InteriorProps.hatch(kit, f)
		InteriorLayout.WallVariant.CONSOLE:
			InteriorProps.console(kit, f, variety)
		InteriorLayout.WallVariant.PORTHOLE:
			InteriorProps.porthole(kit, f)
		InteriorLayout.WallVariant.LOCKERS:
			InteriorProps.lockers(kit, f, variety)
		InteriorLayout.WallVariant.DISPLAY:
			InteriorProps.display(kit, f, variety)
		# PANEL: the trim is the whole wall.
