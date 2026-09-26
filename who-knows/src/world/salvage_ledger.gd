class_name SalvageLedger
extends RefCounted

## What has been taken from the salvage clouds (docs/superpowers/specs/
## 2026-09-24-quantum-energy-design.md §10.3), by cloud id and item index. A
## cloud that loads again leaves those out, so nothing taken comes back.
## Taken means swallowed by the hose; nothing else removes salvage in this
## build. Pure; SalvageField owns one for the session (saving it is a hook,
## §17).

var _taken := {}   # StringName cloud id -> {int index: true}

## Remembers that item `index` of cloud `cloud_id` is gone. Taking it again
## changes nothing.
func take(cloud_id: StringName, index: int) -> void:
	if not _taken.has(cloud_id):
		_taken[cloud_id] = {}
	_taken[cloud_id][index] = true

func is_taken(cloud_id: StringName, index: int) -> bool:
	return _taken.has(cloud_id) and _taken[cloud_id].has(index)

## How many of a cloud's `count` items are still out there: whether it still
## holds anything, for the marker (spec §10.4).
func remaining(cloud_id: StringName, count: int) -> int:
	var gone: int = _taken[cloud_id].size() if _taken.has(cloud_id) else 0
	return maxi(count - gone, 0)
