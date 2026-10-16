class_name FireControl
extends Node

## One ship's fire control (ship weapons spec §5.1): its orders, the targets
## you marked in priority order, and every ASSIGN_EVERY a target for each
## turret -- the first listed it can engage, else the nearest hostile it can,
## else none. The turrets aim and fire themselves. An enemy ship will drive one
## the same way, its list written by its AI. Saved with the ship.

signal changed

enum Orders { HOLD, ENGAGE }

var orders := Orders.HOLD
var list: Array[StringName] = []
## The ship it fires for: never a target of its own.
var ship: Node
## Its turrets: each has can_engage(node) -> bool, muzzle() -> Vector3, and
## `target`, `no_arc` and `state`.
var turrets: Array = []
## The list as last resolved, for the HUD and the board: {id, node, label,
## distance, bearing}, node null while it is not found.
var entries: Array[Dictionary] = []
var _missing := {}   # id -> seconds unseen
var _since := 0.0

func _physics_process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	_since += delta
	if _since >= WeaponValues.ASSIGN_EVERY:
		assign(_since)
		_since = 0.0

## Marks `id` (spec §5.1, §9.1): a new one at the end, or in the last place
## when the list is full; one already listed to the top. Its own hull is
## refused. True if it is listed now.
func mark(id: StringName) -> bool:
	if id == &"" or (ship != null and id == Weapons.ship_id(ship)):
		return false
	if list.has(id):
		list.erase(id)
		list.push_front(id)
	elif list.size() < WeaponValues.LIST_MOST:
		list.append(id)
	else:
		list[WeaponValues.LIST_MOST - 1] = id
	_missing.erase(id)
	changed.emit()
	return true

## Marks the target nearest the line from `from` along `dir`, within `cone`
## (radians) of it and `reach` metres (spec §9.1). Its id, or &"" for none.
func mark_nearest(from: Vector3, dir: Vector3, cone: float, reach: float) -> StringName:
	var best: StringName = &""
	var best_angle := cone
	if not is_inside_tree():
		return best
	for n in get_tree().get_nodes_in_group(Weapons.TARGETS):
		var node := n as Node3D
		if node == null or Weapons.is_own(ship, node) or not Weapons.usable(node):
			continue
		var to := Weapons.point_of(node) - from
		if to.length() > reach or to.length_squared() < 1e-6:
			continue
		var angle := dir.angle_to(to)
		if angle <= best_angle:
			best_angle = angle
			best = Weapons.id_of(node)
	if best != &"":
		mark(best)
	return best

func unmark(id: StringName) -> void:
	if list.has(id):
		list.erase(id)
		_missing.erase(id)
		changed.emit()

func clear() -> void:
	list.clear()
	_missing.clear()
	changed.emit()

func set_orders(o: Orders) -> void:
	orders = o
	changed.emit()

func toggle_orders() -> void:
	set_orders(Orders.HOLD if orders == Orders.ENGAGE else Orders.ENGAGE)

## The first entry to the back (Tab at the weapons station, spec §7.2).
func rotate_list() -> void:
	if list.size() > 1:
		list.append(list.pop_front())
		changed.emit()

## Resolves the list and gives each turret its target. `elapsed` is the time
## since the last call, for the grace of an entry that has gone.
func assign(elapsed: float) -> void:
	var tree := get_tree() if is_inside_tree() else null
	var listed: Array[Node3D] = []
	entries.clear()
	for id in list.duplicate():
		var node := Weapons.find(tree, id)
		if node == null:
			_missing[id] = float(_missing.get(id, 0.0)) + elapsed
			if _missing[id] >= WeaponValues.MISSING_GRACE - 0.0001:
				list.erase(id)
				_missing.erase(id)
				changed.emit()
			else:
				entries.append({"id": id, "node": null, "label": String(id).to_upper(), "distance": -1.0, "bearing": false})
			continue
		_missing.erase(id)
		if not Weapons.is_own(ship, node):
			listed.append(node)
		entries.append({"id": id, "node": node, "label": Weapons.label_of(node), "distance": _distance_to(node),
			"bearing": false})
	for t in turrets:
		if not is_instance_valid(t):
			continue
		t.target = null if orders == Orders.HOLD else _pick(t, listed, tree)
		t.no_arc = orders == Orders.ENGAGE and not listed.is_empty() and t.target == null
	for e in entries:
		var raw = e["node"]
		e["bearing"] = raw != null and is_instance_valid(raw) and _anyone_can(raw as Node3D)

func bearing(id: StringName) -> bool:
	for e in entries:
		if e["id"] == id:
			return e["bearing"]
	return false

## Each turret's state, for the HUD's pips.
func pips() -> Array[StringName]:
	var out: Array[StringName] = []
	for t in turrets:
		if is_instance_valid(t):
			out.append(t.state)
	return out

func _pick(turret, listed: Array[Node3D], tree: SceneTree) -> Node3D:
	for node in listed:
		if turret.can_engage(node):
			return node
	if tree == null:
		return null
	var best: Node3D = null
	var best_d := INF
	for n in tree.get_nodes_in_group(Weapons.TARGETS):
		var node := n as Node3D
		if node == null or Weapons.is_own(ship, node) or not Weapons.usable(node) or not Weapons.is_hostile(node):
			continue
		if not turret.can_engage(node):
			continue
		var d: float = (turret.muzzle() as Vector3).distance_to(Weapons.point_of(node))
		if d < best_d:
			best_d = d
			best = node
	return best

func _anyone_can(node: Node3D) -> bool:
	for t in turrets:
		if is_instance_valid(t) and t.can_engage(node):
			return true
	return false

func _distance_to(node: Node3D) -> float:
	var from := ship as Node3D
	var hull: Node3D = ship.get("exterior") if ship != null and "exterior" in ship else from
	return hull.global_position.distance_to(Weapons.point_of(node)) if hull != null and hull.is_inside_tree() else -1.0

func to_dict() -> Dictionary:
	var ids := []
	for id in list:
		ids.append(String(id))
	return {"orders": "engage" if orders == Orders.ENGAGE else "hold", "list": ids}

func from_dict(d: Dictionary) -> void:
	orders = Orders.ENGAGE if String(d.get("orders", "hold")) == "engage" else Orders.HOLD
	list.clear()
	_missing.clear()
	for id in d.get("list", []):
		if list.size() < WeaponValues.LIST_MOST:
			list.append(StringName(id))
	changed.emit()
