class_name SunPump
extends StaticBody3D

## Halla's sun pump (docs/superpowers/specs/2026-11-16-wadoo-design.md §7): a
## stone well head beside her dry garden, with a bronze frame whose cage holds a
## sun cell. The beast broke its cell. Holding a new one, [F] Fit the sun cell,
## and the pump wakes: the cell glows in its cage, the rod nods as it draws,
## water runs down the stone channel to the bed, and over GROW_TIME the garden's
## green crops rise over the dry ones. They are drawn a little wider than the
## dry ones (OasisLooks.crops `widen`), so once grown they cover them.
##
## Built by PlaceField from the layout's `sun_pump` ({at, garden, channel_to}), a
## child of the place's node in its frame. It knows nothing of the village: the
## flight scene answers `fitted` (it takes the cell from your hands and marks the
## task) and sets `working` from WadooState (set_working).

signal fitted(actor: Node)

const NAME := "SunPump"
## What it takes.
const CELL := &"sun_cell"
## How long the garden takes to grow green, s, and how tall it starts (of its
## full height).
const GROW_TIME := 60.0
const GROW_FROM := 0.05
## The rod nods once every NOD_EVERY s, by NOD rad either way; broken, it hangs
## at REST_TILT.
const NOD_EVERY := 1.6
const NOD := 0.2
const REST_TILT := -0.14
const CHANNEL_WIDTH := 0.26
## Its collider: a cylinder over the whole pump, so the Interactor's ray meets it
## at the cage as well as at the well.
const RADIUS := 0.52
const HEIGHT := 1.8

var working := false
var cell: Node3D
var water: Node3D
var green: Node3D
var rod: Node3D
## How far the green has grown, 0 to 1.
var grown := 1.0
var _time := 0.0

## A pump at `f` (its foot, place frame), its channel running to `channel_to`
## (place frame), growing the garden at `garden` (its bed's foot) of `size`,
## whose crops are laid out by `variety` as the village drew its dry ones.
static func make(f: Transform3D, channel_to: Vector3, garden: Transform3D, size: Vector2, variety: float) -> SunPump:
	var pump := SunPump.new()
	pump.name = NAME
	pump.transform = f
	pump.collision_layer = BodyProxy.LAYER
	pump.collision_mask = 0
	pump.add_to_group(&"interactable")
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = RADIUS
	cylinder.height = HEIGHT
	shape.shape = cylinder
	shape.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	pump.add_child(shape)
	var inv := f.affine_inverse()
	var to := inv * channel_to
	to.y = 0.0
	var from := Vector3(to.x, 0.0, to.z).normalized() * (OasisLooks.SUN_WELL.x - 0.05)
	var kit := OasisLooks.kit_under(pump._part("Body"))
	OasisLooks.sun_pump(kit, Transform3D.IDENTITY)
	OasisLooks.channel(kit, from, to, CHANNEL_WIDTH)
	kit.commit()
	pump.rod = pump._part("Rod")
	pump.rod.position = OasisLooks.SUN_ROD_PIVOT
	kit = OasisLooks.kit_under(pump.rod)
	OasisLooks.sun_pump_rod(kit, Transform3D.IDENTITY)
	kit.commit()
	pump.cell = pump._part("Cell")
	pump.cell.position = Vector3(0.0, OasisLooks.SUN_CAGE, 0.0)
	kit = OasisLooks.kit_under(pump.cell)
	ItemLooks.sun_cell(kit, Vector3(0.2, 0.28, 0.2))
	kit.commit()
	pump.water = pump._part("Water")
	kit = OasisLooks.kit_under(pump.water)
	OasisLooks.channel_water(kit, from, to, CHANNEL_WIDTH - 0.04)
	kit.commit()
	pump.green = pump._part("Green")
	var g := inv * garden
	pump.green.transform = Transform3D(g.basis, g.origin + g.basis.y * OasisLooks.BED_TOP)
	kit = OasisLooks.kit_under(pump.green)
	OasisLooks.crops(kit, Transform3D(Basis.IDENTITY, Vector3(0.0, -OasisLooks.BED_TOP, 0.0)), size, false, variety, 0.03)
	kit.commit()
	pump.set_working(false, true)
	return pump

## A node with _process is set processing as it is readied: only while working.
func _ready() -> void:
	set_process(working)

func _part(part_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = part_name
	add_child(n)
	return n

## Working or broken. Woken now, the green grows from GROW_FROM over GROW_TIME;
## `at_once` (as the place loads) it is grown already.
func set_working(on: bool, at_once := false) -> void:
	if on and not working:
		grown = 1.0 if at_once else 0.0
	working = on
	cell.visible = on
	water.visible = on
	green.visible = on
	_show()
	set_process(on)

func _process(delta: float) -> void:
	_time += delta
	grown = minf(grown + delta / GROW_TIME, 1.0)
	_show()

func _show() -> void:
	rod.rotation.z = sin(_time * TAU / NOD_EVERY) * NOD if working else REST_TILT
	green.scale = Vector3(1.0, lerpf(GROW_FROM, 1.0, grown), 1.0)

func prompt_text() -> String:
	return "Fit the sun cell"

## Broken, and you hold a sun cell.
func can_interact(actor: Node) -> bool:
	return not working and Grasp.kind_in(actor) == CELL

func interact(actor: Node) -> void:
	if can_interact(actor):
		fitted.emit(actor)
