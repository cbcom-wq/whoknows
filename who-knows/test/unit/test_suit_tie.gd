extends GutTest

## Which ship your suit belongs to on a spacewalk (docs/superpowers/specs/
## 2026-10-02-many-ships-design.md §4.3): the nearest, once it is
## SWITCH_MARGIN nearer than yours and within REACH.

func test_the_nearer_ship_wins_past_the_margin():
	assert_eq(SuitTie.choose(0, [100.0, 80.0] as Array[float]), 1)

func test_within_the_margin_you_stay():
	assert_eq(SuitTie.choose(0, [100.0, 95.0] as Array[float]), 0)

func test_past_reach_nothing_changes():
	assert_eq(SuitTie.choose(0, [900.0, 600.0] as Array[float]), 0)

func test_with_none_the_nearest_in_reach():
	assert_eq(SuitTie.choose(-1, [700.0, 300.0] as Array[float]), 1)
	assert_eq(SuitTie.choose(-1, [700.0, 600.0] as Array[float]), -1)
	assert_eq(SuitTie.choose(-1, [] as Array[float]), -1)
