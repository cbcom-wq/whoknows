extends GutTest

## The status page's rim (bridge computer spec §7.2).

class Crew extends Node:
	var suit_cell: SuitCell

func _ctx() -> ComputerContext:
	var ctx := ComputerContext.new()
	ctx.store = QuantumStore.new(1200, 600)
	ctx.stats = ShipStats.new()
	ctx.stats.power_gen = 36.0
	ctx.stats.power_draw = 31.3
	return ctx

func test_at_full_power_it_shows_the_store_and_the_power():
	var ctx := _ctx()
	var page := StatusPage.new()
	assert_eq(page.title(), "STATUS")
	assert_eq(page.lines(ctx)[0], "QE 600 / 1200")
	assert_eq(page.lines(ctx)[1], "POWER 36.0 / 31.3 MW")

func test_in_low_power_it_says_so_and_the_core_gives_half():
	var ctx := _ctx()
	ctx.store.amount = 96
	assert_true(ctx.store.is_low_power(), "96 is below the 120 line")
	assert_eq(StatusPage.qe_line(ctx), "QE 96 · LOW POWER")
	assert_eq(StatusPage.power_line(ctx), "POWER 18.0 / 31.3 MW")

func test_it_shows_the_suit_of_whoever_pressed_it():
	var ctx := _ctx()
	assert_eq(StatusPage.suit_line(ctx), "SUIT --", "nobody yet")
	var crew := Crew.new()
	add_child_autofree(crew)
	crew.suit_cell = SuitCell.new()
	crew.suit_cell.charge = 64.0
	ctx.operator = crew
	assert_eq(StatusPage.suit_line(ctx), "SUIT 64%")
	var other := Node.new()
	add_child_autofree(other)
	ctx.operator = other
	assert_eq(StatusPage.suit_line(ctx), "SUIT --", "someone with no suit")

func test_with_nothing_bound_it_shows_dashes_not_errors():
	var ctx := ComputerContext.new()
	assert_eq(StatusPage.qe_line(ctx), "QE --")
	assert_eq(StatusPage.power_line(ctx), "POWER --")

func test_it_uses_no_buttons():
	assert_true(StatusPage.new().lit(_ctx()).is_empty())
	assert_eq(StatusPage.new().big_colour(_ctx()), &"dark")
