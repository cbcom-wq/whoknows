extends GutTest

## The oasis's beacon (desert world spec §8.2; phase 3 plan, Task 5): one contact
## on the ground at the place, shown only inside its world's well.

var _system: SystemRecipe
var _planet: SystemBody
var _contacts: PlaceContacts

func before_all() -> void:
	RockMesh.warm()
	GroundCover.grass_mesh()
	_system = SystemRecipe.from_seed(1337)
	_planet = _system.body(&"p3")
	_contacts = PlaceContacts.new(_system)

func after_all() -> void:
	_system = null
	_contacts = null

func _oasis() -> PlaceDesign:
	for p in _system.places():
		if p.id == &"oasis":
			return p
	return null

## A point `metres` from p3's centre, on the way to the entry (any side will do).
func _at(metres: float) -> UniversePoint:
	var away := _system.entry().minus(_planet.point).normalized()
	return _planet.point.plus(away * metres)

func test_one_beacon_for_the_oasis() -> void:
	var list := _contacts.contacts(_at(_planet.well_radius - 1.0), 100.0, 0.0)
	assert_eq(list.size(), 1)
	if list.is_empty():
		return
	var c := list[0]
	assert_eq(c.kind, PlaceContacts.KIND)
	assert_eq(c.label, "OASIS")
	assert_eq(c.precision, Contact.EXACT)
	var terrain := WorldTerrain.new(_planet.recipe)
	var ground := _planet.point.plus(_oasis().dir() * (_planet.radius + terrain.height_at(_oasis().dir())))
	assert_lt(absf(c.point.minus(ground).length() - 2.0), 3.0, "within 3 m of the ground")
	assert_eq(_contacts.contact(c.id, _at(0.0), 0.0), c)
	assert_true(String(c.id).begins_with(PlaceContacts.PREFIX))

func test_beacon_only_inside_the_well() -> void:
	var limit := _system.warp_target(&"p3").limit
	assert_eq(_contacts.contacts(_at(limit), 1.0e9, 0.0).size(), 0, "none at the warp limit")
	assert_eq(_contacts.contacts(_at(_planet.well_radius + 1.0), 1.0e9, 0.0).size(), 0, "none just outside the well")
	assert_eq(_contacts.contacts(_at(_planet.well_radius - 1.0), 1.0, 0.0).size(), 1, "one 1 m inside, whatever the range")
	var other := _system.planets()[0] if _system.planets()[0].id != &"p3" else _system.planets()[1]
	assert_eq(_contacts.contacts(other.point, 1.0e9, 0.0).size(), 0, "none in another world's well")

func test_no_beacon_without_one() -> void:
	var plain := SystemRecipe.from_seed(4242, false)
	var planet := plain.planets()[0]
	var design := SystemDesign.from_data({"seed": 4242, "bodies": {str(planet.id): {
		"places": [{"id": "camp", "name": "CAMP", "lat": 10.0, "lon": 20.0, "heading": 0.0, "beacon": false}]}}}, "test")
	var system := SystemRecipe.with_design(4242, design)
	assert_eq(system.places().size(), 1)
	var none := PlaceContacts.new(system)
	assert_eq(none.contacts(system.body(planet.id).point, 1.0e9, 0.0).size(), 0)
