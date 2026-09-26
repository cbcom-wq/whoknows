class_name NpcLooks
extends RefCounted

## What NPCs look like (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §13.4, §14.4), built in code. Until a
## species has its look, a plain box its size stands in.

## The look called `look`, its origin at the feet.
static func build(look: StringName, _variety: float, inside: bool) -> Node3D:
	match look:
		_:
			return placeholder(inside)

## A box: an NPC with no look yet.
static func placeholder(inside: bool) -> Node3D:
	var root := Node3D.new()
	var box := MeshInstance3D.new()
	box.name = "Placeholder"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.5, 0.5, 0.5)
	box.mesh = mesh
	box.position = Vector3(0, 0.25, 0)
	box.layers = 2 if inside else 1
	root.add_child(box)
	return root
