extends SceneTree
## Writes terrain_golden.json: today's ground, pinned for test_terrain_golden.gd.
## Run: godot --headless --path . -s res://test/unit/golden/make_terrain_golden.gd
## Not a test (the runner takes only test_*.gd files).

const OUT := "res://test/unit/golden/terrain_golden.json"
const PER_WORLD := 200
const WADOO_SAMPLES := 400
const WADOO_RADIUS_M := 2000.0
const ARCHETYPES := [
	WorldRecipe.Archetype.CRATERED,
	WorldRecipe.Archetype.ROLLING,
	WorldRecipe.Archetype.RIDGED,
	WorldRecipe.Archetype.MESA,
]

func _init() -> void:
	var worlds: Array = []
	var found := {}
	for a in ARCHETYPES:
		found[a] = 0
	var s := 1
	while true:
		var done := true
		for a in ARCHETYPES:
			if found[a] < 3:
				done = false
		if done:
			break
		var r := WorldRecipe.from_seed(s)
		if not r.is_desert() and ARCHETYPES.has(r.archetype) and found[r.archetype] < 3:
			found[r.archetype] += 1
			worlds.append(_world(s, r))
		s += 1
	var wadis := SystemRecipe.from_seed(1337).body(&"p3").recipe
	var wt := WorldTerrain.new(wadis)
	var centre := SystemDesign.dir_of(-2.16, -171.97)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261120
	var wadoo: Array = []
	for i in WADOO_SAMPLES:
		var d := _in_disc(centre, WADOO_RADIUS_M / wadis.radius_m, rng)
		wadoo.append([d.x, d.y, d.z, wt.height_at(d)])
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"worlds": _hexed(worlds), "wadoo": _hexed(wadoo)}, "", true, true))
	f.close()
	# Prove it reads back to the bit.
	var back: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT))
	var bad := 0
	for i in wadoo.size():
		for k in 4:
			if _unhex(back.wadoo[i][k]) != float(wadoo[i][k]):
				bad += 1
	for wi in worlds.size():
		for i in worlds[wi].samples.size():
			for k in 7:
				if _unhex(back.worlds[wi].samples[i][k]) != float(worlds[wi].samples[i][k]):
					bad += 1
	print("golden: ", back.worlds.size(), " worlds, ", back.wadoo.size(), " wadoo samples, ", bad, " lossy numbers")
	quit(1 if bad > 0 else 0)

func _world(p_seed: int, r: WorldRecipe) -> Dictionary:
	var t := WorldTerrain.new(r)
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed * 7919 + 13
	var samples: Array = []
	for i in PER_WORLD:
		var d := _random_dir(rng)
		var c := t.colour_at(d, 0.2, 8.0)
		samples.append([d.x, d.y, d.z, t.height_at(d), c.r, c.g, c.b])
	return {"seed": p_seed, "archetype": WorldRecipe.Archetype.keys()[r.archetype], "samples": samples}

func _random_dir(rng: RandomNumberGenerator) -> Vector3:
	var z := rng.randf_range(-1.0, 1.0)
	var a := rng.randf_range(0.0, TAU)
	var rr := sqrt(1.0 - z * z)
	return Vector3(rr * cos(a), z, rr * sin(a)).normalized()

## A uniform random direction within `ang` radians of `centre`.
func _in_disc(centre: Vector3, ang: float, rng: RandomNumberGenerator) -> Vector3:
	var ref := Vector3.UP if absf(centre.y) < 0.9 else Vector3.RIGHT
	var e := centre.cross(ref).normalized()
	var n := centre.cross(e)
	var rad := ang * sqrt(rng.randf())
	var th := rng.randf_range(0.0, TAU)
	return (centre * cos(rad) + (e * cos(th) + n * sin(th)) * sin(rad)).normalized()

## JSON text loses bits on floats, so every number is written as the 16 hex digits
## of its 64-bit pattern (a string); the test reads them back with the same _unhex.
func _hexed(v: Variant) -> Variant:
	if v is float:
		var b := PackedByteArray()
		b.resize(8)
		b.encode_double(0, v)
		return "%08x%08x" % [b.decode_u32(4), b.decode_u32(0)]
	if v is Array:
		return v.map(_hexed)
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _hexed(v[k])
		return out
	return v

func _unhex(h: String) -> float:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_u32(4, h.substr(0, 8).hex_to_int())
	b.encode_u32(0, h.substr(8, 8).hex_to_int())
	return b.decode_double(0)
