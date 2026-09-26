class_name NpcCatalog
extends RefCounted

## Maps species ids to NpcSpecies, as ItemCatalog does items. Production code
## loads from disk; tests register species by hand.

var _defs: Dictionary = {}   # StringName -> NpcSpecies

func register(def: NpcSpecies) -> void:
	if def.id == &"":
		push_error("NpcCatalog: an NpcSpecies must have an id")
		return
	_defs[def.id] = def

func get_def(id: StringName) -> NpcSpecies:
	return _defs.get(id, null)

func has(id: StringName) -> bool:
	return _defs.has(id)

func ids() -> Array:
	return _defs.keys()

static func load_from_dir(path: String = "res://data/npcs") -> NpcCatalog:
	var catalog := NpcCatalog.new()
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("NpcCatalog: cannot open %s" % path)
		return catalog
	for file in dir.get_files():
		var name := file.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var def := ResourceLoader.load(path.path_join(name)) as NpcSpecies
		if def != null:
			catalog.register(def)
	return catalog
