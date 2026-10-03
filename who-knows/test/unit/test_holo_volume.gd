extends GutTest

## The holo over the bridge computer's table (bridge computer spec §5, §7):
## where a contact sits in it, how marks are drawn, and the miniature.

var _holo: HoloVolume

func before_each():
	_holo = HoloVolume.new()
	_holo.setup()
	add_child_autofree(_holo)

func _mark(shape: StringName, at: Vector3, size: float, colour := InteriorPalette.SKY) -> Dictionary:
	return {"shape": shape, "colour": colour, "position": at, "size": size}

func test_the_range_fills_the_volume_s_radius():
	var p := HoloVolume.place(Vector3(0, 0, -1000), 2000.0)
	assert_almost_eq(p["position"], Vector3(0, 0, -0.25), Vector3.ONE * 0.0001)
	assert_false(p["pinned"])
	var q := HoloVolume.place(Vector3(3000, 0, 0), 10000.0)
	assert_almost_eq(q["position"], Vector3(0.15, 0, 0), Vector3.ONE * 0.0001)

func test_height_uses_the_same_scale():
	var p := HoloVolume.place(Vector3(0, 1000, -1000), 10000.0)
	assert_almost_eq(p["position"], Vector3(0, 0.05, -0.05), Vector3.ONE * 0.0001)

func test_beyond_the_range_a_contact_is_pinned_to_the_edge_in_its_own_direction():
	var p := HoloVolume.place(Vector3(0, 0, -45000), 30000.0)
	assert_true(p["pinned"])
	assert_almost_eq(p["position"], Vector3(0, 0, -HoloVolume.RADIUS), Vector3.ONE * 0.0001)
	var q := HoloVolume.place(Vector3(3000, 3000, 0), 2000.0)
	assert_true(q["pinned"])
	var pos: Vector3 = q["position"]
	assert_almost_eq(pos.y, HoloVolume.HALF_HEIGHT, 0.0001, "pinned to the top")
	assert_almost_eq(pos.x, pos.y, 0.0001, "still the same direction")

func test_marks_are_drawn_by_shape_and_colour():
	_holo.show_marks([
		_mark(&"ball", Vector3(0.1, 0, 0), 0.01),
		_mark(&"ball", Vector3(-0.1, 0, 0), 0.02, InteriorPalette.AMBER),
		_mark(&"diamond", Vector3(0, 0, -0.2), 0.012, InteriorPalette.QUANTUM),
	])
	assert_eq(_holo.mark_count(&"ball"), 2)
	assert_eq(_holo.mark_count(&"ball", InteriorPalette.SKY), 1)
	assert_eq(_holo.mark_count(&"ball", InteriorPalette.AMBER), 1)
	assert_eq(_holo.mark_count(&"diamond"), 1)
	assert_eq(_holo.mark_count(&"sphere"), 0)
	var groups := _holo.find_children("Marks_*", "MultiMeshInstance3D", true, false)
	assert_eq(groups.size(), 3, "one MultiMesh per shape and colour")
	_holo.show_marks([])
	assert_eq(_holo.mark_count(&"ball"), 0, "an empty list clears them")

func test_more_marks_than_it_holds_are_cut_off_not_crashed():
	var marks := []
	for i in HoloVolume.CAPACITY + 10:
		marks.append(_mark(&"ball", Vector3.ZERO, 0.006))
	_holo.show_marks(marks)
	assert_eq(_holo.mark_count(&"ball"), HoloVolume.CAPACITY)

func test_a_mark_is_scaled_to_its_size_where_it_is_put():
	_holo.show_marks([_mark(&"ball", Vector3(0.1, 0.05, -0.2), 0.03)])
	var xf := _holo.mark_transform(&"ball", 0)
	assert_almost_eq(xf.origin, Vector3(0.1, 0.05, -0.2), Vector3.ONE * 0.0001)
	assert_almost_eq(xf.basis.get_scale(), Vector3.ONE * 0.03, Vector3.ONE * 0.0001)

func test_a_stalk_runs_from_its_mark_to_the_ship_s_level():
	_holo.show_marks([_mark(&"stalk", Vector3(0.1, -0.2, 0.05), 0.0, InteriorPalette.LIGHT_WARM)])
	var xf := _holo.mark_transform(&"stalk", 0)
	assert_almost_eq(xf.origin, Vector3(0.1, -0.1, 0.05), Vector3.ONE * 0.0001, "centred halfway")
	assert_almost_eq(xf.basis.get_scale().y, 0.2, 0.0001, "as tall as the drop, never negative")

func test_a_pin_faces_out_of_the_volume():
	_holo.show_marks([_mark(&"pin", Vector3(0, 0, -HoloVolume.RADIUS), 0.012)])
	var xf := _holo.mark_transform(&"pin", 0)
	assert_almost_eq(xf.basis.z.normalized(), Vector3(0, 0, -1), Vector3.ONE * 0.0001, "its face turned outward")

func test_the_bracket_shows_and_hides():
	_holo.show_bracket(Vector3(0.1, 0, 0), 0.03, true)
	assert_true(_holo.bracket_shown())
	assert_almost_eq(_holo.bracket_position(), Vector3(0.1, 0, 0), Vector3.ONE * 0.0001)
	_holo.show_bracket(Vector3.ZERO, 0.0, false)
	assert_false(_holo.bracket_shown())

func test_the_map_frame_shows_and_hides():
	_holo.show_map_frame(false)
	assert_false(_holo.map_frame_shown())
	_holo.show_map_frame(true)
	assert_true(_holo.map_frame_shown())

func test_everything_is_on_the_interior_layer_and_nothing_collides():
	_holo.show_marks([_mark(&"ball", Vector3.ZERO, 0.01)])
	for n in _holo.find_children("*", "GeometryInstance3D", true, false):
		assert_eq((n as GeometryInstance3D).layers, InteriorKit.LAYER, str(n.name))
	assert_eq(_holo.find_children("*", "CollisionObject3D", true, false).size(), 0, "you can put your hand in it")

## Spec §7.1: the miniature shares the hull's meshes rather than copying them,
## and is sized so its longest side is 0.8 m.
func test_the_miniature_shares_the_meshes_it_is_given():
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1, 1, 9)
	var meshes: Array[Mesh] = [mesh]
	var bounds := AABB(Vector3(-0.5, -0.5, -4.5), Vector3(1, 1, 9))
	_holo.show_miniature(meshes, bounds)
	assert_true(_holo.miniature_shown())
	assert_eq(_holo.miniature_meshes()[0], mesh, "the same resource, not a copy")
	var drawn := _holo.find_children("*", "MeshInstance3D", true, false).filter(func(n): return n.mesh == mesh)
	assert_eq(drawn.size(), 1)
	var inst: MeshInstance3D = drawn[0]
	assert_eq(inst.material_override, InteriorMaterials.holo())
	assert_eq(inst.layers, InteriorKit.LAYER)
	var longest: float = bounds.size.z * (inst.get_parent() as Node3D).scale.z
	assert_almost_eq(longest, HoloVolume.MINIATURE_SIZE, 0.001)
	_holo._process(1.0)
	assert_almost_eq((inst.get_parent().get_parent() as Node3D).rotation.y, HoloVolume.SPIN, 0.0001, "it turns")
	_holo.clear_miniature()
	assert_false(_holo.miniature_shown())
	assert_eq(_holo.find_children("*", "MeshInstance3D", true, false).filter(func(n): return n.mesh == mesh).size(), 0)

## Computer mode spec §4.4: the operator spins the holo's contents about its
## upright, the ship's turn and all; the table and the ring stay put.
func test_spin_turns_the_marks_about_the_holo_s_upright():
	_holo.show_marks([_mark(&"ball", Vector3(0, 0, -0.2), 0.02)])
	_holo.set_spin(PI * 0.5)
	assert_almost_eq(_holo.spin(), PI * 0.5, 0.000001)
	var expected := _holo.global_transform * (Basis(Vector3.UP, PI * 0.5) * Vector3(0, 0, -0.2))
	assert_almost_eq(_holo.marks_to_global(Vector3(0, 0, -0.2)), expected, Vector3.ONE * 0.0001)

func test_spin_comes_on_top_of_the_ship_s_turn():
	_holo.set_turn(Basis(Vector3.UP, 0.3))
	_holo.set_spin(0.2)
	var expected := _holo.global_transform * (Basis(Vector3.UP, 0.5) * Vector3(0, 0, -0.2))
	assert_almost_eq(_holo.marks_to_global(Vector3(0, 0, -0.2)), expected, Vector3.ONE * 0.0001)

func test_the_chevron_hides_while_the_ring_stays():
	_holo.show_map_frame(true)
	_holo.show_chevron(false)
	assert_false(_holo.chevron_shown())
	assert_true(_holo.map_frame_shown())
	_holo.show_map_frame(false)
	_holo.show_chevron(true)
	assert_false(_holo.chevron_shown(), "the frame hidden hides it too")

func test_the_ring_stays_put_and_the_chevron_spins():
	var map_frames = _holo.find_children("MapFrame", "MeshInstance3D", true, false)
	var chevrons = _holo.find_children("Chevron", "MeshInstance3D", true, false)
	for part in map_frames:
		assert_eq(part.get_parent(), _holo, "every MapFrame part's parent is the HoloVolume itself")
	var spin_node = _holo.get_node("Spin")
	for part in chevrons:
		assert_eq(part.get_parent(), spin_node, "every Chevron part's parent is the Spin node")

func test_round_trip_chevron_visibility():
	_holo.show_chevron(false)
	_holo.show_map_frame(false)
	_holo.show_map_frame(true)
	assert_false(_holo.chevron_shown(), "chevron stays hidden through map frame on/off cycle")

## inside() is place()'s pin test for a point already in the holo's metres: the
## map's ticks use it instead of a Dictionary each.
func test_inside_is_what_place_leaves_unpinned():
	for rel in [Vector3(0, 0, -900), Vector3(1999, 0, 0), Vector3(2001, 0, 0), Vector3(1500, 0, 1500),
			Vector3(0, 1199, 0), Vector3(0, 1201, 0), Vector3(-800, -900, 300)]:
		var placed := HoloVolume.place(rel, 2000.0)
		assert_eq(HoloVolume.inside(rel * (HoloVolume.RADIUS / 2000.0)), not placed["pinned"], "%s" % rel)

## add_ticks draws what add_mark would, a tick at a time.
func test_add_ticks_draws_what_add_mark_would():
	var at := PackedVector3Array([Vector3(0.1, 0, 0), Vector3(0, 0.05, -0.2)])
	_holo.begin_marks()
	_holo.add_ticks(InteriorPalette.HOLO_DIM, at, 0.01)
	_holo.end_marks()
	var batched := [_holo.mark_transform(&"tick", 0), _holo.mark_transform(&"tick", 1)]
	_holo.begin_marks()
	for p in at:
		_holo.add_mark(&"tick", InteriorPalette.HOLO_DIM, p, 0.01)
	_holo.end_marks()
	assert_eq(_holo.mark_count(&"tick", InteriorPalette.HOLO_DIM), 2)
	assert_eq(batched, [_holo.mark_transform(&"tick", 0), _holo.mark_transform(&"tick", 1)])
