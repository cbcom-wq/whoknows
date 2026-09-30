extends GutTest

## How hurt something is (docs/superpowers/specs/
## 2026-09-29-health-and-damage-design.md §3, §6, §7.1).

func test_take_lowers_current_and_returns_what_it_took():
	var h := Health.make(100.0)
	assert_eq(h.take(30.0), 30.0)
	assert_eq(h.current, 70.0)
	assert_eq(h.take(90.0), 70.0, "never below 0")
	assert_eq(h.current, 0.0)
	assert_true(h.is_empty())

func test_hurt_fires_with_the_amount_taken():
	var h := Health.make(40.0)
	watch_signals(h)
	h.take(50.0)
	assert_signal_emitted_with_parameters(h, "hurt", [40.0])

func test_emptied_fires_once():
	var h := Health.make(20.0)
	watch_signals(h)
	h.take(10.0)
	assert_signal_not_emitted(h, "emptied")
	h.take(10.0)
	assert_signal_emit_count(h, "emptied", 1)
	h.take(10.0)
	assert_signal_emit_count(h, "emptied", 1, "already empty")
	assert_signal_emit_count(h, "hurt", 2, "nothing taken at 0 is no hurt")

func test_heal_caps_at_max():
	var h := Health.make(100.0)
	h.take(30.0)
	h.heal(50.0)
	assert_eq(h.current, 100.0)

func test_it_regenerates_only_after_the_calm():
	var h := Health.make(100.0, 10.0, 5.0)
	h.take(50.0)
	h.tick(9.0)
	assert_eq(h.current, 50.0)
	h.tick(1.0)
	h.tick(2.0)
	assert_almost_eq(h.current, 60.0, 0.001)
	h.take(1.0)
	h.tick(5.0)
	assert_almost_eq(h.current, 59.0, 0.001, "a new hurt restarts the calm")

func test_no_regen_rate_means_no_regen():
	var h := Health.make(100.0, 0.0, 0.0)
	h.take(10.0)
	h.tick(100.0)
	assert_eq(h.current, 90.0)

func test_an_empty_health_does_not_regenerate():
	var h := Health.make(100.0, 1.0, 5.0)
	h.take(100.0)
	h.tick(10.0)
	assert_eq(h.current, 0.0, "waking is its owner's business")

func test_fraction():
	var h := Health.make(40.0)
	h.take(10.0)
	assert_almost_eq(h.fraction(), 0.75, 0.001)

func test_round_trip():
	var h := Health.make(100.0)
	h.take(35.0)
	var back := Health.make(100.0)
	back.from_dict(h.to_dict())
	assert_eq(back.current, 65.0)
	back.from_dict({})
	assert_eq(back.current, 65.0, "a missing value keeps what it has")
