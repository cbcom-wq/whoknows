extends GutTest

## The stimulus bus (docs/superpowers/specs/2026-09-26-npc-foundation-design.md
## §6.1): short-lived, found by the space you are in, moved by the floating
## origin outside.

var _outside: Node3D
var _interior: Node3D
var _ext_bus: StimulusBus
var _int_bus: StimulusBus

func before_each():
	_outside = Node3D.new()
	add_child_autofree(_outside)
	_interior = Node3D.new()
	_outside.add_child(_interior)
	_ext_bus = StimulusBus.new()
	_outside.add_child(_ext_bus)
	_ext_bus.setup(_outside)
	_int_bus = StimulusBus.new()
	_outside.add_child(_int_bus)
	_int_bus.setup(_interior)

func test_emitted_stimuli_last_their_time():
	var s := Stimulus.make(Stimulus.SOUND, Vector3.ZERO, 1.0, 10.0)
	_ext_bus.emit(s, 0.5)
	assert_eq(_ext_bus.since(0.0).size(), 1)
	_ext_bus._physics_process(0.3)
	assert_eq(_ext_bus.count(), 1)
	assert_eq(_ext_bus.since(0.1).size(), 0, "since asks for newer ones")
	_ext_bus._physics_process(0.3)
	assert_eq(_ext_bus.count(), 0, "gone after half a second")

func test_each_node_finds_the_bus_of_its_own_space():
	var aboard := Node3D.new()
	_interior.add_child(aboard)
	var out := Node3D.new()
	_outside.add_child(out)
	assert_eq(StimulusBus.for_node(aboard), _int_bus)
	assert_eq(StimulusBus.for_node(out), _ext_bus)
	StimulusBus.send(aboard, Stimulus.make(Stimulus.SOUND, Vector3.ZERO, 1.0, 5.0))
	assert_eq(_int_bus.count(), 1)
	assert_eq(_ext_bus.count(), 0)

func test_with_no_bus_sending_does_nothing():
	var lonely := Node3D.new()
	add_child_autofree(lonely)
	StimulusBus.send(lonely, Stimulus.make(Stimulus.SOUND, Vector3.ZERO, 1.0, 5.0))
	assert_null(StimulusBus.for_node(lonely))

func test_a_shift_moves_live_stimuli():
	var universe := Universe.new()
	add_child_autofree(universe)
	var bus := StimulusBus.new()
	_outside.add_child(bus)
	bus.setup(_outside, universe)
	var s := Stimulus.make(Stimulus.VIBRATION, Vector3(2500, 0, 0), 1.0, 30.0)
	bus.emit(s)
	universe.shift(Vector3(2000, 0, 0))
	assert_eq(s.position, Vector3(500, 0, 0))

func test_lights_are_only_those_on_in_this_space():
	var item_def := ItemCatalog.load_from_dir("res://data/items").get_def(&"hand_lamp")
	if item_def == null:
		pending("no hand_lamp item")
		return
	var lamp := Item.new()
	lamp.setup(item_def, 0.0)
	_interior.add_child(lamp)
	var use := lamp.use_node as HandLamp
	assert_not_null(use)
	assert_eq(_int_bus.lights().size(), 0, "off")
	use.on = true
	assert_eq(_int_bus.lights().size(), 1, "on")
	assert_eq(_ext_bus.lights().size(), 0, "not outside's")
