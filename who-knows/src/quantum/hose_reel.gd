class_name HoseReel
extends StowPoint

## The reel on an airlock's outer face (docs/superpowers/specs/
## 2026-09-24-quantum-energy-design.md §11.1): it holds the nozzle, pays the
## line out when the nozzle is taken, and winds the nozzle home over WIND_TIME
## when it is let go. It is a StowPoint, so Grasp takes the nozzle from it like
## anything off a rack.
##
## AirlockAlcove builds it, with the hull; Airlock.bind gives it the home's
## `sink`, `room` and `line_parent` and stocks it. The hull is rebuilt whenever
## a block changes, which frees the reel and its nozzle: a nozzle held then
## notices its reel is gone and uses itself up (HoseNozzle).

const STOW_CLASS := &"hose"
## Home along the line, seconds.
const WIND_TIME := 1.0

## Credits an item to the home's store: `func(item: Item) -> bool`.
var sink: Callable
## How much QE the home's store can still take: `func() -> int`. Invalid means
## unlimited (a test without a store).
var room: Callable
## Where the line lives: the home's Outside, which never moves itself.
var line_parent: Node3D
## The line, while the nozzle is out.
var line: HoseLine

var _winding: Item = null
var _wind_t := 0.0
var _wind_from := Transform3D.IDENTITY
## True once this reel has been stocked: it is stocked once in its life.
var _stocked := false

func _init() -> void:
	super()
	accepts = STOW_CLASS
	name = "HoseReel"

## Where the line is anchored: the reel's own origin, in the world.
func anchor() -> Vector3:
	return global_position

## True while the nozzle is not secured here: in a hand, or winding home.
func is_out() -> bool:
	return is_free()

## Makes a nozzle of `def` and secures it here, once per reel: a hull-keeping
## rebuild binds the same reel again while the nozzle may be out, and a free
## reel is then not an empty one. The nozzle is drawn for outside from the
## start and never a floating-origin member: it lives under this reel, which is
## on the hull, or in your hands.
func stock_nozzle(def: ItemDefinition) -> void:
	if _stocked or not is_free() or def == null:
		return
	_stocked = true
	var nozzle := Item.new()
	nozzle.setup(def)
	nozzle.set_space(true)
	if nozzle.use_node != null and "reel" in nozzle.use_node:
		nozzle.use_node.reel = self
	add_child(nozzle, true)
	secure(nozzle)

## Taken: the line pays out.
func release() -> Item:
	var out := super.release()
	if out != null:
		_pay_out(out)
	return out

func _pay_out(nozzle: Item) -> void:
	if line != null and is_instance_valid(line) and not line.ended:
		return
	if line_parent == null or not line_parent.is_inside_tree():
		return
	line = HoseLine.new()
	line.name = "HoseLine"
	line_parent.add_child(line)
	line.setup(self, nozzle)

## Winds a let-go nozzle home along the line over WIND_TIME, then secures it.
## False if one is already winding.
func take_back(nozzle: Item) -> bool:
	if _winding != null or not is_inside_tree():
		return false
	_winding = nozzle
	_wind_t = 0.0
	nozzle.set_held()
	nozzle.reparent(self, true)
	_wind_from = nozzle.global_transform
	return true

func _physics_process(delta: float) -> void:
	if _winding != null:
		if not is_instance_valid(_winding):
			_winding = null
			return
		_wind_t = minf(_wind_t + delta / WIND_TIME, 1.0)
		_winding.global_transform = _wind_from.interpolate_with(item_transform(_winding), _wind_t)
		if _wind_t >= 1.0:
			var home := _winding
			_winding = null
			secure(home)
			if line != null and is_instance_valid(line):
				line.finish()

func _exit_tree() -> void:
	if line != null and is_instance_valid(line):
		line.finish()
