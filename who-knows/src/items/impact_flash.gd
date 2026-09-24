class_name ImpactFlash
extends Node3D

## A short burst of plasma light (docs/superpowers/specs/
## 2026-09-23-hands-and-items-design.md §9): at the muzzle when the pistol
## fires, and where a bolt lands. It grows and shrinks to nothing -- by scale,
## so the shared glow material is never touched -- with a warm light fading
## beside it, then frees itself.

enum Kind { MUZZLE, IMPACT }

const DURATION := {Kind.MUZZLE: 0.05, Kind.IMPACT: 0.15}
const SIZE := {Kind.MUZZLE: 0.08, Kind.IMPACT: 0.3}
const LIGHT_ENERGY := 0.8
const LIGHT_RANGE := 3.0

static var _mesh: Mesh

var kind: Kind = Kind.IMPACT
var _age := 0.0
var _burst: MeshInstance3D
var _light: OmniLight3D

static func spawn(parent: Node, at: Vector3, normal: Vector3, flash_kind: Kind) -> ImpactFlash:
	var flash := ImpactFlash.new()
	flash.kind = flash_kind
	parent.add_child(flash)
	var up := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	flash.global_transform = Transform3D(Basis.looking_at(-normal, up), at + normal * 0.01)
	return flash

func _ready() -> void:
	_burst = MeshInstance3D.new()
	_burst.mesh = _shared_mesh()
	_burst.material_override = InteriorMaterials.glow()
	_burst.layers = InteriorKit.LAYER
	_burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_burst.scale = Vector3.ONE * 0.001
	add_child(_burst)
	_light = OmniLight3D.new()
	_light.light_color = InteriorPalette.LIGHT_WARM
	_light.light_energy = LIGHT_ENERGY
	_light.omni_range = LIGHT_RANGE
	_light.light_cull_mask = InteriorKit.LAYER
	_light.shadow_enabled = false
	add_child(_light)

func _process(delta: float) -> void:
	_age += delta
	var t: float = _age / DURATION[kind]
	if t >= 1.0:
		queue_free()
		return
	_burst.scale = Vector3.ONE * maxf(sin(t * PI) * SIZE[kind], 0.001)
	_light.light_energy = LIGHT_ENERGY * (1.0 - t)

## A unit burst facing +z: a plasma disc with a hot core and a chunky centre.
static func _shared_mesh() -> Mesh:
	if _mesh == null:
		var holder := Node3D.new()
		var kit := InteriorKit.new(holder)
		kit.disc(InteriorKit.Batch.GLOW, Transform3D.IDENTITY, 1.0, InteriorKit.lit(InteriorPalette.PLASMA, 2.4))
		kit.disc(InteriorKit.Batch.GLOW, InteriorKit.at(Vector3(0, 0, 0.02)), 0.5,
			InteriorKit.lit(InteriorPalette.LIGHT_WARM, 2.4))
		kit.bevel_box(InteriorKit.Batch.GLOW, Transform3D.IDENTITY, Vector3.ONE * 0.6, 0.1,
			InteriorKit.lit(InteriorPalette.PLASMA, 2.4))
		_mesh = kit.commit()[0].mesh
		holder.free()
	return _mesh
