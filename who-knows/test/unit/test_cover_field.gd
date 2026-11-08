extends GutTest

## The ground cover drawn round you (phase 2 plan, Task 5; call 9): blocks
## BLOCK_UP levels coarser than the finest chunks, out to BOULDER_REACH, built
## on workers from GroundCover.scatter, each a member of the exterior space
## placed from its UniversePoint, none at all high up.

var _universe: Universe
var _system: SystemRecipe
## Off the cube's grid lines, as test_world_surface's.
var _up := Vector3(0.31, 0.9, 0.22).normalized()

func before_all():
	RockMesh.warm()
	GroundCover.grass_mesh()

var _made: WorldSurface

## A job runs a method on its surface, which locks it: GUT's free() would
## refuse it. Wait for them first.
func after_each():
	WorldSurface.warn_on_floor = true
	if is_instance_valid(_made):
		for id: int in _made._jobs.values():
			WorkerThreadPool.wait_for_task_completion(id)
		_made._jobs.clear()
		_made.cover.wait_for_jobs()
	_made = null

func after_all():
	_system = null

## System 1337's p3: a desert, with thick air.
func _planet() -> SystemBody:
	if _system == null:
		_system = SystemRecipe.from_seed(1337)
	return _system.body(&"p3")

func _surface(altitude: float, up := _up) -> WorldSurface:
	_universe = Universe.new()
	add_child_autofree(_universe)
	var p := _planet()
	var s := WorldSurface.new()
	s.setup(p, _universe)
	add_child_autofree(s)
	_made = s
	s.build_roots()
	var focus := _above(s, altitude, up)
	_universe.origin = focus
	s.update(focus)
	return s

func _above(s: WorldSurface, altitude: float, up := _up) -> UniversePoint:
	var p := _planet()
	return p.point.plus(up * (p.radius + s.terrain.height_at(up) + altitude))

func _terrain() -> WorldTerrain:
	return WorldTerrain.new(_planet().recipe)

static func _block_of(key: Vector4i) -> Vector4i:
	var b := key
	for i in CoverField.BLOCK_UP:
		b = CubeSphere.parent(b)
	return b

## A block's finest keys.
static func _finest(block: Vector4i) -> Array[Vector4i]:
	var out: Array[Vector4i] = [block]
	for i in CoverField.BLOCK_UP:
		var next: Array[Vector4i] = []
		for k in out:
			next.append_array(CubeSphere.children(k))
		out = next
	return out

static func _name(key: Vector4i) -> String:
	return "Cover_%d_%d_%d_%d" % [key.x, key.y, key.z, key.w]

# --- choosing the blocks ------------------------------------------------------

func test_blocks_near_cover_the_reach():
	var t := _terrain()
	var depth := CubeSphere.depth_for(t.radius)
	var edge := CubeSphere.edge_m(t.radius, depth - CoverField.BLOCK_UP)
	# On a face, and across a cube edge.
	for up: Vector3 in [_up, CubeSphere.direction(0, 0.995, 0.3)]:
		var local := up * (t.radius + t.height_at(up) + 2.0)
		var blocks := CoverField.blocks_near(t, local, CoverField.BOULDER_REACH)
		assert_gt(blocks.size(), 0)
		var have := {}
		for b in blocks:
			assert_eq(b.y, depth - CoverField.BLOCK_UP, "a block is BLOCK_UP over the finest")
			have[b] = true
		assert_eq(have.size(), blocks.size(), "each block once")
		var inside := 0
		for k in TerrainCollider.keys_near(t, depth, local, CoverField.BOULDER_REACH + 64.0):
			if Vector3(TerrainChunkData.centre_of(t, k)).distance_to(local) > CoverField.BOULDER_REACH:
				continue
			inside += 1
			assert_true(have.has(_block_of(k)), "%s's block %s is asked for" % [k, _block_of(k)])
		assert_gt(inside, 100)
		for b in blocks:
			var d := Vector3(TerrainChunkData.centre_of(t, b)).distance_to(local)
			assert_lte(d, CoverField.BOULDER_REACH + edge, "%s is %.0f m off" % [b, d])
		gut.p("%d blocks of %.0f m within %.0f m (%d finest keys)" % [blocks.size(), edge,
			CoverField.BOULDER_REACH, inside])

func test_blocks_ahead_are_asked_for_first():
	var t := _terrain()
	var local := _up * (t.radius + t.height_at(_up) + 2.0)
	var v := _up.cross(Vector3.RIGHT).normalized() * 150.0
	var blocks := CoverField.blocks_near(t, local, CoverField.BOULDER_REACH, v)
	var quarter := blocks.size() / 4
	assert_gt(quarter, 3)
	for i in quarter:
		var to := Vector3(TerrainChunkData.centre_of(t, blocks[i])) - local
		assert_gt(to.dot(v), 0.0, "block %d of %d (%s) lies ahead" % [i, blocks.size(), blocks[i]])
	# Nothing beside you is left out for the ones ahead.
	for b in CoverField.blocks_near(t, local, CoverField.BOULDER_REACH):
		assert_true(blocks.has(b), "%s is still asked for" % b)

func test_nothing_high_up():
	var t := _terrain()
	var high := _up * (t.radius + t.height_at(_up) + CoverField.BOULDER_REACH + 10.0)
	assert_eq(CoverField.blocks_near(t, high, CoverField.BOULDER_REACH).size(), 0)
	var s := _surface(500.0)
	s.cover.finish()
	assert_eq(s.cover.block_count(), 0)
	assert_eq(s.cover.get_child_count(), 0)

# --- drawing them ---------------------------------------------------------------

func test_cover_is_what_scatter_says():
	var s := _surface(2.0)
	s.cover.finish()
	assert_gt(s.cover.block_count(), 10)
	var t := _terrain()
	var checked := 0
	for b in s.cover.block_keys():
		var block := s.cover.get_node(_name(b)) as Node3D
		assert_not_null(block, "%s is drawn" % b)
		var total := 0
		var first: Array = []
		var first_key := Vector4i.ZERO
		for k in _finest(b):
			var c := GroundCover.scatter(t, k)
			total += c.boulders.size()
			if first.is_empty() and not c.boulders.is_empty():
				first = c.boulders[0]
				first_key = k
		var drawn := 0
		for n in block.get_children():
			if n.name.begins_with("Boulders"):
				drawn += (n as MultiMeshInstance3D).multimesh.instance_count
		assert_eq(drawn, total, "%s draws every boulder its finest keys scatter" % b)
		if first.is_empty():
			continue
		var centre := TerrainChunkData.centre_of(t, b)
		var want: Transform3D = first[0]
		want.origin += Vector3(TerrainChunkData.centre_of(t, first_key) - centre)
		var mm := (block.get_node("Boulders%d" % int(first[1])) as MultiMeshInstance3D).multimesh
		var found := false
		var buf := mm.buffer
		for i in mm.instance_count:
			var got := AsteroidStream.unpack(buf, i)
			if got.origin.distance_to(want.origin) < 0.001:
				found = got.basis.x.distance_to(want.basis.x) < 0.001 \
					and got.basis.y.distance_to(want.basis.y) < 0.001 \
					and got.basis.z.distance_to(want.basis.z) < 0.001
				break
		assert_true(found, "%s's first boulder is where scatter put it, moved by the block's centre" % b)
		var at := _universe.to_engine(_planet().point.plus(Vector3(centre)))
		assert_almost_eq(block.global_position, at, Vector3.ONE * 0.001)
		checked += 1
	assert_gt(checked, 0, "some block has boulders")

func test_a_block_is_drawn_as_the_plan_says():
	var s := _surface(2.0)
	s.cover.finish()
	var grass := 0
	for b in s.cover.block_keys():
		var block := s.cover.get_node(_name(b)) as Node3D
		for n in block.get_children():
			var m := n as MultiMeshInstance3D
			assert_not_null(m)
			assert_eq(m.visibility_range_fade_mode, GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF)
			assert_true(m.multimesh.use_colors, "instance colours")
			var mat := m.material_override as StandardMaterial3D
			assert_true(mat.vertex_color_use_as_albedo)
			assert_eq(mat.roughness, 1.0)
			if n.name == "Grass":
				grass += 1
				assert_eq(m.multimesh.mesh, GroundCover.grass_mesh())
				assert_eq(m.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
				assert_eq(m.visibility_range_end, CoverField.GRASS_REACH)
				assert_eq(m.visibility_range_end_margin, 15.0)
				assert_eq(mat.cull_mode, BaseMaterial3D.CULL_DISABLED)
			else:
				assert_eq(m.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
				assert_eq(m.visibility_range_end, CoverField.BOULDER_REACH)
				assert_eq(m.visibility_range_end_margin, 40.0)
				var shape := int(String(n.name).trim_prefix("Boulders"))
				assert_eq(m.multimesh.mesh, RockMesh.mesh(shape, 1))
	assert_gt(grass, 0, "a desert has grass")

func test_far_blocks_go():
	var s := _surface(2.0)
	s.cover.finish()
	var first := s.cover.block_keys()
	assert_gt(first.size(), 0)
	var along := _up.cross(Vector3.RIGHT).normalized()
	var there := (_up + along * (1000.0 / _planet().radius)).normalized()
	s.update(_above(s, 2.0, there))
	s.cover.finish()
	assert_gt(s.cover.block_count(), 0)
	for b in s.cover.block_keys():
		assert_false(first.has(b), "%s from the first place is gone" % b)
	for b in first:
		var n := s.cover.get_node_or_null(_name(b))
		assert_true(n == null or n.is_queued_for_deletion(), "%s's node goes" % b)

func test_blocks_follow_a_shift():
	var s := _surface(2.0)
	s.cover.finish()
	assert_false(s.cover.is_in_group(Universe.EXTERIOR_SPACE), "the field never moves")
	assert_eq(s.cover.global_transform, Transform3D.IDENTITY)
	var t := _terrain()
	var check := func() -> void:
		for b in s.cover.block_keys():
			var block := s.cover.get_node(_name(b)) as Node3D
			assert_true(block.is_in_group(Universe.EXTERIOR_SPACE), "%s shifts" % b)
			var want := _planet().point.plus(Vector3(TerrainChunkData.centre_of(t, b)))
			var got := _universe.to_universe(block.global_position)
			assert_lt(got.minus(want).length(), 0.001, "%s is at its UniversePoint" % b)
	check.call()
	_universe.shift(Vector3(2000, 0, -1000))
	check.call()
	assert_eq(s.cover.global_transform, Transform3D.IDENTITY)

## Task 4 made boulders solid; here the ray proves the drawn one is the solid
## one, in the field's own frame.
func test_boulders_are_solid_where_the_ground_is():
	var s := _surface(2.0)
	var t := s.terrain
	var depth := CubeSphere.depth_for(t.radius)
	var under := CubeSphere.key_for(_up, depth)
	var key := Vector4i(-1, 0, 0, 0)
	var boulder: Array = []
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var k := Vector4i(under.x, depth, under.z + dx, under.w + dy)
			for b: Array in GroundCover.scatter(t, k).boulders:
				if float(b[3]) >= 1.2:
					key = k
					boulder = b
					break
			if not boulder.is_empty():
				break
		if not boulder.is_empty():
			break
	assert_false(boulder.is_empty(), "a boulder near by")
	if boulder.is_empty():
		return
	var place: Transform3D = boulder[0]
	var local := Vector3(TerrainChunkData.centre_of(t, key)) + place.origin
	var up := local.normalized()
	var anchor := RigidBody3D.new()
	anchor.freeze = true
	anchor.collision_mask = BodyProxy.LAYER
	anchor.add_to_group(AsteroidStream.SPACE_ANCHOR)
	anchor.add_to_group(Universe.EXTERIOR_SPACE)
	add_child_autofree(anchor)
	var p := _planet()
	anchor.global_position = _universe.to_engine(p.point.plus(local + up * (float(boulder[3]) + 2.0)))
	s.update(_universe.to_universe(anchor.global_position))
	await wait_physics_frames(2)
	var top := _universe.to_engine(p.point.plus(local))
	var query := PhysicsRayQueryParameters3D.create(top + up * 10.0, top - up * 10.0, BodyProxy.LAYER)
	var hit := s.get_world_3d().direct_space_state.intersect_ray(query)
	assert_false(hit.is_empty(), "the ray meets something solid")
	if hit.is_empty():
		return
	var hit_local := _universe.to_universe(hit.position).minus(p.point)
	var over := t.altitude_of(hit_local)
	assert_gt(over, 0.25 * float(boulder[3]), "the ray stops on the boulder's top, %.2f m over the ground" % over)

# --- cost -------------------------------------------------------------------------

## What a tick costs on the main thread: with nothing to do, and applying a
## block (call 9: low flight is at 122-128 fps against 120).
func test_a_tick_is_cheap():
	var s := _surface(2.0)
	s.cover.finish()
	var focus := _above(s, 2.0)
	s.cover.update(focus)
	var t0 := Time.get_ticks_usec()
	for i in 1000:
		s.cover.update(focus)
	var idle := (Time.get_ticks_usec() - t0) / 1000.0
	# A tick that reselects: moved RESELECT_AFTER, at 150 m/s low flight.
	var along := _up.cross(Vector3.RIGHT).normalized()
	var worst := 0.0
	var total := 0.0
	for i in 20:
		var there := (_up + along * ((i + 1) * CoverField.RESELECT_AFTER / _planet().radius)).normalized()
		var f := _above(s, 2.0, there)
		s.cover._selected_usec = Time.get_ticks_usec() - int(CoverField.RESELECT_AFTER / 150.0 * 1e6)
		var t1 := Time.get_ticks_usec()
		s.cover._select_for(f)
		var us := float(Time.get_ticks_usec() - t1)
		worst = maxf(worst, us)
		total += us
	# Applying one block: a finished one, made again.
	var b: Vector4i = s.cover.block_keys()[0]
	var data: Variant = s.cover._build(b, s.terrain)
	(s.cover._blocks[b] as Node).free()
	s.cover._blocks.erase(b)
	var t2 := Time.get_ticks_usec()
	s.cover._make_block(data)
	var apply := float(Time.get_ticks_usec() - t2)
	# Streaming: 1 km on, ticks every 2 ms until it has caught up.
	var far := (_up + along * (1000.0 / _planet().radius)).normalized()
	var f2 := _above(s, 2.0, far)
	s.cover._selected_usec = Time.get_ticks_usec() - int(1000.0 / 150.0 * 1e6)
	var ticks := 0
	var busy := 0.0
	var busy_worst := 0.0
	s.cover.update(f2)
	while not s.cover._settled and ticks < 5000:
		OS.delay_usec(2000)
		var t3 := Time.get_ticks_usec()
		s.cover.update(f2)
		var us := float(Time.get_ticks_usec() - t3)
		busy += us
		busy_worst = maxf(busy_worst, us)
		ticks += 1
	assert_true(s.cover._settled, "it catches up")
	gut.p("cover tick: idle %.1f us; reselect mean %.0f us, worst %.0f us; one block applied in %.0f us; streaming %d blocks: %d ticks, mean %.0f us, worst %.0f us"
		% [idle, total / 20.0, worst, apply, s.cover.block_count(), ticks, busy / maxf(ticks, 1), busy_worst])
	assert_lt(idle, 50.0, "nothing to do costs next to nothing")
	assert_lt(apply, CoverField.APPLY_BUDGET_USEC * 2.0)
