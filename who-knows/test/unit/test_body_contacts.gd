extends GutTest

## The star, planets and moons for the sensors (the system skeleton spec §10).

func test_a_contact_per_body_found_by_id_anywhere():
	var system := SystemRecipe.from_seed(1337)
	var source := BodyContacts.new(system)
	var entry := system.entry()
	var all := source.contacts(entry, 1e9, 0.0)
	assert_eq(all.size(), system.bodies.size())
	for b in system.bodies:
		var c := source.contact(BodyContacts.id_of(b), entry, 0.0)
		assert_not_null(c)
		assert_eq(c.kind, &"body")
		assert_eq(c.label, b.name)
		assert_eq(c.radius, b.radius)
		assert_eq(c.precision, Contact.EXACT)

func test_range_counts_from_the_surface():
	var system := SystemRecipe.from_seed(1337)
	var source := BodyContacts.new(system)
	var star := system.star
	var from := star.point.plus(Vector3(0, 0, star.radius + 5000.0))
	var ids := source.contacts(from, 6000.0, 0.0).map(func(c: Contact) -> StringName: return c.id)
	assert_true(ids.has(&"body:star"))
	ids = source.contacts(from, 4000.0, 0.0).map(func(c: Contact) -> StringName: return c.id)
	assert_false(ids.has(&"body:star"))
