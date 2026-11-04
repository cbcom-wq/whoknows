extends GutTest

## Your own hull through your windows (the owner, 2026-11-03: from the
## Warden's bridge "I see just a floating turret, beneath it should be the rest
## of the ship"). The canopy camera stands inside the hull, so the skin is
## split: the pieces that wrap the cabin -- in a walkable cell, a canopy cell
## or a pod's, or facing into one -- stay on the own layer alone, which the
## windows leave out; the rest is on ExteriorBuilder.SEEN_INSIDE_LAYER too,
## which every window shows. Checked on every library ship.

var _library: ShipLibrary
var _cat: BlockCatalog

func before_all():
	_library = ShipLibrary.load_from_dir()
	_cat = BlockCatalog.load_from_dir("res://data/blocks")

func _built(id: StringName) -> ExteriorBuilder:
	var body := RigidBody3D.new()
	add_child_autofree(body)
	var builder := ExteriorBuilder.new()
	body.add_child(builder)
	builder.body_path = builder.get_path_to(body)
	builder.bind(_library.grid(id), _cat)
	builder.rebuild()
	return builder

static func _vertices(kit: Node) -> PackedVector3Array:
	var out := PackedVector3Array()
	for mi: MeshInstance3D in kit.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			out.append_array(mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX])
	return out

## The cell a hull-space point is strictly inside (1 cm in from its faces),
## or none.
static func _inside_cell(v: Vector3) -> Variant:
	var coord := Vector3i((v / ShipGrid.CELL_SIZE).round())
	var d := (v - ShipGrid.cell_center(coord)).abs()
	var inner := ShipGrid.CELL_SIZE * 0.5 - 0.01
	if d.x < inner and d.y < inner and d.z < inner:
		return coord
	return null

func test_the_skin_beyond_the_cabin_is_seen_from_inside():
	for id in _library.ids():
		var skin := _built(id).skin()
		var hull := skin.get_node("Hull")
		var meshes := hull.find_children("*", "GeometryInstance3D", true, false)
		assert_gt(meshes.size(), 0, "%s has a skin" % id)
		for g: GeometryInstance3D in meshes:
			assert_eq(g.layers, ExteriorBuilder.OWN_HULL_LAYER | ExteriorBuilder.SEEN_INSIDE_LAYER,
				"%s: %s is seen from inside" % [id, g.name])

func test_what_wraps_the_cabin_and_the_windows_stay_on_the_own_layer():
	for id in _library.ids():
		var skin := _built(id).skin()
		for kit in ["Cabin", "Windows"]:
			for g: GeometryInstance3D in skin.get_node(kit).find_children("*", "GeometryInstance3D", true, false):
				assert_eq(g.layers, ExteriorBuilder.OWN_HULL_LAYER, "%s: %s/%s" % [id, kit, g.name])

func test_nothing_seen_from_inside_is_within_the_cabin_or_its_glass():
	for id in _library.ids():
		var builder := _built(id)
		var cabin := builder.layout().cabin
		assert_gt(cabin.size(), 0, "%s has a cabin" % id)
		var within := {}
		for v in _vertices(builder.skin().get_node("Hull")):
			var c: Variant = _inside_cell(v)
			if c != null and cabin.has(c):
				within[c] = true
		assert_eq(within.keys(), [], "%s: pieces seen from inside lie in these cabin cells" % id)

## The pieces in front of the Warden's bridge glass -- the slope under it, the
## brow over it and the cheeks beside it -- would block the view out.
func test_the_warden_s_bridge_glass_is_left_clear():
	var builder := _built(&"warden")
	var cabin := builder.layout().cabin
	var hidden := 0
	for v in _vertices(builder.skin().get_node("Cabin")):
		var c: Variant = _inside_cell(v)
		if c != null and cabin.has(c):
			hidden += 1
	assert_gt(hidden, 0, "the canopy row's pieces are on the own layer alone")

## What the Warden's heavy turret stands on: the bow ahead of the bridge.
func test_the_warden_s_bow_is_seen_from_the_bridge():
	var builder := _built(&"warden")
	var under := Vector3i(0, -1, -9)
	assert_true(_library.grid(&"warden").get_block(Vector3i(0, 0, -9)).block_id == &"turret_heavy",
		"the heavy turret is where this test thinks")
	var seen := 0
	for v in _vertices(builder.skin().get_node("Hull")):
		if _within(v, under, 0.1):
			seen += 1
	assert_gt(seen, 0, "the deck under the turret is drawn through the windows")

static func _within(v: Vector3, coord: Vector3i, margin: float) -> bool:
	var d := (v - ShipGrid.cell_center(coord)).abs()
	var r := ShipGrid.CELL_SIZE * 0.5 + margin
	return d.x <= r and d.y <= r and d.z <= r
