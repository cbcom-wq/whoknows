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
	&"watch": &"Idle_FoldArms", &"nod": &"Yes", &"crouch": &"Crouch_Idle", &"dead": &"Death01"}
## Clips that loop while their action lasts, though the library made them once-through.
const HELD := [&"Farm_Watering", &"Farm_Harvest", &"Farm_PlantSeed", &"Fixing_Kneeling", &"Interact",
	&"PickUp_Table", &"Consume"]
## Moving: walking over WALK_OVER m/s, jogging over JOG_OVER.
const WALK_OVER := 0.2
const JOG_OVER := 2.4
## The library's pace (m/s at its hips' height, LIB_HIPS m: wadee_rig.py measures it).
const WALK_PACE := 1.05
const CARRY_PACE := 0.67
const JOG_PACE := 5.9
const LIB_HIPS := 0.917
const BLEND := 0.3
## Level of detail, by the distance to the camera drawing it, m.
const SHADOW_WITHIN := 25.0
const FULL_RATE_WITHIN := 30.0
const FAR_RATE := 15.0
const LOD_EVERY := 0.5
## The staff across the back: where it hangs in the model's own space (facing +z).
const STAFF_AT := Vector3(0.0, 1.02, -0.18)
const STAFF_LEAN := 0.56

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
## The model's hips over the ground at rest, m (sets its pace).
var hips := LIB_HIPS
var _body: Node3D
var _fade := Vector2.ZERO
var _lod_left := 0.0
var _near := true
var _step_left := 0.0
var _pending := 0.0

func build(variety: float, fade: Vector2) -> void:
	_fade = fade
	model = MODELS[clampi(int(variety * MODELS.size()), 0, MODELS.size() - 1)]

## Becomes `person` ({model, seed, role, staff}); a look not told stays its variety's model.
func set_person(person: Dictionary) -> void:
	model = str(person.get("model", model))
	seed = int(person.get("seed", seed))
	role = StringName(person.get("role", role))
	_load()
	if bool(person.get("staff", false)):
		_add_staff()

func _ready() -> void:
	if _body == null:
		_load()

func _load() -> void:
	if _body != null:
		remove_child(_body)
		_body.queue_free()
		_body = null
		staff = null
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
	var at := BoneAttachment3D.new()
	at.name = "Back"
	at.bone_name = "UpperChest"
	skel.add_child(at)
	staff = scene.instantiate()
	staff.name = "Sunstaff"
	var rest := skel.get_bone_global_rest(skel.find_bone("UpperChest"))
	staff.transform = rest.affine_inverse() * Transform3D(Basis(Vector3.BACK, STAFF_LEAN), STAFF_AT)
	at.add_child(staff)

func skeleton() -> Skeleton3D:
	if _body == null:
		return null
	var found := _body.find_children("*", "Skeleton3D", true, false)
	return found[0] as Skeleton3D if not found.is_empty() else null

## What the mind asks for this think.
func act(p_action: StringName) -> void:
	action = p_action

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
	var s := speed()
	var want: StringName = CLIPS.get(action, &"Idle")
	var pace := 0.0
	if action != &"dead" and s > JOG_OVER:
		want = &"Jog_Fwd"
		pace = JOG_PACE
	elif action != &"dead" and s > WALK_OVER:
		want = &"Walk_Carry" if action == &"carry" else &"Walk"
		pace = CARRY_PACE if action == &"carry" else WALK_PACE
	if want == &"Sitting_Idle" and clip != &"Sitting_Idle":
		want = &"Sitting_Enter"
	if not player.has_animation(want):
		want = &"Idle"
	player.speed_scale = clampf(s / (pace * hips / LIB_HIPS), 0.5, 2.0) if pace > 0.0 else 1.0
	if want == clip:
		return
	clip = want
	player.play(clip, 0.0 if at_once else BLEND)
	if clip == &"Sitting_Enter":
		player.queue(&"Sitting_Idle")
