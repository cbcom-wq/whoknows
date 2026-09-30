class_name BlockInstance
extends Resource

## One placed block. Deliberately tiny — a ship holds hundreds of these.
## Per-instance state lives here, which is why Slice 5's unidentified
## salvage will be a new field rather than a schema change.

@export var block_id: StringName
@export var orientation: int = 0     ## 0..23, see BlockOrientation
## hp lost; 0 is intact (health and damage spec §4.2). Only BlockDamage
## writes it.
@export var damage: float = 0.0

func duplicate_instance() -> BlockInstance:
	var copy := BlockInstance.new()
	copy.block_id = block_id
	copy.orientation = orientation
	copy.damage = damage
	return copy
