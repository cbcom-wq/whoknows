extends GutTest

## WadeeLook (docs/superpowers/specs/2026-11-16-wadoo-design.md §11): the model faces
## -z, is one mesh with one material in the person's colours, plays the clip its
## speed and its action ask for, carries a staff only if told, and drops its
## shadow far from the camera.

var _body: CharacterBody3D
var _look: WadeeLook

func _make(person: Dictionary) -> WadeeLook:
	_body = CharacterBody3D.new()
	add_child_autofree(_body)
	_look = WadeeLook.new()
	_look.build(0.1, Vector2(330, 380))
	_body.add_child(_look)
	_look.set_person(person)
	return _look

func test_faces_minus_z():
	var look := _make({"model": "a", "seed": 3, "role": &"villager"})
	var skel := look.skeleton()
	var toes := skel.find_bone("LeftToes")
	var at := look.to_local(skel.global_transform * skel.get_bone_global_rest(toes).origin)
	assert_lt(at.z, 0.0, "the toes point along -z")

func test_one_mesh_one_material():
	var look := _make({"model": "q", "seed": 3, "role": &"queen"})
	assert_eq(look.find_children("*", "MeshInstance3D", true, false).size(), 1)
	assert_eq(look.mesh.mesh.get_surface_count(), 1)
	assert_true(look.mesh.material_override is StandardMaterial3D)

func test_colours_by_seed():
	var look := _make({"model": "b", "seed": 77, "role": &"villager"})
	var tex := (look.mesh.material_override as StandardMaterial3D).albedo_texture
	var want := WadeePalette.colours(77, &"villager")
	var img := tex.get_image()
	assert_true(img.get_pixel(WadeePalette.SKIN, 0).is_equal_approx(want[WadeePalette.SKIN]))
	assert_true(img.get_pixel(WadeePalette.CLOTH_1, 0).is_equal_approx(want[WadeePalette.CLOTH_1]))

func test_clip_follows_action():
	var look := _make({"model": "c", "seed": 1, "role": &"villager"})
	assert_eq(look.clip, &"Idle")
	look.act(&"water")
	look._process(0.05)
	assert_eq(look.clip, &"Farm_Watering")
	assert_eq(look.player.get_animation(&"Farm_Watering").loop_mode, Animation.LOOP_LINEAR,
		"held while the action lasts")
	look.act(&"talk")
	look._process(0.05)
	assert_eq(look.clip, &"Idle_Talking")
	look.act(&"sit")
	look._process(0.05)
	assert_eq(look.clip, &"Sitting_Enter", "sits down first")

func test_walks_when_moving_and_jogs_fast():
	var look := _make({"model": "m", "seed": 1, "role": &"villager"})
	_body.velocity = Vector3(1.1, 0.0, 0.0)
	look._process(0.05)
	assert_eq(look.clip, &"Walk")
	assert_almost_eq(look.player.speed_scale, 1.1 / (WadeeLook.WALK_PACE * look.hips / WadeeLook.LIB_HIPS), 0.01)
	_body.velocity = Vector3(0.0, 0.0, -3.5)
	look._process(0.05)
	assert_eq(look.clip, &"Jog_Fwd")
	_body.velocity = Vector3(0.0, 2.0, 0.0)
	look._process(0.05)
	assert_eq(look.clip, &"Idle", "falling is not walking")

func test_staff_only_for_the_sunguard():
	var guard := _make({"model": "s", "seed": 1, "role": &"sunguard", "staff": true})
	assert_not_null(guard.staff)
	var villager := _make({"model": "a", "seed": 1, "role": &"villager"})
	assert_null(villager.staff)

func test_shadow_lod():
	var look := _make({"model": "n", "seed": 5, "role": &"villager"})
	var cam := Camera3D.new()
	add_child_autofree(cam)
	cam.current = true
	cam.global_position = look.global_position + Vector3(0, 1.6, 40.0)
	look._lod()
	assert_eq(look.mesh.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	cam.global_position = look.global_position + Vector3(0, 1.6, 8.0)
	look._lod()
	assert_eq(look.mesh.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
