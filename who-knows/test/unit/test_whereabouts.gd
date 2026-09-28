extends GutTest

## Where you are (the system skeleton spec §8): places at known points,
## innermost first; hysteresis at their edges; signals once per change.

var _system: SystemRecipe

func before_all():
	# A seed with a ringed planet, so every kind of place is there.
	for s in range(1, 200):
		var sys := SystemRecipe.from_seed(s)
		if sys.planets().any(func(p: SystemBody) -> bool: return p.ring != null and not sys.moons_of(p).is_empty()):
			_system = sys
			return

func _ringed() -> SystemBody:
	for p in _system.planets():
		if p.ring != null and not _system.moons_of(p).is_empty():
			return p
	return null

func _ids(places: Array) -> Array:
	return places.map(func(p: Whereabouts.Place) -> StringName: return p.id)

func test_open_space_is_just_the_system():
	var far := UniversePoint.at(0, SystemRecipe.PLANE_Y + 90000, 0)
	var places := Whereabouts.places_at(_system, far)
	assert_eq(_ids(places), [&"system"])
	assert_eq(places[0].name, _system.name)

func test_in_a_ring_near_its_planet():
	var p := _ringed()
	var ring := p.ring
	var across := ring.normal.cross(Vector3.RIGHT).normalized()
	var at := p.point.plus(across * (ring.inner + ring.outer) * 0.5)
	var ids := _ids(Whereabouts.places_at(_system, at))
	assert_eq(ids[0], StringName("ring_%s" % p.id))
	assert_true(ids.has(StringName("near_%s" % p.id)))
	assert_eq(ids[ids.size() - 1], &"system")

func test_near_a_moon_is_inside_near_its_planet():
	var p := _ringed()
	var m := _system.moons_of(p)[0]
	var ids := _ids(Whereabouts.places_at(_system, m.point.plus(Vector3(0, m.radius + 100.0, 0))))
	assert_lt(ids.find(StringName("near_%s" % m.id)), ids.find(StringName("near_%s" % p.id)), "the moon first")

func test_in_a_belt():
	var belt := _system.belts[0]
	var at := belt.centre.plus(Vector3(belt.radius, 0, 0))
	var ids := _ids(Whereabouts.places_at(_system, at))
	assert_eq(ids, [&"belt_0", &"system"])

func test_you_leave_only_beyond_the_edge():
	var belt := _system.belts[0]
	var just_out := belt.centre.plus(Vector3(belt.radius + belt.half_width + 50.0, 0, 0))
	assert_false(_ids(Whereabouts.places_at(_system, just_out)).has(&"belt_0"), "not entered from outside")
	assert_true(_ids(Whereabouts.places_at(_system, just_out, {&"belt_0": true})).has(&"belt_0"), "not yet left")
	var well_out := belt.centre.plus(Vector3(belt.radius + belt.half_width + 150.0, 0, 0))
	assert_false(_ids(Whereabouts.places_at(_system, well_out, {&"belt_0": true})).has(&"belt_0"))

func test_the_node_says_once_when_you_come_and_go():
	var universe := Universe.new()
	add_child_autofree(universe)
	var focus := Node3D.new()
	add_child_autofree(focus)
	universe.set_focus(focus)
	var belt := _system.belts[0]
	universe.origin = belt.centre.plus(Vector3(belt.radius, 0, 0))
	var w := Whereabouts.new()
	add_child_autofree(w)
	watch_signals(w)
	w.setup(_system, universe)
	assert_signal_emit_count(w, "entered", 2, "the belt and the system")
	assert_eq(w.dust(), Whereabouts.DUST_THICK)
	assert_true(w.text().begins_with(_system.name + " › in "), w.text())
	w.look()
	assert_signal_emit_count(w, "entered", 2, "nothing new")
	focus.global_position = Vector3(0, 60000, 0)
	w.look()
	assert_signal_emit_count(w, "left", 1)
	assert_eq(w.dust(), Whereabouts.DUST_OPEN)
