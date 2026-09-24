extends GutTest

## The item uses added 2026-09-24 (hands-and-items spec §4.2, as amended): a
## hand lamp that switches, a flare that burns out, a datapad whose screen
## turns on. Each is built from its real definition on disk.

var _cat: ItemCatalog

func before_all():
	_cat = ItemCatalog.load_from_dir()

func _item(id: StringName) -> Item:
	var item := Item.new()
	item.setup(_cat.get_def(id))
	add_child_autofree(item)
	return item

func _use(item: Item) -> bool:
	return item.use(Transform3D.IDENTITY, null, null)

func test_the_hand_lamp_switches_on_and_off():
	var lamp := _item(&"hand_lamp")
	var use: HandLamp = lamp.use_node
	var beam: SpotLight3D = use.find_children("*", "SpotLight3D", true, false)[0]
	assert_false(beam.visible, "starts off")
	assert_true(_use(lamp))
	assert_true(beam.visible)
	assert_eq(use.status(), "on")
	assert_eq(lamp.prompt_text(), "Pick up Hand lamp (on)")
	assert_true(_use(lamp))
	assert_false(beam.visible)
	assert_eq(use.status(), "")

func test_the_hand_lamp_is_warm_and_follows_you_outside():
	var beam: SpotLight3D = _item(&"hand_lamp").use_node.find_children("*", "SpotLight3D", true, false)[0]
	assert_eq(beam.light_color, InteriorPalette.LIGHT_WARM)
	assert_false(beam.shadow_enabled)
	assert_eq(beam.light_cull_mask & 2, 2, "lights the interior")
	assert_eq(beam.light_cull_mask & 1, 1, "and the outside, on a spacewalk")

func test_the_hand_lamp_shines_from_its_lens_along_its_nose():
	var lamp := _item(&"hand_lamp")
	var beam: SpotLight3D = lamp.use_node.find_children("*", "SpotLight3D", true, false)[0]
	assert_almost_eq(lamp.to_local(beam.global_position), lamp.definition.use_point, Vector3.ONE * 0.0001)
	assert_almost_eq(lamp.global_basis.inverse() * -beam.global_basis.z, Vector3.FORWARD, Vector3.ONE * 0.0001)

func test_a_flare_strikes_once():
	var flare := _item(&"flare")
	var use: Flare = flare.use_node
	var light: OmniLight3D = use.find_children("*", "OmniLight3D", true, false)[0]
	assert_false(light.visible)
	assert_true(_use(flare))
	assert_true(light.visible)
	assert_eq(flare.prompt_text(), "Pick up Flare (burning)")
	assert_false(_use(flare), "you cannot strike it twice")

func test_a_flare_burns_out():
	var flare := _item(&"flare")
	var use: Flare = flare.use_node
	_use(flare)
	use.burn_left = 0.02
	simulate(flare, 1, 0.05)
	assert_eq(use.burn, Flare.Burn.SPENT)
	assert_false(use.find_children("*", "OmniLight3D", true, false)[0].visible)
	assert_eq(flare.prompt_text(), "Pick up Flare (spent)")
	assert_false(_use(flare), "a spent flare stays spent")

func test_a_burning_flare_is_a_warm_light():
	var light: OmniLight3D = _item(&"flare").use_node.find_children("*", "OmniLight3D", true, false)[0]
	assert_eq(light.light_color, InteriorPalette.LIGHT_WARM)
	assert_false(light.shadow_enabled)
	assert_eq(light.light_cull_mask & 3, 3)

func test_the_datapad_screen_toggles():
	var pad := _item(&"datapad")
	var screen: Node3D = pad.use_node.get_node("Screen")
	assert_false(screen.visible)
	assert_true(_use(pad))
	assert_true(screen.visible)
	assert_gt(screen.find_children("*", "MeshInstance3D", true, false).size(), 0, "it has a screen to show")
	assert_true(_use(pad))
	assert_false(screen.visible)

func test_only_the_pistol_kicks():
	assert_gt(_item(&"plasma_pistol").use_node.recoil(), 0.0)
	for id in [&"hand_lamp", &"flare", &"datapad"]:
		assert_eq(_item(id).use_node.recoil(), 0.0, "%s does not kick the hand" % id)
