extends GutTest

## What the sensors say (NPC foundation spec §22.2): nothing beyond reach, a
## ping with a seeded error far off, a region the thing always lies inside
## close by -- the same every time for the same inputs.

var _life := SenseProfile.life()

func _at(x: float, y: float, z: float) -> UniversePoint:
	return UniversePoint.at(0, 0, 0).plus(Vector3(x, y, z))

func test_the_life_profile_is_as_the_owner_chose():
	assert_eq(_life.kind, &"life")
	assert_eq(_life.label, "LIFE?")
	assert_almost_eq(_life.reach, 4000.0, 0.01)
	assert_almost_eq(_life.region_within, 1000.0, 0.01)
	assert_almost_eq(_life.region_radius * 2.0, 30.0, 0.01, "a region 30 m across")

func test_beyond_reach_there_is_nothing():
	assert_null(Sense.read(_life, _at(0, 0, 0), _at(0, 0, 4500), &"life:a:0", 0.0))

func test_far_off_a_ping_in_the_rough_direction():
	var c := Sense.read(_life, _at(0, 0, 0), _at(0, 0, -3000), &"life:a:0", 1.0)
	assert_eq(c.precision, Contact.PING)
	assert_eq(c.kind, &"life")
	assert_eq(c.km, 3)
	var dir := c.point.minus(_at(0, 0, 0)).normalized()
	assert_lt(rad_to_deg(dir.angle_to(Vector3.FORWARD)), 10.01, "within 10 degrees")
	assert_almost_eq(c.point.minus(_at(0, 0, 0)).length(), 3000.0, 1.0, "at the true distance")

func test_a_ping_is_the_same_until_the_next_one_and_then_moves():
	var a := Sense.read(_life, _at(0, 0, 0), _at(0, 0, -3000), &"life:a:0", 0.5)
	var b := Sense.read(_life, _at(0, 0, 0), _at(0, 0, -3000), &"life:a:0", 3.5)
	var c := Sense.read(_life, _at(0, 0, 0), _at(0, 0, -3000), &"life:a:0", 4.5)
	assert_true(a.point.is_equal_approx(b.point), "one ping lasts its period")
	assert_false(a.point.is_equal_approx(c.point), "the next has a new error")
	assert_almost_eq(a.taken, 0.0, 0.001)
	assert_almost_eq(c.taken, 4.0, 0.001)
	assert_almost_eq(a.fresh_for, 4.0, 0.001)

func test_close_by_a_region_it_lies_inside():
	for n in 50:
		var id := StringName("life:rock:%d" % n)
		var thing := _at(10, 0, -600)
		var c := Sense.read(_life, _at(0, 0, 0), thing, id, 0.0)
		assert_eq(c.precision, Contact.REGION)
		assert_almost_eq(c.radius, 15.0, 0.001)
		var off := c.point.minus(thing).length()
		assert_lt(off, c.radius - 7.0, "%s: the herd and its spread fit inside" % id)

func test_a_regions_place_is_the_same_every_time():
	var a := Sense.read(_life, _at(0, 0, 0), _at(0, 0, -600), &"life:x:1", 0.0)
	var b := Sense.read(_life, _at(5, 0, 0), _at(0, 0, -600), &"life:x:1", 99.0)
	assert_true(a.point.is_equal_approx(b.point))

func test_salvage_reads_by_its_own_numbers():
	var s := SenseProfile.salvage()
	var c := Sense.read(s, _at(0, 0, 0), _at(0, 0, -1500), &"salvage:0", 0.0)
	assert_eq(c.precision, Contact.REGION)
	assert_almost_eq(c.radius, 75.0, 0.001)
	assert_eq(c.kind, &"salvage")
	assert_ne(HudPalette.for_kind(&"life"), HudPalette.for_kind(&"salvage"), "told apart by colour")
