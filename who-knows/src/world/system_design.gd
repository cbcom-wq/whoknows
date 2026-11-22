class_name SystemDesign
extends RefCounted

## What a hand has decided about one star system (desert world spec §8): tweaks
## to bodies the seed rolled, terrain stamps and named places. Data in
## data/systems/<star name>.json, keyed inside by "seed". A seed with no file is
## exactly what it always was. Read-only once loaded.
##
## {"seed": 1337, "bodies": {"p3": {"tweak": {...}, "stamps": [...], "places": [...]}}}
##
## Tweak keys: name, radius, gravity, palette (a palette's name), archetype and
## atmosphere (enum names). Stamp keys: id, kind (flatten / basin / mesa), lat +
## lon or place + at ([east, north] in that place's frame), radius, edge, level,
## raise, keep, floor, depth, height (a mesa's top over its level), ground.
## Place keys: id, name, lat, lon, heading, beacon.
## Plan keys (a desert only): the dials sea, seas, mountains, ranges, plateaus,
## canyons, peak, oases and buttes; keep, a list of {place, radius, blend} discs that
## keep today's ground; pins, a Dictionary of placement wishes for the plan.

const DIR := "res://data/systems"

const TWEAK_KEYS: Array[String] = ["name", "radius", "gravity", "palette", "archetype", "atmosphere"]
const STAMP_KEYS: Array[String] = ["id", "kind", "lat", "lon", "place", "at", "radius", "edge", "level",
	"raise", "keep", "floor", "depth", "height", "stretch", "heading", "wobble", "ground"]
const PLACE_KEYS: Array[String] = ["id", "name", "lat", "lon", "heading", "beacon"]
const BODY_KEYS: Array[String] = ["tweak", "stamps", "places", "plan"]
## The plan section's keys: the dials, the kept discs and the pins.
## A literal, since GDScript will not add arrays in a constant; a test holds it
## equal to PlanDials.NAMES + ["keep", "pins"].
const PLAN_KEYS: Array[String] = ["sea", "seas", "mountains", "ranges", "plateaus", "canyons", "peak", "oases",
	"buttes", "keep", "pins"]
## Each dial's allowed range in a file: the rolls' span, with 0 allowed for
## shares and counts.
const PLAN_RANGES := {"sea": Vector2(0.0, 0.25), "seas": Vector2(0.0, 2.0), "mountains": Vector2(0.0, 0.15),
	"ranges": Vector2(0.0, 5.0), "plateaus": Vector2(0.0, 0.30), "canyons": Vector2(0.0, 6.0),
	"peak": Vector2(600.0, 2500.0), "oases": Vector2(0.0, 8.0), "buttes": Vector2(0.0, 6.0)}
## A stamp's kind as the file spells it.
const KINDS := {"flatten": TerrainStamp.Kind.FLATTEN, "basin": TerrainStamp.Kind.BASIN,
	"mesa": TerrainStamp.Kind.MESA}

## Every design in DIR by seed, filled on the first for_seed call (SystemRecipe
## makes the starting system on the main thread before any worker); workers
## only read it after.
static var _cache := {}
static var _cached := false

var seed := 0
var path := ""
## Each designed body's Dictionary, by body id.
var bodies := {}

## The design for `p_seed`, or null.
static func for_seed(p_seed: int) -> SystemDesign:
	if not _cached:
		for file in DirAccess.get_files_at(DIR):
			if file.get_extension() == "json":
				var d := load_file("%s/%s" % [DIR, file])
				if d != null:
					_cache[d.seed] = d
		_cached = true
	return _cache.get(p_seed)

## The design in the JSON file at `p_path`; null, and an error, when it is
## not a design.
static func load_file(p_path: String) -> SystemDesign:
	if not FileAccess.file_exists(p_path):
		push_error("no system design at %s" % p_path)
		return null
	var json := JSON.new()
	var d: SystemDesign = null
	if json.parse(FileAccess.get_file_as_string(p_path)) == OK:
		d = from_data(json.data, p_path)
	if d == null:
		push_error("%s is not a system design" % p_path)
	return d

## A design from parsed JSON; null when it has no seed or its bodies are not an
## object.
static func from_data(data: Variant, p_path := "") -> SystemDesign:
	if not data is Dictionary or not (data.get("seed") is float or data.get("seed") is int) or not data.get("bodies", {}) is Dictionary:
		return null
	var d := SystemDesign.new()
	d.seed = int(data["seed"])
	d.path = p_path
	for key: String in data.get("bodies", {}):
		var body: Variant = data["bodies"][key]
		d.bodies[StringName(key)] = body if body is Dictionary else {}
	return d

## The direction on a world at `lat_deg`, `lon_deg`: north is +y, longitude 0 is
## +x and east is toward -z there (worlds never turn).
static func dir_of(lat_deg: float, lon_deg: float) -> Vector3:
	var phi := deg_to_rad(lat_deg)
	var lambda := deg_to_rad(lon_deg)
	return Vector3(cos(phi) * cos(lambda), sin(phi), -cos(phi) * sin(lambda))

## A place's frame at `dir`: x east, y up, z south, turned `heading_deg`
## clockwise seen from above. At the poles north is taken as -z.
static func frame_at(dir: Vector3, heading_deg: float) -> Basis:
	var north := Vector3.UP - dir * dir.y
	north = Vector3(0.0, 0.0, -1.0) if north.length() < 1e-9 else north.normalized()
	var east := north.cross(dir)
	var frame := Basis(east, dir, east.cross(dir))
	return frame * Basis(Vector3.UP, -deg_to_rad(heading_deg))

## Writes the tweak and stamps for `body_id` into `recipe`, which is that
## body's own. Run before anything reads the recipe's name, radius or well.
func apply_to(recipe: WorldRecipe, body_id: StringName) -> void:
	if not bodies.has(body_id):
		return
	var tweak: Dictionary = _section(body_id, "tweak", {})
	if tweak.has("name"):
		recipe.name = str(tweak["name"])
	if tweak.has("radius"):
		recipe.radius_m = float(tweak["radius"])
	if tweak.has("gravity"):
		recipe.surface_gravity = float(tweak["gravity"])
	if tweak.has("palette"):
		var index := _palette_index(str(tweak["palette"]))
		if index >= 0:
			recipe.palette = index
	if tweak.has("archetype") and WorldRecipe.Archetype.has(str(tweak["archetype"])):
		recipe.archetype = WorldRecipe.Archetype[str(tweak["archetype"])]
	if tweak.has("atmosphere") and WorldRecipe.Atmosphere.has(str(tweak["atmosphere"])):
		recipe.atmosphere = WorldRecipe.Atmosphere[str(tweak["atmosphere"])]
	recipe.stamps.append_array(_stamps(body_id, recipe.radius_m, PackedStringArray()))
	var places := places_on(body_id)
	for place in places:
		recipe.pin_places[place.id] = place.dir()
	var plan: Dictionary = _section(body_id, "plan", {})
	recipe.plan_pins = plan.duplicate(true)
	var keep: Array = plan.get("keep", []) if plan.get("keep", []) is Array else []
	for entry: Variant in keep:
		if not entry is Dictionary:
			continue
		for place in places:
			if str(place.id) == str(entry.get("place", "")):
				recipe.keeps.append({"place": place.id, "dir": place.dir(),
					"radius": float(entry.get("radius", 0.0)), "blend": float(entry.get("blend", 0.0))})

func places_on(body_id: StringName) -> Array[PlaceDesign]:
	var out: Array[PlaceDesign] = []
	for p: Variant in _section(body_id, "places", []):
		if not p is Dictionary:
			continue
		var place := PlaceDesign.new()
		place.id = StringName(str(p.get("id", "")))
		place.name = str(p.get("name", ""))
		place.body_id = body_id
		place.lat = float(p.get("lat", 0.0))
		place.lon = float(p.get("lon", 0.0))
		place.heading = float(p.get("heading", 0.0))
		place.beacon = bool(p.get("beacon", false))
		out.append(place)
	return out

## Every broken rule of this design on `system`, as text naming the body; empty
## when it is valid. `system` may be built with or without this design.
func problems(system: SystemRecipe) -> PackedStringArray:
	var out := PackedStringArray()
	for body_id: StringName in bodies:
		var body := system.body(body_id)
		if body == null or body.recipe == null:
			out.append("%s: the system has no such world" % body_id)
			continue
		var section: Dictionary = bodies[body_id]
		for key: String in section:
			if not BODY_KEYS.has(key):
				out.append("%s: unknown key %s" % [body_id, key])
		var tweak: Dictionary = _section(body_id, "tweak", {})
		out.append_array(_tweak_problems(body_id, tweak))
		out.append_array(_plan_problems(body_id, tweak, body.recipe))
		var radius := float(tweak.get("radius", body.recipe.radius_m))
		var palette_index := _palette_index(str(tweak["palette"])) if tweak.has("palette") else body.recipe.palette
		var palette: Dictionary = SpacePalette.WORLDS[palette_index] if palette_index >= 0 else {}
		var stamps := _stamps(body_id, radius, out)
		for s in stamps:
			if s.ground != &"" and not palette.has(s.ground):
				out.append("%s: stamp %s has ground %s, which the %s palette lacks" % [
					body_id, s.id, s.ground, palette.get(&"name", "unknown")])
		_overlap_problems(body_id, stamps, radius, out)
		for place in places_on(body_id):
			if absf(place.lat) > 90.0:
				out.append("%s: place %s has latitude %s, outside 90" % [body_id, place.id, place.lat])
			var flat := stamps.any(func(s: TerrainStamp) -> bool:
				return s.kind == TerrainStamp.Kind.FLATTEN and s.metres_from(place.dir(), radius) <= s.radius)
			if not flat:
				out.append("%s: place %s is not on a stamped flat part" % [body_id, place.id])
	return out

## The section `key` of a body, or `fallback` when it is missing or the wrong
## sort of thing.
func _section(body_id: StringName, key: String, fallback: Variant) -> Variant:
	var value: Variant = bodies.get(body_id, {}).get(key, fallback)
	return value if typeof(value) == typeof(fallback) else fallback

static func _palette_index(palette_name: String) -> int:
	for i in SpacePalette.WORLDS.size():
		if SpacePalette.WORLDS[i][&"name"] == StringName(palette_name):
			return i
	return -1

func _plan_problems(body_id: StringName, tweak: Dictionary, base: WorldRecipe) -> PackedStringArray:
	var out := PackedStringArray()
	if not bodies[body_id].has("plan"):
		return out
	var plan: Variant = bodies[body_id]["plan"]
	if not plan is Dictionary:
		out.append("%s: plan is not an object" % body_id)
		return out
	var desert := base.is_desert()
	if tweak.has("archetype") and WorldRecipe.Archetype.has(str(tweak["archetype"])):
		desert = WorldRecipe.Archetype[str(tweak["archetype"])] == WorldRecipe.Archetype.DUNES
	if not desert:
		out.append("%s: only a desert takes a plan" % body_id)
	for key: String in plan:
		if not PLAN_KEYS.has(key):
			out.append("%s: unknown plan key %s" % [body_id, key])
		elif PLAN_RANGES.has(key):
			var v: Variant = plan[key]
			var r: Vector2 = PLAN_RANGES[key]
			if not (v is float or v is int) or float(v) < r.x or float(v) > r.y:
				out.append("%s: plan %s is %s, outside %s to %s" % [body_id, key, v, r.x, r.y])
	var places := places_on(body_id)
	var keep: Variant = plan.get("keep", [])
	if not keep is Array:
		out.append("%s: plan keep is not a list" % body_id)
		keep = []
	for entry: Variant in keep:
		if not entry is Dictionary:
			out.append("%s: a plan keep is not an object" % body_id)
			continue
		if not places.any(func(p: PlaceDesign) -> bool: return str(p.id) == str(entry.get("place", ""))):
			out.append("%s: plan keep names place %s, which is not on it" % [body_id, entry.get("place", "")])
		if float(entry.get("radius", 0.0)) <= 0.0 or float(entry.get("blend", 0.0)) < 0.0:
			out.append("%s: plan keep needs a radius over 0 and a blend of 0 or more" % body_id)
	if not plan.get("pins", {}) is Dictionary:
		out.append("%s: plan pins is not an object" % body_id)
	return out

func _tweak_problems(body_id: StringName, tweak: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for key: String in tweak:
		if not TWEAK_KEYS.has(key):
			out.append("%s: unknown tweak key %s" % [body_id, key])
	if tweak.has("palette") and _palette_index(str(tweak["palette"])) < 0:
		out.append("%s: unknown palette %s" % [body_id, tweak["palette"]])
	if tweak.has("archetype") and not WorldRecipe.Archetype.has(str(tweak["archetype"])):
		out.append("%s: unknown archetype %s" % [body_id, tweak["archetype"]])
	if tweak.has("atmosphere") and not WorldRecipe.Atmosphere.has(str(tweak["atmosphere"])):
		out.append("%s: unknown atmosphere %s" % [body_id, tweak["atmosphere"]])
	return out

## The stamps of a body on a world of `world_radius`, in file order, each
## resolved to a direction. Whatever is wrong with one is added to `errors`,
## and that stamp is left out.
func _stamps(body_id: StringName, world_radius: float, errors: PackedStringArray) -> Array[TerrainStamp]:
	var out: Array[TerrainStamp] = []
	var places := places_on(body_id)
	for entry: Variant in _section(body_id, "stamps", []):
		if not entry is Dictionary:
			continue
		var data: Dictionary = entry
		var s := TerrainStamp.new()
		s.id = StringName(str(data.get("id", "")))
		var bad := false
		for key: String in data:
			if not STAMP_KEYS.has(key):
				errors.append("%s: stamp %s has unknown key %s" % [body_id, s.id, key])
				bad = true
		var kind_name := str(data.get("kind", "flatten"))
		if KINDS.has(kind_name):
			s.kind = KINDS[kind_name]
		else:
			errors.append("%s: stamp %s has unknown kind %s" % [body_id, s.id, kind_name])
			bad = true
		s.radius = float(data.get("radius", 0.0))
		s.edge = float(data.get("edge", 0.0))
		s.level = float(data["level"]) if data.has("level") else NAN
		s.raise = float(data.get("raise", 0.0))
		s.keep = float(data.get("keep", 0.0))
		s.floor_radius = float(data.get("floor", 0.0))
		s.depth = float(data.get("depth", 0.0))
		s.height = float(data.get("height", 0.0))
		s.stretch = float(data.get("stretch", 1.0))
		s.heading = float(data.get("heading", 0.0))
		s.wobble = float(data.get("wobble", 0.0))
		var bearing := deg_to_rad(s.heading)
		s.ground = StringName(str(data.get("ground", "")))
		if data.has("place"):
			var found: PlaceDesign = null
			for p in places:
				if str(p.id) == str(data["place"]):
					found = p
			var at: Variant = data.get("at", [0.0, 0.0])
			if found == null:
				errors.append("%s: stamp %s names place %s, which is not on it" % [body_id, s.id, data["place"]])
				bad = true
			elif at is Array and at.size() == 2:
				s.centre = found.local_dir(float(at[0]), float(at[1]), world_radius)
				s.axis = found.local_dir(float(at[0]) + sin(bearing), float(at[1]) + cos(bearing), world_radius) - s.centre
			else:
				errors.append("%s: stamp %s has an at that is not [east, north]" % [body_id, s.id])
				bad = true
		else:
			var lat := float(data.get("lat", 0.0))
			if absf(lat) > 90.0:
				errors.append("%s: stamp %s has latitude %s, outside 90" % [body_id, s.id, lat])
				bad = true
			s.centre = dir_of(lat, float(data.get("lon", 0.0)))
			var north := Vector3.UP - s.centre * s.centre.y
			if north.length() > 1e-9:
				north = north.normalized()
				s.axis = north * cos(bearing) + north.cross(s.centre) * sin(bearing)
		if s.keep < 0.0 or s.keep >= 1.0:
			errors.append("%s: stamp %s has keep %s, outside 0 to 1" % [body_id, s.id, s.keep])
			bad = true
		if s.kind == TerrainStamp.Kind.MESA and (s.height <= 0.0 or s.edge <= 0.0):
			errors.append("%s: mesa %s needs a height and an edge over 0" % [body_id, s.id])
			bad = true
		if s.stretch < 1.0 or s.wobble < 0.0 or s.wobble >= 0.5:
			errors.append("%s: stamp %s needs a stretch of 1 or more and a wobble from 0 to under 0.5" % [body_id, s.id])
			bad = true
		elif s.kind != TerrainStamp.Kind.MESA and (s.stretch != 1.0 or s.wobble != 0.0):
			errors.append("%s: only a mesa takes a stretch or a wobble (%s)" % [body_id, s.id])
			bad = true
		if not bad and not s.is_round():
			s.shape()
		if not bad:
			out.append(s)
	return out

## Two stamps keep apart or the earlier holds the later wholly inside its
## `radius` (the plan's call 4); anything else is a problem.
func _overlap_problems(body_id: StringName, stamps: Array[TerrainStamp], world_radius: float,
		out: PackedStringArray) -> void:
	for i in stamps.size():
		for j in range(i + 1, stamps.size()):
			if stamp_margin(stamps[i], stamps[j], world_radius) < 0.0:
				out.append("%s: stamps %s and %s neither keep apart nor nest" % [body_id, stamps[i].id, stamps[j].id])

## How far (m) the stamps `outer` and `inner` (in that order on their body) are
## from breaking call 4: apart, the gap between their reaches; nested, how far
## inside `outer`'s flat part `inner`'s reach lies; whichever is more. Under 0
## is a problem.
static func stamp_margin(outer: TerrainStamp, inner: TerrainStamp, world_radius: float) -> float:
	var d := outer.metres_from(inner.centre, world_radius)
	return maxf(d - outer.reach() - inner.reach(), outer.radius - d - inner.reach())
