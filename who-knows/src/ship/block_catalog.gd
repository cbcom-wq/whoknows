class_name BlockCatalog
extends RefCounted

## Maps block ids to definitions. Production code loads from disk;
## tests build catalogs by hand, which is why ShipGrid never touches this.

var _defs: Dictionary = {}   # StringName -> BlockDefinition

func register(def: BlockDefinition) -> void:
	assert(def.id != &"", "BlockDefinition must have an id")
	_defs[def.id] = def

func get_def(id: StringName) -> BlockDefinition:
	return _defs.get(id, null)

func has(id: StringName) -> bool:
	return _defs.has(id)

func ids() -> Array:
	return _defs.keys()

static func load_from_dir(path: String = "res://data/blocks") -> BlockCatalog:
	var catalog := BlockCatalog.new()
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("BlockCatalog: cannot open %s" % path)
		return catalog
	for file in dir.get_files():
		var name := file.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var def := ResourceLoader.load(path.path_join(name)) as BlockDefinition
		if def != null:
			catalog.register(def)
	return catalog
