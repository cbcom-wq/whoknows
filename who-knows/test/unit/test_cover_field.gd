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
	# On a face, across a cube edge, and by a cube's corner (three faces).
	for up: Vector3 in [_up, CubeSphere.direction(0, 0.995, 0.3), CubeSphere.direction(0, 0.996, 0.997)]:
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

## Higher up, the reach along the ground is what the height leaves of
## BOULDER_REACH: every block wanted can be seen within it in the slant.
func test_higher_up_less_is_wanted():
	var t := _terrain()
	var low := _up * (t.radius + t.height_at(_up) + 2.0)
	var high := _up * (t.radius + t.height_at(_up) + CoverField.BOULDER_REACH * 0.9)
	var at_low := CoverField.blocks_near(t, low, CoverField.BOULDER_REACH)
	var at_high := CoverField.blocks_near(t, high, CoverField.BOULDER_REACH)
	assert_gt(at_high.size(), 0)
	assert_lt(at_high.size(), at_low.size() / 2)
	var h := t.altitude_of(high)
	var along := sqrt(CoverField.BOULDER_REACH ** 2 - h * h)
	var here := _up * t.radius
	for b in at_high:
		var bound := CoverField._bound(b, t.radius)
		var d := here.distance_to(bound[0]) - float(bound[1])
		assert_lte(d, along + 0.01, "%s lies within %.0f m along the ground" % [b, along])
	gut.p("%d blocks wanted at 2 m, %d at %.0f m" % [at_low.size(), at_high.size(), CoverField.BOULDER_REACH * 0.9])

## Level flight about BOULDER_REACH up: climbing a little past it wants
## nothing new but frees nothing either, so coming back down asks for nothing.
func test_level_flight_near_the_reach_keeps_its_blocks():
	var s := _surface(CoverField.BOULDER_REACH * 0.9)
	s.cover.finish()
	var first := s.cover.block_keys()
	assert_gt(first.size(), 0)
	s.update(_above(s, CoverField.BOULDER_REACH + 10.0))
	assert_eq(s.cover._wanted.size(), 0, "nothing wanted over the reach")
	assert_eq(s.cover.block_keys().size(), first.size(), "and nothing let go")
	s.update(_above(s, CoverField.BOULDER_REACH * 0.9))
	assert_eq(s.cover.jobs_in_flight(), 0, "back down, nothing to build again")
	assert_eq(s.cover.block_keys().size(), first.size())

## Boarding, a load or a warp's arrival moves the focus far in no time: no
## velocity is read from it, so nothing is biased ahead.
func test_a_jump_has_no_velocity():
	var s := _surface(2.0)
	var along := _up.cross(Vector3.RIGHT).normalized()
	var there := (_up + along * (1000.0 / _planet().radius)).normalized()
	var f := _above(s, 2.0, there)
	s.cover.update(f)
	var at_rest := CoverField.blocks_near(s.terrain, f.minus(_planet().point), CoverField.BOULDER_REACH)
	assert_eq(s.cover._wanted, at_rest)

## Final review, deferred: a choice less than a tick after the last (the
## wall clock's jitter, at very high speed) still reads the velocity, from
## half a tick: the blocks ahead come first.
func test_a_choice_under_a_tick_after_the_last_still_reads_the_velocity():
	var s := _surface(2.0)
	var along := _up.cross(Vector3.RIGHT).normalized()
	s.cover._select_for(_above(s, 2.0))
	var tick := 1.0 / Engine.physics_ticks_per_second
	var dt := tick * 0.75
	var there := (_up + along * (1000.0 * dt / _planet().radius)).normalized()
	var f := _above(s, 2.0, there)
	s.cover._selected_usec = Time.get_ticks_usec() - int(dt * 1e6)
	s.cover._select_for(f)
	var at_rest := CoverField.blocks_near(s.terrain, f.minus(_planet().point), CoverField.BOULDER_REACH)
	var moving := CoverField.blocks_near(s.terrain, f.minus(_planet().point), CoverField.BOULDER_REACH,
		along * 1000.0)
	assert_ne(moving, at_rest, "at 1 km/s the blocks ahead come first")
	assert_ne(s.cover._wanted, at_rest, "the velocity was read")

# --- drawing them ---------------------------------------------------------------

func test_cover_is_what_scatter_says():
	var s := _surface(2.0)
	s.cover.finish()
	assert_gt(s.cover.block_count(), 10)
	var t := _terrain()
	var checked := 0
	var grass_checked := 0
	for b in s.cover.block_keys():
		var block := s.cover.get_node(_name(b)) as Node3D
		assert_not_null(block, "%s is drawn" % b)
		var total := 0
		var first: Array = []
		var first_key := Vector4i.ZERO
		var tufts := {}
		for k in _finest(b):
			var c := GroundCover.scatter(t, k)
			total += c.boulders.size()
			if first.is_empty() and not c.boulders.is_empty():
				first = c.boulders[0]
				first_key = k
			if not c.grass.is_empty():
				tufts[Vector3(TerrainChunkData.centre_of(t, k) - TerrainChunkData.centre_of(t, b))] = c.grass
		# Grass, where it is drawn: one MultiMesh a finest chunk, at its
		# centre, each tuft as scattered.
		var holder := block.get_node_or_null("Grass")
		if holder != null:
			assert_eq(holder.get_child_count(), tufts.size(), "%s: one grass node a finest chunk with tufts" % b)
			for g: MultiMeshInstance3D in holder.get_children():
				assert_true(tufts.has(g.position), "%s's grass node sits at a finest chunk's centre" % b)
				if not tufts.has(g.position):
					continue
				var want_grass: Array = tufts[g.position]
				assert_eq(g.multimesh.instance_count, want_grass.size())
				var gbuf := g.multimesh.buffer
				var gt := AsteroidStream.unpack(gbuf, 0)
				var wt: Transform3D = want_grass[0][0]
				assert_almost_eq(gt.origin, wt.origin, Vector3.ONE * 0.001)
				assert_almost_eq(gt.basis.y, wt.basis.y, Vector3.ONE * 0.001)
				var last := want_grass.size() - 1
				var wc: Color = want_grass[last][1]
				assert_true(Color(gbuf[last * 16 + 12], gbuf[last * 16 + 13], gbuf[last * 16 + 14], gbuf[last * 16 + 15]).is_equal_approx(wc),
					"a tuft's colour is the scatter's")
				grass_checked += 1
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
		var slot := CoverField.tier_slot(first)
		var mm := (block.get_node("Boulders%d_%d" % [slot >> 1, slot & 1]) as MultiMeshInstance3D).multimesh
		var found := false
		var buf := mm.buffer
		var want_colour: Color = first[2]
		for i in mm.instance_count:
			var got := AsteroidStream.unpack(buf, i)
			if got.origin.distance_to(want.origin) < 0.001:
				found = got.basis.x.distance_to(want.basis.x) < 0.001 \
					and got.basis.y.distance_to(want.basis.y) < 0.001 \
					and got.basis.z.distance_to(want.basis.z) < 0.001 \
					and Color(buf[i * 16 + 12], buf[i * 16 + 13], buf[i * 16 + 14], buf[i * 16 + 15]).is_equal_approx(want_colour)
				break
		assert_true(found, "%s's first boulder is where scatter put it, moved by the block's centre" % b)
		var at := _universe.to_engine(_planet().point.plus(Vector3(centre)))
		assert_almost_eq(block.global_position, at, Vector3.ONE * 0.001)
		checked += 1
	assert_gt(checked, 0, "some block has boulders")
	assert_gt(grass_checked, 0, "some grass is drawn and checked")

func test_a_block_is_drawn_as_the_plan_says():
	var s := _surface(2.0)
	s.cover.finish()
	var grass := 0
	var t := _terrain()
	var here := _up * t.radius
	var grass_nodes: Array[MultiMeshInstance3D] = []
	var far_seen := {}
	var shadows_seen := 0
	for b in s.cover.block_keys():
		var block := s.cover.get_node(_name(b)) as Node3D
		var bound := CoverField._bound(b, t.radius)
		var ground := here.distance_to(bound[0]) - float(bound[1])
		var holder := block.get_node_or_null("Grass")
		if ground > CoverField.GRASS_ZONE + CoverField.RESELECT_AFTER:
			assert_null(holder, "%s, %.0f m off, has no grass nodes" % [b, ground])
		for n in block.get_children():
			if n == holder:
				continue
			var m := n as MultiMeshInstance3D
			assert_not_null(m)
			if String(n.name).begins_with("Shadow"):
				# The near stones' shadows, undithered, as far as they are drawn.
				var seen := block.get_node("Boulders" + String(n.name).trim_prefix("Shadow")) as MultiMeshInstance3D
				assert_eq(m.multimesh, seen.multimesh, "%s casts its stones' shadows" % n.name)
				assert_eq(m.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
				assert_same(m.material_override, CoverField.shadow_material())
				assert_eq((m.material_override as StandardMaterial3D).distance_fade_mode, BaseMaterial3D.DISTANCE_FADE_DISABLED)
				var shadow_tier := int(String(n.name).get_slice("_", 1))
				var whole := float(bound[1]) + CoverField.tier_reach(shadow_tier) - CoverField.tier_fade(shadow_tier)
				assert_almost_eq(m.visibility_range_end, minf(seen.visibility_range_end, whole), 0.01,
					"%s's shadows end where its stones begin to fade, or with them" % n.name)
				shadows_seen += 1
				continue
			# "Boulders<shape>_<tier>", its shadows "Shadow<shape>_<tier>" and its
			# twin past the shadows "Far<shape>_<tier>".
			var far := String(n.name).begins_with("Far")
			var label := String(n.name).trim_prefix("Far" if far else "Boulders")
			var shape := int(label.get_slice("_", 0))
			var tier := int(label.get_slice("_", 1))
			# Its middle may lie half a diagonal past its nearest ground.
			var near := CoverField.BOULDER_SHADOW_REACH + float(bound[1])
			var end := CoverField.tier_reach(tier) + float(bound[1])
			# The node's own range never fades: the material's dither does.
			assert_eq(m.visibility_range_fade_mode, GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED)
			assert_same(m.material_override, CoverField.boulder_material(tier), "%s's tier's look" % n.name)
			if far:
				# The same stones past the shadows' reach, without them, to the end.
				var with_shadow := block.get_node("Boulders" + label) as MultiMeshInstance3D
				assert_eq(m.multimesh, with_shadow.multimesh, "%s draws its own MultiMesh" % n.name)
				assert_eq(m.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
				assert_almost_eq(m.visibility_range_begin, near - CoverField.SHADOW_OVERLAP, 0.01)
				assert_almost_eq(m.visibility_range_end, end, 0.01)
				far_seen[tier] = true
				continue
			assert_eq(m.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s's shadows are its Shadow twin's" % n.name)
			assert_not_null(block.get_node_or_null("Shadow" + label), "%s has its shadows" % n.name)
			assert_almost_eq(m.visibility_range_end, minf(near, end), 0.01)
			if end > near:
				assert_not_null(block.get_node_or_null("Far" + label), "%s has its shadowless twin" % n.name)
			assert_eq(m.multimesh.mesh, RockMesh.mesh(shape, 1))
			assert_true(m.multimesh.use_colors, "instance colours")
			var look := m.material_override as StandardMaterial3D
			assert_true(look.vertex_color_use_as_albedo)
			assert_eq(look.roughness, 1.0)
		if holder == null:
			continue
		for n in holder.get_children():
			var m := n as MultiMeshInstance3D
			assert_not_null(m)
			grass_nodes.append(m)
			grass += 1
			assert_eq(m.multimesh.mesh, GroundCover.grass_mesh())
			assert_eq(m.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			assert_eq(m.visibility_range_end, CoverField.GRASS_REACH)
			assert_eq(m.visibility_range_end_margin, 15.0)
			assert_eq((m.material_override as StandardMaterial3D).cull_mode, BaseMaterial3D.CULL_DISABLED)
	assert_eq(far_seen.size(), 2, "both size tiers drawn past the shadows")
	assert_gt(shadows_seen, 0, "near stones cast their shadows")
	for m in grass_nodes:
		assert_eq(m.visibility_range_fade_mode, GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF)
		assert_true(m.multimesh.use_colors, "instance colours")
		var mat := m.material_override as StandardMaterial3D
		assert_true(mat.vertex_color_use_as_albedo)
		assert_eq(mat.roughness, 1.0)
	assert_gt(grass, 16, "a desert has grass, a node a finest chunk")
	gut.p("%d blocks, %d grass nodes" % [s.cover.block_count(), grass])

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
	assert_gt(s.cover.block_count(), 0, "blocks to check")
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

## A guard, not CoverField's own work (Task 4 made boulders solid): a ray down
## onto a boulder GroundCover.scatter puts near an anchor meets the surface's
## collision (WorldSurface's solid finest chunks) on the boulder's top, not
## the ground under it.
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
	# Applying one block: a finished one, made again.
	var b: Vector4i = s.cover._grass_on.keys()[0]
	var data: Variant = s.cover._build(b, s.terrain)
	(s.cover._blocks[b] as Node).free()
	s.cover._blocks.erase(b)
	s.cover._grass_on.erase(b)
	var t2 := Time.get_ticks_usec()
	s.cover._make_block(data)
	var apply := float(Time.get_ticks_usec() - t2)
	# Its grass, a node a finest chunk.
	var t4 := Time.get_ticks_usec()
	s.cover._make_grass(b)
	var grass := float(Time.get_ticks_usec() - t4)
	var grass_nodes := (s.cover._grass[b] as Array).size()
	# Building one on a worker's thread, here.
	var t5 := Time.get_ticks_usec()
	s.cover._build(b, s.terrain)
	var build := float(Time.get_ticks_usec() - t5) / 1000.0
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
	# Reselecting while flying up to a cube edge and on to it at 150 m/s, 20 m
	# a choice from about a kilometre off, the memo warm from the way there;
	# and a first choice by a corner, cold.
	var t := _terrain()
	var memo := {}
	var edge_worst := 0.0
	var edge_samples: Array[float] = []
	var crossed := 0
	var first_cold := 0.0
	var u := 0.97
	var prev := CubeSphere.direction(0, u, 0.3) * t.radius
	while u < 1.0:
		var next := u + 0.0001
		var p := CubeSphere.direction(0, next, 0.3) * t.radius
		if p.distance_to(prev) < CoverField.RESELECT_AFTER and next < 1.0:
			u = next
			continue
		u = next
		var dir := p.normalized()
		var at := dir * (t.radius + t.height_at(dir) + 2.0)
		var v := (p - prev).normalized() * 150.0
		prev = p
		var t6 := Time.get_ticks_usec()
		CoverField._near(t, at, CoverField.BOULDER_REACH, v, memo, CoverField.KEEP_MARGIN)
		var us := float(Time.get_ticks_usec() - t6)
		# The first choice fills the memo: an arrival's cost, not the edge's.
		if crossed > 0:
			edge_worst = maxf(edge_worst, us)
			edge_samples.append(us)
		else:
			first_cold = us
		crossed += 1
	var corner := CubeSphere.direction(0, 0.996, 0.997)
	var corner_at := corner * (t.radius + t.height_at(corner) + 2.0)
	var t7 := Time.get_ticks_usec()
	CoverField._near(t, corner_at, CoverField.BOULDER_REACH, Vector3.ZERO, {}, CoverField.KEEP_MARGIN)
	var cold := float(Time.get_ticks_usec() - t7)
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
	edge_samples.sort()
	var edge_median := edge_samples[edge_samples.size() / 2] if not edge_samples.is_empty() else 0.0
	gut.p("cover tick: idle %.1f us; reselect in the open mean %.0f us, worst %.0f us; flying to a cube edge (%d choices) median %.0f us, worst %.0f us; a first choice, cold, in the open %.0f us, by a corner %.0f us"
		% [idle, total / 20.0, worst, crossed, edge_median, edge_worst, first_cold, cold])
	gut.p("cover tick: one block applied in %.0f us, its grass (%d nodes) in %.0f us; a block built in %.1f ms; streaming %d blocks: %d ticks, mean %.0f us, worst %.0f us"
		% [apply, grass_nodes, grass, build, s.cover.block_count(), ticks, busy / maxf(ticks, 1), busy_worst])
	assert_lt(idle, 50.0, "nothing to do costs next to nothing")
	assert_lt(apply, CoverField.APPLY_BUDGET_USEC * 2.0)
	# The median, not the worst sample (final review M7): one wall-clock sample
	# flaps while a probe or another test shares the machine.
	assert_false(edge_samples.is_empty(), "choices made on the way to the edge")
	assert_lt(edge_median, 1000.0, "a cube edge costs well under a millisecond")

## Task 7b: each size tier fades out by the material's own pixel dither, the
## small first, ending at its reach: no line where the stones stop, and no
## new shader (style guide §3.5).
func test_stones_fade_by_size():
	assert_lt(CoverField.SMALL_REACH, CoverField.BOULDER_REACH, "the small go first")
	assert_gt(CoverField.BOULDER_SHADOW_REACH, 0.0)
	for tier in 2:
		var look := CoverField.boulder_material(tier)
		assert_same(CoverField.boulder_material(tier), look, "one look a tier")
		assert_eq(look.distance_fade_mode, BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER)
		assert_eq(look.distance_fade_min_distance, CoverField.tier_reach(tier), "gone at the reach")
		assert_eq(look.distance_fade_max_distance, CoverField.tier_reach(tier) - CoverField.tier_fade(tier),
			"whole until its fade begins")
		assert_gt(CoverField.tier_fade(tier), 0.0)
		assert_lt(CoverField.tier_fade(tier), CoverField.tier_reach(tier))
	assert_eq(CoverField.grass_material().distance_fade_mode, BaseMaterial3D.DISTANCE_FADE_DISABLED,
		"the grass fades by its range, not the dither")
	# A stone's tier is its size's.
	assert_eq(CoverField.tier_slot([Transform3D(), RockMesh.Shape.SHARD, Color.WHITE, CoverField.BIG_STONE]),
		int(RockMesh.Shape.SHARD) * 2 + 1)
	assert_eq(CoverField.tier_slot([Transform3D(), RockMesh.Shape.BOULDER, Color.WHITE, CoverField.BIG_STONE - 0.01]),
		int(RockMesh.Shape.BOULDER) * 2)
