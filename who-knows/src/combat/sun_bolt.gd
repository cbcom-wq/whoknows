class_name SunBolt
extends Bolt

## A bolt of stored sun (docs/superpowers/specs/2026-11-16-wadoo-design.md §8, §9):
## the Sunguard throw it from their sunstaffs, and the queen's sun-rod lets you
## throw it. Slower than a plasma bolt, so at their range you can step out of its
## way, and gold, the colour of sunglass. Its flight and its landing are Bolt's;
## this sets its numbers and its look.

const SPEED := 30.0
const LIFETIME := 1.6
## Newton-seconds given to whatever it hits.
const PUSH := 4.0
## hp: a Sunguard's bolt (spec §9). The sun-rod's is SunRod.DAMAGE.
const DAMAGE := 12.0
## What a Sunguard's bolt meets: the hull, you (the avatar's layer), the ground and
## the town's walls and houses, items. Not the Wadees: it passes their own by.
const AT_YOU_MASK := 1 | 4 | BodyProxy.LAYER | 32
const LENGTH := 0.7
const THICKNESS := 0.12
const LIGHT_ENERGY := 0.8
const LIGHT_RANGE := 3.5
## How much brighter the sun-rod's are with the water-stone charm (spec §8).
const CHARMED := 1.8
## The burst on you, of a burst elsewhere: it lands 0.3 m from your eye, where a
## full one hid a sixth of the view; your hurt (the red edge, the jolt) says the rest.
const ON_YOU_FLASH := 0.25

## Its light and its flash against a plain bolt's.
var bright := 1.0

static var _mesh: Mesh

func _init() -> void:
	speed = SPEED
	lifetime = LIFETIME
	push = PUSH
	damage = DAMAGE
	kind = &"sun"

## Set `ray_mask` before it enters the tree to aim it at you (AT_YOU_MASK); left
## at 0 it meets what a plasma bolt meets where it is.
func _ready() -> void:
	if ray_mask == 0:
		ray_mask = PlasmaBolt.mask(outside)
	if outside:
		add_to_group(Universe.EXTERIOR_SPACE)
	flash_bright = bright
	flash_scale = 1.2
	var body := MeshInstance3D.new()
	body.mesh = _shared_mesh()
	body.material_override = InteriorMaterials.glow()
	body.layers = PlasmaBolt.render_layer(outside)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)
	var light := OmniLight3D.new()
	light.light_color = WadeePalette.LAMP
	light.light_energy = LIGHT_ENERGY * bright
	light.omni_range = LIGHT_RANGE
	light.light_cull_mask = PlasmaBolt.light_mask(outside)
	light.shadow_enabled = false
	add_child(light)

## A stretched glowing capsule of sunglass along -z, shared by every sun bolt.
static func _shared_mesh() -> Mesh:
	if _mesh == null:
		var holder := Node3D.new()
		var kit := InteriorKit.new(holder)
		kit.bevel_box(InteriorKit.Batch.GLOW, Transform3D.IDENTITY, Vector3(THICKNESS, THICKNESS, LENGTH),
			THICKNESS * 0.45, InteriorKit.lit(WadeePalette.SUNGLASS, 2.8))
		_mesh = kit.commit()[0].mesh
		holder.free()
	return _mesh

func impact(result: Dictionary) -> void:
	if result.get("collider") is Avatar:
		flash_scale = ON_YOU_FLASH
	super(result)
