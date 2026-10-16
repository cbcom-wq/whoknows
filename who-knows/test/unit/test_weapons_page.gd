extends GutTest

## The WEAPONS page (ship weapons spec §7.4): the orders, the list with each
## entry's distance and bearing, each turret's state; prev and next pick, RANGE
## drops, the big button switches the orders.

class StubTurret extends Node3D:
	var target: Node3D
	var no_arc := false
	var state: StringName = &"firing"
	func can_engage(_n: Node3D) -> bool:
		return true
	func muzzle() -> Vector3:
		return Vector3.ZERO

var _fc: FireControl
var _ctx: ComputerContext

func before_each():
	_fc = FireControl.new()
	add_child_autofree(_fc)
	var t := StubTurret.new()
	add_child_autofree(t)
	_fc.turrets = [t]
	_ctx = ComputerContext.new()
	_ctx.fire_control = _fc

func _entry(id: StringName, label: String, distance: float, bearing := true) -> Dictionary:
	return {"id": id, "node": null, "label": label, "distance": distance, "bearing": bearing}

func test_no_turrets_no_weapons():
	_fc.turrets = []
	assert_eq(WeaponsPage.board_lines(_fc, 0), PackedStringArray(["NO WEAPONS"]))

func test_lines():
	_fc.mark(&"ship:A")
	_fc.entries = [{"id": &"ship:A", "node": null, "label": "WARDEN", "distance": 1400.0, "bearing": true}]
	var lines := WeaponsPage.new().lines(_ctx)
	assert_eq(lines[0], "HOLD · 1 TURRET")
	assert_string_contains(lines[1], "1 WARDEN 1.4 KM")
	assert_string_contains(lines[2], "T1 FIRING")

func test_buttons():
	var page := WeaponsPage.new()
	_fc.mark(&"ship:A")
	_fc.mark(&"ship:B")
	page.press(&"big", _ctx)
	assert_eq(_fc.orders, FireControl.Orders.ENGAGE)
	assert_eq(page.big_colour(_ctx), &"go")
	page.press(&"next", _ctx)
	assert_eq(page.selected, 1)
	page.press(&"range", _ctx)
	assert_eq(_fc.list, [&"ship:A"] as Array[StringName])

func test_an_entry_that_cannot_bear_says_no_arc_and_a_near_one_metres():
	_fc.mark(&"ship:A")
	_fc.entries = [_entry(&"ship:A", "WARDEN", 640.0, false)]
	assert_string_contains(WeaponsPage.board_lines(_fc, -1)[1], "1 WARDEN 640 M NO ARC")

func test_a_target_not_yet_found_has_no_distance():
	_fc.mark(&"ship:A")
	_fc.entries = [_entry(&"ship:A", "SHIP:A", -1.0, false)]
	assert_string_contains(WeaponsPage.board_lines(_fc, -1)[1], "1 SHIP:A -- NO ARC")

func test_the_selected_entry_is_marked_and_none_when_negative():
	_fc.entries = [_entry(&"a", "A", 100.0), _entry(&"b", "B", 200.0)]
	assert_string_contains(WeaponsPage.board_lines(_fc, 1)[1], ">2 B")
	assert_false(WeaponsPage.board_lines(_fc, -1)[1].contains(">"))

func test_nothing_listed_says_how_to_mark():
	assert_string_contains(WeaponsPage.board_lines(_fc, 0)[1], "NO TARGETS")

func test_the_lit_buttons_follow_the_list():
	var page := WeaponsPage.new()
	assert_eq(page.lit(_ctx), [&"big"] as Array[StringName])
	_fc.mark(&"ship:A")
	assert_eq(page.lit(_ctx), [&"range", &"prev", &"big", &"next"] as Array[StringName])
	_fc.turrets = []
	assert_eq(page.lit(_ctx), [] as Array[StringName])
	assert_eq(page.big_colour(_ctx), &"dark")

func test_the_orders_show_on_the_head_and_the_big_button():
	var page := WeaponsPage.new()
	assert_eq(page.big_colour(_ctx), &"amber")
	assert_eq(page.prompt(&"big", _ctx), "Engage")
	_fc.set_orders(FireControl.Orders.ENGAGE)
	assert_eq(page.prompt(&"big", _ctx), "Hold fire")
	assert_true(WeaponsPage.board_lines(_fc, -1)[0].begins_with("ENGAGE"))

func test_prev_wraps_and_the_selection_survives_a_save():
	var page := WeaponsPage.new()
	_fc.mark(&"ship:A")
	_fc.mark(&"ship:B")
	page.press(&"prev", _ctx)
	assert_eq(page.selected, 1)
	var again := WeaponsPage.new()
	again.restore(page.save())
	assert_eq(again.selected, 1)

func test_a_page_without_fire_control_does_not_fail():
	var page := WeaponsPage.new()
	var bare := ComputerContext.new()
	assert_eq(page.lines(bare), PackedStringArray(["NO WEAPONS"]))
	page.press(&"big", bare)
	assert_eq(page.title(), "WEAPONS")

# --- Fitting the text on a screen -------------------------------------------

func _crowd() -> void:
	_fc.list = [&"a", &"b", &"c"] as Array[StringName]
	_fc.entries = [
		_entry(&"a", "ASTEROID FRAGMENT FIELD", 12500.0, false),
		_entry(&"b", "A VERY LONG SHIP NAME", 1400.0),
		_entry(&"c", "WWWWWWWWWWWW", 12500.0, false),
	]
	_fc.turrets = []
	for i in 4:
		var t := StubTurret.new()
		t.state = [&"firing", &"no_arc", &"low_power", &"tracking"][i]
		add_child_autofree(t)
		_fc.turrets.append(t)

func test_every_line_fits_the_columns():
	_crowd()
	for columns in [WeaponsPage.PAGE_COLUMNS, WeaponsPage.BOARD_COLUMNS]:
		for selected in [-1, 0, 1, 2]:
			for line in WeaponsPage.board_lines(_fc, selected, columns):
				assert_lte(line.length(), columns, "'%s' within %d" % [line, columns])

func test_a_crowded_list_shows_the_selected_first_and_counts_the_rest():
	_crowd()
	var line := WeaponsPage.board_lines(_fc, 1, WeaponsPage.PAGE_COLUMNS)[1]
	assert_true(line.begins_with(">2 "), line)
	assert_string_contains(line, "+")

func test_crowded_turrets_group_by_state():
	_crowd()
	var line := WeaponsPage.board_lines(_fc, -1, 24)[2]
	assert_string_contains(line, "1 FIRING")
	assert_lte(line.length(), 24)

## The text's size in metres as Label3D draws it: the font's own measure of the
## widest line and the stack of lines, times the label's pixel size. (A Label3D's
## own AABB stays empty until it has drawn a frame.)
func _measure(label: Label3D) -> Vector2:
	var font: Font = label.font if label.font != null else ThemeDB.fallback_font
	var size := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size)
	return size * label.pixel_size

func test_the_page_s_text_fits_the_table_s_screen():
	_crowd()
	var label := ReadoutPanel.make_readout(InteriorKit.LAYER, 450.0)
	label.pixel_size = ShipComputer.SCREEN_PIXEL
	add_child_autofree(label)
	var shown := PackedStringArray(["WEAPONS"])
	shown.append_array(WeaponsPage.board_lines(_fc, 0, WeaponsPage.PAGE_COLUMNS))
	label.text = "
".join(shown)
	var box := _measure(label)
	gut.p("table text: %.3f x %.3f m" % [box.x, box.y])
	assert_gt(box.x, 0.1, "the text was measured")
	assert_lte(box.x, ShipComputer.SCREEN_SIZE.x, "wide: %.3f m on a %.2f m screen" % [box.x, ShipComputer.SCREEN_SIZE.x])
	# The title and three lines are the most a page has; the status page's four
	# lines fill the screen to the same height.
	assert_lte(label.text.split("
").size(), 4, "no more lines than the other pages")

func test_the_board_s_text_fits_the_station_screen():
	_crowd()
	var label := WeaponsStation.make_board()
	add_child_autofree(label)
	assert_lte(label.width * label.pixel_size, WeaponsStation.SCREEN_SIZE.x, "the label's width in metres")
	label.text = "
".join(WeaponsPage.board_lines(_fc, -1, WeaponsPage.BOARD_COLUMNS))
	var box := _measure(label)
	gut.p("board text: %.3f x %.3f m" % [box.x, box.y])
	assert_gt(box.x, 0.1, "the text was measured")
	assert_lte(box.x, label.width * label.pixel_size, "wide: %.3f m, inside the label's own width" % box.x)
	assert_lte(box.y, WeaponsStation.SCREEN_SIZE.y, "tall: %.3f m" % box.y)
