extends GutTest

## QuantumStore (quantum energy spec §3.2, §15.1): the store's own rules, in
## isolation from the plant that owns one and the flight computer that
## spends it.

func test_the_line_is_ten_percent_rounded_up():
	var s := QuantumStore.new(1200, 600)
	assert_eq(s.line(), 120)
	var odd := QuantumStore.new(1205, 600)
	assert_eq(odd.line(), 121, "rounds up, not to the nearest")

func test_low_power_below_the_line_full_power_at_it():
	var s := QuantumStore.new(1200, 120)
	assert_false(s.is_low_power(), "at the line: full power")
	s.spend(1, &"test")
	assert_true(s.is_low_power(), "one below: low power")

func test_room_is_capacity_minus_amount():
	var s := QuantumStore.new(1200, 600)
	assert_eq(s.room(), 600)

func test_spend_is_all_or_nothing():
	var s := QuantumStore.new(1200, 100)
	assert_false(s.can_spend(101))
	assert_false(s.spend(101, &"test"))
	assert_eq(s.amount, 100, "refused, so nothing changed")
	assert_true(s.spend(100, &"test"))
	assert_eq(s.amount, 0)

func test_a_spend_may_take_the_store_to_zero():
	var s := QuantumStore.new(1200, 5)
	assert_true(s.spend(5, &"test"))
	assert_eq(s.amount, 0)

func test_a_credit_over_capacity_is_refused():
	var s := QuantumStore.new(1200, 1150)
	assert_false(s.credit(51, &"test"))
	assert_eq(s.amount, 1150, "refused, not partly wasted")
	assert_true(s.credit(50, &"test"), "exactly fills it")
	assert_eq(s.amount, 1200)

func test_drain_takes_at_most_whats_there_and_returns_it():
	var s := QuantumStore.new(1200, 10)
	assert_eq(s.drain(50, &"test"), 10, "down to 0, never negative")
	assert_eq(s.amount, 0)
	assert_eq(s.drain(1, &"test"), 0, "nothing left to take")

func test_set_capacity_clamps_the_amount_without_restocking():
	var s := QuantumStore.new(1200, 600)
	s.set_capacity(400)
	assert_eq(s.capacity, 400)
	assert_eq(s.amount, 400, "clamped down")
	s.set_capacity(1200)
	assert_eq(s.amount, 400, "a bigger capacity does not restock it")

## The pilot light (§3.2): below 25, +1 QE every 5 s, and never above 25.

func test_the_pilot_light_credits_one_qe_every_five_seconds():
	var s := QuantumStore.new(1200, 0)
	s.tick(4.9)
	assert_eq(s.amount, 0, "not yet")
	s.tick(0.1)
	assert_eq(s.amount, 1)
	s.tick(5.0)
	assert_eq(s.amount, 2)

func test_the_pilot_light_never_charges_above_its_cap():
	var s := QuantumStore.new(1200, 24)
	s.tick(5.0)
	assert_eq(s.amount, 25)
	s.tick(50.0)
	assert_eq(s.amount, 25, "never above the cap")

func test_the_pilot_light_is_silent_above_its_cap():
	var s := QuantumStore.new(1200, 200)
	watch_signals(s)
	s.tick(50.0)
	assert_eq(s.amount, 200, "far above 25: nothing to do")
	assert_signal_not_emitted(s, "changed")

func test_continuous_costs_debit_whole_qe_as_they_accrue():
	var s := QuantumStore.new(1200, 600)
	# 5 QE/s (boost's rate) over a sixth of a second at a time: 0.833 QE a call.
	assert_true(s.spend_continuous(5.0 / 6.0, &"boost"))
	assert_eq(s.amount, 600, "a fraction alone debits nothing yet")
	assert_true(s.spend_continuous(5.0 / 6.0, &"boost"))
	assert_eq(s.amount, 599, "the accrued whole QE comes out (1.667 -> 1 debited, 0.667 left accrued)")

func test_continuous_costs_accrue_independently_per_purpose():
	var s := QuantumStore.new(1200, 600)
	s.spend_continuous(0.6, &"boost")
	s.spend_continuous(0.6, &"suit")
	assert_eq(s.amount, 600, "neither purpose alone has reached a whole QE")
	s.spend_continuous(0.6, &"boost")
	assert_eq(s.amount, 599, "boost's own accrual reached 1.2, debiting one")

## Signals: what QuantumPlant and the HUD react to.

func test_changed_fires_on_a_spend_and_a_credit():
	var s := QuantumStore.new(1200, 600)
	watch_signals(s)
	s.spend(1, &"test")
	assert_signal_emitted_with_parameters(s, "changed", [599, 1200])
	s.credit(1, &"test")
	assert_signal_emitted_with_parameters(s, "changed", [600, 1200])

func test_low_power_changed_fires_only_on_a_crossing():
	var s := QuantumStore.new(1200, 121)
	watch_signals(s)
	s.spend(1, &"test")   # 120: still at the line, full power
	assert_signal_not_emitted(s, "low_power_changed")
	s.spend(1, &"test")   # 119: below it
	assert_signal_emitted_with_parameters(s, "low_power_changed", [true])
	assert_signal_emit_count(s, "low_power_changed", 1)
	s.credit(1, &"test")   # back to 120: full power again
	assert_signal_emitted_with_parameters(s, "low_power_changed", [false])
