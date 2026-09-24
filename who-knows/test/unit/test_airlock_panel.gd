extends GutTest

## Airlock spec §3.4: one big button and a live readout.

var _panel: AirlockPanel

func before_each():
	_panel = AirlockPanel.new()
	_panel.setup(&"room", 2)
	add_child_autofree(_panel)

func test_it_is_an_interactable_on_the_given_layer():
	assert_true(_panel.is_in_group("interactable"))
	assert_eq(_panel.collision_layer, 2)

func test_its_prompt_comes_from_its_provider():
	assert_eq(_panel.prompt_text(), "")
	_panel.prompt_source = func() -> String: return "Depressurize"
	assert_eq(_panel.prompt_text(), "Depressurize")

func test_pressing_it_says_which_panel():
	watch_signals(_panel)
	_panel.interact(null)
	assert_signal_emitted_with_parameters(_panel, "pressed", [&"room"])

func test_the_readout_shows_its_lines_and_one_button_colour():
	_panel.set_readout(PackedStringArray(["PRESSURE 64 kPa", "CYCLING"]), &"cycling")
	assert_eq(_panel.readout_text(), "PRESSURE 64 kPa\nCYCLING")
	assert_eq(_panel.button_state(), &"cycling")
