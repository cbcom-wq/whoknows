extends GutTest

## The place field in the real flight scene (desert world phase 3): the oasis on
## p3 loads near you and frees far off, stands on the floor, holds its pool's
## water at its level, and follows the floating origin as one node.
##
## The starter is held (frozen) over the oasis rather than landed on the pad:
## nothing here is about touching down, only about where the place is.

var _root: Node
var _ship: Ship
var _universe: Universe
var _body: SystemBody
var _place: PlaceDesign
var _terrain: WorldTerrain

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_universe = _root.get_node("Universe")
	await wait_physics_frames(3)
	var system: SystemRecipe = _root.system
	_place = system.places()[0]
	_body = system.body(_place.body_id)
	_terrain = _root.star_system.whereabouts.terrain_of(_body)

## Holds the starter `height` m over the ground `east`, `north` m from the place.
func _hold_over(east: float, north: float, height: float) -> void:
	var d := _place.local_dir(east, north, _body.radius)
	var at := _body.point.plus(d * (_body.radius + _terrain.height_at(d) + height))
	_ship.exterior.freeze = true
	_ship.exterior.linear_velocity = Vector3.ZERO
	_ship.exterior.global_position = _universe.to_engine(at)
	await wait_physics_frames(3)

func _oasis() -> Node3D:
	return _root.places.loaded(&"oasis")

func test_the_oasis_loads_near_and_frees_far():
	await _hold_over(0, 0, 60.0)
	assert_not_null(_oasis(), "loaded at the place")
	assert_eq(_root.places.get_child_count(), 1, "one place")
	assert_eq(_oasis().name, &"Place_oasis")
	await _hold_over(7000, 0, 200.0)
	assert_not_null(_oasis(), "still there 7 km off")
	await _hold_over(11000, 0, 200.0)
	assert_null(_oasis(), "freed at 11 km")
	await wait_physics_frames(2)
	assert_eq(_root.places.get_child_count(), 0, "and gone from the tree")
	await _hold_over(0, 0, 60.0)
	assert_not_null(_oasis(), "back when you are")

func test_the_place_sits_on_the_ground():
	await _hold_over(0, 0, 60.0)
	var here := _universe.to_universe(_oasis().global_position).minus(_body.point)
	var floor_h := PlaceField.floor_height(_terrain, _place.dir())
	assert_almost_eq(here.length() - _body.radius, floor_h, 0.02, "on the oasis floor")
	assert_almost_eq(here.normalized().dot(_place.dir()), 1.0, 1e-6, "at the place")
	assert_true(_oasis().global_basis.is_equal_approx(_place.frame()), "in the place's frame")
	assert_lt(_terrain.height_at(_place.dir()), floor_h - 1.0, "the pool is dug under the floor")

func test_the_water_lies_at_its_level():
	await _hold_over(0, 0, 60.0)
	var mesh := _oasis().find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var centre := _oasis().to_local(mesh.global_transform * mesh.get_aabb().get_center())
	assert_almost_eq(centre.y, -0.3, 0.01, "0.3 m under the floor")
	assert_eq(mesh.layers, 1, "drawn on the world's layer")
	assert_almost_eq(mesh.get_aabb().size.y, 0.0, 0.001, "flat")
	var radius := mesh.get_aabb().size.x * 0.5
	assert_between(radius, 14.0, 18.5, "about the pool's size")

func test_place_follows_a_shift():
	await _hold_over(0, 0, 60.0)
	var node := _oasis()
	var before := _universe.to_universe(node.global_position)
	var shift := Vector3(2000, 1000, -3000)
	_universe.shift(shift)
	assert_almost_eq(node.global_position, _universe.to_engine(before), Vector3.ONE * 0.001, "moved with the origin")
	var after := _universe.to_universe(node.global_position)
	assert_true(after.is_equal_approx(before), "the same point in the universe")
	assert_true(node.is_in_group(Universe.EXTERIOR_SPACE))

func test_only_the_place_is_a_member():
	await _hold_over(0, 0, 60.0)
	var count := 0
	for n in _oasis().find_children("*", "", true, false):
		count += 1
		assert_false(n.is_in_group(Universe.EXTERIOR_SPACE), "%s" % n.name)
		assert_false(n.is_in_group(Universe.HOLDS_SHIFT), "%s" % n.name)
	assert_gt(count, 2, "it has pieces")

func test_on_ground_is_in_the_places_frame_and_on_the_terrain():
	var pad := PlaceField.on_ground(_place, _terrain, -80.0, -40.0)
	var d := _place.local_dir(-80.0, -40.0, _body.radius)
	var from_centre := _place.frame() * pad + PlaceField.origin_of(_place, _terrain)
	assert_almost_eq(from_centre.length() - _body.radius, _terrain.height_at(d), 0.01)
	assert_almost_eq(pad.x, -80.0, 0.1)
	assert_almost_eq(pad.z, 40.0, 0.1)
	# The pad stands 0.15 m over its own level; the floor rolls, so that level is the
	# pad stamp's, not the bank's. The world curves about 0.18 m away at 90 m.
	var pad_over_bank := 0.15
	for s in _terrain.stamps:
		if s.id == &"pad":
			pad_over_bank += s.level
		elif s.id == &"pool_bank":
			pad_over_bank -= s.level
	assert_almost_eq(pad.y, pad_over_bank - 0.18, 0.2, "the pad, over the pool's bank less the curve at 90 m")

func test_ground_fn_is_on_ground_to_the_bit():
	var fast := PlaceField.ground_fn(_place, _terrain)
	for p: Vector2 in [Vector2.ZERO, Vector2(-80, -40), Vector2(46, -28), Vector2(414, 188), Vector2(-19.5, 45.6)]:
		assert_eq(fast.call(p.x, p.y), PlaceField.on_ground(_place, _terrain, p.x, p.y), "at %s" % p)

## The layout points of `key` in oasis.json: arrays of [east, north].
func _layout_points(key: String) -> Array:
	return _place.layout().get(key, [])

func test_palms_stand_on_the_ground():
	await _hold_over(0, 0, 60.0)
	var palms := _oasis().get_node("Palms") as StaticBody3D
	var points := _layout_points("palms")
	assert_eq(points.size(), 7, "seven palms")
	assert_eq(palms.get_child_count(), points.size(), "a trunk each")
	for i in points.size():
		var c := palms.get_child(i) as CollisionShape3D
		var shape := c.shape as CapsuleShape3D
		var foot := c.transform.origin - c.transform.basis.y * shape.height * 0.5
		var want := PlaceField.on_ground(_place, _terrain, float(points[i][0]), float(points[i][1]))
		assert_lt(foot.distance_to(want), 0.05, "palm %d's foot is on the ground" % i)

func test_palm_trunks_are_solid():
	await _hold_over(0, 0, 60.0)
	var palms := _oasis().get_node("Palms") as StaticBody3D
	assert_eq(palms.collision_layer, BodyProxy.LAYER, "on the terrain's layer")
	var at: Array = _layout_points("palms")[3]
	var foot := PlaceField.on_ground(_place, _terrain, float(at[0]), float(at[1]))
	var from := _oasis().to_global(foot + Vector3(-4.0, 1.2, 0.0))
	var to := _oasis().to_global(foot + Vector3(4.0, 1.2, 0.0))
	var query := PhysicsRayQueryParameters3D.create(from, to, BodyProxy.LAYER)
	var hit := _oasis().get_world_3d().direct_space_state.intersect_ray(query)
	assert_false(hit.is_empty(), "a ray at chest height hits something")
	if not hit.is_empty():
		assert_eq(hit["collider"], palms, "the palms")
		assert_lt(_oasis().to_local(hit["position"]).distance_to(foot + Vector3(0, 1.2, 0)), 0.7, "at the trunk")

func test_the_green_ring_and_the_village_pieces_are_one_kit_and_one_multimesh():
	await _hold_over(0, 0, 60.0)
	var meshes := _oasis().find_children("*", "MultiMeshInstance3D", true, false)
	assert_eq(meshes.size(), 1, "one MultiMesh for all the grass")
	var village := _oasis().get_node("Village")
	var solids := village.get_children().filter(func(n): return n is MeshInstance3D and n.name == &"DressingSolid")
	assert_eq(solids.size(), 1, "one kit's solids")

func test_the_grass_stays_out_of_the_water():
	await _hold_over(0, 0, 60.0)
	var ring := _oasis().find_children("*", "MultiMeshInstance3D", true, false)[0] as MultiMeshInstance3D
	var pool := _oasis().find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var edge := pool.get_aabb().size.x * 0.5
	var tufts: PackedVector3Array = ring.get_meta(&"tufts")
	assert_gt(tufts.size(), 500)
	for i in tufts.size():
		var at := tufts[i]
		assert_gt(Vector2(at.x, at.z).length(), edge - PlaceField.SHORE_LAP + 1.5 - 0.01, "tuft %d" % i)

func test_no_grass_grows_in_a_garden_bed():
	await _hold_over(0, 0, 60.0)
	var ring := _oasis().find_children("*", "MultiMeshInstance3D", true, false)[0] as MultiMeshInstance3D
	var tufts: PackedVector3Array = ring.get_meta(&"tufts")
	for g: Dictionary in _place.layout()["gardens"]:
		var at := PlaceField.on_ground(_place, _terrain, float(g["at"][0]), float(g["at"][1]))
		var half := Vector2(float(g["size"][0]), float(g["size"][1])) * 0.5
		for t in tufts:
			assert_false(absf(t.x - at.x) < half.x and absf(t.z - at.z) < half.y, "a tuft in the bed at %s" % [g["at"]])

# --- the village outside: shells, the wall, the tracks, the outcrop (Task 9) ---

## The ground's height at layout point `east`, `north`, in the place's frame.
func _ground_y(east: float, north: float) -> float:
	return PlaceField.on_ground(_place, _terrain, east, north).y

## The lowest ground under a rectangle `size` (east by north, m) at `at`,
## turned `yaw` degrees clockwise, sampled every half metre.
func _lowest_under_rect(at: Array, size: Vector2, yaw: float) -> float:
	var lo := INF
	var turn := deg_to_rad(yaw)
	var nx := int(ceil(size.x / 0.5))
	var ny := int(ceil(size.y / 0.5))
	for i in nx + 1:
		for j in ny + 1:
			var e := -size.x * 0.5 + size.x * i / nx
			var n := -size.y * 0.5 + size.y * j / ny
			lo = minf(lo, _ground_y(float(at[0]) + e * cos(turn) + n * sin(turn),
				float(at[1]) - e * sin(turn) + n * cos(turn)))
	return lo

func _lowest_under_disc(at: Array, radius: float) -> float:
	var lo := _ground_y(float(at[0]), float(at[1]))
	for ring in range(1, int(ceil(radius / 0.5)) + 1):
		var r := minf(ring * 0.5, radius)
		for k in 36:
			var a := TAU * k / 36.0
			lo = minf(lo, _ground_y(float(at[0]) + r * sin(a), float(at[1]) + r * cos(a)))
	return lo

## The lowest ground along a run of the wall, under both its faces.
func _lowest_along(run: Array) -> float:
	var lo := INF
	for k in run.size() - 1:
		var a := Vector2(float(run[k][0]), float(run[k][1]))
		var b := Vector2(float(run[k + 1][0]), float(run[k + 1][1]))
		var side := (b - a).normalized().orthogonal() * BrickShell.RUN * 0.5
		var n := int(ceil(a.distance_to(b) / 0.5))
		for j in n + 1:
			var p := a.lerp(b, float(j) / n)
			for q: Vector2 in [p + side, p - side]:
				lo = minf(lo, _ground_y(q.x, q.y))
	return lo

func _pieces() -> Array:
	return _oasis().get_node("Village").get_meta(&"pieces", [])

## Each shell's, wall run's and garden's lowest point lies within 0.1 m of the
## lowest ground under its footprint. On a stamped piece (the crushed hut, the
## gardens) that ground is the stamp's level; on an unstamped one (home 5, on
## the bank's blend; the wall) the piece starts at the lowest ground under it
## (its plinth) or follows the ground down, so nowhere does a gap show.
func test_every_piece_sits_on_the_ground():
	await _hold_over(0, 0, 60.0)
	var layout := _place.layout()
	var lowest := {}
	for p: Dictionary in _pieces():
		lowest[p["id"]] = float(p["lowest"])
	var checked := 0
	for s: Dictionary in layout["shells"]:
		var want := _lowest_under_disc(s["at"], float(s["radius"])) if s["kind"] == "round" \
			else _lowest_under_rect(s["at"], Vector2(float(s["size"][0]), float(s["size"][2])), float(s.get("yaw", 0)))
		assert_true(lowest.has(s["id"]), "shell %s was built" % s["id"])
		assert_almost_eq(float(lowest.get(s["id"], INF)), want, 0.1, "shell %s sits on the ground" % s["id"])
		checked += 1
	var runs: Array = layout["wall"]["runs"]
	for k in runs.size():
		var id := "wall_%d" % k
		assert_almost_eq(float(lowest.get(id, INF)), _lowest_along(runs[k]), 0.1, "%s follows the ground" % id)
		checked += 1
	var gardens: Array = layout["gardens"]
	for k in gardens.size():
		var g: Dictionary = gardens[k]
		var id := "garden_%d" % k
		var want := _lowest_under_rect(g["at"], Vector2(float(g["size"][0]), float(g["size"][1])), 0.0)
		assert_almost_eq(float(lowest.get(id, INF)), want, 0.1, "%s sits on the ground" % id)
		checked += 1
	assert_eq(checked, 7, "two shells, two runs, three gardens")

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(_oasis().to_global(from), _oasis().to_global(to), BodyProxy.LAYER)
	return _oasis().get_world_3d().direct_space_state.intersect_ray(query)

## A point `height` m over the ground at layout [east, north].
func _over(p: Vector2, height: float) -> Vector3:
	return PlaceField.on_ground(_place, _terrain, p.x, p.y) + Vector3(0, height, 0)

func test_the_wall_has_its_gap():
	await _hold_over(0, 0, 60.0)
	var wall: Dictionary = _place.layout()["wall"]
	var runs: Array = wall["runs"]
	var end_a: Array = runs[0][runs[0].size() - 1]
	var end_b: Array = runs[1][0]
	var a_end := Vector2(float(end_a[0]), float(end_a[1]))
	var b_end := Vector2(float(end_b[0]), float(end_b[1]))
	var gap := (a_end + b_end) * 0.5
	var across := (b_end - a_end).normalized().orthogonal()
	var at := _over(gap, 1.0)
	var span := Vector3(across.x, 0, -across.y) * 5.0
	var hit := _ray(at + span, at - span)
	assert_true(hit.is_empty(), "nothing in the gap at 1 m: %s" % [hit.get("position")])
	for run: Array in runs:
		for k in run.size() - 1:
			var a := Vector2(float(run[k][0]), float(run[k][1]))
			var b := Vector2(float(run[k + 1][0]), float(run[k + 1][1]))
			var side := (b - a).normalized().orthogonal()
			var m := _over((a + b) * 0.5, 1.0)
			var d := Vector3(side.x, 0, -side.y) * 3.0
			var through := _ray(m + d, m - d)
			assert_false(through.is_empty(), "the wall between %s and %s is solid" % [a, b])
			if not through.is_empty():
				assert_eq(through["collider"], _oasis().get_node("Brick"), "on the brick's body")

## The tracks' prints: each print's vertices, in the place's frame.
func _prints(id: String) -> Array:
	var mesh := _oasis().get_node_or_null("Tracks_%s" % id) as MeshInstance3D
	assert_not_null(mesh, "the %s tracks" % id)
	if mesh == null:
		return []
	assert_eq(mesh.layers, OasisLooks.WORLD_LAYER, "on the world's layer")
	return mesh.get_meta(&"prints", [])

func _centre(print_vertices: PackedVector3Array) -> Vector3:
	var c := Vector3.ZERO
	for v in print_vertices:
		c += v
	return c / maxf(print_vertices.size(), 1)

func test_the_tracks_lead_out_of_the_gap():
	await _hold_over(0, 0, 60.0)
	var gap_at: Array = _place.layout()["wall"]["gap"]
	var gap := Vector2(float(gap_at[0]), float(gap_at[1]))
	var prints := _prints("out")
	assert_gt(prints.size(), 100, "a long line of prints")
	if prints.is_empty():
		return
	var first := _centre(prints[0])
	assert_lt(Vector2(first.x, -first.z).distance_to(gap), 6.0, "the first by the gap")
	var far := 0.0
	var mean := Vector2.ZERO
	var off_ground := 0
	for p: PackedVector3Array in prints:
		var c := _centre(p)
		var off := Vector2(c.x, -c.z) - gap
		far = maxf(far, off.length())
		mean += off
		if off.length() > 20.0:
			var bearing := fposmod(rad_to_deg(atan2(off.x, off.y)), 360.0)
			assert_almost_eq(bearing, 60.0, 10.0, "a print %.0f m out bears 60" % off.length())
		for v in p:
			if absf(v.y - _ground_y(v.x, -v.z)) > 0.05:
				off_ground += 1
	assert_eq(off_ground, 0, "every print's vertices are on the ground under them")
	mean /= prints.size()
	assert_almost_eq(fposmod(rad_to_deg(atan2(mean.x, mean.y)), 360.0), 60.0, 10.0, "they bear 60 from the gap")
	assert_between(far, 350.0, 400.0, "the last is 350-400 m out")
	var hut: Dictionary = _place.layout()["shells"].filter(func(s): return s["kind"] == "crushed")[0]
	var inward := _prints("in")
	assert_gt(inward.size(), 4, "and a short set in to the crushed hut")
	if not inward.is_empty():
		var last := _centre(inward[inward.size() - 1])
		var to_hut := Vector2(last.x, -last.z).distance_to(Vector2(float(hut["at"][0]), float(hut["at"][1])))
		# Ending by the hut but short of its stamp's lip (hut_crushed, reach
		# 9 m): coarser chunks cut across a lip, so a print on it is half
		# buried there (test_the_tracks_lie_on_the_drawn_ground).
		assert_between(to_hut, 10.5, 13.0, "ending by the hut, short of its stamp's lip")

## The ground drawn under each print, not height_at: beyond the near chunks
## the world draws coarser quads (5-10 m at 150-400 m), which stray from
## height_at between their corners. For the chunks really drawn with the
## starter held over the gap, and for the leaves the surface would choose
## from the pad, the lookout's top and 300 m over the oasis, every vertex of
## every print lies over the drawn triangle under it (never buried) and no
## more than 8 cm over it (never floating).
const TRACK_OVER_DRAWN := [0.005, 0.08]

func test_the_tracks_lie_on_the_drawn_ground():
	var gap_at: Array = _place.layout()["wall"]["gap"]
	await _hold_over(float(gap_at[0]), float(gap_at[1]), 3.0)
	var surface: WorldSurface = (_root.star_system.proxy(_body.id) as BodyProxy).surface()
	assert_not_null(surface)
	if surface == null:
		return
	surface.finish()
	var depth_max := CubeSphere.depth_for(_body.radius)
	var height_at := func(d: Vector3) -> float: return _terrain.height_at(d)
	var leaves := {"drawn, held over the gap": surface.visible_chunks()}
	for spot: Array in [["the pad's eye", -80.0, -40.0, 1.6], ["the lookout's top", -19.5, 45.6, 9.6],
			["300 m over the oasis", 0.0, 0.0, 300.0]]:
		var d := _place.local_dir(spot[1], spot[2], _body.radius)
		var focus := d * (_body.radius + _terrain.height_at(d) + float(spot[3]))
		leaves[spot[0]] = WorldSurface.select(_body.radius, _terrain.relief, depth_max, focus, {}, {}, height_at)[0]
	var frame := _place.frame()
	var origin := PlaceField.origin_of(_place, _terrain)
	var gap := Vector2(float(gap_at[0]), float(gap_at[1]))
	for seen: String in leaves:
		var drawn := {}
		for k: Vector4i in leaves[seen]:
			drawn[k] = true
		var lo := INF
		var hi := -INF
		var coarsest := depth_max
		var bands := {}
		for id in ["out", "in"]:
			for p: PackedVector3Array in _prints(id):
				var band := "%s %d" % [id, int(Vector2(_centre(p).x, -_centre(p).z).distance_to(gap) / 100.0) * 100]
				for v in p:
					var local := frame * v + origin
					var depth := 0
					while depth < depth_max and not drawn.has(CubeSphere.key_for(local.normalized(), depth)):
						depth += 1
					var over := TerrainChunkData.drawn_altitude_of(_terrain, local, depth)
					lo = minf(lo, over)
					hi = maxf(hi, over)
					coarsest = mini(coarsest, depth)
					var b: Array = bands.get(band, [INF, -INF, depth_max])
					bands[band] = [minf(b[0], over), maxf(b[1], over), mini(b[2], depth)]
		var keys := bands.keys()
		keys.sort()
		for band in keys:
			var b: Array = bands[band]
			gut.p("%s, the %s m prints: %.3f-%.3f m over the drawn ground (quads up to %.1f m)" % [seen, band,
				b[0], b[1], CubeSphere.edge_m(_body.radius, b[2]) / CubeSphere.QUADS])
		assert_lt(coarsest, depth_max, "%s: some prints lie on coarser chunks than the finest" % seen)
		assert_gt(lo, TRACK_OVER_DRAWN[0], "%s: no print is buried in the drawn ground" % seen)
		assert_lt(hi, TRACK_OVER_DRAWN[1], "%s: and none floats over it" % seen)

## Each stone's top (its highest point) in the place's frame.
func _stone_tops() -> Array:
	var outcrop := _oasis().get_node("Outcrop") as Node3D
	var tops := []
	for c in outcrop.find_children("*", "CollisionShape3D", true, false):
		var shape := (c as CollisionShape3D).shape as ConvexPolygonShape3D
		var to_place := _oasis().global_transform.affine_inverse() * (c as CollisionShape3D).global_transform
		var top := Vector3(0, -INF, 0)
		for p in shape.points:
			var q := to_place * p
			if q.y > top.y:
				top = q
		tops.append(top)
	return tops

## The stones' tops open to the sky (nothing lies over them, so you can stand
## there) are the outcrop's tops; a step's top half under another stone is not.
## From the floor (a top at most 0.7 m over the ground beside it), a chain of
## them, each at most 0.7 m over the last and at most 2.5 m from it, reaches a
## top at least 7 m over the ground under it.
func test_the_outcrop_can_be_climbed():
	await _hold_over(0, 0, 60.0)
	var outcrop := _oasis().get_node("Outcrop") as Node3D
	var body := outcrop.get_node("Stones") as StaticBody3D
	assert_eq(body.collision_layer, BodyProxy.LAYER, "solid as the ground's boulders are")
	var tops := []
	for t: Vector3 in _stone_tops():
		var down := _ray(t + Vector3(0, 3, 0), t - Vector3(0, 1, 0))
		if not down.is_empty() and absf(_oasis().to_local(down["position"]).y - t.y) < 0.08:
			tops.append(t)
	assert_gt(tops.size(), 8, "big stones and steps, open to the sky")
	var reached := {}
	var queue := []
	for i in tops.size():
		var t: Vector3 = tops[i]
		if t.y - _ground_y(t.x, -t.z) <= 0.7:
			reached[i] = true
			queue.append(i)
	assert_false(queue.is_empty(), "a first step off the floor")
	while not queue.is_empty():
		var i: int = queue.pop_front()
		for j in tops.size():
			if reached.has(j):
				continue
			var a: Vector3 = tops[i]
			var b: Vector3 = tops[j]
			if b.y - a.y <= 0.7 and Vector2(a.x - b.x, a.z - b.z).length() <= 2.5:
				reached[j] = true
				queue.append(j)
	var best := -INF
	for i in reached:
		var t: Vector3 = tops[i]
		best = maxf(best, t.y - _ground_y(t.x, -t.z))
	gut.p("%d tops open, %d reached, the highest %.2f m up" % [tops.size(), reached.size(), best])
	assert_gt(best, 7.0, "a chain of tops reaches 7 m up")
	# The lookout: the highest top of all. You stand on it: reached by the
	# chain, or walked up to from a top the chain reaches, over the stones'
	# own colliders at no more than WALK_SLOPE, and level enough at its top.
	var lookout := 0
	for i in tops.size():
		if (tops[i] as Vector3).y > (tops[lookout] as Vector3).y:
			lookout = i
	var top: Vector3 = tops[lookout]
	var up := top.y - _ground_y(top.x, -top.z)
	assert_gt(up, 7.0, "the lookout is over 7 m up")
	var walked := reached.has(lookout)
	var how := "the chain reaches it" if walked else "not reached"
	for i in reached:
		if walked:
			break
		var from: Vector3 = tops[i]
		var steepest := _walk_steepest(from, top)
		if steepest <= WALK_SLOPE:
			walked = true
			how = "walked up from the top %.2f m up, %.1f m off, no steeper than %.0f deg" % [
				from.y - _ground_y(from.x, -from.z), Vector2(from.x - top.x, from.z - top.z).length(), steepest]
	gut.p("the lookout %.2f m up: %s; its top %.0f deg across" % [up, how, _steepest_round(top, 0.6)])
	assert_true(walked, "you can climb onto the lookout's top")
	assert_lt(_steepest_round(top, 0.6), WALK_SLOPE, "and stand there")

## The steepest a walk may climb, deg: under the avatar's floor_max_angle (45).
const WALK_SLOPE := 38.0

## The steepest climb, deg, walking straight from `a` to `b` over whatever is
## solid under the way (sampled every 0.2 m by rays down); INF if there is a
## hole or a wall (a rise of more than 0.35 m between samples).
func _walk_steepest(a: Vector3, b: Vector3) -> float:
	var span := Vector2(b.x - a.x, b.z - a.z).length()
	var n := maxi(1, ceili(span / 0.2))
	var last := a.y
	var steepest := 0.0
	for k in range(1, n + 1):
		var p := a.lerp(b, float(k) / n)
		var hit := _ray(Vector3(p.x, maxf(a.y, b.y) + 3.0, p.z), Vector3(p.x, p.y - 20.0, p.z))
		if hit.is_empty():
			return INF
		var y := _oasis().to_local(hit["position"]).y
		var rise := y - last
		if rise > 0.35:
			return INF
		steepest = maxf(steepest, rad_to_deg(atan2(rise, span / n)))
		last = y
	return steepest

## The steepest the solid surface is round `p`, deg, within `radius`.
func _steepest_round(p: Vector3, radius: float) -> float:
	var steepest := 0.0
	for k in 8:
		var a := TAU * k / 8.0
		var q := p + Vector3(cos(a), 0.0, sin(a)) * radius
		var hit := _ray(Vector3(q.x, p.y + 3.0, q.z), Vector3(q.x, p.y - 5.0, q.z))
		if hit.is_empty():
			return INF
		steepest = maxf(steepest, rad_to_deg(atan2(absf(p.y - _oasis().to_local(hit["position"]).y), radius)))
	return steepest

## Every item of call 7 this task builds has its piece (the enterable homes,
## the workshop and the comms hut come with the buildings, later).
func test_the_village_is_whole():
	await _hold_over(0, 0, 60.0)
	var count := {}
	for p: Dictionary in _pieces():
		var kind := str(p["kind"])
		count[kind] = int(count.get(kind, 0)) + 1
	assert_eq(count.get("palm", 0), 7, "seven palms")
	assert_eq(count.get("garden", 0), 3, "three gardens")
	assert_eq(count.get("pump", 0), 1, "the pump")
	assert_eq(count.get("path", 0), 1, "the path")
	assert_eq(count.get("shell", 0), 2, "home 5 and the crushed hut")
	assert_eq(count.get("wall", 0), 2, "the wall's two runs")
	assert_eq(count.get("rubble", 0), 1, "the rubble")
	assert_eq(count.get("sail", 0), 2, "two shade sails")
	var kinds := []
	for s: Dictionary in _place.layout().get("shells", []):
		kinds.append(s["kind"])
	kinds.sort()
	assert_eq(kinds, ["crushed", "round"], "home 5 is round, and the hut crushed")
	assert_not_null(_oasis().get_node_or_null("Tracks_out"), "the tracks out")
	assert_not_null(_oasis().get_node_or_null("Tracks_in"), "the tracks in")
	assert_not_null(_oasis().get_node_or_null("Outcrop"), "the outcrop")
	assert_not_null(_oasis().get_node_or_null("Brick"), "the brick is solid")
