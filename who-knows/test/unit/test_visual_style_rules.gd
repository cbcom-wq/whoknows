extends GutTest

## Guards the rules in docs/design/visual-style.md that a machine can check.
## If one fails, fix the code. A rule changes only with the owner's approval,
## in the guide and here together.

const SHADER_DIR := "res://data/materials/interior/"

## Interior code that paints: every colour must come from InteriorPalette.
## InteriorKit is exempt -- it packs data (screen modes, glow energy) into
## vertex colours rather than choosing colours.
const PAINTING_FILES := [
	"res://src/ship/interior/interior_props.gd",
	"res://src/ship/interior/interior_dressing.gd",
	"res://src/ship/interior/interior_materials.gd",
	"res://src/ship/interior/interior_layout.gd",
	"res://src/ship/interior/sliding_door.gd",
	"res://src/ship/interior_builder.gd",
	"res://src/items/item_looks.gd",
	"res://src/avatar/glove.gd",
	"res://src/avatar/hands.gd",
]

## The reusable asset library and what it builds with. Ships are generated
## from blueprints, so these must work from a frame alone -- never the grid.
const REUSABLE_FILES := [
	"res://src/ship/interior/interior_props.gd",
	"res://src/ship/interior/interior_kit.gd",
	"res://src/ship/interior/sliding_door.gd",
	"res://src/items/item_looks.gd",
	"res://src/items/item.gd",
	"res://src/avatar/glove.gd",
	"res://src/avatar/hands.gd",
]
const GRID_SIDE := ["ShipGrid", "BlockCatalog", "DeckGraph", "InteriorLayout", "InteriorBuilder",
	"InteriorDressing"]

## A script with its comments removed, so doc comments may name what the code
## itself must not use.
static func _code(path: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var comment_at := line.find("#")
		out.append(line if comment_at < 0 else line.substr(0, comment_at))
	return "\n".join(out)

func test_colours_come_only_from_the_palette():
	var literal := RegEx.create_from_string("\\bColor8?\\s*\\(|\\bColor\\.[A-Z_]+\\b")
	for path in PAINTING_FILES:
		var hit := literal.search(_code(path))
		assert_null(hit, "%s names a colour directly (%s): add it to InteriorPalette instead -- docs/design/visual-style.md §2.2"
			% [path, hit.get_string() if hit != null else ""])

func test_the_asset_library_never_sees_the_grid():
	for path in REUSABLE_FILES:
		var code := _code(path)
		for ident in GRID_SIDE:
			var use := RegEx.create_from_string("\\b%s\\b" % ident)
			assert_null(use.search(code),
				"%s uses %s: props build from (kit, frame, variety) alone -- docs/design/visual-style.md §3" % [path, ident])

func test_the_interior_shader_budget_is_three():
	var shaders: Array = []
	for file in DirAccess.get_files_at(SHADER_DIR):
		if file.ends_with(".gdshader"):
			shaders.append(file)
	shaders.sort()
	assert_eq(shaders, ["canopy_window.gdshader", "glow.gdshader", "screen.gdshader"],
		"a new interior shader needs a reason no geometry can meet and the owner's approval -- docs/design/visual-style.md §2.5")
