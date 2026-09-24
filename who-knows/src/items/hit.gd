class_name Hit
extends RefCounted

## What a hit carries to whatever it lands on (docs/superpowers/specs/
## 2026-09-23-hands-and-items-design.md §9.3): anything with
## receive_hit(hit: Hit) is told. Nothing takes damage yet; Slice 2's damage
## reads this.

var position: Vector3
var normal: Vector3
var direction: Vector3
## Newton-seconds.
var impulse: Vector3
var source: Node

static func make(at: Vector3, surface_normal: Vector3, dir: Vector3, push: Vector3, from: Node) -> Hit:
	var hit := Hit.new()
	hit.position = at
	hit.normal = surface_normal
	hit.direction = dir
	hit.impulse = push
	hit.source = from
	return hit
