extends GutTest

## Strays (docs/superpowers/specs/2026-09-26-saving-design.md §7): kept while
## you are near, forgotten after FORGET_AFTER spent beyond FORGET_BEYOND.

var _here := UniversePoint.at(0, 0, 0)

func _ledger_with_one_at(metres: float) -> StrayLedger:
	var ledger := StrayLedger.new()
	ledger.add(&"mug", 0.3, _here.plus(Vector3(metres, 0, 0)), Basis.IDENTITY, Vector3.ZERO, Vector3.ZERO)
	return ledger

func test_a_stray_near_you_is_kept_however_long():
	var ledger := _ledger_with_one_at(StrayLedger.FORGET_BEYOND - 10.0)
	assert_eq(ledger.tick(StrayLedger.FORGET_AFTER * 10.0, _here), [] as Array[int])
	assert_eq(ledger.entries.size(), 1)

func test_a_far_stray_is_forgotten_after_its_time():
	var ledger := _ledger_with_one_at(StrayLedger.FORGET_BEYOND + 10.0)
	assert_eq(ledger.tick(StrayLedger.FORGET_AFTER - 1.0, _here).size(), 0)
	assert_eq(ledger.tick(1.0, _here).size(), 1)
	assert_eq(ledger.entries.size(), 0)

func test_coming_back_starts_its_clock_again():
	var ledger := _ledger_with_one_at(StrayLedger.FORGET_BEYOND + 10.0)
	ledger.tick(StrayLedger.FORGET_AFTER - 1.0, _here)
	ledger.tick(0.1, _here.plus(Vector3(StrayLedger.FORGET_BEYOND, 0, 0)))
	assert_eq(ledger.tick(StrayLedger.FORGET_AFTER - 1.0, _here).size(), 0)

func test_its_far_time_carries_across_a_save():
	var ledger := _ledger_with_one_at(StrayLedger.FORGET_BEYOND + 10.0)
	ledger.tick(StrayLedger.FORGET_AFTER - 60.0, _here)
	var again := StrayLedger.new()
	again.from_dict(JSON.parse_string(JSON.stringify(ledger.to_dict(), "", false, true)))
	assert_eq(again.entries.size(), 1)
	assert_eq(again.tick(59.0, _here).size(), 0)
	assert_eq(again.tick(1.0, _here).size(), 1)

func test_a_saved_stray_keeps_where_it_is_and_how_it_moves():
	var ledger := StrayLedger.new()
	var at := UniversePoint.at(123456789, -5, 77).plus(Vector3(0.25, 0.5, 0.75))
	ledger.add(&"crate", 0.6, at, Basis(Vector3.UP, 1.0), Vector3(1, 2, 3), Vector3(0, 0.5, 0), {"on": true})
	var again := StrayLedger.new()
	again.from_dict(JSON.parse_string(JSON.stringify(ledger.to_dict(), "", false, true)))
	var e: Dictionary = again.entries.values()[0]
	assert_eq(e["kind"], &"crate")
	assert_true((e["at"] as UniversePoint).is_equal_approx(at))
	assert_true((e["turn"] as Basis).is_equal_approx(Basis(Vector3.UP, 1.0)))
	assert_eq(e["v"], Vector3(1, 2, 3))
	assert_eq(e["use"], {"on": true})
