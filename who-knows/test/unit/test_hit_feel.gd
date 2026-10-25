extends GutTest

## Taking a hit, aboard (hostile ships spec §6.1): the view you see through is
## knocked away from the hit's side and settles; the cabin's ceiling lights
## dip and come back. Both scale with the hit's damage and are capped.

func _avatar() -> Avatar:
	var avatar: Avatar = load("res://scenes/avatar.tscn").instantiate()
	add_child_autofree(avatar)
	return avatar

func _lamp(energy: float) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.light_energy = energy
	add_child_autofree(lamp)
	return lamp

func _dip_with(lamp: OmniLight3D) -> CabinDip:
	var dip := CabinDip.new()
	add_child_autofree(dip)
	dip.register(lamp)
	return dip

func test_strength_scales_with_damage():
	assert_almost_eq(HitFeel.strength(15.0), 0.125, 0.0001, "a light bolt")
	assert_almost_eq(HitFeel.strength(120.0), 1.0, 0.0001, "a heavy bolt")
	assert_almost_eq(HitFeel.strength(5.0), 0.1, 0.0001, "the least is still felt")
	assert_almost_eq(HitFeel.strength(500.0), 1.0, 0.0001, "never past a heavy bolt")

func test_a_heavy_knock_is_bigger_and_settles():
	var heavy := _avatar()
	var light := _avatar()
	heavy.knock(1.0, Vector3.RIGHT)
	light.knock(0.125, Vector3.RIGHT)
	assert_almost_eq(absf(heavy.view_roll()), HitFeel.ROLL_MOST, 0.0001)
	assert_almost_eq(absf(light.view_roll()), HitFeel.ROLL_MOST * 0.125, 0.0001, "an eighth")
	assert_gt(absf(heavy.camera.h_offset), 0.0, "the view is shifted too")
	assert_lt(heavy.camera.h_offset, 0.0, "away from the hit, which came from the right")
	for you: Avatar in [heavy, light]:
		var t := 0.0
		while t < HitFeel.SETTLE + 0.05:
			you.tick_knock(0.01)
			t += 0.01
		assert_almost_eq(you.view_roll(), 0.0, 0.00001, "settled")
		assert_almost_eq(you.camera.h_offset, 0.0, 0.00001)
		assert_almost_eq(you.camera.v_offset, 0.0, 0.00001)

func test_a_burst_storm_is_capped():
	var you := _avatar()
	for i in 12:
		you.knock(1.0, Vector3.RIGHT)
	assert_lte(absf(you.view_roll()), HitFeel.ROLL_MOST * HitFeel.CEILING + 0.00001)
	assert_lte(Vector2(you.camera.h_offset, you.camera.v_offset).length(),
		HitFeel.SHIFT_MOST * HitFeel.CEILING + 0.00001)

func test_the_dip_dims_and_recovers():
	var lamp := _lamp(2.0)
	var dip := _dip_with(lamp)
	assert_almost_eq(dip.factor(), 1.0, 0.0001, "at rest")
	dip.dip(1.0)
	dip.tick(0.05)
	assert_lte(lamp.light_energy, 2.0 * HitFeel.DIP_HEAVY_LEVEL + 0.001, "near dark within 0.1 s")
	for i in 55:
		dip.tick(0.01)
	assert_almost_eq(lamp.light_energy, 2.0, 0.0001, "back after 0.6 s")
	dip.dip(0.125)
	var lowest := 2.0
	var t := 0.0
	var dark_for := 0.0
	while t < 0.5:
		dip.tick(0.01)
		t += 0.01
		lowest = minf(lowest, lamp.light_energy)
		if lamp.light_energy < 2.0 - 0.0001:
			dark_for = t
	assert_lte(dark_for, 0.15, "a light bolt is a quick dip")
	assert_gte(lowest, 2.0 * HitFeel.DIP_LIGHT_LEVEL - 0.0001, "and never deep")
	assert_lt(lowest, 2.0, "but a dip")

func test_a_weaker_dip_does_not_cut_a_stronger_one_short():
	var lamp := _lamp(2.0)
	var dip := _dip_with(lamp)
	dip.dip(1.0)
	dip.tick(0.2)
	dip.dip(0.125)
	dip.tick(0.2)
	assert_lt(dip.factor(), 1.0, "the heavy dip still runs at 0.4 s")

func test_flicker_follows_the_dip():
	var lamp := _lamp(0.45)
	var disc := MeshInstance3D.new()
	add_child_autofree(disc)
	var material := InteriorMaterials.glow().duplicate() as ShaderMaterial
	var flicker := LightFlicker.attach(lamp, disc, material)
	var bright := -1.0
	for i in 20000:
		if LightFlicker.level_at(i * 0.01, flicker.phase) >= 1.0:
			bright = i * 0.01
			break
	assert_gte(bright, 0.0, "the flicker has a bright beat")
	flicker._clock = bright
	flicker._process(0.0)
	assert_almost_eq(lamp.light_energy, 0.45, 0.0001, "bright without a dip")
	var dip := CabinDip.new()
	add_child_autofree(dip)
	flicker.dip = dip
	dip.dip(1.0)
	dip.tick(0.02)
	flicker._process(0.0)
	assert_lte(lamp.light_energy, 0.45 * HitFeel.DIP_HEAVY_LEVEL + 0.0001)

func test_the_gun_camera_shakes_without_turning():
	var job := WeaponsJob.new()
	add_child_autofree(job)
	job.camera = Camera3D.new()
	add_child_autofree(job.camera)
	job.active = true
	var basis := job.camera.global_basis
	job.knock(1.0, Vector3.RIGHT)
	assert_lt(job.camera.h_offset, 0.0, "shaken away from the hit")
	assert_true(job.camera.global_basis.is_equal_approx(basis), "the aim is untouched")
	job.tick_knock(HitFeel.SETTLE + 0.05)
	assert_almost_eq(job.camera.h_offset, 0.0, 0.00001, "settled")

func test_a_hull_hit_is_felt_aboard():
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(root)
	await wait_process_frames(2)
	var ship: Ship = root.aboard
	var you: Avatar = root.get_node("Ship/Interior/Avatar")
	var director: CameraDirector = root.get_node("CameraDirector")
	director.sit_now(ship.seat)
	watch_signals(ship)
	var cell: Vector3i = ship.grid.coords()[0]
	var hit := Hit.make(ship.exterior.to_global(ShipGrid.cell_center(cell)), Vector3.UP, Vector3.DOWN,
		Vector3.ZERO, null)
	hit.damage = 120.0
	hit.kind = &"phaser"
	ship._on_hull_hit(hit)
	assert_signal_emitted(ship, "felt_hit")
	var params: Array = get_signal_parameters(ship, "felt_hit")
	assert_almost_eq(float(params[0]), 1.0, 0.0001, "a heavy bolt's strength")
	await wait_process_frames(1)
	assert_ne(you.view_roll(), 0.0, "the view is knocked")
	assert_lt(ship.cabin_dip.factor(), 1.0, "the cabin's lights dip")
	assert_gt(ship.cabin_dip.lamps(), 0, "its ceiling lamps are registered")
