extends SceneTree

## Prints WadooPaths's grid over the oasis as text: '#' solid, '.' open, 'D' a door
## spot, 'o' the hub, 'x' a cell unreachable from the hub. North is up.
##   godot --headless --path . --script res://test/probes/wadoo_map.gd

func _init() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/places/oasis.json"))
	var paths := WadooPaths.build(layout, 11.0)
	var hub := paths.nearest_open(Vector2(14.0, 10.0))
	var door_cells := {}
	for id: String in paths.doors:
		for d: Dictionary in paths.doors[id]:
			door_cells[WadooPaths.cell_of(d["at"])] = true
	var lines := PackedStringArray()
	for j in range(112, -113, -2):
		var row := ""
		for i in range(-112, 113, 2):
			var p := Vector2(i, j) * 0.5
			var c := WadooPaths.cell_of(p)
			if door_cells.has(c):
				row += "D"
			elif WadooPaths.cell_of(hub) == c:
				row += "o"
			elif not paths.is_open(p):
				row += "#"
			elif paths.route(hub, p).is_empty():
				row += "x"
			else:
				row += "."
		lines.append("%4d %s" % [j, row])
	print("\n".join(lines))
	quit()
