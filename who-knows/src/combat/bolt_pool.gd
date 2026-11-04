class_name BoltPool
extends Node3D

## Every turret bolt (ship weapons spec §6.3): made once and reused, so a
## broadside makes no nodes. One per game, under the outside world; it never
## moves, and each bolt is shifted by the floating origin itself.

const GROUP := &"bolt_pool"

## Bolts flying or fading now, and every bolt ever made: for the probe.
var live := 0
var made := 0
var _free: Array[PhaserBolt] = []

func _ready() -> void:
	add_to_group(GROUP)

static func find(tree: SceneTree) -> BoltPool:
	return tree.get_first_node_in_group(GROUP) as BoltPool if tree != null else null

## A `kind` turret's bolt from `from` along `dir`, carried at `carrier`.
func fire(kind: StringName, from: Vector3, dir: Vector3, carrier: Vector3, source: Node,
		exclude: Array[RID]) -> PhaserBolt:
	var bolt: PhaserBolt
	if _free.is_empty():
		bolt = PhaserBolt.new()
		bolt.name = "Bolt%d" % made
		bolt.pool = self
		add_child(bolt)
		made += 1
	else:
		bolt = _free.pop_back()
	live += 1
	bolt.arm(kind, from, dir, carrier, source, exclude)
	return bolt

## The bolts armed and not yet landed or fading: what a pilot watches for.
func flying() -> Array[PhaserBolt]:
	var out: Array[PhaserBolt] = []
	for child in get_children():
		var bolt := child as PhaserBolt
		if bolt != null and not bolt.is_spent():
			out.append(bolt)
	return out

func release(bolt: PhaserBolt) -> void:
	live -= 1
	_free.append(bolt)
