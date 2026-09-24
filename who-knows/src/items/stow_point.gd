class_name StowPoint
extends Node3D

## A place that secures one item (docs/superpowers/specs/
## 2026-09-23-hands-and-items-design.md §5.1): a rack cradle, a spot on a
## counter, a place on a shelf. Its origin is where the stowed item's base
## sits -- the centre of the item's local -y face -- and the item's axes lie
## along its own. A secured item is frozen, so no burn can move it.

const GROUP := &"stow_point"

## The stow class it takes (ItemDefinition.stow_class).
@export var accepts: StringName
## The item id stocked here when a ship first loads, or &"".
@export var stock: StringName

var item: Item = null

func _init() -> void:
	add_to_group(GROUP)

func is_free() -> bool:
	return item == null or not is_instance_valid(item) or item.stow_point != self

func fits(candidate: Item) -> bool:
	return is_free() and candidate != null and candidate.definition.stow_class == accepts

## Where an item's origin goes when it is secured here.
func item_transform(candidate: Item) -> Transform3D:
	return global_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, candidate.definition.size.y * 0.5, 0.0))

func secure(candidate: Item) -> void:
	item = candidate
	candidate.set_stowed(self)
	candidate.global_transform = item_transform(candidate)
	candidate.linear_velocity = Vector3.ZERO
	candidate.angular_velocity = Vector3.ZERO

## Lets the item go loose and forgets it.
func release() -> Item:
	var out := item
	item = null
	if out != null and is_instance_valid(out) and out.stow_point == self:
		out.set_loose()
	return out
