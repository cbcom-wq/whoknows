extends GutTest

## The bridge computer and the cockpit, hurt and mended, in the real ship
## (docs/superpowers/specs/2026-10-03-ship-damage-sections-design.md §2.2,
## §7); the engines and the core are in test_ship_damage.gd, the warp in
## test_warp_scene.gd.

var _root: Node
var _ship: Ship

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")

func _cell(comp: StringName) -> Vector3i:
	for coord: Vector3i in _ship.damage.component_of:
		if _ship.damage.component_of[coord] == comp:
			return coord
	return Vector3i(99, 99, 99)

func _hurt(comp: StringName, share: float) -> void:
	var want: float = _ship.damage.component_hp[comp] * share
	var now: float = _ship.damage.component_damage[comp]
	if want > now:
		_ship.take_damage(_cell(comp), want - now)
	else:
		_ship.repair_component(comp, now - want)

func test_a_wrecked_computer_is_dark_and_answers_offline():
	var table: ShipComputer = _ship.interior_builder.computers()[0]
	assert_ne(table.screen_text(), "")
	assert_ne(table.prompt(&"page"), "Offline")
	_hurt(&"computer", 1.0)
	assert_true(table.offline())
	table.update(0.1)
	assert_eq(table.screen_text(), "", "the screen is dark")
	assert_false(table.holo.visible, "and the holo")
	for button in ShipComputer.BUTTONS:
		assert_eq(table.prompt(button), "Offline")
	var page := table.page_index
	table.press(&"page")
	assert_eq(table.page_index, page, "the buttons do nothing")
	_hurt(&"computer", 0.0)
	table.update(0.1)
	assert_false(table.offline())
	assert_ne(table.screen_text(), "", "mended: lit again")
	assert_true(table.holo.visible)

func test_a_damaged_computer_s_screen_glitches_then_steadies():
	var table: ShipComputer = _ship.interior_builder.computers()[0]
	var steady := table.screen_text()
	_hurt(&"computer", 0.6)
	var glitched := false
	for i in 80:
		table._glitch(0.05)
		if table.screen_text() != steady:
			glitched = true
			break
	assert_true(glitched, "it jumps within a few seconds")
	for i in 10:
		table._glitch(0.05)
	var now := table.screen_text()
	table._refresh()
	assert_eq(now, table.screen_text(), "and comes back to the page as it is")

func test_a_damaged_cockpit_is_sluggish_and_cracked():
	var flight := _ship.flight_computer
	assert_eq(flight.assist_strength, 1.0)
	var cracks := _root.get_node("HudRoot/Screen/CanopyCracks") as CanopyCracks
	assert_not_null(cracks, "the HUD has the cracks")
	cracks.render(flight.build_telemetry())
	assert_eq(cracks.level, 0)
	_hurt(&"cockpit", 0.6)
	assert_eq(flight.assist_strength, 0.5)
	assert_true(flight.assist_enabled, "still assisted")
	cracks.render(flight.build_telemetry())
	assert_eq(cracks.level, 1)
	var t := flight.attitude_torque(Vector3(0, 1, 0), Vector3.ZERO)
	_hurt(&"cockpit", 0.0)
	var whole := flight.attitude_torque(Vector3(0, 1, 0), Vector3.ZERO)
	assert_lte(absf(t.y), absf(whole.y), "it asks for less")
	cracks.render(flight.build_telemetry())
	assert_eq(cracks.level, 0)

func test_a_wrecked_cockpit_turns_the_assist_off_and_the_hud_flickers():
	var flight := _ship.flight_computer
	_hurt(&"cockpit", 1.0)
	assert_false(flight.assist_enabled)
	flight.assist_enabled = true
	assert_false(flight.assist_enabled, "refused")
	assert_true(flight.build_telemetry().hud_flicker)
	assert_eq(flight.build_telemetry().cockpit_cracks, 2)
	assert_false(_ship.stats.crippled, "still flyable")
	_hurt(&"cockpit", 0.0)
	flight.assist_enabled = true
	assert_true(flight.assist_enabled, "mended: the assist comes back on")
	assert_false(flight.build_telemetry().hud_flicker)

func test_the_status_page_names_the_hull_and_the_worst_component():
	var ctx := ComputerContext.new()
	ctx.damage = _ship.damage
	assert_eq(StatusPage.damage_line(ctx), "HULL 100% · ALL SYSTEMS OK")
	_hurt(&"engines", 0.6)
	assert_eq(StatusPage.damage_line(ctx), "HULL 100% · ENGINES DAMAGED")
	_hurt(&"cockpit", 1.0)
	assert_eq(StatusPage.damage_line(ctx), "HULL 100% · COCKPIT WRECKED", "a wreck before a damaged one")
	_ship.damage.section_damage[&"port_bow"] = _ship.damage.section_hp[&"port_bow"]
	assert_string_starts_with(StatusPage.damage_line(ctx), "HULL %d%%" % roundi(_ship.hull_whole() * 100.0))
	assert_eq(StatusPage.damage_line(ComputerContext.new()), "HULL --")
