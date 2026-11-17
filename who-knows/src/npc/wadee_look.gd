class_name WadeeLook
extends Node3D

## A Wadee as drawn (docs/superpowers/specs/2026-11-16-wadoo-design.md §11): one of the
## Blender-made models (assets/wadee/wadee_<model>.glb, tools/blender/wadee_rig.py), one
## mesh with one material coloured from WadeePalette by the person's seed, and the
## library's motions, picked from how fast its Npc moves and the action its mind
## asks for. Far off it is cheap: no shadow past SHADOW_WITHIN, and its motion
## stepped at FAR_RATE past FULL_RATE_WITHIN.
##
## Its origin is at the feet, facing -z as every NPC does (the models face +z).

const MODELS := ["a", "b", "c", "m", "n"]
## Clips by the mind's action, standing.
const CLIPS := {&"": &"Idle", &"talk": &"Idle_Talking", &"water": &"Farm_Watering", &"harvest": &"Farm_Harvest",
	&"plant": &"Farm_PlantSeed", &"kneel": &"Fixing_Kneeling", &"interact": &"Interact", &"lift": &"PickUp_Table",
	&"sit": &"Sitting_Idle", &"sit_talk": &"Sitting_Talking", &"rise": &"Sitting_Exit", &"drink": &"Consume",
	&"watch": &"Idle_FoldArms", &"nod": &"Yes", &"crouch": &"Crouch_Idle", &"cower": &"Crouch_Idle",
	&"dead": &"Death01", &"armed": &"Spell_Simple_Idle", &"aim": &"Spell_Simple_Idle",
	&"shoot": &"Spell_Simple_Shoot", &"roll": &"Roll"}
## Clips that loop while their action lasts, though the library made them once-through.
const HELD := [&"Farm_Watering", &"Farm_Harvest", &"Farm_PlantSeed", &"Fixing_Kneeling", &"Interact",
	&"PickUp_Table", &"Consume"]
## Clips played once through, to their end, whatever the mind asks meanwhile
## (Wadoo spec §9): a shot, a dodge, a stagger. Only falling dead cuts one short.
const ONCE := [&"Spell_Simple_Shoot", &"Roll", &"Hit_Chest"]
## Actions begun anew each time the mind turns to them: each is one shot, one roll.
const TRIGGERED := [&"shoot", &"roll"]
## Actions with the staff in the hand rather than across the back.
const ARMED := [&"armed", &"aim", &"shoot", &"roll"]
## Into a stagger, a shot or a fall, s: quicker than the usual blend.
const SNAP := 0.08
## The staff in the right hand, held upright at the side as the left hand casts
## (Spell_Simple_Idle, _Shoot): gripped at the palm (HAND_PALM down the hand
## bone) HAND_GRIP_UP up from its butt, and turned HAND_TURN in the bone's frame,
## so that in those two clips it leans out to the right and forward, its glowing
## head beside the shoulder where one she aims at sees it (the look's (0.3, 1,
## -0.45)), its butt in and back behind the skirt. The hand bone is
## bent at the wrist, so the turn was measured from the clips
## (test/probes/wadee_poses.gd prints it), not reasoned from the bone's axes.
const HAND_PALM := 0.07
const HAND_GRIP_UP := 0.3
const HAND_TURN := Vector3(-0.77, PI, -2.337)
## The staff's glass head over its grip, m (sunstaff.glb).
const STAFF_HEAD := Vector3(0.0, 1.03, 0.0)
## Moving: walking over WALK_OVER m/s, jogging over JOG_OVER.
const WALK_OVER := 0.2
const JOG_OVER := 2.4
## The library's pace (m/s at its hips' height, LIB_HIPS m: wadee_rig.py measures it).
const WALK_PACE := 1.05
const CARRY_PACE := 0.67
const JOG_PACE := 5.9
const LIB_HIPS := 0.917
const BLEND := 0.3
## Clips of sitting: from one to another it stays seated; from anything else it
## sits down first (Sitting_Enter).
const SEATED := [&"Sitting_Enter", &"Sitting_Idle", &"Sitting_Talking"]
## Level of detail, by the distance to the camera drawing it, m.
const SHADOW_WITHIN := 25.0
const FULL_RATE_WITHIN := 30.0
const FAR_RATE := 15.0
const LOD_EVERY := 0.5
## The staff across the back: where it hangs in the model's own space (facing +z).
const STAFF_AT := Vector3(0.0, 1.02, -0.18)
const STAFF_LEAN := 0.56
## A worn armlet (Lio's, once given; Wadoo spec §7): on the left forearm, this
## far from the elbow to the wrist, drawn this size (ItemLooks.armlet), a little
## wider than the item so the wrist never shows through it.
const ARMLET_ALONG := 0.8
const ARMLET_SIZE := Vector3(0.11, 0.04, 0.11)

static var _scenes := {}
static var _surface: ImageTexture

var model := ""
var role: StringName = &"villager"
var seed := 0
## What the mind asks for, and the clip playing.
var action: StringName = &""
var clip: StringName = &""
var mesh: MeshInstance3D
var player: AnimationPlayer
var staff: Node3D
## Where the staff hangs: across the back, or in the right hand (armed).
var armed := false
## What they wear besides their clothes and staff: a gift given (`wears`).
var worn: Array[StringName] = []
## The model's hips over the ground at rest, m (sets its pace).
var hips := LIB_HIPS
var _body: Node3D
var _back: BoneAttachment3D
var _hand: BoneAttachment3D
var _fade := Vector2.ZERO
var _lod_left := 0.0
var _near := true
var _step_left := 0.0
var _pending := 0.0
var _after_sit: StringName = &"Sitting_Idle"

func build(variety: float, fade: Vector2) -> void:
	_fade = fade
	model = MODELS[clampi(int(variety * MODELS.size()), 0, MODELS.size() - 1)]

## Becomes `person` ({model, seed, role, staff, wears}); a look not told stays
## its variety's model.
func set_person(person: Dictionary) -> void:
	model = str(person.get("model", model))
	seed = int(person.get("seed", seed))
	role = StringName(person.get("role", role))
	worn.clear()
	for kind: Variant in person.get("wears", []):
		worn.append(StringName(kind))
	_load()
	if bool(person.get("staff", false)):
		_add_staff()
	for kind in worn:
		_add_worn(kind)

## Puts `kind` on now (a gift just given): only the armlet is drawn.
func wear(kind: StringName) -> void:
	if worn.has(kind):
		return
	worn.append(kind)
	_add_worn(kind)

func _add_worn(kind: StringName) -> void:
	var skel := skeleton()
	if kind != &"armlet" or skel == null or skel.find_bone("LeftLowerArm") < 0 or skel.find_bone("LeftHand") < 0:
		return
	var lower := skel.get_bone_global_rest(skel.find_bone("LeftLowerArm"))
	# the wrist in the forearm's own frame: the armlet's axis runs along the arm
	var wrist := lower.affine_inverse() * skel.get_bone_global_rest(skel.find_bone("LeftHand")).origin
	var at := BoneAttachment3D.new()
	at.name = "Armlet"
	at.bone_name = "LeftLowerArm"
	skel.add_child(at)
	var ring := Node3D.new()
	ring.name = "Ring"
	ring.transform = Transform3D(Basis(Quaternion(Vector3.UP, wrist.normalized())), wrist * ARMLET_ALONG)
	at.add_child(ring)
	var kit := OasisLooks.kit_under(ring)
	ItemLooks.armlet(kit, ARMLET_SIZE)
	for m in kit.commit():
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if _fade.y > 0.0:
			m.visibility_range_end = _fade.y

func _ready() -> void:
	if _body == null:
		_load()

func _load() -> void:
	if _body != null:
		remove_child(_body)
		_body.queue_free()
		_body = null
		staff = null
		_back = null
		_hand = null
		armed = false
	var scene := _scene(model)
	if scene == null:
		return
	_body = scene.instantiate()
	_body.name = "Body"
	_body.rotation = Vector3(0.0, PI, 0.0)
	add_child(_body)
	mesh = _body.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	mesh.material_override = _material()
	if _fade.y > 0.0:
		mesh.visibility_range_end = _fade.y
	player = _body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var skel := skeleton()
	if skel != null and skel.find_bone("Hips") >= 0:
		hips = skel.get_bone_global_rest(skel.find_bone("Hips")).origin.y
	clip = &""
	_choose(true)

static func _scene(tag: String) -> PackedScene:
	if not _scenes.has(tag):
		var path := "res://assets/wadee/wadee_%s.glb" % tag
		var scene: PackedScene = load(path) if ResourceLoader.exists(path) else null
		_scenes[tag] = scene
		if scene != null:
			# the clips are the scene's own resources, shared by all its instances
			var probe := scene.instantiate()
			var p := probe.find_child("AnimationPlayer", true, false) as AnimationPlayer
			for name: StringName in HELD:
				if p != null and p.has_animation(name):
					p.get_animation(name).loop_mode = Animation.LOOP_LINEAR
			probe.free()
	return _scenes[tag]

func _material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(WadeePalette.image(seed, role))
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if _surface == null:
		_surface = ImageTexture.create_from_image(WadeePalette.surface())
	m.roughness_texture = _surface
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.metallic_texture = _surface
	m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	m.metallic = 1.0
	m.roughness = 1.0
	return m

## The sunstaff, across the back.
func _add_staff() -> void:
	var skel := skeleton()
	var scene: PackedScene = load("res://assets/wadee/sunstaff.glb") if ResourceLoader.exists("res://assets/wadee/sunstaff.glb") else null
	if skel == null or scene == null or skel.find_bone("UpperChest") < 0:
		return
	_back = BoneAttachment3D.new()
	_back.name = "Back"
	_back.bone_name = "UpperChest"
	skel.add_child(_back)
	staff = scene.instantiate()
	staff.name = "Sunstaff"
	_back.add_child(staff)
	if skel.find_bone("RightHand") >= 0:
		_hand = BoneAttachment3D.new()
		_hand.name = "Hand"
		_hand.bone_name = "RightHand"
		skel.add_child(_hand)
	_hang_staff(armed)

## The staff across the back, or in the right hand.
func _hang_staff(in_hand: bool) -> void:
	armed = in_hand and _hand != null
	if staff == null:
		return
	var skel := skeleton()
	var to := _hand if armed else _back
	if staff.get_parent() != to:
		staff.get_parent().remove_child(staff)
		to.add_child(staff)
	if armed:
		var turn := Basis.from_euler(HAND_TURN)
		staff.transform = Transform3D(turn, Vector3(0.0, HAND_PALM, 0.0) - turn.y * HAND_GRIP_UP)
	else:
		var rest := skel.get_bone_global_rest(skel.find_bone("UpperChest"))
		staff.transform = rest.affine_inverse() * Transform3D(Basis(Vector3.BACK, STAFF_LEAN), STAFF_AT)

## Where a bolt leaves the staff, world; null with no staff.
func staff_head() -> Variant:
	if staff == null or not staff.is_inside_tree():
		return null
	return staff.global_transform * STAFF_HEAD

func skeleton() -> Skeleton3D:
	if _body == null:
		return null
	var found := _body.find_children("*", "Skeleton3D", true, false)
	return found[0] as Skeleton3D if not found.is_empty() else null

## What the mind asks for this think. A shot or a roll starts its clip the
## think it is asked for; falling dead cuts anything short.
func act(p_action: StringName) -> void:
	var was := action
	action = p_action
	if staff != null and (action in ARMED) != armed and action != &"dead":
		_hang_staff(action in ARMED)
	if player == null:
		return
	if action == &"dead" and was != &"dead":
		_once(CLIPS[&"dead"])
	elif action in TRIGGERED and action != was:
		_once(CLIPS[action])

## A wound of `share` of their health (Npc.take_damage): a stagger, however big
## (Hit_Knockback lays them flat by 0.3 s and there is no clip to get up again).
## Nothing once dead.
func hurt(_share: float) -> void:
	if action == &"dead" or player == null:
		return
	_once(&"Hit_Chest")

## Plays `name` from its start now, quickly blended in.
func _once(name: StringName) -> void:
	if not player.has_animation(name):
		return
	clip = name
	player.speed_scale = 1.0
	player.play(name, SNAP)
	player.seek(0.0, false)

func _process(delta: float) -> void:
	if player == null or not is_visible_in_tree():
		return
	_lod_left -= delta
	if _lod_left <= 0.0:
		_lod_left = LOD_EVERY
		_lod()
	_choose(false)
	_pending += delta
	if _near:
		player.advance(_pending)
		_pending = 0.0
	else:
		_step_left -= delta
		if _step_left <= 0.0:
			_step_left = 1.0 / FAR_RATE
			player.advance(_pending)
			_pending = 0.0

## Shadows and a full rate of motion only near the camera.
func _lod() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var d := global_position.distance_to(cam.global_position) if cam != null else 0.0
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if d <= SHADOW_WITHIN \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_near = d <= FULL_RATE_WITHIN

## How fast its body moves over the ground, m/s.
func speed() -> float:
	var body := get_parent() as Node3D
	var v: Variant = body.get(&"velocity") if body != null else null
	if v == null:
		return 0.0
	var up := body.global_basis.y.normalized()
	var vel: Vector3 = v
	return (vel - up * vel.dot(up)).length()

## The clip for now: moving, by its speed; standing, by the action.
func _choose(at_once: bool) -> void:
	# a queued clip (sitting down, then sitting) moves on by itself
	if player.is_playing() and player.current_animation != "":
		clip = StringName(player.current_animation)
	# a shot, a dodge, a stagger plays to its end; the dead stay down
	if action == &"dead" or (clip in ONCE and player.is_playing()):
		return
	var s := speed()
	var want: StringName = CLIPS.get(action, &"Idle")
	var pace := 0.0
	if action != &"dead" and s > JOG_OVER:
		want = &"Jog_Fwd"
		pace = JOG_PACE
	elif action != &"dead" and s > WALK_OVER:
		want = &"Walk_Carry" if action == &"carry" else &"Walk"
		pace = CARRY_PACE if action == &"carry" else WALK_PACE
	if want in SEATED and clip == &"Sitting_Enter" and player.is_playing():
		# sitting down: the clip queued after it follows by itself
		_after_sit = want
		return
	if (want == &"Sitting_Idle" or want == &"Sitting_Talking") and not clip in SEATED:
		_after_sit = want
		want = &"Sitting_Enter"
	if not player.has_animation(want):
		want = &"Idle"
	player.speed_scale = clampf(s / (pace * hips / LIB_HIPS), 0.5, 2.0) if pace > 0.0 else 1.0
	if want == clip:
		return
	clip = want
	player.play(clip, 0.0 if at_once else BLEND)
	if clip == &"Sitting_Enter":
		player.queue(_after_sit)
