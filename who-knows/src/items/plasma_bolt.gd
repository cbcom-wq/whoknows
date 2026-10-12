class_name PlasmaBolt
extends Bolt

## A plasma bolt (docs/superpowers/specs/2026-09-23-hands-and-items-design.md
## §9.2, §9.3): the pistol's. Its flight and its landing are Bolt's; this sets its
## numbers and its look.

const SPEED := 45.0
const LIFETIME := 1.5
## Newton-seconds given to whatever it hits.
const PUSH := 6.0
## hp a bolt takes from what it hits (health and damage spec §5.1).
const DAMAGE := 10.0
## interior_geometry | items.
const RAY_MASK := 2 | 32 | Npc.LAYER
## Outside: exterior_hull | terrain | items | asteroids | npcs -- Item.SPACE_MASK
## without the avatar.
const SPACE_RAY_MASK := 1 | BodyProxy.LAYER | 32 | AsteroidBody.LAYER | Npc.LAYER
## Chunky enough to read at the far end of a corridor: at 0.06 m thick it was
## a hairline by four metres.
const LENGTH := 0.5
const THICKNESS := 0.09
const LIGHT_ENERGY := 0.4
const LIGHT_RANGE := 2.5

static var _mesh: Mesh

func _init() -> void:
	speed = SPEED
	lifetime = LIFETIME
	push = PUSH
	damage = DAMAGE
	kind = &"plasma"

## The rays it casts, for where it is.
static func mask(out: bool) -> int:
	return SPACE_RAY_MASK if out else RAY_MASK

## What draws it and what its light falls on: the interior's aboard, the
## world's outside (as the repair torch's sparks).
static func render_layer(out: bool) -> int:
	return Item.SPACE_LAYER if out else InteriorKit.LAYER

static func light_mask(out: bool) -> int:
	return (1 | ExteriorBuilder.OWN_HULL_LAYER) if out else InteriorKit.LAYER

func _ready() -> void:
	ray_mask = mask(outside)
	if outside:
		add_to_group(Universe.EXTERIOR_SPACE)
	var body := MeshInstance3D.new()
	body.mesh = _shared_mesh()
	body.material_override = InteriorMaterials.glow()
	body.layers = render_layer(outside)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)
	var light := OmniLight3D.new()
	light.light_color = InteriorPalette.LIGHT_WARM
	light.light_energy = LIGHT_ENERGY
	light.omni_range = LIGHT_RANGE
	light.light_cull_mask = light_mask(outside)
	light.shadow_enabled = false
	add_child(light)

## A stretched glowing capsule along -z, shared by every bolt.
static func _shared_mesh() -> Mesh:
	if _mesh == null:
		var holder := Node3D.new()
		var kit := InteriorKit.new(holder)
		kit.bevel_box(InteriorKit.Batch.GLOW, Transform3D.IDENTITY, Vector3(THICKNESS, THICKNESS, LENGTH),
			THICKNESS * 0.4, InteriorKit.lit(InteriorPalette.PLASMA, 2.4))
		_mesh = kit.commit()[0].mesh
		holder.free()
	return _mesh
