class_name ItemCatalog
extends RefCounted

## Maps item ids to definitions, as BlockCatalog does blocks. Production code
## loads from disk; tests register definitions by hand.

var _defs: Dictionary = {}   # StringName -> ItemDefinition

func register(def: ItemDefinition) -> void:
	if def.id == &"":
		push_error("ItemCatalog: an ItemDefinition must have an id")
		return
	_defs[def.id] = def

func get_def(id: StringName) -> ItemDefinition:
	return _defs.get(id, null)

func has(id: StringName) -> bool:
	return _defs.has(id)

func ids() -> Array:
	return _defs.keys()

static func load_from_dir(path: String = "res://data/items") -> ItemCatalog:
	var catalog := ItemCatalog.new()
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("ItemCatalog: cannot open %s" % path)
		return catalog
	for file in dir.get_files():
		var name := file.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var def := ResourceLoader.load(path.path_join(name)) as ItemDefinition
		if def != null:
			catalog.register(def)
	return catalog
