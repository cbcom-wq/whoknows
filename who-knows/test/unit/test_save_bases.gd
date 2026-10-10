extends GutTest

## Bases through a save and a load (habitat modules spec §11), in the real
## flight scene, at the test's own path.

const SCENE := "res://scenes/flight_test.tscn"
const DIR := "user://test_save_bases"
const PATH := DIR + "/game.json"

class Ground extends PlantSurface:
	var y := 0.0
	func _init(p_y: float) -> void:
		y = p_y
	func cast(from: Vector3, dir: Vector3, reach: float) -> Dictionary:
		var to := from + dir * reach
		if from.y >= y and to.y <= y:
			return {"position": from.lerp(to, (from.y - y) / (from.y - to.y)), "normal": Vector3.UP}
		return {}
	func fixed() -> bool:
		return true
	func site_id() -> StringName:
		return &"rock:save"

var _real_save_time := 0

func before_all():
	_real_save_time = FileAccess.get_modified_time(SaveGame.DEFAULT_PATH) if FileAccess.file_exists(SaveGame.DEFAULT_PATH) else 0

func after_all():
	var now := FileAccess.get_modified_time(SaveGame.DEFAULT_PATH) if FileAccess.file_exists(SaveGame.DEFAULT_PATH) else 0
	assert_eq(now, _real_save_time, "the owner's real save is untouched")

func before_each():
	_clear()

func after_each():
	_clear()

func _clear() -> void:
	for suffix in ["", ".bak", ".tmp", ".old"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)

func _scene() -> Node:
	var root: Node = load(SCENE).instantiate()
	root.save_enabled = true
	root.save_path = PATH
	add_child(root)
	return root

func _drop(root: Node) -> void:
	remove_child(root)
	root.free()

func _plant(root: Node) -> Base:
	var ship: Ship = root.get_node("Ship")
	var at := ship.exterior.global_position + Vector3(0, -40, 60)
	var r := Planting.fit(Ground.new(at.y), ModuleCatalog.get_def(ModuleCatalog.HUB), at, Vector3.FORWARD, 0)
	var base: Base = root.bases.plant(ModuleCatalog.HUB, r, Ground.new(at.y))
	base.tick_unfold(HabitatValues.UNFOLD + 0.1)
	return base

func test_a_base_round_trips():
	var root := _scene()
	var base := _plant(root)
	base.quantum.store.credit(90, &"test")
	var mug := Item.new()
	mug.setup(base.item_catalog.get_def(&"mug"))
	base.items.add_child(mug)
	mug.global_position = base.wake_spots()[0].origin + Vector3.UP * 0.3
	# Where it stands in the universe: a load puts the origin elsewhere, so its
	# engine position is not the same number.
	var where: UniversePoint = root.get_node("Universe").to_universe(base.exterior.global_position)
	assert_true(root.save_now())
	_drop(root)
	var again := _scene()
	await wait_physics_frames(2)
	var back: Base = again.bases.named(&"Base1")
	assert_not_null(back, "awake: it is near")
	assert_eq(back.quantum.store.amount, 90)
	assert_eq(back.items.get_children().filter(func(n): return n is Item).size(), 1, "the mug")
	var now: UniversePoint = again.get_node("Universe").to_universe(back.exterior.global_position)
	assert_lt(now.minus(where).length(), 0.05, "where it stood")
	assert_eq(again.bases.next_number, 2)
	_drop(again)

## A drill's state survives a save and a load (the final review): its ore,
## how long it has run, when it was last credited and the fraction it is owed;
## and what it earned before the save is not paid again after the load.
func test_a_drill_s_state_round_trips_and_pays_nothing_twice():
	var root := _scene()
	var base := _plant(root)
	var frame: Transform3D = root.bases.frame_of(base.site)
	var ground := Ground.new((root.get_node("Ship") as Ship).exterior.global_position.y - 40.0)
	var r := Planting.fit(ground, ModuleCatalog.get_def(ModuleCatalog.DRILL), frame * Vector3(10, -2, 0),
		Vector3.FORWARD, 0, base.site, frame)
	assert_eq(r.fit, Planting.Fit.OK)
	root.bases.plant(ModuleCatalog.DRILL, r, ground)
	base.tick_unfold(HabitatValues.UNFOLD + 0.1)
	var i: int = base.site.drills()[0]
	root.play_time = 5000.0
	var drill: Dictionary = base.site.modules[i]["drill"]
	drill.merge({"richness": 2.75, "veined": true, "ran": 900.0, "credited_at": 4000.0, "owed": 0.25}, true)
	var paid := base.credit_drills()
	assert_eq(paid, floori(0.25 + 1000.0 * 2.75 / HabitatValues.DRILL_PERIOD + 1e-6), "earned up to the save")
	var stored := base.quantum.store.amount
	var kept: Dictionary = (base.site.modules[i]["drill"] as Dictionary).duplicate()
	assert_true(root.save_now())
	_drop(root)
	var again := _scene()
	await wait_physics_frames(2)
	var back: Base = again.bases.named(&"Base1")
	assert_not_null(back, "awake: it is near")
	# Two ticks of play have passed since the load, and it has been credited
	# for them: a few hundredths of a QE.
	var loaded: Dictionary = back.site.modules[i]["drill"]
	assert_almost_eq(float(loaded["richness"]), 2.75, 1e-6, "richness")
	assert_eq(loaded["veined"], true, "veined")
	assert_almost_eq(float(loaded["credited_at"]), again.play_time, 1e-6, "credited up to now")
	assert_almost_eq(float(loaded["ran"]), float(kept["ran"]) + again.play_time - 5000.0, 1e-3, "ran")
	assert_almost_eq(float(loaded["owed"]),
		float(kept["owed"]) + (again.play_time - 5000.0) * 2.75 / HabitatValues.DRILL_PERIOD, 1e-3, "owed")
	assert_lt(again.play_time - 5000.0, 1.0, "the clock went on from the save")
	assert_eq(back.quantum.store.amount, stored, "the store as saved: nothing paid twice at the wake")
	assert_eq(back.credit_drills(), 0, "nor after it")
	var owed := float(loaded["owed"])
	again.play_time += 60.0
	assert_eq(back.credit_drills(), floori(owed + 60.0 * 2.75 / HabitatValues.DRILL_PERIOD + 1e-6),
		"and on from there")
	_drop(again)

func test_a_save_inside_a_base_loads_you_inside_it_with_the_ship_asleep():
	var root := _scene()
	var base := _plant(root)
	var avatar: Avatar = root.get_node("Ship/Interior/Avatar")
	avatar.move_aboard(base.interior, base.wake_spots()[0])
	root.board_base(base)
	var ship: Ship = root.get_node("Ship")
	ship.exterior.global_position += Vector3(25000, 0, 0)
	ship.exterior.linear_velocity = Vector3.ZERO
	assert_true(root.save_now())
	_drop(root)
	var again := _scene()
	await wait_physics_frames(2)
	var back: Base = again.bases.named(&"Base1")
	assert_same(again.home, back, "you are in the base")
	# The avatar was moved into the base, so it is no longer at its scene path.
	assert_eq(again._avatar.get_parent(), back.interior)
	assert_same(again.get_node("Universe").focus, back.exterior, "the origin follows the base")
	again.fleet.check_sleep()
	assert_true(again.fleet.sleeping(again.get_node("Ship")), "your ship, 25 km off, asleep")
	_drop(again)

func test_the_gate_waits_while_a_module_unfolds():
	var root := _scene()
	var ship: Ship = root.get_node("Ship")
	var at := ship.exterior.global_position + Vector3(0, -40, 60)
	var r := Planting.fit(Ground.new(at.y), ModuleCatalog.get_def(ModuleCatalog.HUB), at, Vector3.FORWARD, 0)
	root.bases.plant(ModuleCatalog.HUB, r, Ground.new(at.y))
	assert_eq(root.bases.busy(), "unfolding")
	_drop(root)

## A load that starts the world over (a generator changed) drops the bases, as
## it drops strays: the rocks they stood on are gone.
func test_a_world_started_over_drops_the_bases():
	var root := _scene()
	_plant(root)
	assert_true(root.save_now())
	_drop(root)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	data["generators"]["asteroids"] = int(data["generators"]["asteroids"]) + 1
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "", false, true))
	f.close()
	var again := _scene()
	await wait_physics_frames(2)
	assert_true(again.resumed, "it loaded")
	assert_true(again.bases.sites().is_empty(), "no base left")
	assert_eq(again.bases.next_number, 1)
	assert_same(again.home, again.aboard, "you are aboard your ship")
	assert_engine_error("another version; back to the start; its bases are dropped",
		"the world started over, and it says so, bases and all")
	_drop(again)

## A spacewalk tied to a base comes back tied to it: the base wakes, and your
## suit's hull is its exterior.
func test_a_spacewalk_tied_to_a_base_comes_back_tied_to_it():
	var root := _scene()
	var base := _plant(root)
	var ship: Ship = root.get_node("Ship")
	var avatar: Avatar = root.get_node("Ship/Interior/Avatar")
	var lock: Airlock = base.airlocks.values()[0]
	var near_base := base.exterior.global_transform * (lock.alcove.outer_frame * Vector3(0, 0.3, -6.0))
	avatar.enter_suit(base.outside, Transform3D(Basis.IDENTITY, near_base), Vector3.ZERO, ship.exterior)
	root.suit_tie.check()
	assert_same(root.home, base, "tied to the base")
	assert_true(root.save_now())
	_drop(root)
	var again := _scene()
	await wait_physics_frames(2)
	var back: Base = again.bases.named(&"Base1")
	assert_not_null(back)
	assert_eq(again._avatar.mode, Avatar.Mode.SUIT, "on a spacewalk")
	assert_same(again.home, back, "tied to the base")
	assert_same(again._avatar.hull, back.exterior)
	assert_same(again._avatar.beacon_source.get_object(), back.airlocks.values()[0], "home is its airlock")
	_drop(again)
