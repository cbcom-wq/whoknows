extends GutTest

## ShipRules (docs/superpowers/specs/2026-10-02-ship-library-design.md §4):
## the starter breaks none, and each rule is broken by a copy of the starter
## broken just that way (spec §11 says how each was chosen). Notes never count.

var _cat: BlockCatalog
var _g: ShipGrid

func before_all():
	_cat = BlockCatalog.load_from_dir("res://data/blocks")

func before_each():
	_g = ShipLibrary.load_from_dir().grid(ShipLibrary.STARTER)

func _put(coord: Vector3i, id: StringName, o := 0) -> void:
	var i := BlockInstance.new()
	i.block_id = id
	i.orientation = o
	_g.set_block(coord, i)

static func _codes(items: Array) -> Array:
	return items.map(func(i: Dictionary) -> StringName: return i["code"])

## The first rule broken with `code`, after asserting there is one.
func _breaks(code: StringName) -> Dictionary:
	var found := ShipRules.check(_g, _cat)
	assert_has(_codes(found["rules"]), code, "breaks %s (found %s)" % [code, found["rules"]])
	for i in found["rules"]:
		if i["code"] == code:
			return i
	return {"text": "", "cell": null}

func test_the_starter_breaks_no_rule():
	var found := ShipRules.check(_g, _cat)
	assert_eq(found["rules"], [], "broken: %s" % [found["rules"]])

func test_notes_never_count_as_rules():
	var notes: Array = ShipRules.check(_g, _cat)["notes"]
	assert_eq(_codes(notes).count(&"RCS_BLOCKED"), 6, "six of the starter's eight rcs fire into a neighbour")
	assert_has(_codes(notes), &"FEEL")
	assert_has(_codes(notes), &"SIZE")

func test_an_unknown_block_is_named_and_nothing_else_is_checked():
	_put(Vector3i(0, 0, 0), &"warp_banana")
	var rules: Array = ShipRules.check(_g, _cat)["rules"]
	assert_eq(_codes(rules), [&"UNKNOWN_BLOCK"])
	assert_eq(rules[0]["cell"], Vector3i(0, 0, 0))
	assert_string_contains(rules[0]["text"], "warp_banana")

func test_the_validator_speaks_through_its_rule():
	_g.clear_block(Vector3i(0, 1, -1))
	assert_string_contains(_breaks(&"VALIDATOR")["text"], "SINGLE_CORE")

func test_power_needs_ten_percent_to_spare():
	_put(Vector3i(0, 2, 3), &"thruster")
	_breaks(&"POWER_MARGIN")
	assert_does_not_have(_codes(ShipRules.check(_g, _cat)["rules"]), &"VALIDATOR",
		"inside the validator's own margin")

func test_with_no_main_thruster_it_cannot_thrust():
	for c in _g.coords():
		if _g.get_block(c).block_id == &"thruster":
			_put(c, &"hull")
	_breaks(&"CANNOT_THRUST")

func test_without_the_retro_pair_it_cannot_brake():
	_g.clear_block(Vector3i(-2, 1, -2))
	_g.clear_block(Vector3i(2, 1, -2))
	_breaks(&"CANNOT_BRAKE")

func test_without_the_nose_pair_it_cannot_yaw():
	_g.clear_block(Vector3i(-1, 1, -4))
	_g.clear_block(Vector3i(1, 1, -4))
	assert_string_contains(_breaks(&"NO_AUTHORITY")["text"], "yaw")

func test_the_stern_bank_a_deck_down_pitches_it_under_burn():
	for x in [-1, 0, 1]:
		_put(Vector3i(x, 1, 3), &"hull")
		_put(Vector3i(x, -1, 3), &"thruster")
	assert_string_contains(_breaks(&"UNBALANCED")["text"], "pitch")

func test_every_thruster_wrecked_it_is_crippled():
	var hp := _cat.get_def(&"thruster").hp
	for c in _g.coords():
		if _g.get_block(c).block_id == &"thruster":
			_g.get_block(c).damage = hp * BlockDamage.WRECKED_AT
	_breaks(&"CRIPPLED")

func test_with_the_canopy_row_made_hull_there_is_no_pod():
	for x in [-1, 0, 1]:
		_put(Vector3i(x, 0, -4), &"hull")
	_breaks(&"NO_HELM")

func test_boxed_in_you_cannot_stand_up_from_the_helm():
	for c in [Vector3i(0, 0, -2), Vector3i(-1, 0, -3), Vector3i(1, 0, -3)]:
		_put(c, &"hull")
	assert_eq(_breaks(&"NO_STAND")["cell"], Vector3i(0, 0, -3), "at the helm")

func test_with_the_airlock_made_deck_nothing_cycles():
	_put(Vector3i(0, 0, 3), &"deck")
	_breaks(&"NO_AIRLOCK")

func test_a_wall_across_the_corridor_cuts_off_the_stern():
	_put(Vector3i(0, 0, 1), &"hull")
	var cut := _breaks(&"CUT_OFF")
	assert_string_contains(cut["text"], "can't be reached on foot")
	assert_eq(cut["cell"], Vector3i(-1, 0, 2), "the first of them")

func test_a_deck_upstairs_is_cut_off_until_ladders_climb():
	_put(Vector3i(0, 2, 0), &"deck")
	_put(Vector3i(0, 2, 1), &"deck")
	var found: Array = ShipRules.check(_g, _cat)["rules"].filter(
		func(i: Dictionary) -> bool: return i["code"] == &"CUT_OFF")
	assert_eq(found.size(), 1)
	assert_string_contains(found[0]["text"], "storey 2")
	assert_string_contains(found[0]["text"], "ladders don't climb yet")
	assert_eq(found[0]["cell"], Vector3i(0, 2, 0))

func test_a_shaped_block_beside_a_porthole_leaves_it_no_window():
	_put(Vector3i(-2, 0, -2), &"fairing_slope_long_low", 8)
	assert_eq(_breaks(&"WINDOW_UNMATCHED")["cell"], Vector3i(-1, 0, -2))

func test_a_closet_in_a_pocket_of_its_own_strands_the_droid():
	_put(Vector3i(1, 0, 2), &"bulkhead")
	_put(Vector3i(3, 0, 0), &"closet")
	assert_string_contains(_breaks(&"DROID")["text"], "dock at (3, 0, 0)")

func test_a_bow_with_nothing_to_lose_never_shows_a_hole():
	var held := Ship.inner_of(_g, _cat)
	var d := ShipDamage.build(_g, _cat, held)
	for c: Vector3i in d.sections_of:
		if (d.sections_of[c] as Array).has(&"starboard_bow") and not held.has(c) \
				and ShipDamage.STRUCTURE.has(_g.get_block(c).block_id):
			_put(c, &"grav_plating")
	assert_string_contains(_breaks(&"NO_PIECES")["text"], "starboard bow")

const BRIDGE := "res://test/fixtures/bridge/bridge.json"

func _bridge() -> ShipGrid:
	return ShipLibrary.read(BRIDGE)["grid"]

func _codes_of(grid: ShipGrid) -> Array:
	var out := []
	for r in ShipRules.check(grid, BlockCatalog.load_from_dir("res://data/blocks"))["rules"]:
		out.append(r["code"])
	return out

func _set_block(grid: ShipGrid, c: Vector3i, id: StringName, o := 0) -> void:
	var inst := BlockInstance.new()
	inst.block_id = id
	inst.orientation = o
	grid.set_block(c, inst)

func test_the_bridge_fixture_breaks_no_rule():
	assert_eq(_codes_of(_bridge()), [])

func test_no_glass_ahead_of_the_helm_breaks_no_helm():
	var g := _bridge()
	_set_block(g, Vector3i(0, 0, -5), &"hull")
	assert_has(_codes_of(g), &"NO_HELM")

func test_two_helms_breaks_two_helms():
	var g := _bridge()
	_set_block(g, Vector3i(-1, 0, -4), &"pilot_seat")
	assert_has(_codes_of(g), &"TWO_HELMS")

func test_a_station_with_nowhere_to_stand_breaks_no_stand():
	var g := _bridge()
	for c in [Vector3i(-2, 0, -3), Vector3i(-1, 0, -4)]:
		_set_block(g, c, &"hull")
	assert_has(_codes_of(g), &"NO_STAND")

func test_a_chair_facing_a_wall_breaks_seat_faces_wall():
	var g := _bridge()
	_set_block(g, Vector3i(0, 0, -3), &"hull")
	assert_has(_codes_of(g), &"SEAT_FACES_WALL")

func test_a_blocked_ramp_breaks_dais_blocked():
	var g := _bridge()
	_set_block(g, Vector3i(0, 0, -1), &"hull")
	assert_has(_codes_of(g), &"DAIS_BLOCKED")

func test_the_starter_still_breaks_none():
	assert_eq(_codes_of(ShipLibrary.load_from_dir().grid(&"starter")), [])
