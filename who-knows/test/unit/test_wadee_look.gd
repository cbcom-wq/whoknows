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

func test_sits_down_once_and_stays_seated():
	var look := _make({"model": "a", "seed": 2, "role": &"villager"})
	look.act(&"sit")
	for k in 40:
		look._process(0.05)
	assert_eq(look.clip, &"Sitting_Idle", "sat down, then sits")
	look.act(&"sit_talk")
	look._process(0.05)
	assert_eq(look.clip, &"Sitting_Talking", "talks seated, without standing up")
	look.act(&"sit")
	look._process(0.05)
	assert_eq(look.clip, &"Sitting_Idle")
	look.act(&"rise")
	look._process(0.05)
	assert_eq(look.clip, &"Sitting_Exit")

## Wadoo spec §7: Lio wears her armlet once given: on the left forearm near the
## wrist, put on at once (wear) and again whenever she wakes (`wears`).
func test_wears_the_armlet_on_the_left_forearm():
	var look := _make({"model": "a", "seed": 3, "role": &"villager"})
	var skel := look.skeleton()
	assert_eq(skel.find_children("Armlet", "BoneAttachment3D", false, false).size(), 0, "not until given")
	look.wear(&"armlet")
	look.wear(&"armlet")
	var on := skel.find_children("Armlet", "BoneAttachment3D", false, false)
	assert_eq(on.size(), 1, "once")
	assert_eq((on[0] as BoneAttachment3D).bone_name, "LeftLowerArm")
	var ring := on[0].get_node("Ring") as Node3D
	var lower := skel.get_bone_global_rest(skel.find_bone("LeftLowerArm"))
	var wrist := skel.get_bone_global_rest(skel.find_bone("LeftHand")).origin
	var p := lower * ring.position
	assert_lt(p.distance_to(wrist), p.distance_to(lower.origin) * 0.5, "near the wrist")
	assert_gt(ring.find_children("*", "MeshInstance3D", true, false).size(), 0, "drawn")
	var n := skel.get_child_count()
	look.wear(&"crown")
	assert_eq(skel.get_child_count(), n, "anything else is not drawn")
	var again := _make({"model": "a", "seed": 3, "role": &"villager", "wears": [&"armlet"]})
	assert_eq(again.skeleton().find_children("Armlet", "BoneAttachment3D", false, false).size(), 1,
		"worn when she wakes")

## Wadoo spec §9: a shot, a roll and a stagger play once to their end, whatever
## the mind asks meanwhile; each shot starts its clip again.
func test_a_shot_plays_through_and_again():
	var look := _make({"model": "s", "seed": 1, "role": &"sunguard", "staff": true})
	look.act(&"aim")
	look._process(0.05)
	assert_eq(look.clip, &"Spell_Simple_Idle", "aiming")
	look.act(&"shoot")
	look._process(0.05)
	assert_eq(look.clip, &"Spell_Simple_Shoot")
	look.act(&"aim")
	look._process(0.2)
	assert_eq(look.clip, &"Spell_Simple_Shoot", "the throw is not cut short by aiming")
	look._process(0.4)
	look._process(0.05)
	assert_eq(look.clip, &"Spell_Simple_Idle", "then back to aiming")
	look.act(&"shoot")
	look._process(0.05)
	assert_eq(look.clip, &"Spell_Simple_Shoot", "the next shot")
	assert_lt(look.player.current_animation_position, 0.1, "from its start")

## Wadoo spec §9: the staff comes off the back into the right hand to fight, and
## the bolt leaves its glass head.
func test_the_staff_in_the_hand_to_fight():
	var look := _make({"model": "s", "seed": 1, "role": &"sunguard", "staff": true})
	assert_false(look.armed)
	assert_eq(look.staff.get_parent().name, "Back")
	look.act(&"armed")
	assert_true(look.armed)
	assert_eq(look.staff.get_parent().name, "Hand")
	assert_eq((look.staff.get_parent() as BoneAttachment3D).bone_name, "RightHand")
	var head: Vector3 = look.staff_head()
	var hand := look.skeleton().global_transform * look.skeleton().get_bone_global_pose(look.skeleton().find_bone("RightHand")).origin
	var over_grip := WadeeLook.STAFF_HEAD.y - WadeeLook.HAND_GRIP_UP
	assert_between(head.distance_to(hand), over_grip - 0.12, over_grip + 0.12,
		"gripped a third of the way up: the head is the rest of the staff from the hand")
	look.act(&"")
	assert_false(look.armed, "back across the back")
	assert_eq(look.staff.get_parent().name, "Back")
	var villager := _make({"model": "a", "seed": 1, "role": &"villager"})
	villager.act(&"armed")
	assert_null(villager.staff_head(), "no staff, no head")

## Wadoo spec §9: hurt, a stagger, however big; dead, they fall
## and stay down whatever else is asked.
func test_staggers_and_falls():
	var look := _make({"model": "a", "seed": 2, "role": &"villager"})
	look.hurt(0.1)
	assert_eq(look.clip, &"Hit_Chest")
	look._process(0.5)
	look.hurt(0.4)
	assert_eq(look.clip, &"Hit_Chest", "a big wound staggers too: knocked flat, they could not get up")
	assert_almost_eq(look.player.current_animation_position, 0.0, 0.01, "from its start again")
	look.act(&"dead")
	assert_eq(look.clip, &"Death01", "falling cuts the stagger short")
	assert_eq(look.player.get_animation(&"Death01").loop_mode, Animation.LOOP_NONE)
	for i in 30:
		look._process(0.1)
	assert_eq(look.clip, &"Death01", "and they stay down")
	look.hurt(0.5)
	assert_eq(look.clip, &"Death01", "the dead do not stagger")
	_body.velocity = Vector3(2.0, 0.0, 0.0)
	look._process(0.1)
	assert_eq(look.clip, &"Death01", "nor walk")

## Wadoo spec §9: cornered, a villager crouches.
func test_cowers_crouched():
	var look := _make({"model": "b", "seed": 2, "role": &"villager"})
	look.act(&"cower")
	look._process(0.05)
	assert_eq(look.clip, &"Crouch_Idle")
