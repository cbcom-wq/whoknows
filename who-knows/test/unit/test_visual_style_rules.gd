extends GutTest

## Guards the rules in docs/design/visual-style.md that a machine can check.
## If one fails, fix the code. A rule changes only with the owner's approval,
## in the guide and here together.

const SHADER_DIR := "res://data/materials/interior/"

## Code that paints: every colour must come from a palette -- InteriorPalette
## inside, HullPalette for the hull's outside (the airlock's hatch face),
## SpacePalette for space: rocks, worlds and stars.
## InteriorKit is exempt -- it packs data (screen modes, glow energy) into
## vertex colours rather than choosing colours.
const PAINTING_FILES := [
	"res://src/ui/computer_overlay.gd",
	"res://src/ship/interior/interior_props.gd",
	"res://src/ship/interior/interior_dressing.gd",
	"res://src/ship/interior/interior_materials.gd",
	"res://src/ship/interior/interior_layout.gd",
	"res://src/ship/hull/hull_props.gd",
	"res://src/ship/hull/hull_materials.gd",
	"res://src/ship/hull/hull_layout.gd",
	"res://src/ship/hull/hull_dressing.gd",
	"res://src/ship/interior/sliding_door.gd",
	"res://src/ship/interior/toilet_lid.gd",
	"res://src/ship/interior_builder.gd",
	"res://src/ship/ship_lights.gd",
	"res://src/ship/lights_panel.gd",
	"res://src/items/item_looks.gd",
	"res://src/avatar/glove.gd",
	"res://src/avatar/hands.gd",
	"res://src/items/impact_flash.gd",
	"res://src/items/plasma_bolt.gd",
	"res://src/items/hand_lamp.gd",
	"res://src/items/flare.gd",
	"res://src/items/datapad.gd",
	"res://src/ship/airlock/airlock.gd",
	"res://src/ship/airlock/airlock_alcove.gd",
	"res://src/ship/airlock/airlock_hatch.gd",
	"res://src/ship/airlock/airlock_panel.gd",
	"res://src/ship/airlock/airlock_room.gd",
	"res://src/ship/airlock/airlock_show.gd",
	"res://src/habitat/base_exterior.gd",
	"res://src/habitat/package_ghost.gd",
	"res://src/world/rock_mesh.gd",
	"res://src/world/asteroid_recipe.gd",
	"res://src/world/asteroid_stream.gd",
	"res://src/world/asteroid_bubble.gd",
	"res://src/world/asteroid_body.gd",
	"res://src/world/rock_detail.gd",
	"res://src/world/asteroid_detail.gd",
	"res://src/world/asteroid_details.gd",
	"res://src/world/puffs.gd",
	"res://src/world/world_recipe.gd",
	"res://src/world/system_recipe.gd",
	"res://src/world/body_look.gd",
	"res://src/world/world_terrain.gd",
	"res://src/world/terrain_chunk_data.gd",
	"res://src/world/world_surface.gd",
	"res://src/world/body_proxy.gd",
	"res://src/world/star_system.gd",
	"res://src/world/ring_look.gd",
	"res://src/world/belt_look.gd",
	"res://src/world/space_dust.gd",
	"res://src/flight/rcs_show.gd",
	"res://src/flight/warp_arrival.gd",
	"res://src/ship/interior/readout_panel.gd",
	"res://src/quantum/quantum_core.gd",
	"res://src/quantum/quantum_machine.gd",
	"res://src/quantum/quantum_bay.gd",
	"res://src/quantum/charge_dock.gd",
	"res://src/quantum/quantum_show.gd",
	"res://src/npc/npc_looks.gd",
	"res://src/npc/droid_look.gd",
	"res://src/npc/skitter_look.gd",
	"res://src/ship/computer/holo_volume.gd",
	"res://src/ship/computer/ship_computer.gd",
	"res://src/ship/computer/map_page.gd",
	"res://src/ship/exterior_builder.gd",
	"res://src/ship/damage_show.gd",
	"res://src/items/repair_torch.gd",
	"res://src/ui/hurt_edge.gd",
	"res://src/ui/hull_panel.gd",
]

## The reusable asset library and what it builds with. Ships are generated
## from blueprints, so these must work from a frame alone -- never the grid.
const REUSABLE_FILES := [
	"res://src/ship/interior/interior_props.gd",
	"res://src/ship/hull/hull_props.gd",
	"res://src/ship/hull/hull_materials.gd",
	"res://src/ship/interior/interior_kit.gd",
	"res://src/ship/interior/sliding_door.gd",
	"res://src/ship/interior/toilet_lid.gd",
	"res://src/items/item_looks.gd",
	"res://src/items/item.gd",
	"res://src/avatar/glove.gd",
	"res://src/avatar/hands.gd",
	"res://src/ship/airlock/airlock_hatch.gd",
	"res://src/ship/airlock/airlock_panel.gd",
	"res://src/ship/airlock/airlock_show.gd",
	"res://src/world/puffs.gd",
	"res://src/ship/interior/readout_panel.gd",
	"res://src/quantum/quantum_core.gd",
	"res://src/quantum/quantum_bay.gd",
	"res://src/quantum/charge_dock.gd",
	"res://src/quantum/quantum_show.gd",
	"res://src/quantum/quantum_machine.gd",
	"res://src/npc/npc_looks.gd",
	"res://src/npc/droid_look.gd",
	"res://src/ship/computer/holo_volume.gd",
	"res://src/ship/computer/ship_computer.gd",
	"res://src/ship/computer/computer_station.gd",
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
