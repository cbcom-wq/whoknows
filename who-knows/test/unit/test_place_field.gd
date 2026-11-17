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
	for p: Vector2 in [Vector2.ZERO, Vector2(-80, -40), Vector2(32.2, -16.1), Vector2(414, 188), Vector2(-21.2, 79.2)]:
		assert_eq(fast.call(p.x, p.y), PlaceField.on_ground(_place, _terrain, p.x, p.y), "at %s" % p)

## The layout points of `key` in oasis.json: arrays of [east, north].
func _layout_points(key: String) -> Array:
	return _place.layout().get(key, [])

func test_palms_stand_on_the_ground():
	await _hold_over(0, 0, 60.0)
	var palms := _oasis().get_node("Palms") as StaticBody3D
	var points := _layout_points("palms")
	assert_eq(points.size(), 10, "seven palms by the pool and three among the buildings (Rework 1)")
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
	var ring := _oasis().get_node("GrassRing")
	assert_gt(meshes.size(), 8, "the grass in tiles, each fading by its own distance")
	for m in meshes:
		assert_eq(m.get_parent(), ring, "all of them the ring's")
	var green := _oasis().get_node("GreenPatch").get_children().filter(func(n): return n is MeshInstance3D)
	assert_eq(green.size(), 1, "one mesh for the green patch")
	var village := _oasis().get_node("Village")
	var solids := village.get_children().filter(func(n): return n is MeshInstance3D and n.name == &"DressingSolid")
	assert_eq(solids.size(), 1, "one kit's solids")

func test_the_grass_stays_out_of_the_water():
	await _hold_over(0, 0, 60.0)
	var ring := _oasis().get_node("GrassRing")
	var pool := _oasis().get_node("Pool").find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var edge := pool.get_aabb().size.x * 0.5
	var tufts: PackedVector3Array = ring.get_meta(&"tufts")
	assert_gt(tufts.size(), 500)
	for i in tufts.size():
		var at := tufts[i]
		assert_gt(Vector2(at.x, at.z).length(), edge - PlaceField.SHORE_LAP + 1.5 - 0.01, "tuft %d" % i)

func test_no_grass_grows_in_a_garden_bed():
	await _hold_over(0, 0, 60.0)
	var ring := _oasis().get_node("GrassRing")
	var tufts: PackedVector3Array = ring.get_meta(&"tufts")
	for g: Dictionary in _place.layout()["gardens"]:
		var at := PlaceField.on_ground(_place, _terrain, float(g["at"][0]), float(g["at"][1]))
		var half := Vector2(float(g["size"][0]), float(g["size"][1])) * 0.5
		for t in tufts:
			assert_false(absf(t.x - at.x) < half.x and absf(t.z - at.z) < half.y, "a tuft in the bed at %s" % [g["at"]])

## Rework 1, round 2: no hollow in the green. Nowhere in the green ring's
## ellipse (36 x 26 m round the pool, out of the pool's own basin) nor under
## any vertex of the green patch (its outline wobbles past the ellipse) does
## the ground lie under the water's level + HOLLOW_CLEAR: the pool sits at
## the bottom of its oasis, as water would.
const HOLLOW_CLEAR := 0.1

func test_no_hollow_in_the_green_lies_under_the_water():
	await _hold_over(0, 0, 60.0)
	var layout := _place.layout()
	var level := PlaceField.floor_at(_place, _terrain, 0, 0).y + float(layout["pool"].get("level", -0.3))
	var axes: Array = layout["grass_ring"]["axes"]
	var pool := _stamp_named("pool")
	var lowest := INF
	var low_at := Vector2.ZERO
	var samples := 0
	for i in range(-40, 41):
		for j in range(-30, 31):
			var p := Vector2(i, j)
			if pow(p.x / float(axes[0]), 2.0) + pow(p.y / float(axes[1]), 2.0) > 1.0 or p.length() <= pool.radius:
				continue
			var y := _ground_y(p.x, p.y)
			samples += 1
			if y < lowest:
				lowest = y
				low_at = p
	var laid: PackedVector3Array = _oasis().get_node("GreenPatch").get_meta(&"laid")
	var under := 0
	for v in laid:
		if v.y < level + HOLLOW_CLEAR:
			under += 1
	gut.p("the green's lowest ground %.3f m over the water at (%.0f, %.0f), %d samples" % [lowest - level, low_at.x, low_at.y, samples])
	assert_gt(samples, 2000, "the ellipse sampled every metre")
	assert_gt(lowest, level + HOLLOW_CLEAR, "no hollow under the water's level + %.1f m" % HOLLOW_CLEAR)
	assert_eq(under, 0, "nor under the green patch")

## The green patch under the ring (Checkpoint B) lies on the ground the world
## draws: every vertex at least 1.5 cm over the finest ground's triangle under
## it (the solid ground, drawn near you), nearly all of them no more than 3.5
## cm over it; where the pool bank's stamp eases out, coarser chunks' quads
## (drawn from the air) cut over the finest's, and the patch is raised to lie
## on them too, never more than PATCH_RAISED_MOST over the finest. It is never
## under the ground drawn from the pad's eye, from 150 m or from 300 m over
## the oasis. None of it is in the water: every vertex lies past the water's
## edge and over its level.
const PATCH_OVER_FINEST := [0.015, 0.035]
const PATCH_RAISED_MOST := 0.13

func test_the_green_patch_lies_on_the_drawn_ground_out_of_the_water():
	await _hold_over(0, 0, 60.0)
	var laid: PackedVector3Array = _oasis().get_node("GreenPatch").get_meta(&"laid")
	assert_gt(laid.size(), 3000, "a carpet of triangles")
	var pool := _oasis().get_node("Pool").find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var edge := pool.get_aabb().size.x * 0.5 - PlaceField.SHORE_LAP
	var level := PlaceField.floor_at(_place, _terrain, 0, 0).y + float(_place.layout()["pool"].get("level", -0.3))
	var frame := _place.frame()
	var origin := PlaceField.origin_of(_place, _terrain)
	var depth_max := CubeSphere.depth_for(_body.radius)
	var lo := INF
	var hi := -INF
	var near := INF
	var wet := 0
	var raised := 0
	for v in laid:
		var local := frame * v + origin
		var over := TerrainChunkData.drawn_altitude_of(_terrain, local, depth_max)
		lo = minf(lo, over)
		hi = maxf(hi, over)
		if over > PATCH_OVER_FINEST[1]:
			raised += 1
		near = minf(near, Vector2(v.x, v.z).length())
		if v.y < level + 0.01:
			wet += 1
	gut.p("the patch: %.3f-%.3f m over the finest drawn ground, %d of %d vertices raised over %.3f; nearest the pool's middle %.2f m (its edge %.2f)" % [
		lo, hi, raised, laid.size(), PATCH_OVER_FINEST[1], near, edge])
	assert_between(lo, PATCH_OVER_FINEST[0], PATCH_OVER_FINEST[1], "none buried in the finest ground")
	assert_lt(hi, PATCH_RAISED_MOST, "and none floating far over it")
	# Rework 2: the bank rolls (keep 0.2), so the level courts and the pool's
	# shore meet it at small lips, where coarser chunks lift the patch a little
	# more often (about 7%, the most under 0.1 m).
	assert_lt(raised, laid.size() / 11, "nearly all of it within %.3f m of it" % PATCH_OVER_FINEST[1])
	assert_gt(near, edge, "none of it in the water")
	assert_eq(wet, 0, "and all of it over the water's level")
	var height_at := func(d: Vector3) -> float: return _terrain.height_at(d)
	for spot: Array in [["the pad's eye", -80.0, -40.0, 1.6], ["150 m over the oasis", 0.0, 0.0, 150.0],
			["300 m over the oasis", 0.0, 0.0, 300.0]]:
		var d := _place.local_dir(spot[1], spot[2], _body.radius)
		var focus := d * (_body.radius + _terrain.height_at(d) + float(spot[3]))
		var drawn := {}
		for k: Vector4i in WorldSurface.select(_body.radius, _terrain.relief, depth_max, focus, {}, {}, height_at)[0]:
			drawn[k] = true
		var low := INF
		var coarsest := depth_max
		var under := 0
		var under_near := INF
		for v in laid:
			var local := frame * v + origin
			var depth := 0
			while depth < depth_max and not drawn.has(CubeSphere.key_for(local.normalized(), depth)):
				depth += 1
			coarsest = mini(coarsest, depth)
			var over := TerrainChunkData.drawn_altitude_of(_terrain, local, depth)
			low = minf(low, over)
			if over < 0.0:
				under += 1
				under_near = minf(under_near, Vector2(v.x, v.z).length())
		gut.p("from %s: at least %.3f m over the drawn ground (quads up to %.1f m); %d of %d vertices under it, the nearest the pool %.1f m out" % [
			spot[0], low, CubeSphere.edge_m(_body.radius, coarsest) / CubeSphere.QUADS, under, laid.size(), under_near])
		assert_gt(low, 0.01, "%s: the patch is never under the drawn ground" % spot[0])


# --- the village outside: shells, the wall, the tracks (Task 9, Rework 1) -------

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
func _lowest_along(run: PackedVector2Array) -> float:
	var lo := INF
	for k in run.size() - 1:
		var a := run[k]
		var b := run[k + 1]
		var side := (b - a).normalized().orthogonal() * BrickShell.RUN * 0.5
		var n := int(ceil(a.distance_to(b) / 0.5))
		for j in n + 1:
			var p := a.lerp(b, float(j) / n)
			for q: Vector2 in [p + side, p - side]:
				lo = minf(lo, _ground_y(q.x, q.y))
	return lo

func _pieces() -> Array:
	return _oasis().get_node("Village").get_meta(&"pieces", [])

func _stamp_named(id: String) -> TerrainStamp:
	for s in _terrain.stamps:
		if str(s.id) == id:
			return s
	return null

## The ring wall as built: its runs, gate piers, gate and breach.
func _ring() -> Dictionary:
	return PlaceField.ring_wall(_place.layout()["wall"])

func _at_of(s: Dictionary) -> Vector2:
	return Vector2(float(s["at"][0]), float(s["at"][1]))

## A shell's footprint, [east, north], every quarter metre round its edge.
func _outline(s: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	var c := _at_of(s)
	if s["kind"] == "round":
		for k in 96:
			var a := TAU * k / 96.0
			out.append(c + Vector2(sin(a), cos(a)) * float(s["radius"]))
		return out
	var half := Vector2(float(s["size"][0]), float(s["size"][2])) * 0.5
	var turn := deg_to_rad(float(s.get("yaw", 0.0)))
	var x := Vector2(cos(turn), -sin(turn))
	var front := Vector2(sin(turn), cos(turn))
	var corners := [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]
	for k in 4:
		var a: Vector2 = corners[k]
		var b: Vector2 = corners[(k + 1) % 4]
		var n := maxi(1, ceili(a.distance_to(b) / 0.25))
		for j in n:
			var p := a.lerp(b, float(j) / n)
			out.append(c + x * p.x + front * p.y)
	return out

## How far `p` is from the wall's faces (runs RUN thick, square gate piers), m.
func _from_wall(p: Vector2, ring: Dictionary) -> float:
	var best := INF
	for run: PackedVector2Array in ring["runs"]:
		for k in run.size() - 1:
			best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, run[k], run[k + 1])) - BrickShell.RUN * 0.5)
	var pier: Array = _place.layout()["wall"]["gate"].get("pier", [1.2, 3.4])
	for q: Array in ring["piers"]:
		var along: Vector2 = q[1]
		var off: Vector2 = p - (q[0] as Vector2)
		var local := Vector2(absf(off.dot(along)), absf(off.dot(along.orthogonal()))) - Vector2.ONE * float(pier[0]) * 0.5
		best = minf(best, Vector2(maxf(local.x, 0.0), maxf(local.y, 0.0)).length() + minf(maxf(local.x, local.y), 0.0))
	return best

## The middle of the ring's gate or breach.
func _opening(which: String) -> Vector2:
	var ends: Array = _ring()[which]
	return ((ends[0] as Vector2) + (ends[1] as Vector2)) * 0.5

## Rework 1: each building's floor is its compound's stamp's level (within
## 0.02 m), its walls start SUNK under it (no plinth sinks it in the sand), and
## the ground under its whole footprint is that level. Each garden sits on its
## own stamp's level; each run of the wall and each yard wall follows the
## ground.
func test_every_piece_sits_on_the_ground():
	await _hold_over(0, 0, 60.0)
	var layout := _place.layout()
	var by_id := {}
	for p: Dictionary in _pieces():
		by_id[p["id"]] = p
	var checked := 0
	for s: Dictionary in layout["shells"]:
		var id := str(s["id"])
		assert_true(by_id.has(id), "shell %s was built" % id)
		if not by_id.has(id):
			continue
		var level := _ground_y(float(s["at"][0]), float(s["at"][1]))
		var floor_y := float(by_id[id].get("floor", INF))
		assert_almost_eq(floor_y, level, 0.02, "%s's floor is its stamp's level" % id)
		assert_almost_eq(float(by_id[id]["lowest"]), floor_y - BrickShell.SUNK, 0.02, "%s's walls start just under it" % id)
		var under := _lowest_under_disc(s["at"], float(s["radius"])) if s["kind"] == "round" \
			else _lowest_under_rect(s["at"], Vector2(float(s["size"][0]), float(s["size"][2])), float(s.get("yaw", 0)))
		assert_almost_eq(under, level, 0.02, "%s: the ground under all of it is level" % id)
		checked += 1
	for b: Dictionary in layout.get("benches", []):
		var id := "bench_%d" % layout["benches"].find(b)
		var lowest := float(by_id.get(id, {}).get("lowest", INF))
		assert_lt(lowest, _ground_y(float(b["at"][0]), float(b["at"][1])) - 0.05, "%s's feet are in the ground" % id)
		assert_gt(lowest, _ground_y(float(b["at"][0]), float(b["at"][1])) - 0.4, "%s is not buried" % id)
		checked += 1
	if layout.has("memorial"):
		var m: Array = layout["memorial"]["at"]
		var lowest := float(by_id.get("memorial", {}).get("lowest", INF))
		assert_lt(lowest, _ground_y(float(m[0]), float(m[1])), "the memorial's stones stand in the ground")
		assert_gt(lowest, _ground_y(float(m[0]), float(m[1])) - 0.6, "not sunk")
		checked += 1
	var runs: Array = _ring()["runs"]
	for k in runs.size():
		var id := "wall_%d" % k
		assert_almost_eq(float(by_id.get(id, {}).get("lowest", INF)), _lowest_along(runs[k]) - BrickShell.SUNK, 0.1,
			"%s follows the ground" % id)
		checked += 1
	var yards: Array = layout.get("yards", [])
	for y: Dictionary in yards:
		var id := str(y["id"])
		var run := PackedVector2Array()
		for q: Array in y["points"]:
			run.append(Vector2(float(q[0]), float(q[1])))
		assert_almost_eq(float(by_id.get(id, {}).get("lowest", INF)), _lowest_along(run) - BrickShell.SUNK, 0.1,
			"%s follows the ground" % id)
		checked += 1
	for g: Dictionary in layout["gardens"]:
		var id := str(g["id"])
		var level := _ground_y(float(g["at"][0]), float(g["at"][1]))
		assert_almost_eq(float(by_id.get(id, {}).get("floor", INF)), level, 0.02, "%s is on its stamp's level" % id)
		var under := _lowest_under_rect(g["at"], Vector2(float(g["size"][0]), float(g["size"][1])), 0.0)
		assert_almost_eq(under, level, 0.02, "%s: the ground under it is level" % id)
		checked += 1
	assert_eq(checked, 17 + yards.size() + layout.get("benches", []).size() + 1,
		"twelve shells, two runs, three gardens, the yards, the benches and the memorial")
	assert_gt(yards.size(), 4, "yard walls between the compounds' buildings")

func _ray(from: Vector3, to: Vector3, exclude: Array[RID] = []) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(_oasis().to_global(from), _oasis().to_global(to), BodyProxy.LAYER, exclude)
	return _oasis().get_world_3d().direct_space_state.intersect_ray(query)

## Whether the segment `from`-`to` meets the body `want`, whatever else lies
## on the way (each other body met is left out and the ray cast again).
func _meets(from: Vector3, to: Vector3, want: Node) -> bool:
	var exclude: Array[RID] = []
	for i in 8:
		var hit := _ray(from, to, exclude)
		if hit.is_empty():
			return false
		if hit["collider"] == want:
			return true
		exclude.append((hit["collider"] as CollisionObject3D).get_rid())
	return false

## A point `height` m over the ground at layout [east, north].
func _over(p: Vector2, height: float) -> Vector3:
	return PlaceField.on_ground(_place, _terrain, p.x, p.y) + Vector3(0, height, 0)

## Rework 1: a full ring wall, hugging the village (round 2: 44-48 m out on
## the mean, wandering up to 3 m). A ray at 1 m from the pool outward, across the
## wall's line, meets the wall in every direction but the gate's and the
## breach's; those two are open; the gate faces the pad within 20 deg, and
## the wall keeps off the pad's stamp.
func test_the_wall_rings_the_village():
	await _hold_over(0, 0, 60.0)
	var wall_body := _oasis().get_node_or_null("Wall")
	assert_not_null(wall_body, "the wall is its own body")
	if wall_body == null:
		return
	assert_eq((wall_body as StaticBody3D).collision_layer, BodyProxy.LAYER)
	var layout := _place.layout()
	var wall: Dictionary = layout["wall"]
	var ring_points: Array = wall["ring"]
	assert_between(ring_points.size(), 12, 16, "a chunky polygon of 12 to 16 runs")
	var radii := []
	var mean := 0.0
	for p: Array in ring_points:
		radii.append(Vector2(float(p[0]), float(p[1])).length())
		mean += radii.back() / ring_points.size()
	gut.p("the ring: %.1f m out on the mean, %.1f to %.1f" % [mean, radii.min(), radii.max()])
	assert_between(mean, 44.0, 48.0, "it hugs the village, 44-48 m out")
	assert_gt(radii.min(), mean - 3.0, "wandering in by up to 3 m")
	assert_lt(radii.max(), mean + 3.0, "and out")
	var ring := _ring()
	var pier: Array = wall["gate"]["pier"]
	var spans := []
	for name in ["gate", "breach"]:
		var ends: Array = ring[name]
		var mid := _opening(name)
		var gap := (ends[0] as Vector2).distance_to(ends[1])
		var piers := float(pier[0]) if name == "gate" else 0.0
		var width := gap - piers
		gut.p("the %s at (%.1f, %.1f), %.2f m wide" % [name, mid.x, mid.y, width])
		if name == "gate":
			assert_between(width, 4.0, 5.0, "the gate is 4-5 m wide")
		else:
			assert_between(width, 7.0, 9.0, "the breach is 7-9 m wide")
		# [bearing, how far out, the open half-width, the walled half-width]
		spans.append([rad_to_deg(atan2(mid.x, mid.y)), mid.length(), width * 0.5 - 0.6, width * 0.5 + piers + 0.5])
	var open := 0
	var closed := 0
	for k in 720:
		var bearing := k * 0.5
		var dir := Vector2(sin(deg_to_rad(bearing)), cos(deg_to_rad(bearing)))
		var walled := true
		var gap := false
		for s: Array in spans:
			var along := deg_to_rad(absf(wrapf(bearing - float(s[0]), -180.0, 180.0))) * float(s[1])
			walled = walled and along > float(s[3])
			gap = gap or along < float(s[2])
		if not walled and not gap:
			continue
		var met := _meets(_over(dir * 38.0, 1.0), _over(dir * 62.0, 1.0), wall_body)
		if gap:
			assert_false(met, "open at bearing %.1f" % bearing)
			open += 1
		else:
			assert_true(met, "the wall at bearing %.1f" % bearing)
			closed += 1
	gut.p("%d bearings walled, %d open" % [closed, open])
	assert_gt(closed, 650, "walled nearly all round")
	assert_gt(open, 6, "the gate and the breach are open")
	# The gate faces the pad: its outward normal and the way to the pad's middle.
	var g: Array = ring["gate"]
	var gate_mid := _opening("gate")
	var normal := ((g[1] as Vector2) - (g[0] as Vector2)).orthogonal().normalized()
	if normal.dot(gate_mid) < 0.0:
		normal = -normal
	var pad := Vector2(float(layout["pad"]["at"][0]), float(layout["pad"]["at"][1]))
	var off := rad_to_deg(normal.angle_to(pad - gate_mid))
	gut.p("the gate faces %.1f deg off the pad" % off)
	assert_lt(absf(off), 20.0, "the gate faces the pad")
	var nearest := INF
	for run: PackedVector2Array in ring["runs"]:
		for k in run.size() - 1:
			nearest = minf(nearest, pad.distance_to(Geometry2D.get_closest_point_to_segment(pad, run[k], run[k + 1])))
	assert_gt(nearest, _stamp_named("pad").reach() + 3.0, "the wall keeps off the pad")
	# The piers are thicker and taller than the wall.
	assert_gt(float(pier[0]), BrickShell.RUN, "thicker")
	assert_gt(float(pier[1]), float(wall.get("height", 2.6)), "taller")

## Between two compounds, building to building or to a yard wall's line, m:
## the lanes. Within one, each building stands COMPOUND_GAP from its nearest.
const SHELL_GAP := 3.0
const COMPOUND_GAP := [0.3, 2.0]
## No building nearer the ring wall's face than this (m); BACKED of them back
## onto it, within 1.5 m.
const WALL_BACK := 0.5
const BACKED := 3

## The margin between two of the terrain's stamps, the earlier as the outer.
func _margin(a: TerrainStamp, b: TerrainStamp) -> float:
	if _terrain.stamps.find(a) > _terrain.stamps.find(b):
		return SystemDesign.stamp_margin(b, a, _body.radius)
	return SystemDesign.stamp_margin(a, b, _body.radius)

## A yard wall's line, every quarter metre.
func _yard_line(y: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	var pts: Array = y["points"]
	for k in pts.size() - 1:
		var a := Vector2(float(pts[k][0]), float(pts[k][1]))
		var b := Vector2(float(pts[k + 1][0]), float(pts[k + 1][1]))
		var n := maxi(1, ceili(a.distance_to(b) / 0.25))
		for i in n + 1:
			out.append(a.lerp(b, float(i) / n))
	return out

## Rework 1, round 2: twelve buildings, 4 to enter (Part C), 6 whole shells
## and 2 crushed huts, packed in 4 or 5 compounds of 2 to 4, the way a
## mud-brick village packs together. Each compound stands on one stamp (keep
## 0, every footprint in its flat part with an apron of 0.8-2 m), which keeps
## apart from every other stamp but the floor and the pool's bank it nests in.
## In a compound each building stands COMPOUND_GAP from its nearest; between
## compounds every building and yard wall keeps SHELL_GAP apart (the lanes).
## No building is nearer the ring wall than WALL_BACK, and BACKED back onto it.
func test_twelve_buildings_in_compounds():
	var layout := _place.layout()
	var shells: Array = layout["shells"]
	assert_eq(shells.size(), 12, "twelve buildings")
	var enterable := []
	var crushed := 0
	var whole := 0
	var round := 0
	for s: Dictionary in shells:
		if bool(s.get("enterable", false)):
			enterable.append(s["id"])
		elif s["kind"] == "crushed":
			crushed += 1
		else:
			whole += 1
		if s["kind"] == "round":
			round += 1
	enterable.sort()
	assert_eq(enterable, ["comms", "home_3", "home_4", "workshop"], "the four Part C buildings")
	assert_eq(whole, 6, "six whole shells")
	assert_eq(crushed, 2, "two crushed huts")
	assert_eq(round, 2, "two of them round")
	assert_true(shells.any(func(s): return s["id"] == "home_5" and s["kind"] == "round"), "home 5 is one")
	assert_true(shells.any(func(s): return s["kind"] == "box" and float(s["size"][1]) > 5.0), "one of two storeys")
	var compounds := {}
	for s: Dictionary in shells:
		var c := str(s.get("stamp", ""))
		if not compounds.has(c):
			compounds[c] = []
		compounds[c].append(s)
	assert_between(compounds.size(), 4, 5, "four or five compounds")
	var crushed_together := shells.filter(func(s): return s["kind"] == "crushed").map(func(s): return s["stamp"])
	assert_eq(crushed_together[0], crushed_together[1], "the crushed pair is one compound")
	var outlines := {}
	var of := {}
	for c: String in compounds:
		var members: Array = compounds[c]
		assert_between(members.size(), 2, 4, "%s: two to four buildings" % c)
		var st := _stamp_named(c)
		assert_not_null(st, "%s has its stamp" % c)
		if st == null:
			continue
		assert_eq(st.kind, TerrainStamp.Kind.FLATTEN)
		assert_eq(st.keep, 0.0, "%s's ground is dead level" % c)
		assert_eq(st.raise, 0.0)
		assert_between(st.edge, 1.0, 2.0, "%s's edge" % c)
		var reach := 0.0
		for s: Dictionary in members:
			var id := str(s["id"])
			outlines[id] = _outline(s)
			of[id] = c
			for p in outlines[id]:
				reach = maxf(reach, st.metres_from(_place.local_dir(p.x, p.y, _body.radius), _body.radius))
		assert_between(st.radius - reach, 0.8, 2.0, "%s: its buildings and an apron of about 1 m" % c)
		for other in _terrain.stamps:
			if other != st and other.id != &"oasis_floor":
				assert_gte(_margin(st, other), 0.3, "%s keeps apart from %s, or nests in it" % [c, other.id])
	for y: Dictionary in layout.get("yards", []):
		outlines[str(y["id"])] = _yard_line(y)
		of[str(y["id"])] = str(y["stamp"])
	var ring := _ring()
	var ids := outlines.keys()
	var backed := 0
	var nearest := {}
	var lanes := INF
	for i in ids.size():
		var a: String = ids[i]
		var yard_a := not shells.any(func(s): return s["id"] == a)
		if not yard_a:
			var wall_gap := INF
			for p in outlines[a]:
				wall_gap = minf(wall_gap, _from_wall(p, ring))
			assert_gte(wall_gap, WALL_BACK, "%s keeps off the wall's face" % a)
			if wall_gap < 1.5:
				backed += 1
		for j in range(i + 1, ids.size()):
			var b: String = ids[j]
			var yard_b := not shells.any(func(s): return s["id"] == b)
			var gap := INF
			for p in outlines[a]:
				for q in outlines[b]:
					gap = minf(gap, p.distance_to(q))
			if of[a] != of[b]:
				lanes = minf(lanes, gap)
				assert_gte(gap, SHELL_GAP, "a lane between %s and %s" % [a, b])
			elif not yard_a and not yard_b:
				assert_gte(gap, COMPOUND_GAP[0], "%s and %s do not run into each other" % [a, b])
				nearest[a] = minf(nearest.get(a, INF), gap)
				nearest[b] = minf(nearest.get(b, INF), gap)
	for id in nearest:
		assert_lte(float(nearest[id]), COMPOUND_GAP[1], "%s stands by another of its compound" % id)
	gut.p("the narrowest lane between compounds %.1f m; %d buildings back onto the wall" % [lanes, backed])
	assert_gte(backed, BACKED, "a few back onto the wall")

## Rework 1: a 1.2 m wide walk from the gate to the pool, and from the breach
## to the pool, meets nothing solid in the village: no shell, no wall, no
## palm. Rays at knee, waist and head height across and along the way.
func test_the_lanes_are_open():
	await _hold_over(0, 0, 60.0)
	var solid := [_oasis().get_node("Brick"), _oasis().get_node("Wall"), _oasis().get_node("Palms")]
	for name in ["gate", "breach"]:
		var mid := _opening(name)
		var from := mid + mid.normalized() * 3.0
		var to := mid.normalized() * 17.0
		var across := (to - from).normalized().orthogonal() * 0.6
		var n := ceili(from.distance_to(to) / 0.5)
		var blocked := 0
		for k in n + 1:
			var p := from.lerp(to, float(k) / n)
			var q := from.lerp(to, float(mini(k + 1, n)) / n)
			for h in [0.3, 1.0, 1.8]:
				var pairs := [[_over(p - across, h), _over(p + across, h)]]
				if k < n:
					for side in [-1.0, 0.0, 1.0]:
						pairs.append([_over(p + across * side, h), _over(q + across * side, h)])
				for pair: Array in pairs:
					for body in solid:
						if _meets(pair[0], pair[1], body):
							blocked += 1
							gut.p("the %s's lane meets %s at (%.1f, %.1f), %.1f m up" % [name, body.name, p.x, p.y, h])
		assert_eq(blocked, 0, "the way from the %s to the pool is open" % name)

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

func test_the_tracks_lead_out_of_the_breach():
	await _hold_over(0, 0, 60.0)
	var gap := _opening("breach")
	var ring := _ring()
	var prints := _prints("out")
	assert_gt(prints.size(), 100, "a long line of prints")
	if prints.is_empty():
		return
	# Round 2: the bank's edge (its lip) lies just outside the breach, and no print
	# lies across a lip, so the line starts past it, over the rubble outside.
	var first := _centre(prints[0])
	var bank := _stamp_named("pool_bank")
	assert_lt(Vector2(first.x, -first.z).distance_to(gap), 22.0, "the first just out of the breach")
	assert_lt(Vector2(first.x, -first.z).length(), bank.reach() + 6.0, "just past the bank's lip")
	var far := 0.0
	var mean := Vector2.ZERO
	var off_ground := 0
	var under_wall := 0
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
			if _from_wall(Vector2(v.x, -v.z), ring) < 0.2:
				under_wall += 1
	assert_eq(off_ground, 0, "every print's vertices are on the ground under them")
	assert_eq(under_wall, 0, "no print runs under the wall")
	mean /= prints.size()
	assert_almost_eq(fposmod(rad_to_deg(atan2(mean.x, mean.y)), 360.0), 60.0, 10.0, "they bear 60 from the breach")
	assert_between(far, 350.0, 400.0, "the last is 350-400 m out")
	# In from the breach toward the crushed huts: the nearest one ends them.
	var hut: Dictionary = {}
	for s: Dictionary in _place.layout()["shells"]:
		if s["kind"] == "crushed" and (hut.is_empty() or _at_of(s).distance_to(gap) < _at_of(hut).distance_to(gap)):
			hut = s
	var inward := _prints("in")
	assert_gt(inward.size(), 4, "and a short set in toward the crushed huts")
	if inward.is_empty() or hut.is_empty():
		return
	var hut_at := _at_of(hut)
	var last := _centre(inward[inward.size() - 1])
	var to_hut := Vector2(last.x, -last.z).distance_to(hut_at)
	# Ending by the hut but short of its stamp's lip: coarser chunks cut across
	# a lip, so a print on it is half buried there
	# (test_the_tracks_lie_on_the_drawn_ground).
	# Round 2: the hut's compound stamp lies level in the pool's bank, so the
	# prints may run onto it; they end by the hut, short of its walls.
	var hut_reach := 0.0
	for p in _outline(hut):
		hut_reach = maxf(hut_reach, p.distance_to(hut_at))
	gut.p("the last print in is %.1f m from %s (its walls reach %.1f m)" % [to_hut, hut["id"], hut_reach])
	assert_lt(to_hut, hut_reach + 6.0, "ending by %s" % hut["id"])
	var nearest := INF
	for p: PackedVector3Array in inward:
		for v in p:
			nearest = minf(nearest, Vector2(v.x, -v.z).distance_to(hut_at))
			if _from_wall(Vector2(v.x, -v.z), ring) < 0.2:
				under_wall += 1
	assert_gt(nearest, hut_reach + 0.5, "every print short of its walls")
	assert_eq(under_wall, 0, "and none under the wall")
	# No print lies across a stamp's lip, where its level meets other ground
	# (coarser chunks cut across a lip, so a print on it is half buried there).
	# The floor's 150 m blend is no lip, and a stamp level with the ground
	# round it (a compound nested in the bank) has none.
	var lipped := []
	for st in _terrain.stamps:
		if st.id != &"oasis_floor" and _has_lip(st):
			lipped.append(st)
	assert_true(lipped.any(func(st): return st.id == &"pool_bank"), "the bank has a lip")
	for id in ["out", "in"]:
		for p: PackedVector3Array in _prints(id):
			for st: TerrainStamp in lipped:
				var on := 0
				for v in p:
					var dir := _place.local_dir(v.x, -v.z, _body.radius)
					var m := st.metres_from(dir, _body.radius)
					if m > st.flat_radius(dir) - 0.5 and m < st.reach() + 0.5:
						on += 1
				assert_eq(on, 0, "a %s print across %s's lip" % [id, st.id])

## Whether the ground just past `st`'s reach differs from its top (more than
## 1 cm anywhere round it): whether it has a lip.
func _has_lip(st: TerrainStamp) -> bool:
	var top := st.level + st.raise + (st.height if st.kind == TerrainStamp.Kind.MESA else 0.0)
	if st.kind == TerrainStamp.Kind.BASIN:
		return true
	var side := st.centre.cross(Vector3.UP).normalized()
	var other := st.centre.cross(side)
	var a := (st.reach() + 0.3) / _body.radius
	for k in 24:
		var turn := TAU * k / 24.0
		var d := (st.centre * cos(a) + (side * cos(turn) + other * sin(turn)) * sin(a)).normalized()
		if absf(_terrain.height_at(d) - top) > 0.01:
			return true
	return false

## The ground drawn under each print, not height_at: beyond the near chunks
## the world draws coarser quads (5-10 m at 150-400 m), which stray from
## height_at between their corners. For the chunks really drawn with the
## starter held over the breach, and for the leaves the surface would choose
## from the pad, the ledge's top and 300 m over the oasis, every vertex of
## every print lies over the drawn triangle under it (never buried) and no
## more than 8 cm over it (never floating).
const TRACK_OVER_DRAWN := [0.005, 0.08]

func test_the_tracks_lie_on_the_drawn_ground():
	var gap := _opening("breach")
	await _hold_over(gap.x, gap.y, 3.0)
	var surface: WorldSurface = (_root.star_system.proxy(_body.id) as BodyProxy).surface()
	assert_not_null(surface)
	if surface == null:
		return
	surface.finish()
	var depth_max := CubeSphere.depth_for(_body.radius)
	var height_at := func(d: Vector3) -> float: return _terrain.height_at(d)
	var leaves := {"drawn, held over the breach": surface.visible_chunks()}
	var ledge := _stamp_named("ledge")
	var ledge_at := _place.frame().inverse() * (ledge.centre - _place.dir()) * _body.radius
	for spot: Array in [["the pad's eye", -80.0, -40.0, 1.6], ["the ledge's top", ledge_at.x, -ledge_at.z, 1.6],
			["300 m over the oasis", 0.0, 0.0, 300.0]]:
		var d := _place.local_dir(spot[1], spot[2], _body.radius)
		var focus := d * (_body.radius + _terrain.height_at(d) + float(spot[3]))
		leaves[spot[0]] = WorldSurface.select(_body.radius, _terrain.relief, depth_max, focus, {}, {}, height_at)[0]
	var frame := _place.frame()
	var origin := PlaceField.origin_of(_place, _terrain)
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

## Every item of the layout this phase builds has its piece (the enterable
## buildings are plain shells until Part C makes them bases).
func test_the_village_is_whole():
	await _hold_over(0, 0, 60.0)
	var count := {}
	for p: Dictionary in _pieces():
		var kind := str(p["kind"])
		count[kind] = int(count.get(kind, 0)) + 1
	assert_eq(count.get("palm", 0), 10, "seven palms by the pool and three among the buildings")
	assert_eq(count.get("garden", 0), 3, "three gardens")
	assert_eq(count.get("pump", 0), 1, "the pump")
	assert_eq(count.get("path", 0), 1, "the path")
	assert_eq(count.get("shell", 0), 12, "twelve buildings")
	assert_eq(count.get("yard", 0), _place.layout().get("yards", []).size(), "every yard wall")
	assert_eq(count.get("wall", 0), 2, "the ring's two runs, between the gate and the breach")
	assert_eq(count.get("pier", 0), 2, "the gate's two piers")
	assert_eq(count.get("rubble", 0), 2, "rubble in and out of the breach")
	assert_between(int(count.get("sail", 0)), 2, 3, "two or three shade sails")
	assert_eq(count.get("bench", 0), 2 * int(count.get("sail", 0)), "two benches under each sail")
	assert_eq(count.get("memorial", 0), 1, "the memorial")
	assert_not_null(_oasis().get_node_or_null("Tracks_out"), "the tracks out")
	assert_not_null(_oasis().get_node_or_null("Tracks_in"), "the tracks in")
	assert_null(_oasis().get_node_or_null("Outcrop"), "no outcrop: the ledge is ground")
	assert_not_null(_oasis().get_node_or_null("Brick"), "the brick is solid")
	assert_not_null(_oasis().get_node_or_null("Wall"), "and the wall")
	# The items: the crate by a crushed hut, the canister by the path inside the gate.
	var items := {}
	for e: Dictionary in _place.layout()["items"]:
		items[e["id"]] = _at_of(e)
	var hut := INF
	for s: Dictionary in _place.layout()["shells"]:
		if s["kind"] == "crushed":
			hut = minf(hut, _at_of(s).distance_to(items.get("crate_hut", Vector2.INF)))
	assert_lt(hut, 8.0, "the crate is by a crushed hut")
	var gate_mid := _opening("gate")
	var canister: Vector2 = items.get("canister_path", Vector2.INF)
	assert_lt(canister.length(), gate_mid.length(), "the canister is inside the gate")
	assert_lt(canister.distance_to(gate_mid), 10.0, "near it")

# --- Rework 2: floors, doors, the grass's edge, the ledge -------------------------

## The shell pieces, by id.
func _shell_pieces() -> Dictionary:
	var out := {}
	for p: Dictionary in _pieces():
		if p["kind"] == "shell":
			out[p["id"]] = p
	return out

## The height a ray straight down from `from_height` m over the ground at
## layout point `p` meets the Brick body, or a room's furniture in an open shell
## (WadooRooms, the hall's basin), at (in the place's frame), or NAN.
func _brick_down(p: Vector2, from_height: float) -> float:
	var top := _over(p, from_height)
	var hit := _ray(top, top - Vector3(0, from_height + 2.0, 0))
	if hit.is_empty():
		return NAN
	var by: Node = hit["collider"]
	if by != _oasis().get_node("Brick") and not by.get_parent().name.begins_with("Room_"):
		return NAN
	return _oasis().to_local(hit["position"]).y

## Rework 2 (the owner: "They don't have floors?"): inside every shell a ray
## down meets its floor slab at the foundation's height over its stamp's
## level. A crushed hut's fallen slabs lie on that floor, so the lowest of a
## few rays is the floor.
func test_every_shell_has_a_floor():
	await _hold_over(0, 0, 60.0)
	var pieces := _shell_pieces()
	for s: Dictionary in _place.layout()["shells"]:
		var id := str(s["id"])
		var level := _ground_y(float(s["at"][0]), float(s["at"][1]))
		var lowest := INF
		var met := 0
		var c := _at_of(s)
		for off: Vector2 in [Vector2.ZERO, Vector2(1.0, 0.6), Vector2(-1.0, -0.6), Vector2(0.8, -0.8), Vector2(-0.8, 0.8)]:
			var y := _brick_down(c + off, 1.5)
			if not is_nan(y):
				met += 1
				lowest = minf(lowest, y)
		assert_eq(met, 5, "%s: every ray down inside meets something" % id)
		assert_almost_eq(lowest, level + BrickShell.FOUNDATION, 0.02, "%s: its floor is the foundation's height over its stamp" % id)
		assert_almost_eq(float(pieces.get(id, {}).get("slab", INF)), level + BrickShell.FOUNDATION, 0.02, "%s's slab" % id)

## Rework 2: at every door the way in rises by steps: the ground, a threshold
## stone, the floor in the doorway; each step over 0 and no more than 0.15 m.
func test_a_threshold_is_a_step():
	await _hold_over(0, 0, 60.0)
	var pieces := _shell_pieces()
	var checked := 0
	for id: String in pieces:
		var doors: Array = pieces[id].get("doors", [])
		assert_gt(doors.size(), 0, "%s has a door" % id)
		for d: Array in doors:
			var middle: Vector3 = d[0]
			var out: Vector3 = d[1]
			var foot := middle + out * (BrickShell.WALL * 0.5 + BrickShell.THRESHOLD_DEEP + 0.4)
			var heights := [_ground_y(foot.x, -foot.z)]
			for along in [BrickShell.WALL * 0.5 + BrickShell.FOUNDATION_PROUD + 0.2, 0.0]:
				var p: Vector3 = middle + out * along
				var y := _brick_down(Vector2(p.x, -p.z), 0.9)
				assert_false(is_nan(y), "%s: something to stand on %.2f m out of its door" % [id, along])
				heights.append(y)
			gut.p("%s's door: ground %.3f, threshold %.3f, floor %.3f" % [id, heights[0], heights[1], heights[2]])
			for k in range(1, heights.size()):
				var rise: float = heights[k] - heights[k - 1]
				assert_gt(rise, 0.0, "%s: a step up" % id)
				assert_lte(rise, 0.15 + 0.005, "%s: no more than 0.15 m" % id)
			checked += 1
	assert_eq(checked, 12, "a door in every shell")

## Rework 2: a whole shell's door is shut (a ray through its middle meets its
## collider; an open shell's, the door's leaf, WadooDoor); a crushed hut stays
## open where its walls broke.
func test_shell_doors_are_shut():
	await _hold_over(0, 0, 60.0)
	var pieces := _shell_pieces()
	var brick := _oasis().get_node("Brick")
	for s: Dictionary in _place.layout()["shells"]:
		var id := str(s["id"])
		var p: Dictionary = pieces.get(id, {})
		if s["kind"] == "crushed":
			# Across the broken (+x) side, over the stumps and what fell in.
			var turn := deg_to_rad(float(s.get("yaw", 0.0)))
			var x := Vector2(cos(turn), -sin(turn))
			var c := _at_of(s)
			var floor_y := float(p.get("slab", 0.0))
			var from := _over(c + x * (float(s["size"][0]) * 0.5 + 2.0), 0.0)
			var to := _over(c, 0.0)
			from.y = floor_y + 1.9
			to.y = floor_y + 1.9
			assert_false(_meets(from, to, brick), "%s is open where it broke" % id)
			continue
		var doors: Array = p.get("doors", [])
		assert_gt(doors.size(), 0, "%s has a door" % id)
		for d: Array in doors:
			var middle: Vector3 = (d[0] as Vector3) + Vector3(0, 1.0, 0)
			var out: Vector3 = d[1]
			var shut: Node = brick
			if bool(s.get("open", false)):
				var door := _oasis().find_child(WadooDoor.NAME, false, false) as WadooDoor
				assert_not_null(door, "%s has its door" % id)
				shut = door.body if door != null else brick
			assert_true(_meets(middle + out * 1.0, middle - out * 1.0, shut), "%s's door is shut" % id)

## How far inside the green's outline (its tufts' and its patch's, round the
## pool's middle on the ground) `at` is, m: under 0 past it.
func _green_edge_of(at: Vector3, centre: Vector3) -> float:
	var axes: Array = _place.layout()["grass_ring"]["axes"]
	var d := Vector2(at.x - centre.x, at.z - centre.z)
	return OasisLooks.green_reach(Vector2(float(axes[0]), float(axes[1])), d.angle(), hash(String(_place.id))) - d.length()

## Rework 2 (the owner: "the grass just ends abruptly"): the tufts thin out
## toward the green's edge, its outer 4 m band under half as thick as the 4 m
## within it, and a scatter of strays lies 2-8 m past it.
func test_the_grass_fades_at_its_edge():
	await _hold_over(0, 0, 60.0)
	var tufts: PackedVector3Array = _oasis().get_node("GrassRing").get_meta(&"tufts")
	var centre := PlaceField.on_ground(_place, _terrain, 0, 0)
	var axes: Array = _place.layout()["grass_ring"]["axes"]
	var seed := hash(String(_place.id))
	var bands := [0, 0]
	var beyond := 0
	for t in tufts:
		var inside := _green_edge_of(t, centre)
		if inside >= 0.0 and inside < 4.0:
			bands[0] += 1
		elif inside >= 4.0 and inside < 8.0:
			bands[1] += 1
		elif inside < -1.0:
			beyond += 1
			assert_gt(inside, -8.5, "a stray no more than 8 m out")
	# The two bands' areas, round the outline.
	var areas := [0.0, 0.0]
	for k in 720:
		var a := TAU * k / 720.0
		var r := OasisLooks.green_reach(Vector2(float(axes[0]), float(axes[1])), a, seed)
		areas[0] += 0.5 * (r * r - pow(r - 4.0, 2)) * TAU / 720.0
		areas[1] += 0.5 * (pow(r - 4.0, 2) - pow(r - 8.0, 2)) * TAU / 720.0
	var outer: float = bands[0] / areas[0]
	var inner: float = bands[1] / areas[1]
	gut.p("tufts a square metre: %.2f in the outer 4 m, %.2f in the 4 m within; %d strays past the edge" % [outer, inner, beyond])
	assert_lt(outer, inner * 0.5, "the outer band is under half as thick")
	assert_gt(outer, 0.0, "but not bare")
	assert_gt(beyond, 8, "a scatter of strays past the edge")

## Rework 2: a way up the ledge on its village side: stone steps, each a tread
## at least 1.2 m deep (its middle +-0.6 m along the stair is the step's own
## top, solid, with the ground under it), each rising no more than 0.7 m from
## the ground at its foot, step to step, and onto the mesa's flat top.
func test_the_ledge_can_be_climbed():
	await _hold_over(-12.2, 70.0, 30.0)
	var ledge := _oasis().get_node_or_null("Ledge")
	assert_not_null(ledge, "the ledge is dressed")
	if ledge == null:
		return
	var steps: Array = ledge.get_meta(&"steps", [])
	assert_gt(steps.size(), 5, "a stair of stones")
	if steps.is_empty():
		return
	var body := ledge.get_node("Stones")
	var at: Array = _place.layout()["ledge"]["at"]
	var top := _ground_y(float(at[0]), float(at[1]))
	var first: Array = steps[0]
	var before: Vector3 = (first[0] as Vector3) - (first[1] as Vector3) * 1.2
	var last_y := _ground_y(before.x, -before.z)
	var rises := []
	for k in steps.size():
		var s: Array = steps[k]
		var mid: Vector3 = s[0]
		var along: Vector3 = s[1]
		for off in [-0.6, 0.0, 0.6]:
			var p: Vector3 = mid + along * off
			var hit := _ray(p + Vector3(0, 2.0, 0), p - Vector3(0, 2.0, 0))
			assert_false(hit.is_empty(), "step %d is solid %.1f m along" % [k, off])
			if not hit.is_empty():
				assert_eq(hit["collider"], body, "step %d: its own stone" % k)
				assert_almost_eq(_oasis().to_local(hit["position"]).y, mid.y, 0.03, "step %d's tread is flat" % k)
			assert_lt(_ground_y(p.x, -p.z), mid.y - 0.01, "step %d: the ground is under its tread" % k)
		rises.append(mid.y - last_y)
		last_y = mid.y
	var lastp: Array = steps[steps.size() - 1]
	var onto: Vector3 = ledge.get_meta(&"landing", Vector3.ZERO)
	var landing := _ground_y(onto.x, -onto.z)
	var reach := Vector2(onto.x - (lastp[0] as Vector3).x, onto.z - (lastp[0] as Vector3).z).length()
	assert_lte(reach, 2.6, "the last step is a stride from the top (%.2f m)" % reach)
	rises.append(landing - last_y)
	gut.p("the stair: %d steps, rises %s, the top %.2f m" % [steps.size(), str(rises.map(func(r): return snappedf(r, 0.01))), top])
	for r in rises:
		assert_gt(r, 0.0, "every step rises")
		assert_lte(r, 0.7, "by no more than 0.7 m")
	assert_almost_eq(landing, top, 0.05, "onto the mesa's flat top")
	assert_eq(_stamp_named("ledge").kind, TerrainStamp.Kind.MESA)
	assert_between(int(ledge.get_meta(&"boulders", 0)), 4, 16, "a few boulders fallen at its foot")
	assert_gt(int(ledge.get_meta(&"talus", 0)), 20, "and a talus of smaller stones")
