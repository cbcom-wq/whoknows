extends GutTest

## The helmet's hose sounds (quantum energy spec §13): the suction's loop while
## you hold the nozzle on a spacewalk, and a gulp each time it swallows.

var _outside: Node3D
var _avatar: Avatar
var _sounds: SuitSounds

func before_each():
	_outside = Node3D.new()
	add_child_autofree(_outside)
	_avatar = (load("res://scenes/avatar.tscn") as PackedScene).instantiate() as Avatar
	add_child_autofree(_avatar)
	_avatar.enter_suit(_outside, Transform3D.IDENTITY, Vector3.ZERO, null)
	# The cell starts empty, and a dry suit lets the nozzle go: charge it.
	_avatar.suit_cell.charge = SuitCell.CAPACITY
	_sounds = _avatar.get_node("SuitSounds")

func _warm() -> void:
	Synth.warm_up()
	var deadline := Time.get_ticks_msec() + 20000
	while not Synth.is_warm() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

func _nozzle() -> Item:
	var item := Item.new()
	item.setup(ItemCatalog.load_from_dir().get_def(&"hose_nozzle"))
	item.set_space(true)
	_outside.add_child(item)
	return item

func test_holding_the_nozzle_on_a_spacewalk_draws_the_hose():
	await _warm()
	_avatar.grasp.take(_nozzle())
	_avatar.grasp.holding = true
	_sounds.tick()
	var hose: AudioStreamPlayer = _sounds.get_node("Hose")
	assert_true(hose.playing)
	assert_same(hose.stream, Synth.sound(&"hose_draw"))
	assert_eq(hose.bus, AudioBuses.SUIT)

func test_letting_go_of_the_trigger_stops_the_hose():
	await _warm()
	_avatar.grasp.take(_nozzle())
	_avatar.grasp.holding = true
	_sounds.tick()
	var hose: AudioStreamPlayer = _sounds.get_node("Hose")
	assert_true(hose.playing)
	_avatar.grasp.holding = false
	_sounds.tick()
	assert_false(hose.playing)

func test_a_swallow_plays_the_gulp():
	await _warm()
	var gulp: AudioStreamPlayer = _sounds.get_node("Gulp")
	assert_false(gulp.playing)
	_avatar.toast.emit("+7 QE · ICE CHUNK")
	assert_true(gulp.playing)
	assert_same(gulp.stream, Synth.sound(&"hose_gulp"))
	assert_eq(gulp.bus, AudioBuses.SUIT)
