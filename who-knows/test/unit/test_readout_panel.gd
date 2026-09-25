extends GutTest

## ReadoutPanel (quantum energy spec §6.3, §14.1): the airlock panel's body,
## big button and live readout, lifted out so the quantum machine (and later
## the bridge computer) can build the same panel at any size, or as a small
## button with no screen. test_airlock_panel.gd guards the airlock's own use.

func _panel(role := &"room", size := ReadoutPanel.SIZE, has_screen := true) -> ReadoutPanel:
	var panel := ReadoutPanel.new()
	panel.setup(role, 2, InteriorKit.LAYER, size, has_screen)
	add_child_autofree(panel)
	return panel

func _hit_size(panel: ReadoutPanel) -> Vector3:
	for child in panel.get_children():
		if child is CollisionShape3D:
			return (child.shape as BoxShape3D).size
	return Vector3.ZERO

func test_the_airlock_panel_is_a_readout_panel():
	var panel := AirlockPanel.new()
	panel.setup(&"room", 2)
	add_child_autofree(panel)
	assert_true(panel is ReadoutPanel)
	assert_eq(ReadoutPanel.SIZE, AirlockPanel.SIZE)

func test_by_default_it_is_the_airlock_panel_with_a_screen():
	var panel := _panel()
	assert_true(panel.is_in_group("interactable"))
	assert_eq(panel.collision_layer, 2)
	assert_eq(_hit_size(panel), ReadoutPanel.SIZE + Vector3(0, 0, 0.04))
	panel.set_readout(PackedStringArray(["STORE 600 QE"]), &"go")
	assert_eq(panel.readout_text(), "STORE 600 QE")
	assert_eq(panel.button_state(), &"go")

func test_its_size_is_a_parameter():
	var size := Vector3(0.24, 0.24, 0.05)
	var panel := _panel(&"big", size)
	assert_eq(_hit_size(panel), size + Vector3(0, 0, 0.04))
	assert_eq(String(panel.name), "Panel_big")

func test_a_small_button_has_no_screen_and_still_lights():
	var panel := _panel(&"next", Vector3(0.16, 0.16, 0.05), false)
	assert_null(panel.readout, "no readout of its own")
	panel.set_readout(PackedStringArray(["IGNORED"]), &"cycling")
	assert_eq(panel.readout_text(), "")
	assert_eq(panel.button_state(), &"cycling")
	watch_signals(panel)
	panel.interact(null)
	assert_signal_emitted_with_parameters(panel, "pressed", [&"next"])

func test_any_other_state_lights_no_button():
	var panel := _panel()
	panel.set_readout(PackedStringArray(), &"")
	assert_eq(panel.button_state(), &"")

## Quantum energy spec §6.3: the machine's screen stands above its bay, apart
## from its big button, and the panel writes its lines there.
func test_a_button_can_be_given_a_screen_that_stands_apart():
	var panel := _panel(&"big", Vector3(0.24, 0.24, 0.05), false)
	var screen := ReadoutPanel.make_readout(InteriorKit.LAYER)
	add_child_autofree(screen)
	panel.readout = screen
	panel.set_readout(PackedStringArray(["MAKE · MUG", "COST 6 QE"]), &"go")
	assert_eq(screen.text, "MAKE · MUG\nCOST 6 QE")
	assert_eq(panel.readout_text(), screen.text)

func test_a_readout_is_the_airlock_look():
	var screen := ReadoutPanel.make_readout(4)
	add_child_autofree(screen)
	assert_eq(screen.modulate, InteriorPalette.LIGHT_WARM)
	assert_false(screen.shaded)
	assert_eq(screen.layers, 4)

func test_every_mesh_is_on_its_render_layer():
	var panel := ReadoutPanel.new()
	panel.setup(&"outer", 16, 4, Vector3(0.16, 0.16, 0.05), false)
	add_child_autofree(panel)
	var meshes := panel.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0)
	for mesh in meshes:
		assert_eq(mesh.layers, 4)
