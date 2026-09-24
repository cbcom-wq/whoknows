class_name HandLamp
extends ItemUse

## A hand lamp (docs/superpowers/specs/2026-09-23-hands-and-items-design.md
## §4.2, as amended 2026-09-24): use switches a warm beam on and off. It stays
## as it was when dropped, stowed or thrown, and it lights the outside as well
## as the cabin, so a lamp carried out onto a spacewalk is still a lamp.

const ENERGY := 2.6
const RANGE := 10.0
const ANGLE := 22.0
## The exterior and interior render layers: it lights wherever you take it.
const CULL_MASK := 1 | 2

var on := false

var _beam: SpotLight3D
var _lens: Node3D

func _ready() -> void:
	var at := _use_point()
	# SpotLight3D shines along its -z, which is the lamp's nose.
	_beam = SpotLight3D.new()
	_beam.name = "Beam"
	_beam.position = at
	_beam.light_color = InteriorPalette.LIGHT_WARM
	_beam.light_energy = ENERGY
	_beam.spot_range = RANGE
	_beam.spot_angle = ANGLE
	_beam.shadow_enabled = false
	_beam.light_cull_mask = CULL_MASK
	add_child(_beam)
	_lens = Node3D.new()
	_lens.name = "Lens"
	add_child(_lens)
	var kit := InteriorKit.new(_lens)
	kit.disc(InteriorKit.Batch.GLOW, Transform3D(Basis(Vector3.UP, PI), at + Vector3(0, 0, -0.001)), 0.024,
		InteriorKit.lit(InteriorPalette.LIGHT_WARM, InteriorMaterials.GLOW_ENERGY))
	kit.commit()
	_show()

func use(_item: Item, _aim: Transform3D, _world: Node3D, _holder: CollisionObject3D) -> bool:
	on = not on
	_show()
	return true

func status() -> String:
	return "on" if on else ""

func _show() -> void:
	_beam.visible = on
	_lens.visible = on

func _use_point() -> Vector3:
	var item := get_parent() as Item
	return item.definition.use_point if item != null and item.definition != null else Vector3.ZERO
