extends GutTest

## WadeePalette (docs/superpowers/specs/2026-11-16-wadoo-design.md §11): every
## person's colours come from their seed and role, and five bodies dress as many.

func test_sixteen_slots():
	assert_eq(WadeePalette.colours(1, &"villager").size(), 16)
	var img := WadeePalette.image(1, &"villager")
	assert_eq(img.get_width(), 16)
	assert_eq(img.get_height(), 1)

func test_the_same_seed_gives_the_same_colours():
	assert_eq(WadeePalette.colours(1234, &"villager"), WadeePalette.colours(1234, &"villager"))

func test_seeds_differ():
	var seen := {}
	for n in 25:
		var c := WadeePalette.colours(n * 7919 + 13, &"villager")
		seen["%s|%s" % [c[WadeePalette.SKIN].to_html(), c[WadeePalette.CLOTH_1].to_html()]] = true
	assert_gte(seen.size(), 20, "25 villagers should look like at least 20 different people")

func test_three_cloths_differ():
	for n in 40:
		var c := WadeePalette.colours(n, &"villager")
		assert_ne(c[WadeePalette.CLOTH_1], c[WadeePalette.CLOTH_2])
		assert_ne(c[WadeePalette.CLOTH_2], c[WadeePalette.CLOTH_3])
		assert_ne(c[WadeePalette.CLOTH_1], c[WadeePalette.CLOTH_3])

func test_the_sunguard_dress_alike():
	var a := WadeePalette.colours(1, &"sunguard")
	var b := WadeePalette.colours(2, &"sunguard")
	assert_eq(a[WadeePalette.CLOTH_1], b[WadeePalette.CLOTH_1])
	assert_eq(a[WadeePalette.CLOTH_2], b[WadeePalette.CLOTH_2])

func test_bronze_is_metal():
	var s := WadeePalette.surface()
	assert_almost_eq(s.get_pixel(WadeePalette.BRONZE_SLOT, 0).b, WadeePalette.METAL_BRONZE, 0.01)
	assert_almost_eq(s.get_pixel(WadeePalette.SKIN, 0).b, 0.0, 0.01)
	assert_almost_eq(s.get_pixel(WadeePalette.CLOTH_1, 0).g, WadeePalette.ROUGH_CLOTH, 0.01)
