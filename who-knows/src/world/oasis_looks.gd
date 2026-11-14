class_name OasisLooks
extends RefCounted

## What the oasis's pieces look like: faceted shapes built with an InteriorKit
## in the oasis's colours (OasisPalette). The kit builds on the outside's own
## layer here (layer 1, the world), never the interior's.

## Where the kit builds the pool's water: layer 1 and the world's light.
const WORLD_LAYER := 1

## A kit that draws on the world's layer under `root`.
static func kit_under(root: Node3D) -> InteriorKit:
	var kit := InteriorKit.new(root)
	kit.layer = WORLD_LAYER
	kit.light_mask = WORLD_LAYER
	return kit

## The pool's water: a flat, faceted disc of `radius` in the frame `f`'s
## horizontal plane (its up is the frame's y), in OasisPalette.WATER.
static func water(kit: InteriorKit, f: Transform3D, radius: float) -> void:
	var flat := Transform3D(f.basis * Basis(Vector3.RIGHT, -PI * 0.5), f.origin)
	kit.disc(InteriorKit.Batch.SOLID, flat, radius, InteriorKit.solid(OasisPalette.WATER))
