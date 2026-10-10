extends GutTest

## EVA cargo (habitat modules spec §4.1): a package is carried out onto a
## spacewalk, used there, let go there as a stray, and slows the suit.

class PlantUse extends ItemUse:
	var count := 0
	func use(_item: Item, _aim: Transform3D, _world: Node3D, _holder: CollisionObject3D) -> bool:
		count += 1
		return true

var _world: Node3D
var _body: CharacterBody3D
var _grasp: Grasp

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)
	_body = CharacterBody3D.new()
	_world.add_child(_body)
	var head := Node3D.new()
	head.position = Vector3(0, 1.6, 0)
	_body.add_child(head)
	_grasp = Grasp.new()
	_body.add_child(_grasp)
	_grasp.bind(_body, head)
	_grasp.world_root = _world

func _package(cargo := true) -> Item:
	var def := ItemDefinition.new()
	def.id = &"test_package"
	def.mass_kg = 30.0
	def.size = Vector3(0.5, 0.35, 0.5)
	def.grip = ItemDefinition.Grip.CARRY
	def.look = &"crate"
	def.eva_cargo = cargo
	def.module = &"hub"
	def.use = PlantUse
	def.quantum_value = 400
	var item := Item.new()
	item.setup(def)
	_world.add_child(item)
	return item

func test_held_cargo_can_be_used_on_a_spacewalk():
	var item := _package()
	assert_true(_grasp.take(item))
	_grasp.suspended = true
	assert_true(_grasp.can_use(), "carried, out on a spacewalk")
	assert_true(_grasp.use())
	assert_eq((item.use_node as PlantUse).count, 1)

func test_other_carried_things_still_cannot():
	var item := _package(false)
	assert_true(_grasp.take(item))
	_grasp.suspended = true
	assert_false(_grasp.can_use())

func test_cargo_is_let_go_outside_and_says_so():
	var item := _package()
	_grasp.take(item)
	_grasp.suspended = true
	var space := Node3D.new()
	_world.add_child(space)
	_body.reparent(space)
	watch_signals(_grasp)
	var gone := _grasp.let_go_outside()
	assert_same(gone, item)
	assert_eq(_grasp.mode, Grasp.Mode.EMPTY)
	assert_eq(item.get_parent(), space, "into the space you are in, not the interior")
	assert_signal_emitted_with_parameters(_grasp, "let_go", [item])

func test_nothing_else_is_let_go_outside():
	var item := _package(false)
	_grasp.take(item)
	_grasp.suspended = true
	assert_null(_grasp.let_go_outside())
	assert_same(_grasp.item, item)

func test_cargo_slows_the_suit():
	assert_almost_eq(Suit.cargo_accel(120.0, 30.0), 2.0, 0.001, "2.5 x 120 / 150")
	assert_almost_eq(Suit.cargo_accel(120.0, 0.0), Suit.ACCEL, 0.001)
	var v := Suit.step(Vector3.ZERO, Vector3.ZERO, Vector3(0, 0, -1), Basis.IDENTITY, false, 1.0, 2.0)
	assert_almost_eq(v.length(), 2.0, 0.001)
