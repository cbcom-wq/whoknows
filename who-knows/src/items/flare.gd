class_name Flare
extends ItemUse

## An emergency flare (docs/superpowers/specs/2026-09-23-hands-and-items-design.md
## §4.2, as amended 2026-09-24): use strikes it, once. It burns with a warm,
## flickering light for BURN_TIME -- in your hand, on the floor where you threw
## it, on a shelf -- then goes out for good.
##
## Every light is LIGHT_WARM (visual style guide §2.3), so it burns warm, not
## signal red; the glowing tip carries the plasma coral.

enum Burn { UNLIT, BURNING, SPENT }

const BURN_TIME := 60.0
const ENERGY := 0.9
## How far the flicker swings the light either side of ENERGY, as a fraction.
const FLICKER := 0.2
const RANGE := 5.0
## The exterior and interior render layers: it lights wherever it is.
const CULL_MASK := 1 | 2

var burn := Burn.UNLIT
var burn_left := BURN_TIME

var _light: OmniLight3D
var _flame: Node3D
var _phase := 0.0

func _ready() -> void:
	var at := _use_point()
	_light = OmniLight3D.new()
	_light.name = "Light"
	_light.position = at
	_light.light_color = InteriorPalette.LIGHT_WARM
	_light.light_energy = ENERGY
	_light.omni_range = RANGE
	_light.shadow_enabled = false
	_light.light_cull_mask = CULL_MASK
	add_child(_light)
	_flame = Node3D.new()
	_flame.name = "Flame"
	add_child(_flame)
	var kit := InteriorKit.new(_flame)
	kit.bevel_box(InteriorKit.Batch.GLOW, InteriorKit.at(at), Vector3(0.03, 0.03, 0.04), 0.01,
		InteriorKit.lit(InteriorPalette.PLASMA, InteriorMaterials.GLOW_ENERGY))
	kit.bevel_box(InteriorKit.Batch.GLOW, InteriorKit.at(at + Vector3(0, 0, -0.015)), Vector3(0.018, 0.018, 0.025),
		0.006, InteriorKit.lit(InteriorPalette.LIGHT_WARM, InteriorMaterials.GLOW_ENERGY))
	kit.commit()
	_show()

func use(_item: Item, _aim: Transform3D, _world: Node3D, _holder: CollisionObject3D) -> bool:
	if burn != Burn.UNLIT:
		return false
	burn = Burn.BURNING
	_show()
	return true

func status() -> String:
	match burn:
		Burn.BURNING:
			return "burning"
		Burn.SPENT:
			return "spent"
	return ""

func _process(delta: float) -> void:
	if burn != Burn.BURNING:
		return
	burn_left -= delta
	if burn_left <= 0.0:
		burn = Burn.SPENT
		_show()
		return
	_phase += delta
	_light.light_energy = ENERGY * (1.0 + FLICKER * sin(_phase * 23.0) * sin(_phase * 7.3))

func _show() -> void:
	var lit := burn == Burn.BURNING
	_light.visible = lit
	_flame.visible = lit

func _use_point() -> Vector3:
	var item := get_parent() as Item
	return item.definition.use_point if item != null and item.definition != null else Vector3.ZERO
