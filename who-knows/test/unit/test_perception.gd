extends GutTest

## An NPC's senses (docs/superpowers/specs/2026-09-26-npc-foundation-design.md
## §6.2, §6.3): sight in a cone, blocked by walls and dimmed by the dark; lights
## on it; vibration through its own rock only; sound only if it hears; memory
## that fades.

class FakeSite extends NpcSite:
	func frame() -> Transform3D:
		return Transform3D.IDENTITY

class FakeLight extends Node3D:
	var reach := 10.0
	var cone := 44.0
	func light_reach() -> float:
		return reach
	func light_cone_deg() -> float:
		return cone
	func light_origin() -> Transform3D:
		return global_transform
	func light_kind() -> StringName:
		return &"lamp"

var _root: Node3D
var _bus: StimulusBus
var _npc: Npc
var _site: FakeSite
var _species: NpcSpecies
var _player: CharacterBody3D

func _make(inside: bool) -> void:
	_species = NpcSpecies.new()
	_species.id = &"thing"
	_species.size = 0.5
	_species.height = 0.5
	_species.sight_range = 10.0
	_species.sight_cone_deg = 140.0
	_species.dark_sight = 0.3
	_species.hears = 1.0
	_species.feels_vibration = 1.0
	_site = FakeSite.new()
	_site.id = &"rock:a"
	_npc = Npc.new()
	_root.add_child(_npc)
	_npc.setup(NpcRecord.make(&"thing:0", &"thing", &"rock:a", Vector3.ZERO, 1), _species, _site, inside,
		Transform3D.IDENTITY)
	_npc.set_physics_process(false)

func before_each():
	_root = Node3D.new()
	add_child_autofree(_root)
	_bus = StimulusBus.new()
	_root.add_child(_bus)
	_bus.setup(_root)
	_player = CharacterBody3D.new()
	_player.add_to_group(Avatar.GROUP)
	_root.add_child(_player)
	_player.global_position = Vector3(0, 0.4, -5)

func _sense(time := 1.0) -> NpcContext:
	var ctx := NpcContext.new()
	ctx.memory = _npc.memory
	ctx.time = time
	ctx.dt = 0.2
	ctx.grounded = true
	_npc.perception.sense(_npc, ctx, _bus, time)
	return ctx

func test_in_cone_is_measured_across_the_whole_cone():
	assert_true(Perception.in_cone(Vector3.FORWARD, Vector3(-1, 0, -1), 91.0))
	assert_false(Perception.in_cone(Vector3.FORWARD, Vector3(-1, 0, -1), 89.0))
	assert_true(Perception.in_cone(Vector3.FORWARD, Vector3.BACK, 360.0))

func test_sight_is_shorter_in_the_dark_outside_only():
	_make(false)
	assert_almost_eq(Perception.sight_range(_species, false, false), 3.0, 0.001)
	assert_almost_eq(Perception.sight_range(_species, true, false), 10.0, 0.001)
	assert_almost_eq(Perception.sight_range(_species, false, true), 10.0, 0.001)

func test_it_sees_the_player_ahead_inside_but_not_behind_or_through_a_wall():
	_make(true)
	await wait_physics_frames(2)
	var ctx := _sense()
	assert_not_null(ctx.player, "ahead, 5 m, lit ship")
	_player.global_position = Vector3(0, 0.4, 5)
	ctx = _sense(1.2)
	assert_null(ctx.player, "behind it")
	_player.global_position = Vector3(0, 0.4, -5)
	var wall := StaticBody3D.new()
	wall.collision_layer = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.2)
	shape.shape = box
	wall.add_child(shape)
	_root.add_child(wall)
	wall.global_position = Vector3(0, 0.5, -2.5)
	await wait_physics_frames(2)
	ctx = _sense(1.4)
	assert_null(ctx.player, "through a wall")

func test_close_by_it_notices_you_all_round():
	_make(true)
	_species.near_sense = 3.0
	_player.global_position = Vector3(0, 0.4, 2.5)
	await wait_physics_frames(2)
	assert_not_null(_sense().player, "behind it, but near")
	_player.global_position = Vector3(0, 0.4, 3.5)
	assert_null(_sense(1.2).player, "behind it, and not near")

func test_outside_a_dark_player_is_seen_only_close():
	_make(false)
	await wait_physics_frames(2)
	assert_null(_sense().player, "5 m in the dark is past 3 m")
	_player.global_position = Vector3(0, 0.4, -2.5)
	assert_not_null(_sense(1.2).player, "2.5 m is not")

func test_a_carried_light_makes_the_player_seen_far():
	_make(false)
	var lamp := FakeLight.new()
	lamp.add_to_group(StimulusBus.LIGHTS)
	_player.add_child(lamp)
	await wait_physics_frames(2)
	assert_not_null(_sense().player)

func test_a_lamp_pointed_at_it_lights_it_and_one_pointed_away_does_not():
	_make(false)
	var lamp := FakeLight.new()
	lamp.add_to_group(StimulusBus.LIGHTS)
	_root.add_child(lamp)
	lamp.look_at_from_position(Vector3(0, 0.5, -6), Vector3(0, 0.25, 0))
	await wait_physics_frames(2)
	assert_true(_sense().lit)
	lamp.look_at_from_position(Vector3(0, 0.5, -6), Vector3(0, 0.5, -20))
	assert_false(_sense(1.2).lit)
	lamp.look_at_from_position(Vector3(0, 0.5, -6), Vector3(0, 0.25, 0))
	lamp.reach = 0.0
	assert_false(_sense(1.4).lit, "off")

func test_it_feels_vibration_only_through_its_own_rock():
	_make(false)
	_bus.emit(Stimulus.make(Stimulus.VIBRATION, Vector3(0, 0, -10), 1.0, 30.0, null, &"rock:b"))
	_sense()
	assert_null(_npc.memory.surest(Stimulus.VIBRATION, 1.0), "another rock")
	_bus.emit(Stimulus.make(Stimulus.VIBRATION, Vector3(0, 0, -10), 1.0, 30.0, null, &"rock:a"))
	_sense(1.2)
	assert_not_null(_npc.memory.surest(Stimulus.VIBRATION, 1.2), "its own")

func test_a_species_that_does_not_hear_ignores_sound():
	_make(true)
	_species.hears = 0.0
	_bus.emit(Stimulus.make(Stimulus.SOUND, Vector3(0, 0, -2), 1.0, 10.0))
	_sense()
	assert_null(_npc.memory.surest(Stimulus.SOUND, 1.0))
	_species.hears = 1.0
	_bus.emit(Stimulus.make(Stimulus.SOUND, Vector3(0, 0, -2), 1.0, 10.0))
	_sense(1.2)
	assert_not_null(_npc.memory.surest(Stimulus.SOUND, 1.2))

func test_a_hit_is_a_touch():
	_make(true)
	_npc.receive_hit(Hit.make(Vector3(0, 0.3, -0.3), Vector3.BACK, Vector3.FORWARD, Vector3.ZERO, null))
	_sense()
	assert_not_null(_npc.memory.surest(Stimulus.TOUCH, 1.0))

func test_memory_halves_and_forgets():
	var m := NpcMemory.new()
	m.half_life = 2.0
	m.note(&"sound", 7, Vector3.ZERO, 1.0, 0.0)
	assert_almost_eq(m.sure_of(m.percepts[0], 2.0), 0.5, 0.0001)
	m.note(&"sound", 7, Vector3.ONE, 0.9, 2.0)
	assert_eq(m.percepts.size(), 1, "the same source refreshes")
	assert_eq(m.percepts[0].where, Vector3.ONE)
	m.forget_faded(20.0)
	assert_eq(m.percepts.size(), 0)
