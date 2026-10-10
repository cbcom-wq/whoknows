class_name BaseSite
extends RefCounted

## A base as data (docs/superpowers/specs/2026-09-26-habitat-modules-design.md
## §9.1, §11.1): where its frame is, which rock it stands on, its modules, its
## store, and -- while it sleeps or is saved -- its airlocks and the items in
## it. All a sleeping base is; what a save keeps. Its grid is the union of its
## modules' prefabs, so the same site always gives the same grid.

var id: StringName
## The star system it is in, by seed.
var system := 0
## The centre of base cell (0, 0, 0), and the frame's rotation: its y is the
## base's up, and its grid is ShipGrid.CELL_SIZE.
var at: UniversePoint = UniversePoint.new()
var turn := Basis.IDENTITY
## The big rock it stands on (AsteroidRock.id()) and its site
## (RockHerds.site_of()).
var rock := Vector4i.ZERO
var site_id: StringName
## {kind, cell, turns, legs, drill}: the module's kind, its origin cell in the
## base's grid, its quarter turns, its four leg lengths, and its drill's state
## ({} unless it is a drill).
var modules: Array = []
var store := 0
## While asleep or saved: each airlock's to_dict(), by cell key, and the items
## in it, in the interior's frame (GridHome.items_to_dict()).
var airlocks: Dictionary = {}
var items: Array = []

## Adds a module; returns its index.
func add(kind: StringName, cell: Vector3i, turns: int, legs: PackedFloat32Array) -> int:
	modules.append({"kind": kind, "cell": cell, "turns": posmod(turns, 4), "legs": legs, "drill": {}})
	return modules.size() - 1

func remove(index: int) -> void:
	modules.remove_at(index)

## The base cells module `index` fills.
func cells_of(index: int) -> Array[Vector3i]:
	var m: Dictionary = modules[index]
	var out: Array[Vector3i] = []
	for b: Array in ModuleCatalog.get_def(m["kind"]).turned(m["turns"]):
		out.append((m["cell"] as Vector3i) + (b[0] as Vector3i))
	return out

## Every filled cell, and the index of the module that fills it.
func occupied() -> Dictionary:
	var out := {}
	for i in modules.size():
		for c in cells_of(i):
			out[c] = i
	return out

## The base's grid: every module's blocks, turned, at its cells.
func grid() -> ShipGrid:
	var g := ShipGrid.new()
	for m: Dictionary in modules:
		for b: Array in ModuleCatalog.get_def(m["kind"]).turned(m["turns"]):
			var inst := BlockInstance.new()
			inst.block_id = b[1]
			inst.orientation = b[2]
			g.set_block((m["cell"] as Vector3i) + (b[0] as Vector3i), inst)
	return g

## Module `index`'s body centre, in the base's frame.
func centre_of(index: int) -> Vector3:
	var m: Dictionary = modules[index]
	var size := ModuleCatalog.get_def(m["kind"]).turned_size(m["turns"])
	return ShipGrid.cell_center(m["cell"]) + Vector3(size - Vector3i.ONE) * ShipGrid.CELL_SIZE * 0.5

func hubs() -> Array[int]:
	return _of(ModuleCatalog.HUB)

func drills() -> Array[int]:
	return _of(ModuleCatalog.DRILL)

func _of(kind: StringName) -> Array[int]:
	var out: Array[int] = []
	for i in modules.size():
		if modules[i]["kind"] == kind:
			out.append(i)
	return out

func to_dict() -> Dictionary:
	var saved := []
	for m: Dictionary in modules:
		saved.append({"kind": String(m["kind"]), "cell": SaveCodec.vec3i(m["cell"]), "turns": m["turns"],
			"legs": Array(m["legs"]), "drill": m["drill"]})
	return {"id": String(id), "system": system, "at": SaveCodec.upoint(at), "turn": SaveCodec.basis(turn),
		"rock": [rock.x, rock.y, rock.z, rock.w], "site": String(site_id), "modules": saved,
		"store": store, "airlocks": airlocks, "items": items}

static func from_dict(d: Dictionary) -> BaseSite:
	var s := BaseSite.new()
	s.id = StringName(d.get("id", ""))
	s.system = int(d.get("system", 0))
	s.at = SaveCodec.to_upoint(d.get("at"))
	s.turn = SaveCodec.to_basis(d.get("turn"))
	var r: Array = d.get("rock", [0, 0, 0, 0])
	s.rock = Vector4i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
	s.site_id = StringName(d.get("site", ""))
	for m in d.get("modules", []):
		if not (m is Dictionary) or ModuleCatalog.get_def(StringName(m.get("kind", ""))) == null:
			continue
		s.modules.append({"kind": StringName(m["kind"]), "cell": SaveCodec.to_vec3i(m.get("cell")),
			"turns": int(m.get("turns", 0)), "legs": PackedFloat32Array(m.get("legs", [])),
			"drill": m.get("drill", {})})
	s.store = int(d.get("store", 0))
	s.airlocks = d.get("airlocks", {})
	s.items = d.get("items", [])
	return s
