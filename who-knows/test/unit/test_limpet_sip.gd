extends GutTest

## What a Limpet bed drains (docs/superpowers/specs/2026-10-10-rock-creatures-design.md
## §6.1, §6.3): your suit on a spacewalk, 0.4 QE/s each and 1.2 in all; an awake
## base while you are near, 0.05 QE/s each; never your ship. Run in the real
## flight scene with a bed made on the spot as F10 makes one (the dev spawner's
## path), driven by physics frames.

## The ground a base stands on, as far as Bases.plant asks: the rock `id` names.
class Ground extends PlantSurface:
	var id: StringName = &""
	func fixed() -> bool:
		return true
	func site_id() -> StringName:
		return id
	func rock() -> Vector4i:
		return Vector4i(1, 2, 3, 4)

var _root: Node
var _stream: AsteroidStream
var _avatar: Avatar
var _ship: Ship
var _detail: AsteroidDetail
var _site: RockSite
## The surface point the bed is made on, engine space, and the way up from it.
var _at := Vector3.ZERO
var _out := Vector3.UP

# --- Avatar, SuitCell and Hit, without a scene ---------------------------------

func _hit(drain: float) -> Hit:
	var hit := Hit.make(Vector3.ZERO, Vector3.UP, Vector3.FORWARD, Vector3.ZERO, null)
	hit.drain = drain
	hit.kind = &"sip"
	return hit

func _suited() -> Avatar:
	var world := Node3D.new()
	add_child_autofree(world)
	var avatar: Avatar = load("res://scenes/avatar.tscn").instantiate()
	world.add_child(avatar)
	avatar.mode = Avatar.Mode.SUIT
	avatar.suit_cell.charge = 100.0
	return avatar

func test_the_avatar_takes_a_sip_through_the_suit_cell():
	var avatar := _suited()
	var hit := _hit(0.5)
	avatar.receive_hit(hit)
	assert_almost_eq(hit.drained, 0.5, 0.0001)
	assert_almost_eq(avatar.suit_cell.charge, 99.5, 0.0001)

func test_all_the_sips_in_a_second_are_capped_at_1_2():
	var avatar := _suited()
	assert_eq(Avatar.SIP_CAP, 1.2)
	var taken := 0.0
	for i in 10:
		var hit := _hit(0.5)
		avatar.receive_hit(hit)
		taken += hit.drained
	assert_almost_eq(taken, 1.2, 0.0001, "ten asks of 0.5 at once give the budget, no more")
	assert_almost_eq(avatar.suit_cell.charge, 98.8, 0.0001)

func test_the_budget_refills_at_1_2_a_second():
	var avatar := _suited()
	avatar.receive_hit(_hit(5.0))
	avatar.refill_sip(0.5)
	var hit := _hit(5.0)
	avatar.receive_hit(hit)
	assert_almost_eq(hit.drained, 0.6, 0.0001, "half a second gives back 0.6")
	avatar.refill_sip(10.0)
	hit = _hit(5.0)
	avatar.receive_hit(hit)
	assert_almost_eq(hit.drained, 1.2, 0.0001, "and never more than 1.2 at a time")

func test_a_sip_is_nothing_aboard():
	var avatar := _suited()
	avatar.mode = Avatar.Mode.PLATING
	var hit := _hit(0.5)
	avatar.receive_hit(hit)
	assert_eq(hit.drained, 0.0)
	assert_eq(avatar.suit_cell.charge, 100.0)

func test_a_hit_with_no_drain_leaves_the_suit_alone():
	var avatar := _suited()
	var hit := _hit(0.0)
	hit.damage = 10.0
	avatar.receive_hit(hit)
	assert_eq(avatar.suit_cell.charge, 100.0)
	assert_eq(hit.drained, 0.0)
	assert_almost_eq(avatar.health.current, Avatar.MAX_HEALTH - 10.0, 0.0001, "the damage lands as ever")

# --- in the flight scene ---------------------------------------------------------

func _scene() -> void:
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_stream = _root.get_node("AsteroidStream")
	_avatar = _root.get_node("Ship/Interior/Avatar")
	_ship = _root.get_node("Ship")
	await wait_physics_frames(5)

## On a spacewalk `metres` over the start rock's surface above its first
## skitter's home, the ship 400 m further out, with a bed of `count` Limpets
## made there as F10 makes one, live and settled. Fills the suit.
func _bed(count: int, metres: float) -> void:
	await _scene()
	_detail = _stream.details.nearest(_ship.exterior.global_position)
	var probe := RockSite.new(_detail, _stream.seed)
	_at = probe.frame() * probe.start_pose(probe.records[0], 0.0).origin
	_out = (_at - _detail.global_position).normalized()
	_ship.exterior.global_position = _at + _out * 400.0
	_ship.exterior.linear_velocity = Vector3.ZERO
	var pose := Transform3D(Basis.looking_at(-_out, Vector3.UP), _at + _out * metres)
	_avatar.enter_suit(_root.get_node("Outside"), pose, Vector3.ZERO, _ship.exterior)
	_avatar.suit_cell.charge = 100.0
	await wait_physics_frames(40)
	_site = _root.rock_life.site_for(_detail.rock)
	assert_not_null(_site, "the rock's creatures are on offer")
	var dev: DevCreatures = _root.dev_creatures[_root.exterior_npcs]
	var ids: Array[StringName] = []
	for i in count:
		ids.append(dev.next_id(&"limpet"))
	var dir := _site.data.dir_of(_site.frame().affine_inverse() * _at)
	for record in _site.add_group(&"limpet", dir, count, ids):
		dev.add(record, _site)
	await wait_physics_frames(40)
	assert_eq(_limpets().size(), count, "the bed is live")

func _limpets() -> Array[Npc]:
	var out: Array[Npc] = []
	for npc: Npc in _root.exterior_npcs.live_npcs():
		if npc.record.species == &"limpet":
			out.append(npc)
	return out

func _sipped() -> float:
	var total := 0.0
	for npc in _limpets():
		total += npc.sipped
	return total

func test_one_limpet_sips_0_4_qe_a_second_from_your_suit():
	await _bed(1, 2.0)
	var before := _avatar.suit_cell.charge
	var tally := _sipped()
	await wait_physics_frames(600)
	assert_almost_eq(before - _avatar.suit_cell.charge, 4.0, 0.2, "0.4 QE/s for 10 s")
	assert_almost_eq(_sipped() - tally, before - _avatar.suit_cell.charge, 0.0001, "and the Limpet's tally is what the cell lost")

func test_a_whole_bed_takes_no_more_than_1_2_qe_a_second():
	await _bed(6, 2.0)
	await wait_physics_frames(60 * 4)
	var near := 0
	for npc in _limpets():
		if _avatar.global_position.distance_to(npc.global_position) < npc.species.drain_reach:
			near += 1
	assert_gte(near, 3, "enough of the bed is in reach to ask for more than the cap (%d)" % near)
	var before := _avatar.suit_cell.charge
	await wait_physics_frames(600)
	assert_almost_eq(before - _avatar.suit_cell.charge, 12.0, 0.3, "1.2 QE/s for 10 s, not %d x 4" % near)

func test_a_dry_suit_brings_you_home():
	await _bed(6, 2.5)
	# What main does for any dry suit: the thrusters are off and the emergency
	# cell steers you at home (Avatar.suit_step, Suit.home_step).
	_avatar.home_source = func() -> Vector3: return _ship.exterior.global_position
	_avatar.suit_cell.charge = 0.5
	await wait_physics_frames(120)
	assert_true(_avatar.suit_cell.is_dry(), "the bed ran the cell dry")
	assert_eq(_avatar.suit_cell.charge, 0.0)
	assert_eq(_avatar.busy(), "suit dry, coming home")
	assert_false(_avatar.thrusting, "the thrusters are off")
	await wait_physics_frames(120)
	var home := _ship.exterior.global_position - _avatar.global_position
	assert_gt(_avatar.velocity.length(), 0.1, "the emergency cell has you moving")
	assert_gt(_avatar.velocity.normalized().dot(home.normalized()), 0.8, "toward home")
	assert_eq(_avatar.suit_cell.charge, 0.0, "and the bed has nothing more to take")

func test_the_ships_store_is_never_touched():
	await _bed(6, 2.5)
	var store: QuantumStore = _ship.quantum.store
	store.credit(mini(100, store.room()), &"test")
	var before := store.amount
	var cell_before := _avatar.suit_cell.charge
	await wait_physics_frames(600)
	assert_gt(cell_before - _avatar.suit_cell.charge, 5.0, "they sipped")
	assert_eq(store.amount, before, "the ship's store is as it was")

# --- a base -----------------------------------------------------------------------

## A hub planted so that the bed lies round its middle (as Bases.plant takes a
## hub from a fit), unfolded, its store filled to `qe`. The bed lies on a slope
## and the hub is turned to it, its up the rock's, its long side along the bed.
func _plant_base(qe: int) -> Base:
	var along := Vector3.RIGHT
	var far := 0.0
	for a in _limpets():
		for b in _limpets():
			if a.global_position.distance_to(b.global_position) >= far:
				far = a.global_position.distance_to(b.global_position)
				along = b.global_position - a.global_position
	var x := (along - _out * along.dot(_out)).normalized()
	if x.length() < 0.5:
		x = _out.cross(Vector3.RIGHT if absf(_out.x) < 0.9 else Vector3.BACK).normalized()
	var basis := Basis(x, _out, x.cross(_out)).orthonormalized()
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for npc in _limpets():
		var p := basis.inverse() * npc.global_position
		lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
		hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
	# The hub's cell centres fill a box 4 x 2 x 2 m from its origin: put its
	# middle (2, 1, 1) at the middle of the bed's box.
	var r := Planting.Result.new()
	r.fit = Planting.Fit.OK
	r.frame = Transform3D(basis, basis * ((lo + hi) * 0.5 - Vector3(2, 1, 1)))
	r.legs = PackedFloat32Array([0.5, 0.5, 0.5, 0.5])
	var ground := Ground.new()
	ground.id = _site.id
	var base: Base = _root.bases.plant(ModuleCatalog.HUB, r, ground)
	assert_not_null(base, "the base is planted")
	base.tick_unfold(HabitatValues.UNFOLD + 0.1)
	assert_true(base.quantum.store.credit(qe, &"test"))
	return base

func test_an_awake_base_is_sipped_at_0_05_qe_a_second_each():
	await _bed(6, 50.0)
	var base := _plant_base(150)
	# A Limpet holds the behaviour it is in for its min_time (cling's is 5 s)
	# before it takes up the base: the count starts after that.
	await wait_physics_frames(60 * 7)
	var near := 0
	var bases: Bases = _root.bases
	for npc in _limpets():
		var place: Variant = bases.place_of(_site.id, npc.global_position)
		if place != null and (place as Vector3).distance_to(npc.global_position) < Bases.SIP_REACH:
			near += 1
	assert_eq(near, 6, "the bed is within 4 m of a module")
	assert_gt((_avatar.global_position - _at).length(), RockSite.SUIT_DRAW, "and you are far from the Limpets")
	var before := base.quantum.store.amount
	var tally := _sipped()
	await wait_physics_frames(60 * 60)
	assert_almost_eq(float(before - base.quantum.store.amount), 18.0, 1.0, "6 x 0.05 QE/s for 60 s")
	assert_almost_eq(_sipped(), 18.0 + tally, 1.0, "and that is what the Limpets say they took")
	assert_eq(_avatar.suit_cell.charge, 100.0, "your suit untouched")

func test_a_base_is_not_sipped_with_no_one_near():
	await _bed(6, 50.0)
	var base := _plant_base(150)
	# Away: you and your ship 5 km off. The base stays awake (it sleeps past
	# 20 km), and its own body keeps the bed live.
	_ship.exterior.global_position += Vector3(5000, 0, 0)
	_avatar.global_position += Vector3(5000, 0, 0)
	await wait_physics_frames(60)
	assert_same(_root.bases.named(base.site.id), base, "the base is awake")
	assert_eq(_limpets().size(), 6, "and the bed is live, so the store is spared by the rule, not by their absence")
	var before := base.quantum.store.amount
	await wait_physics_frames(60 * 30)
	assert_eq(base.quantum.store.amount, before)

func test_an_asleep_base_is_not_sipped():
	await _bed(6, 50.0)
	var base := _plant_base(150)
	var bases: Bases = _root.bases
	var point: Vector3 = bases.place_of(_site.id, _at)
	assert_gt(bases.sip(_site.id, point, 1.0), 0.0, "awake and in reach, it gives")
	bases.set_physics_process(false)
	bases.sleep(base.site.id)
	assert_null(bases.place_of(_site.id, _at), "a slept base has no place")
	assert_eq(bases.sip(_site.id, point, 1.0), 0.0, "and gives nothing")
	assert_eq(bases.site_named(base.site.id).store, 149, "what it held is kept as it was, less the one QE")
	await wait_physics_frames(2)

func test_a_base_out_of_reach_is_not_sipped():
	await _bed(1, 50.0)
	var base := _plant_base(150)
	var bases: Bases = _root.bases
	var near: Vector3 = bases.place_of(_site.id, _at)
	assert_eq(bases.sip(_site.id, near + _out * (Bases.SIP_REACH + 20.0), 1.0), 0.0, "past SIP_REACH of every module")
	assert_eq(bases.sip(&"rock:elsewhere", near, 1.0), 0.0, "another rock's base is no concern")
	assert_eq(base.quantum.store.amount, 150)

# --- the pay (rock creatures spec §6.4) --------------------------------------------

## Every husk the stray field holds, near or far.
func _husks() -> int:
	return _root.strays.count_of(&"limpet_husk", _at, 100000.0)

## Kills `npc` having sipped `qe`, and returns how many husks lie within a metre
## of where it died, counting only the new ones.
func _kill_after_sipping(npc: Npc, qe: float) -> int:
	npc.sipped = qe
	var before: int = _root.strays.count_of(&"limpet_husk", npc.global_position, 1.0)
	npc.take_damage(100.0)
	assert_true(npc.down, "it is dead")
	return _root.strays.count_of(&"limpet_husk", npc.global_position, 1.0) - before

func test_a_lean_limpet_leaves_one_husk_and_a_fat_one_up_to_four():
	await _bed(3, 50.0)
	var bed := _limpets()
	# Limpets in a bed lie more than a metre from each other by the time they
	# have settled; kill them one at a time, far from the others' husks.
	var all_before := _husks()
	assert_eq(_kill_after_sipping(bed[0], 0.0), 1, "sipped nothing: one husk")
	assert_eq(_kill_after_sipping(bed[1], 95.0), 3, "95 QE: 1 + floor(95 / 40) = 3")
	assert_eq(_kill_after_sipping(bed[2], 400.0), 4, "400 QE: capped at four")
	assert_eq(_husks() - all_before, 8)

func test_the_husks_are_at_rest_and_worth_20_qe():
	await _bed(1, 50.0)
	var npc := _limpets()[0]
	npc.take_damage(100.0)
	var found := 0
	for item: Item in get_tree().get_nodes_in_group(Item.GROUP):
		if item.definition.id != &"limpet_husk":
			continue
		found += 1
		assert_true(item.in_space, "outside")
		assert_eq(item.linear_velocity, Vector3.ZERO)
		assert_eq(item.definition.quantum_value, 20)
		assert_lt(item.global_position.distance_to(npc.global_position), 1.0, "where it died")
	assert_eq(found, 1)

func test_a_dead_limpet_stays_dead():
	await _bed(1, 50.0)
	var npc := _limpets()[0]
	var record := npc.record
	npc.take_damage(100.0)
	assert_true(_root.npc_ledger.is_dead(record.id), "the ledger has it")
	assert_null(_root.exterior_npcs.amend(record), "and a review will not offer it again")
	_root.exterior_npcs.review()
	await wait_physics_frames(5)
	for other: Npc in _limpets():
		assert_ne(other.record.id, record.id, "it is not woken")

## StrayField.count_of counts by kind and distance, an unloaded stray as well
## as a live one (the Delver's grit cap reads it, spec §5.4).
func test_count_of_counts_by_kind_and_distance_loaded_or_not():
	await _scene()
	var strays: StrayField = _root.strays
	var here: Vector3 = _ship.exterior.global_position + Vector3(0, 50, 0)
	_root._drop(&"limpet_husk", here, Vector3.UP, 3)
	_root._drop(&"limpet_husk", here + Vector3(0, 0, 5000), Vector3.UP, 2)
	await wait_physics_frames(2)
	assert_eq(strays.count_of(&"limpet_husk", here, 1.0), 3, "the three at hand, to the metre")
	assert_eq(strays.count_of(&"limpet_husk", here, 10000.0), 5, "and the two 5 km off, unloaded or not")
	assert_eq(strays.count_of(&"mug", here, 10000.0), 0, "only of its kind")
	assert_eq(_root.rock_life.count_near.call(&"limpet_husk", here, 1.0), 3, "and the flight scene hands it on")
