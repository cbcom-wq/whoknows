class_name StrayLedger
extends RefCounted

## Items adrift outside that no seed accounts for (docs/superpowers/specs/
## 2026-09-26-saving-design.md §7): where each is, how it moves, and how long
## you have been far from it. Kept, and saved, while you are near. Once you
## are more than FORGET_BEYOND from one for FORGET_AFTER of play, it is gone
## for good. Coming back within range starts its clock again.
##
## Pure: StrayField keeps the live items and ticks this with where you are.

const FORGET_BEYOND := 5000.0
const FORGET_AFTER := 600.0

## int id -> {kind: StringName, variety: float, at: UniversePoint, turn: Basis,
## v: Vector3, w: Vector3, use: Dictionary, far: float}
var entries := {}
var _next_id := 1

## Remembers a stray and returns its id.
func add(kind: StringName, variety: float, at: UniversePoint, turn: Basis, v: Vector3, w: Vector3,
		use := {}) -> int:
	var id := _next_id
	_next_id += 1
	entries[id] = {"kind": kind, "variety": variety, "at": at, "turn": turn, "v": v, "w": w, "use": use,
		"far": 0.0}
	return id

func has(id: int) -> bool:
	return entries.has(id)

func remove(id: int) -> void:
	entries.erase(id)

## Advances every stray's far-time by `delta` while it is beyond
## FORGET_BEYOND of `focus`, resetting it within, and forgets those whose
## far-time reaches FORGET_AFTER. Returns the forgotten ids.
func tick(delta: float, focus: UniversePoint) -> Array[int]:
	var gone: Array[int] = []
	for id: int in entries:
		var e: Dictionary = entries[id]
		if (e["at"] as UniversePoint).minus(focus).length() > FORGET_BEYOND:
			e["far"] += delta
			if e["far"] >= FORGET_AFTER:
				gone.append(id)
		else:
			e["far"] = 0.0
	for id in gone:
		entries.erase(id)
	return gone

func to_dict() -> Dictionary:
	var out := []
	var ids := entries.keys()
	ids.sort()
	for id: int in ids:
		var e: Dictionary = entries[id]
		out.append({
			"kind": String(e["kind"]), "variety": e["variety"], "at": SaveCodec.upoint(e["at"]),
			"turn": SaveCodec.basis(e["turn"]), "v": SaveCodec.vec3(e["v"]), "w": SaveCodec.vec3(e["w"]),
			"use": e["use"], "far": e["far"],
		})
	return {"strays": out}

## Replaces every stray with the saved ones, numbered afresh.
func from_dict(d: Dictionary) -> void:
	entries.clear()
	_next_id = 1
	for s in d.get("strays", []):
		if not (s is Dictionary):
			continue
		var use: Variant = s.get("use", {})
		var id := add(StringName(s.get("kind", "")), float(s.get("variety", 0.0)), SaveCodec.to_upoint(s.get("at")),
			SaveCodec.to_basis(s.get("turn")), SaveCodec.to_vec3(s.get("v")), SaveCodec.to_vec3(s.get("w")),
			use if use is Dictionary else {})
		entries[id]["far"] = maxf(float(s.get("far", 0.0)), 0.0)
