class_name ShipLibrary
extends RefCounted

## Every ship in the game as a file (docs/superpowers/specs/
## 2026-10-02-ship-library-design.md §3): data/ships/<id>.json, one row per
## block, with a Markdown note beside it holding the reasoning. Loaded as
## NpcCatalog loads species. It only reads and writes: whether a ship's blocks
## exist, and whether it flies, is ShipRules'.

## The starter shuttle: first in ids(), and the ship a new game builds.
const STARTER := &"starter"
## The newest file format this game reads.
const FORMAT := 1
const DIR := "res://data/ships"

## Each file that would not load, and why. Those files are left out.
var errors: Array[String] = []

var _ships := {}   # StringName -> {id, name, description, grid}

static func load_from_dir(path: String = DIR) -> ShipLibrary:
	var library := ShipLibrary.new()
	var dir := DirAccess.open(path)
	if dir == null:
		library.errors.append("%s: cannot open the folder" % path)
		return library
	var files := dir.get_files()
	files.sort()
	for file in files:
		if not file.ends_with(".json"):
			continue
		var ship := read(path.path_join(file))
		if ship.has("error"):
			library.errors.append(ship["error"])
		else:
			library._ships[ship["id"]] = ship
	return library

## One ship file: {id, name, description, grid}, or {error} saying what is
## wrong with it (spec §3.2). Its id must be its file's name.
static func read(path: String) -> Dictionary:
	var file := path.get_file()
	if not FileAccess.file_exists(path):
		return {"error": "%s: no such file" % path}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"error": "%s: bad JSON at line %d (%s)" % [file, json.get_error_line(), json.get_error_message()]}
	var d: Variant = json.data
	if not (d is Dictionary):
		return {"error": "%s: not a ship (the file is not one JSON object)" % file}
	var format: Variant = d.get("format")
	if not _whole(format) or int(format) < 1:
		return {"error": "%s: no format (it must say \"format\": %d)" % [file, FORMAT]}
	if int(format) > FORMAT:
		return {"error": "%s: format %d is newer than this game reads (%d)" % [file, int(format), FORMAT]}
	var id := str(d.get("id", ""))
	if id != file.get_basename():
		return {"error": "%s: its id \"%s\" is not its file's name" % [file, id]}
	var cells: Variant = d.get("cells")
	if not (cells is Array):
		return {"error": "%s: no cells" % file}
	var grid := ShipGrid.new()
	for i in (cells as Array).size():
		var row: Variant = cells[i]
		if not _is_row(row):
			return {"error": "%s: row %d is not [x, y, z, block, orientation] (whole numbers, a block name, an orientation 0-%d)"
				% [file, i + 1, BlockOrientation.COUNT - 1]}
		var coord := Vector3i(int(row[0]), int(row[1]), int(row[2]))
		if grid.has_block(coord):
			return {"error": "%s: row %d puts a second block at %s" % [file, i + 1, coord]}
		var inst := BlockInstance.new()
		inst.block_id = StringName(row[3])
		inst.orientation = int(row[4])
		grid.set_block(coord, inst)
	return {"id": StringName(id), "name": str(d.get("name", id)), "description": str(d.get("description", "")),
		"grid": grid}

## The ship `what` names (ship designer spec §7.2): a library id, or a res://
## or absolute path to a ship file, read as read() reads one; {error} when it
## names none. `library` is asked for ids, loaded from DIR when not given.
static func resolve(what: String, library: ShipLibrary = null) -> Dictionary:
	if what.ends_with(".json"):
		return read(what)
	if library == null:
		library = load_from_dir()
	var id := StringName(what)
	if not library.has(id):
		return {"error": "no library ship called \"%s\"" % what}
	return {"id": id, "name": library.name_of(id), "description": library.description_of(id),
		"grid": library.grid(id)}

## Every ship's id, sorted, the starter first.
func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_ships.keys())
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		if a == STARTER or b == STARTER:
			return a == STARTER and b != STARTER
		return String(a) < String(b))
	return out

func has(id: StringName) -> bool:
	return _ships.has(id)

func name_of(id: StringName) -> String:
	return _ships[id]["name"] if has(id) else ""

func description_of(id: StringName) -> String:
	return _ships[id]["description"] if has(id) else ""

## A fresh grid of ship `id`, every block intact, so building a ship never
## touches the library's copy; null for an id it does not have.
func grid(id: StringName) -> ShipGrid:
	if not has(id):
		return null
	var src: ShipGrid = _ships[id]["grid"]
	var out := ShipGrid.new()
	for coord in src.coords():
		out.set_block(coord, src.get_block(coord).duplicate_instance())
	return out

## Writes `grid` to `path` as a ship file (spec §3.1): a row per block on a
## line of its own, sorted as ShipBlueprint sorts, so a diff shows exactly the
## blocks that changed. No damage: a library ship is new.
static func write(path: String, id: StringName, ship_name: String, description: String,
		grid: ShipGrid) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string("{\n\t\"id\": %s,\n\t\"name\": %s,\n\t\"description\": %s,\n\t\"format\": %d,\n\t\"cells\": [\n%s\n\t]\n}\n" % [
		JSON.stringify(String(id)), JSON.stringify(ship_name), JSON.stringify(description), FORMAT,
		rows_text(grid, "\t\t")])
	f.close()
	return OK

## The grid's rows as a ship file writes them, `indent` before each, joined by
## a comma and a new line. The starter's pin hashes this.
static func rows_text(grid: ShipGrid, indent := "") -> String:
	var bp := ShipBlueprint.from_grid(grid, "")
	var lines := PackedStringArray()
	for i in bp.coords.size():
		var c := bp.coords[i]
		lines.append("%s[%d, %d, %d, %s, %d]" % [indent, c.x, c.y, c.z, JSON.stringify(String(bp.block_ids[i])),
			bp.orientations[i]])
	return ",\n".join(lines)

static func _is_row(row: Variant) -> bool:
	if not (row is Array) or (row as Array).size() != 5:
		return false
	for k in [0, 1, 2, 4]:
		if not _whole(row[k]):
			return false
	return row[3] is String and row[3] != "" and int(row[4]) >= 0 and int(row[4]) < BlockOrientation.COUNT

## A JSON number with nothing after the point (JSON numbers arrive as floats).
static func _whole(v: Variant) -> bool:
	return (v is int or v is float) and float(v) == floorf(float(v))
