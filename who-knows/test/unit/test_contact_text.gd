extends GutTest

## The few capitalised words a screen or the HUD uses for how far a contact is
## (bridge computer spec §5.2, §6.1).

func _contact(precision: StringName, radius := 0.0, km := 0) -> Contact:
	var c := Contact.new()
	c.id = &"x"
	c.kind = &"rock" if precision == Contact.EXACT else &"salvage"
	c.label = "ROCK" if precision == Contact.EXACT else "SALVAGE"
	c.precision = precision
	c.radius = radius
	c.km = km
	return c

func test_a_big_rock_is_as_far_as_its_surface():
	var rock := _contact(Contact.EXACT, 300.0)
	assert_eq(ContactText.distance(rock, 3500.0), "3.2 KM")
	assert_eq(ContactText.distance(rock, 1000.0), "700 M")
	assert_eq(ContactText.distance(rock, 200.0), "0 M", "never less than nothing")

func test_a_ping_says_only_its_rounded_kilometres():
	assert_eq(ContactText.distance(_contact(Contact.PING, 0.0, 4), 3721.0), "~4 KM")

func test_a_region_is_as_far_as_its_edge_and_here_inside():
	var region := _contact(Contact.REGION, 75.0)
	assert_eq(ContactText.distance(region, 715.0), "640 M")
	assert_eq(ContactText.distance(region, 60.0), "HERE")

func test_metres_round_to_tens():
	assert_eq(ContactText.distance(_contact(Contact.EXACT), 644.0), "640 M")
	assert_eq(ContactText.distance(_contact(Contact.EXACT), 999.0), "1000 M")

func test_a_line_is_its_label_and_its_distance():
	assert_eq(ContactText.line(_contact(Contact.EXACT, 300.0), 3500.0), "ROCK · 3.2 KM")
