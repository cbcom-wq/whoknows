class_name HoseNozzle
extends ItemUse

## The hose's nozzle (docs/superpowers/specs/2026-09-24-quantum-energy-design.md
## §11.4): held, with `use` held, it pulls loose items in its cone toward the
## mouth and swallows what reaches it into the home's store. It costs nothing
## and works in low power: gathering is how you climb back out.
##
## Whatever its holder does with it, Grasp hands it back to its reel
## (go_home); it is never a floating-origin member and never a stray.

## An item went in: its name in capitals and what it was worth, for the HUD.
signal swallowed(label: String, value: int)

## The reel it came from. Set when the reel stocks it; null in a test.
var reel: HoseReel:
	set(value):
		reel = value
		_had_reel = value != null

var _had_reel := false
var _refusal := ""
var _since_held := 1.0
var _pulled := false
var _shrinking: Array = []   # [Item, seconds left]
var _orphan_handled := false

## Whether it is pulling or swallowing something right now.
func is_drawing() -> bool:
	return _pulled and _since_held < 0.1

func hold(item: Item, _aim: Transform3D, _world: Node3D, holder: CollisionObject3D, _delta: float) -> bool:
	_since_held = 0.0
	_refusal = ""
	_pulled = false
	if not _usable():
		return false
	var mouth := item.global_transform * item.definition.use_point
	var dir := (-item.global_basis.z).normalized()
	# The mouth rides with whoever holds it: items are funnelled and capped in
	# its frame, not the world's, or a drifting ship would leave them behind.
	var v_mouth := Vector3.ZERO
	if holder is CharacterBody3D:
		v_mouth = (holder as CharacterBody3D).velocity
	for node in item.get_tree().get_nodes_in_group(Item.GROUP):
		var other := node as Item
		if other == null or other == item or not other.in_space or other.state != Item.State.LOOSE:
			continue
		var def := other.definition
		if def.eva_tool or def.quantum_value <= 0:
			continue
		var to := other.global_position - mouth
		if to.length() > Suction.RANGE + 1.0:
			continue
		if not Suction.in_cone(to, dir, Suction.largest_side(def) * 0.5):
			continue
		if Suction.too_big(def):
			_refusal = "Too big"
			continue
		if to.length() <= Suction.SWALLOW:
			if _swallow(other):
				_pulled = true
			continue
		other.sleeping = false
		other.apply_central_force(Suction.pull(-to, other.linear_velocity - v_mouth, other.mass))
		_pulled = true
	return _pulled

## Credits the store first, whole or not at all; only then does the item
## freeze and shrink into the mouth.
func _swallow(other: Item) -> bool:
	if not reel.sink.is_valid() or not bool(reel.sink.call(other)):
		_refusal = "Store full"
		return false
	var value := other.definition.quantum_value
	other.set_held()
	_shrinking.append([other, Suction.SHRINK])
	swallowed.emit(other.definition.display_name.to_upper(), value)
	return true

func _usable() -> bool:
	return reel != null and is_instance_valid(reel) and reel.sink.is_valid()

func _physics_process(delta: float) -> void:
	_since_held += delta
	if _since_held > 0.3:
		_refusal = ""
		_pulled = false
	var nozzle := get_parent() as Item
	if nozzle != null and _had_reel and not is_instance_valid(reel) and not _orphan_handled:
		# The hull was rebuilt under us: the reel is gone. Use it up, so a hand
		# never holds a nozzle with no line.
		_orphan_handled = true
		Item.consume.call_deferred(nozzle)
	_tick_shrinking(delta, nozzle)

## Each swallowed item shrinks into the mouth over SHRINK, then is consumed
## (which tells the salvage ledger it is taken).
func _tick_shrinking(delta: float, nozzle: Item) -> void:
	for i in range(_shrinking.size() - 1, -1, -1):
		var entry: Array = _shrinking[i]
		var thing := entry[0] as Item
		if not is_instance_valid(thing):
			_shrinking.remove_at(i)
			continue
		entry[1] = float(entry[1]) - delta
		if nozzle != null and is_instance_valid(nozzle):
			thing.global_position = nozzle.global_transform * nozzle.definition.use_point
		QuantumShow.swell(thing, clampf(float(entry[1]) / Suction.SHRINK, 0.0, 1.0))
		if float(entry[1]) <= 0.0:
			_shrinking.remove_at(i)
			Item.consume(thing)

func _exit_tree() -> void:
	for entry in _shrinking:
		var thing := entry[0] as Item
		if is_instance_valid(thing) and thing.is_inside_tree():
			Item.consume(thing)
	_shrinking.clear()

## *Too big* or *Store full* while that is what the trigger is meeting.
func aim_text(_item: Item, _aim: Transform3D, _holder: CollisionObject3D) -> String:
	return _refusal

func status() -> String:
	return "drawing" if is_drawing() else ""

## *HOSE 12 M*: the line paid out.
func tool_text() -> String:
	var nozzle := get_parent() as Item
	if not _usable() or nozzle == null:
		return ""
	return "HOSE %d M" % roundi(HoseRope.paid_out(reel.anchor(), nozzle.global_position))

## The line holds you at its length from the reel.
func tether() -> Dictionary:
	if not _usable():
		return {}
	return {"anchor": reel.anchor(), "length": HoseRope.LENGTH}

## Let go in any way: back to the reel, which winds it home.
func go_home(item: Item) -> bool:
	if not _usable():
		return false
	return reel.take_back(item)

## A save waits while the hose is out (it is not saved: the reel is rebuilt
## with the hull, and the nozzle with it).
func busy() -> String:
	if reel != null and is_instance_valid(reel) and reel.is_out():
		return "hose out"
	return ""
