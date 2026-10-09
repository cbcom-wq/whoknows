class_name LinkPanel
extends Node3D

## The hub's link panel (habitat modules spec §6.1): a pedestal by the
## airlock with a screen -- *SHIP 640 · BASE 120*, and each drill's gauge
## beneath -- and two buttons, ◀ to the ship and ▶ to the base, LINK_STEP a
## press and LINK_RATE a second while held. *NO LINK* with no ship within
## LINK_REACH. Built from the kit and ReadoutPanels, in InteriorPalette.

const PEDESTAL := Vector3(0.5, 1.05, 0.3)

var base: Base
var _screen: ReadoutPanel
var _to_ship: ReadoutPanel
var _to_base: ReadoutPanel
var _held := 0.0

func setup(p_base: Base) -> void:
	base = p_base
	var kit := InteriorKit.new(self)
	kit.bevel_box(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(0, PEDESTAL.y * 0.5, 0)), PEDESTAL, 0.04,
		InteriorKit.solid(InteriorPalette.TRIM))
	kit.commit()
	_screen = ReadoutPanel.new()
	_screen.setup(&"link", InteriorKit.LAYER)
	_screen.transform = Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, PEDESTAL.y + 0.2, 0.05))
	add_child(_screen)
	_to_ship = _button(&"to_ship", -0.13)
	_to_base = _button(&"to_base", 0.13)

func _button(role: StringName, x: float) -> ReadoutPanel:
	var b := ReadoutPanel.new()
	b.setup(role, InteriorKit.LAYER, InteriorKit.LAYER, Vector3(0.12, 0.12, 0.04), false)
	b.transform = Transform3D(Basis.IDENTITY, Vector3(x, PEDESTAL.y - 0.15, PEDESTAL.z * 0.5))
	b.prompt_source = func() -> String: return _prompt(role)
	b.pressed.connect(press)
	add_child(b)
	return b

func _process(_delta: float) -> void:
	if _screen != null:
		_screen.set_readout(lines(), &"go" if _ship() != null else &"vacuum")

func _ship() -> Ship:
	var bases := get_tree().get_first_node_in_group(Bases.GROUP) as Bases if is_inside_tree() else null
	if bases == null or not bases.ship_near.is_valid():
		return null
	var ship: Ship = bases.ship_near.call(base.exterior.global_position)
	if ship == null or not QuantumLink.in_reach(base.exterior.global_position, ship.exterior.global_position):
		return null
	return ship

func lines() -> PackedStringArray:
	var ship := _ship()
	var out := PackedStringArray()
	out.append("NO LINK" if ship == null else "SHIP %d · BASE %d" % [ship.quantum.store.amount, base.quantum.store.amount])
	for i in base.site.drills():
		out.append("DRILL %d · %s" % [i, DrillYield.gauge(base.site.modules[i]["drill"])])
	return out

func _prompt(role: StringName) -> String:
	if _ship() == null:
		return ""
	return "Move %d QE to the ship" % HabitatValues.LINK_STEP if role == &"to_ship" \
		else "Move %d QE to the base" % HabitatValues.LINK_STEP

func press(role: StringName) -> void:
	_move(role, HabitatValues.LINK_STEP)

## Held down: LINK_RATE a second, in whole QE.
func hold(role: StringName, delta: float) -> void:
	_held += HabitatValues.LINK_RATE * delta
	var whole := floori(_held)
	_held -= whole
	_move(role, whole)

func _move(role: StringName, n: int) -> void:
	var ship := _ship()
	if ship == null or n <= 0:
		return
	if role == &"to_ship":
		QuantumLink.move(base.quantum.store, ship.quantum.store, n)
	else:
		QuantumLink.move(ship.quantum.store, base.quantum.store, n)
