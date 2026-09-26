extends GutTest

## QuantumShow (docs/superpowers/specs/2026-09-24-quantum-energy-design.md
## §7.5): sparkles, a bead along the conduit, a warm flash, and an item's
## shrink and swell by scale -- built-in particles, the kit and plain
## materials, never a shared material touched.

const PATH := [Vector3(0, 2, 0), Vector3(0, 2.4, 0), Vector3(2, 2.4, 0)]

func _show() -> QuantumShow:
	var show := QuantumShow.new()
	show.setup(Transform3D(Basis.IDENTITY, Vector3(0, 1.2, 0)), PackedVector3Array(PATH), InteriorKit.LAYER)
	add_child_autofree(show)
	return show

func _item() -> Item:
	var item := Item.new()
	item.setup(ItemCatalog.load_from_dir().get_def(&"datapad"))
	add_child_autofree(item)
	return item

func test_sparkles_are_built_in_particles_on_the_interior_layer():
	var show := _show()
	var sparkles: GPUParticles3D = show.get_node("Sparkles")
	assert_eq(sparkles.layers, InteriorKit.LAYER)
	assert_true(sparkles.process_material is ParticleProcessMaterial)
	assert_true(sparkles.draw_pass_1.surface_get_material(0) is StandardMaterial3D, "no new shader")
	assert_almost_eq(sparkles.global_position, Vector3(0, 1.2, 0), Vector3.ONE * 0.0001, "in the bay")
	assert_false(show.is_sparkling())
	show.sparkle(true)
	assert_true(show.is_sparkling())
	show.sparkle(false)
	assert_false(show.is_sparkling())

func test_the_bead_runs_the_conduit_from_the_machine_to_the_core():
	var show := _show()
	assert_false(show.bead_running())
	show.run_bead(0.6)
	assert_true(show.bead_running())
	assert_almost_eq(show.bead_position(), PATH[0], Vector3.ONE * 0.0001, "out of the machine")
	show._process(0.3)
	var mid := show.bead_position()
	assert_almost_eq(mid, show.point_along(0.5), Vector3.ONE * 0.0001, "halfway along, halfway through")
	show._process(0.29)
	assert_true(show.bead_running())
	assert_lt(show.bead_position().distance_to(PATH[2]), 0.05, "nearly at the core")
	show._process(0.02)
	assert_false(show.bead_running(), "gone into the crown")

func test_point_along_measures_the_path_by_length():
	var show := _show()
	assert_almost_eq(show.point_along(0.0), PATH[0], Vector3.ONE * 0.0001)
	assert_almost_eq(show.point_along(1.0), PATH[2], Vector3.ONE * 0.0001)
	# 0.4 m up, then 2 m across: 0.2 of 2.4 m is the top of the rise.
	assert_almost_eq(show.point_along(0.4 / 2.4), PATH[1], Vector3.ONE * 0.0001)
	assert_almost_eq(show.point_along(1.4 / 2.4), Vector3(1, 2.4, 0), Vector3.ONE * 0.0001)

## Spec §7.5: a warm light, energy 0.6, for 0.2 s -- LIGHT_WARM like every
## interior light, no shadows, on the interior's cull mask.
func test_the_flash_is_a_warm_light_for_0_2_s():
	var show := _show()
	var light: OmniLight3D = show.get_node("Flash")
	assert_eq(light.light_color, InteriorPalette.LIGHT_WARM)
	assert_false(light.shadow_enabled)
	assert_eq(light.light_cull_mask, InteriorKit.LAYER)
	assert_false(show.flashing())
	show.flash()
	assert_true(show.flashing())
	assert_almost_eq(light.light_energy, 0.6, 0.0001)
	show._process(0.1)
	assert_true(show.flashing())
	assert_lt(light.light_energy, 0.6)
	show._process(0.11)
	assert_false(show.flashing(), "over in 0.2 s")

## Spec §7.5: by scale, as ImpactFlash does -- the look and whatever its use
## hangs on it, never the collider or the body.
func test_shrink_and_swell_scale_what_the_item_shows_and_nothing_else():
	var item := _item()
	var look: Node3D = item.get_node("Look")
	var collider: CollisionShape3D = item.get_node("Collider")
	QuantumShow.shrink(item, 0.0)
	assert_almost_eq(look.scale, Vector3.ONE, Vector3.ONE * 0.0001, "whole at the start")
	QuantumShow.shrink(item, 0.5)
	assert_lt(look.scale.x, 1.0)
	assert_gt(look.scale.x, QuantumShow.POINT)
	QuantumShow.shrink(item, 1.0)
	assert_almost_eq(look.scale, Vector3.ONE * QuantumShow.POINT, Vector3.ONE * 0.00001, "a point")
	assert_almost_eq(item.use_node.scale, look.scale, Vector3.ONE * 0.00001, "the datapad's screen too")
	assert_eq(collider.scale, Vector3.ONE)
	assert_eq(item.scale, Vector3.ONE)
	QuantumShow.swell(item, 0.0)
	assert_almost_eq(look.scale, Vector3.ONE * QuantumShow.POINT, Vector3.ONE * 0.00001, "from a point")
	QuantumShow.swell(item, 1.0)
	assert_almost_eq(look.scale, Vector3.ONE, Vector3.ONE * 0.0001, "to whole")
