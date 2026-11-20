extends GutTest
## Today's ground, pinned to the bit: every non-desert world at full detail and
## Wadoo's kept ground. Made by golden/make_terrain_golden.gd on the code as it
## was before the WADIS land plan.

const GOLDEN := "res://test/unit/golden/terrain_golden.json"

## Numbers are stored as the 16 hex digits of their 64-bit pattern (JSON text loses bits).
func _f(h: String) -> float:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_u32(4, h.substr(0, 8).hex_to_int())
	b.encode_u32(0, h.substr(8, 8).hex_to_int())
	return b.decode_double(0)

func _golden() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))

func test_every_other_world_keeps_its_ground_to_the_bit():
	for w: Dictionary in _golden().worlds:
		var t := WorldTerrain.new(WorldRecipe.from_seed(int(w.seed)))
		for s: Array in w.samples:
			var d := Vector3(_f(s[0]), _f(s[1]), _f(s[2]))
			assert_eq(t.height_at(d), _f(s[3]))
			assert_eq(t.colour_at(d, 0.2, 8.0), Color(_f(s[4]), _f(s[5]), _f(s[6])))

func test_wadoo_keeps_its_ground_to_the_bit():
	var t := WorldTerrain.new(SystemRecipe.from_seed(1337).body(&"p3").recipe)
	for s: Array in _golden().wadoo:
		assert_eq(t.height_at(Vector3(_f(s[0]), _f(s[1]), _f(s[2]))), _f(s[3]))
