extends GutTest

## SalvageLedger (docs/superpowers/specs/2026-09-24-quantum-energy-design.md
## §10.3): what has been taken, by cloud id and index. Pure; nothing taken
## comes back.

func test_nothing_is_taken_at_first():
	var ledger := SalvageLedger.new()
	assert_false(ledger.is_taken(&"near", 0))
	assert_eq(ledger.remaining(&"near", 12), 12)

func test_a_taken_item_is_remembered_by_cloud_and_index():
	var ledger := SalvageLedger.new()
	ledger.take(&"near", 3)
	assert_true(ledger.is_taken(&"near", 3))
	assert_false(ledger.is_taken(&"near", 4), "only that index")
	assert_false(ledger.is_taken(&"elsewhere", 3), "only that cloud")

func test_remaining_counts_down_and_stops_at_nothing():
	var ledger := SalvageLedger.new()
	for i in 3:
		ledger.take(&"near", i)
		assert_eq(ledger.remaining(&"near", 3), 2 - i)
	assert_eq(ledger.remaining(&"elsewhere", 3), 3, "another cloud is untouched")

func test_taking_the_same_item_twice_counts_once():
	var ledger := SalvageLedger.new()
	ledger.take(&"near", 5)
	ledger.take(&"near", 5)
	assert_eq(ledger.remaining(&"near", 12), 11)
