class_name Weapons
extends RefCounted

## What turrets may shoot (ship weapons spec §4): every target outside is in
## TARGETS, its id in meta ID. Ships, bases, NPCs outside and loose items in
## space join; you never do. Nothing here holds a node: fire control keeps ids
## and finds them again.

const TARGETS := &"weapon_targets"
const ID := &"target_id"
## An NPC is aimed at this far up its own body from its feet, m.
const NPC_CENTRE := 0.4

## Whether a node is hostile, for tests and the enemy project (spec §4.3):
## nothing is in this one.
static var hostile_rule: Callable

static func join(node: Node, id: StringName) -> void:
	node.set_meta(ID, id)
	if not node.is_in_group(TARGETS):
		node.add_to_group(TARGETS)

static func leave(node: Node) -> void:
	if node.is_in_group(TARGETS):
		node.remove_from_group(TARGETS)

static func id_of(node: Node) -> StringName:
	return node.get_meta(ID, &"") if node != null else &""

static func ship_id(ship: Node) -> StringName:
	return StringName("ship:%s" % ship.name)

static func base_id(site_id: StringName) -> StringName:
	return StringName("base:%s" % site_id)

static func npc_id(record_id: StringName) -> StringName:
	return StringName("npc:%s" % record_id)

## Good for the session only (spec §4.4).
static func item_id(item: Node) -> StringName:
	return StringName("item:%d" % item.get_instance_id())

## The part of an id before its colon: &"ship", &"base", &"npc", &"item".
static func kind_of(id: StringName) -> StringName:
	var s := String(id)
	var at := s.find(":")
	return StringName(s.substr(0, at)) if at > 0 else &""

## Whether `node` can be shot at now: alive, in the tree, a target, not dead,
## not a ship asleep.
static func usable(node: Node) -> bool:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree() or not node.is_in_group(TARGETS):
		return false
	if node is Npc and (node as Npc).is_dead():
		return false
	var ship := _ship_of(node)
	if ship != null and ship.is_in_group(Fleet.ASLEEP):
		return false
	return true

## The target called `id`, or null when it is gone.
static func find(tree: SceneTree, id: StringName) -> Node3D:
	if tree == null or id == &"":
		return null
	for node in tree.get_nodes_in_group(TARGETS):
		if is_instance_valid(node) and id_of(node) == id and usable(node):
			return node as Node3D
	return null

## Where to aim at it, now: a hull's centre of mass, an NPC's middle.
static func point_of(node: Node3D) -> Vector3:
	var body := node as RigidBody3D
	if body != null and body.center_of_mass_mode == RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM:
		return body.global_transform * body.center_of_mass
	if node is Npc:
		return node.global_position + node.global_basis.y * NPC_CENTRE
	return node.global_position

static func velocity_of(node: Node3D) -> Vector3:
	if node is RigidBody3D:
		var body := node as RigidBody3D
		return Vector3.ZERO if body.freeze else body.linear_velocity
	if node is CharacterBody3D:
		return (node as CharacterBody3D).velocity
	return Vector3.ZERO

## What the HUD and the board call it.
static func label_of(node: Node) -> String:
	var ship := _ship_of(node) as Ship
	if ship != null:
		var given := ship.launch_blueprint.ship_name if ship.launch_blueprint != null else ""
		return (given if given != "" else String(ship.name)).to_upper()
	if node.has_meta(&"base"):
		return "BASE"
	if node is Npc and (node as Npc).species != null:
		return (node as Npc).species.display_name.to_upper()
	if node is Item and (node as Item).definition != null:
		return (node as Item).definition.display_name.to_upper()
	return String(id_of(node)).to_upper()

static func is_hostile(node: Node) -> bool:
	return hostile_rule.is_valid() and bool(hostile_rule.call(node))

## Whether `node` is `ship`'s own hull (spec §4.4): ships have no owner yet.
static func is_own(ship: Node, node: Node) -> bool:
	return ship != null and node != null and is_instance_valid(node) and _ship_of(node) == ship

## The ship whose hull `node` is, or null: meta &"ship" is set on a hull only,
## and get_meta with a null default errors when it is missing.
static func _ship_of(node: Node) -> Node:
	return node.get_meta(&"ship") as Node if node.has_meta(&"ship") else null
