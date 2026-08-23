class_name BlockInstance
extends Resource

## One placed block. Deliberately tiny — a ship holds hundreds of these.
## Per-instance state lives here, which is why Slice 5's unidentified
## salvage will be a new field rather than a schema change.

@export var block_id: StringName
@export var orientation: int = 0     ## 0..23, see BlockOrientation
@export var hp_current: int = 0

func duplicate_instance() -> BlockInstance:
	var copy := BlockInstance.new()
	copy.block_id = block_id
	copy.orientation = orientation
	copy.hp_current = hp_current
	return copy
