class_name Hit
extends RefCounted

## What a hit carries to whatever it lands on (docs/superpowers/specs/
## 2026-09-23-hands-and-items-design.md §9.3): anything with
## receive_hit(hit: Hit) is told. Health and damage (docs/superpowers/specs/
## 2026-09-29-health-and-damage-design.md §3) adds what it does: its damage
## and kind, and the shape it landed on.

var position: Vector3
var normal: Vector3
var direction: Vector3
## Newton-seconds.
var impulse: Vector3
var source: Node
## hp. 0 for a hit that only pushes.
var damage := 0.0
## &"plasma", &"crash", &"bite"; &"" when it does not matter.
var kind: StringName = &""
## The collider's shape index the hit landed on, or -1: which cell of a hull.
var shape := -1

static func make(at: Vector3, surface_normal: Vector3, dir: Vector3, push: Vector3, from: Node) -> Hit:
	var hit := Hit.new()
	hit.position = at
	hit.normal = surface_normal
	hit.direction = dir
	hit.impulse = push
	hit.source = from
	return hit

## Tells `collider` about `hit` (spec §3): its own receive_hit, or the Callable
## a scriptless body carries in meta &"receive_hit" (the hull, the interior).
static func deliver(collider: Object, hit: Hit) -> void:
	if collider == null:
		return
	if collider.has_method(&"receive_hit"):
		collider.receive_hit(hit)
	elif collider.has_meta(&"receive_hit"):
		(collider.get_meta(&"receive_hit") as Callable).call(hit)
