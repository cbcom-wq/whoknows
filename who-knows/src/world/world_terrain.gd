class_name WorldTerrain
extends RefCounted

## The ground of one world (docs/superpowers/specs/2026-09-30-world-scale-design.md
## §4): how high it is, what colour it is, and how far above it a point is.
## Pure and deterministic: the same on every machine. Everything that needs
## the ground asks this -- the far mesh, the surface's chunks, collision, the
## analytic floor and the speed limit -- never each other.
##
## Not thread-safe (FastNoiseLite is not): each thread makes its own from the
## same recipe, and they all agree.
##
## A height is metres above radius_m, within half the relief either way: a
## continent layer the size of the world under the archetype's own hills,
## and for a cratered world the same craters its far pattern paints. The
## colours are that pattern -- patches, bands, plateaus, craters (style guide
## §3.5) -- with steep ground bare rock, in shade patches a few triangles
## across (PATCH_QUADS) at every detail. A desert (DUNES) is its own shape
## and colours on the same continent layer: dunes, mesas and towers (the
## desert world spec §7.2), and the wind that laid them (wind_at). A planned
## desert draws its plan's land instead (`plan`; the wadis land spec §5, §6):
## the plan's base, each kind of land's own detail close up on it, and its
## canyons cut into that; and that old ground only within its kept discs, to
## the bit.

## Continents: this many across the unit sphere.
const CONTINENT_SCALE := 1.4
## The archetype's hills: the biggest this many metres across, and octaves
## down to the smallest.
const HILL_WAVE := 4000.0
const HILL_OCTAVES := 7
## How the relief is shared between continents and hills.
const CONTINENT_SHARE := 0.45
const HILL_SHARE := 0.55
## Mesa terraces: how many, and the flat share of each.
const TERRACES := 4
const TERRACE_FLAT := 0.8
## A cratered world's hills are this much gentler.
const CRATERED_HILLS := 0.4
## A crater's bowl and rim, as shares of the relief's half.
const CRATER_DEPTH := 0.8
const CRATER_RIM := 0.25
## Of a crater's width, the dark floor; the rest is its light rim.
const CRATER_FLOOR := 0.78
## Craters: how many, and how wide, in radians round the sphere.
const CRATERS := Vector2i(5, 9)
const CRATER_SIZE := Vector2(0.12, 0.35)
## Ridged bands of colour: how many round the sphere.
const BANDS := 9.0
## How finely the colour pattern varies over the unit sphere.
const PATTERN_SCALE := 1.6
## Steeper than this, the ground is bare rock.
const ROCK_SLOPE := deg_to_rad(35.0)
## A shade patch is this many triangles across (about six), so shades come in
## broad patches at every detail, never triangle by triangle.
const PATCH_QUADS := 6.0

# A desert (DUNES; the desert world spec §7.2): long asymmetric dunes on the
# continent layer, running across one wind axis and turning across the world;
# flat mesas where the continent layer is high; rock towers just below them.

## Dunes: crests this far apart, this high at most, the lee taking this share
## of each wave (about 20° at full height; the windward side about 5°).
## Retuned at Checkpoint A (2026-11-07): 18 m over 320 m barely read in flat
## light.
const DUNE_WAVE := 600.0
const DUNE_HEIGHT := 40.0
const DUNE_LEE := 0.18
## The trough is rounded over this share of a wave either side, and the crest
## over DUNE_CREST_EASE (about 7 m either side): a crisp ridge, never a knife
## edge.
const DUNE_EASE := 0.04
const DUNE_CREST_EASE := 0.012
## Along its crest a dune's height swells from this share to full and back,
## by a noise this many metres across (at Checkpoint A from 0.35: on foot the
## low dunes, 6 m, did not read as dunes).
const DUNE_LOW := 0.5
const DUNE_SWELL := 6000.0
## The ridges are level lines of d . wind_axis, shifted by up to this many
## waves by a noise this many metres across, so they turn across the world
## (600 m: the turn Task 2's 1.5 waves of 320 m gave, a little more).
const DUNE_WARP := 1.0
const DUNE_TURN := 5000.0
## Past this |d . wind_axis|, toward the axis's poles where the ridges would
## close into rings, the dunes fade into a flat sand sheet, gone halfway to
## the pole.
const DUNE_POLE := 0.9
## A dune's lee face, from its crest down to the next trough, is dust where
## the dune stands at least this share of its height (before its swell): so
## the colour changes along the ridge and the foot of the slip face, where the
## ground folds, never across a slope. The sand sheets are ground_low.
const DUST_STAND := 0.5
## A desert's shade patches are this many times broader than PATCH_QUADS: on
## smooth sand, narrower ones broke the ground into blotches.
const DESERT_PATCH := 2.0
## Under the dunes and mesas the continent layer stands at this share of its
## height, so the dunes lie on a nearly level floor (a fraction of a degree)
## and are not lost on its slopes.
const DUNE_FLOOR := 0.25
## Mesas rise where the continent layer (continent_at: a share of half the
## relief) is above MESA_FROM; the dunes fade out over MESA_EDGE below it. A
## desert's layer carries MESA_HILLS of the hills, so the mesa line wanders
## and breaks up rather than following a contour.
const MESA_FROM := 0.10
const MESA_EDGE := 0.05
const MESA_HILLS := 0.02
## One terrace per MESA_STEP of the layer, each MESA_RISE of half the relief
## above the last: its riser takes the first 1 - MESA_FLAT of it, the rest is
## flat.
const MESA_STEP := 0.02
const MESA_RISE := 0.15
const MESA_FLAT := 0.98
## Towers stand in the band TOWER_BAND below the mesa line: cells TOWER_WAVE
## metres apart, one in TOWER_SHARE standing, its flat top TOWER_RADIUS in
## radius and its flank spreading to TOWER_FOOT times that. Each rises to the
## first terrace, shorter toward the band's floor. Retuned at Checkpoint A: a
## fifth as many as Task 2's (0.3 of 140 m cells), broad flat-topped buttes
## with near-sheer walls, whose tops (60-164 m across) stay a few quads across
## at 1-2 km, not a rash of cones.
const TOWER_BAND := 0.06
const TOWER_WAVE := 440.0
const TOWER_RADIUS := Vector2(30.0, 82.0)
const TOWER_SHARE := 0.6
const TOWER_FOOT := 1.12
## How far a tower's centre strays from its cell's, as FastNoiseLite's
## cellular jitter: at 0.6 two centres are at least 0.48 of a cell apart, over
## twice the widest flank, so no tower's flank meets another cell's; and every
## point of a tower lies inside its own cell: its centre within 0.262 of its
## cell's, its flank within TOWER_RADIUS.y * TOWER_FOOT = 92 m of that, under
## 0.221 of any cell of 418 m or more (every world over 6 km), 0.483 < 0.5 in
## all.
const TOWER_JITTER := 0.6
## Each cube face's tower cells start this many cells from the last face's,
## more than a face is across, so the faces never share a cell.
const TOWER_FACE_CELLS := 1000.0
## A dune's crest, and its windward and lee slopes, per unit of wave.
const _CREST := 1.0 - DUNE_LEE
const _UP := 1.0 / _CREST
const _DOWN := -1.0 / DUNE_LEE

# A planned desert's ground close up (the wadis land spec §6): each kind of
# land's own detail on the plan's base (WorldPlan.S_BASE), never more than that
# land's WorldPlan.DETAIL_REACH over or under it, so the plan's bounds and its
# canyons' rims hold it. Flat colour throughout, steep ground rock.

## Plains: a gentle roll PLAINS_ROLL metres either way, in swells about
## PLAINS_ROLL_WAVE metres across. It fades out over a dune sea's edge
## (WorldPlan.DUNES_EDGE), down a beach to the water and up onto a range's or a
## plateau's land.
const PLAINS_ROLL := 4.0
const PLAINS_ROLL_WAVE := 900.0
## Mountains: sharp ridged peaks along a range's spine, from a ridged noise of
## the terrain's own (MOUNTAIN_OCTAVES, the biggest MOUNTAIN_WAVE metres
## across), cubed so its ridges stand narrow and steep over wide valleys and
## their faces turn rock (ROCK_SLOPE): a third or more of the ground within a
## third of a range's half-width of its spine. A gentler noise, a wider wave or
## shorter peaks leave most faces under ROCK_SLOPE, all one colour. The peaks
## stand up to MOUNTAIN_ROUGH of the spine's height there and never more than
## MOUNTAIN_ROUGH_MOST metres (within DETAIL_REACH), whole from MOUNTAIN_FULL of
## the mountains' weight in to the spine and falling to none at their edge
## (WorldPlan.MOUNTAINS_FROM). SPINE_SHARE of it is a crest on the spine itself,
## gone SPINE_CREST metres either side, so the spine is a knife ridge standing
## clear of its flanks. All of it fades over the last MOUNTAIN_SHORE metres to
## the water, where a range ends in a cliff (CLIFF_IN).
const MOUNTAIN_ROUGH := 0.25
const MOUNTAIN_ROUGH_MOST := 440.0
const MOUNTAIN_FULL := 0.75
const MOUNTAIN_WAVE := 700.0
const MOUNTAIN_OCTAVES := 4
const SPINE_SHARE := 0.4
const SPINE_CREST := 400.0
const MOUNTAIN_SHORE := 200.0
## A range's foot, its flanks under the mountains' edge: boulders gather
## (in_talus) where S_MOUNTAIN is MOUNTAIN_TALUS.x to MOUNTAIN_TALUS.y; and
## alluvial fans spread there, the peaks' ridges running on as low spurs at most
## FAN_RISE metres tall, rising over the flanks' first FAN.x of weight and gone
## between FAN.y and the mountains' edge.
const MOUNTAIN_TALUS := Vector2(0.25, 0.5)
const FAN_RISE := 7.0
const FAN := Vector2(0.2, 0.3)
## Plateau country: the inner half of a region's edge band (S_PLATEAU from
## WorldPlan.PLATEAU_FROM to 1) climbs to the region's own top (S_PLATEAU_TOP) in
## TERRACES flat terraces, each rising first in a near-sheer rock riser over
## 1 - MESA_FLAT of it, as today's mesas do; the outer half is the talus at their
## foot. The terraces' lines are pushed inward by up to TERRACE_WANDER of the
## climb (most at its foot, none at the top) by a noise TERRACE_WANDER_WAVE
## metres across, so they follow no cell's edge. Today's towers (_tower_stand)
## stand over the outer half and the foot's level in front of the first riser,
## each rising to the first terrace's height and merging into it, shorter over
## the outer half's first TOWER_EASE of S_PLATEAU (from the region's outline).
const TERRACE_WANDER := 0.3
const TERRACE_WANDER_WAVE := 1500.0
const TOWER_EASE := 0.1
## Where a range or a plateau meets the sea it ends in a cliff: the land's height
## held to the cliff line (_cliff_line), then a sheer rock face over the next
## CLIFF_RUN metres of WorldPlan.S_SHORE (a little more on the ground, where the
## shore's metres are drawn out over a coastal cell) down to a beach. The line
## wanders in and out along the coast (the wadis land spec §6, Checkpoint 1):
## CLIFF_IN metres inland of the water's edge (by S_SHORE) at a headland, out to
## CLIFF_BAY at the back of a bay, by a noise of the terrain's own (plan_bays)
## CLIFF_WAVE metres across read along the water's edge, eased from headland to
## bay as its size goes from BAY_NOISE.x to BAY_NOISE.y: a headland wherever the
## noise passes zero, every kilometre or few, and between them bays of every
## width and depth. A bay's back stays well inside a coastal cell (on WADIS the
## first corner off the water is 985 m or more inland of it): on a world whose
## plan's cells are small, no deeper than BAY_CELL of a cell's edge (bay_depth),
## since deeper the water's edge a point faces (_shore_point) is found through
## cells whose field rises slowly, a Newton step runs on two cells and more, and
## the line jumps about the back of the bay in slots of beach a few metres wide
## (TOMERKA-79, WorldRecipe.from_seed(71), cells of 386 m: the line moved 32.6 m
## in a metre with bays CLIFF_BAY deep, 3.0 at 0.75 of a cell, 2.4 at 0.7; and
## KASEN-88, seed 1812, 145 m, then 20.9 at 0.8, 9.0 at 0.75 and 6.9 at 0.7).
## PlanBounds holds every cell within the bay depth of the water down to sea
## level. A coast is all cliff where the land's mountains' weight (PlanMap.held:
## its cell's inland corners', held to the water) or its plateau's is CLIFF_FADE
## or more, and none where there is none. A range's base is held to the water
## the same way, since its cell's corners on the water's edge stand at sea level.
## Only looked for within CLIFF_LOOK metres of the water.
const CLIFF_IN := 40.0
const CLIFF_BAY := 400.0
const BAY_CELL := 0.7
const CLIFF_WAVE := 2500.0
const BAY_NOISE := Vector2(0.05, 0.6)
const CLIFF_RUN := 4.0
const CLIFF_FADE := 0.1
const CLIFF_LOOK := 2000.0
## The water's edge the bays' noise is read at (_shore_point) is found by the
## shore's fall over SHORE_PROBE metres either way, taken as no less than
## SHORE_FLAT's root a metre where the field lies flatter, in SHORE_STEPS Newton
## steps. One is exact where the coast runs straight. By a convex corner of the
## water's edge (a coastal cell with one corner inland, where the field is a
## product) one step slides the point along the coast half as fast as `d` goes
## inland, and a bay's side then rises faster than the shore and folds a pit
## behind the cliff top (ALLOROR-29, WorldRecipe.from_seed(139), had one behind
## a strip of top 250 m wide); three steps take it into the corner instead.
## Where the shore's fall turns at a cell's edge the point slides along the coast
## as `d` crosses it too, over about twice SHORE_PROBE. Probing one way only, or
## 50 m either way, folded a few pits or notches on ALLOROR-29 and TAROR-91 (the
## world of seed 248); 25 m either way folded none on them, WADIS or RINNU-63.
const SHORE_PROBE := 25.0
const SHORE_FLAT := 0.01
const SHORE_STEPS := 3
## Under a cliff the beach rises from sea level at the water's edge BAY_RISE
## metres over its first BAY_SHORE metres of S_SHORE (the waterline's damp band
## lies along that rise), and stands level behind it to the cliff's foot: a
## little over the sea, so the sea's water never lies flat on it. Under a metre,
## so a cliff's foot is within a metre of sea level at a headland and in a bay.
const BAY_RISE := 0.8
const BAY_SHORE := 60.0
## The sea's waterline: wet sand (damp) where the ground stands from DAMP_BAND.x
## metres under sea level to DAMP_BAND.y over it. The ground's height is only
## looked at where the base is within DAMP_LOOK metres of sea level, more than
## the detail lifts or lowers it there.
const DAMP_BAND := Vector2(2.0, 0.6)
const DAMP_LOOK := 50.0
## PlanShapes.kinds' bits for a canyon and for a butte listed near a cell.
const _CANYON_NEAR := 1 << PlanShapes.CANYON
const _BUTTE_NEAR := 1 << PlanShapes.BUTTE
## Of a plateau's whole climb from its outline, how far under its top the first
## terrace stands: the edge band's inner half climbs the upper half of it, and
## the first of TERRACES terraces a TERRACES'th of that.
const _FIRST_TERRACE := 0.5 * (1.0 - 1.0 / TERRACES)

var recipe: WorldRecipe
var radius: float
## Metres from the ground's lowest to its highest, at most, centred on the
## radius: the recipe's relief_m, or on a planned desert the plan's whole range
## (_planned_range), which the streaming pads its bounds by on a world with no
## plan.
var relief: float
## The least and most the ground's height can be, metres above radius: half the
## relief under and over it, or on a planned desert its plan's bounds over the
## whole world, from its seabed to its highest peak. The streaming's horizon
## reaches by them (WorldSurface.select_for).
var lowest: float
var highest: float
## Metres above radius of a planned desert's sea (its plan's sea_level), and
## -INF on every world with no sea. Under it, the ground is seabed, and the
## surface (surface_at) is the water.
var sea_level := -INF
var archetype: WorldRecipe.Archetype
var palette: Dictionary
## [centre direction, angular radius] per crater; empty unless CRATERED.
var craters: Array = []
var band_axis := Vector3.UP
## A desert's dune crests run along this axis's lines of latitude (before
## their warp), and its wind blows across them, toward the axis.
var wind_axis := Vector3.UP

## Extra angle (radians) the stamp cull allows past a stamp's reach. A unit
## direction's dot with a stamp's centre is a 32-bit float, good to about 6e-8
## in cos: near 1 that is a few tenths of a milliradian of angle, so a tight cull
## dropped a pad's outer 10 m or more. The exact test (`metres_from`) still
## decides what a stamp changes.
const STAMP_CULL_SLACK := 2.0e-3

## The recipe's stamps, as this terrain's own copies (a FLATTEN's level filled
## in), and per stamp the cosine of the angle past which it is of no concern.
var stamps: Array[TerrainStamp] = []
var _stamp_cos: PackedFloat64Array = PackedFloat64Array()
## One cap holding every stamp's (its centre, and the cosine of its angular
## radius, STAMP_CULL_SLACK past the farthest): past it no stamp is of
## concern, by one dot. Until the stamps are all taken, the whole sphere.
var _stamps_centre := Vector3.ZERO
var _stamps_cos := -2.0

## A planned desert's plan (WorldRecipe.plan(), the wadis land spec §5): null on
## every other world, and on a desert drawn as it always was (recipe.planned
## false). Its ground is the plan's, and today's inside a kept disc.
var plan: WorldPlan
## The plan's map and its kept discs' cap (WorldPlan.keeps_centre, keeps_cos),
## held here: read per height.
var _map: PlanMap
var _keeps_centre := Vector3.ZERO
var _keeps_cos := 2.0
## Half today's relief (recipe.relief_m): what today's desert ground reads, and
## everything reached from it, where `relief` is a planned desert's whole
## range. So a kept disc stays as it always was.
var _legacy_half := 0.0
## This terrain's own fields for the plan's samples (WorldPlan.S_SIZE long): one
## per terrain, so one per thread, and none made per height.
var _fields := PackedFloat64Array()
## A planned desert's: by cell, the kinds of shape listed near it
## (PlanShapes.kinds); and the noises of its detail close up, its own: the
## plains' roll, the mountains' ridged peaks, the terraces' wander and the sea
## cliffs' bays.
var _near_kinds := PackedByteArray()
var _roll: FastNoiseLite
var _peaks: FastNoiseLite
var _wander: FastNoiseLite
var _bays: FastNoiseLite
## The back of a bay on this world: bay_depth.
var _bay_depth := CLIFF_BAY

var _continents := FastNoiseLite.new()
var _hills := FastNoiseLite.new()
var _pattern := FastNoiseLite.new()
var _shades := FastNoiseLite.new()
## A desert's alone: the ridges' warp, the crests' swell, and the towers'
## cells (two returns of the same cells).
var _wind: FastNoiseLite
var _swell: FastNoiseLite
var _tower_gap: FastNoiseLite
var _tower_cell: FastNoiseLite
## Tower cells per radian across a cube face: about TOWER_WAVE metres each,
## a whole number of them across the face with the face's edges on cell
## edges.
var _tower_scale := 0.0

func _init(p_recipe: WorldRecipe) -> void:
	recipe = p_recipe
	radius = recipe.radius_m
	relief = recipe.relief_m
	_legacy_half = recipe.relief_m * 0.5
	lowest = -relief * 0.5
	highest = relief * 0.5
	archetype = recipe.archetype
	palette = SpacePalette.WORLDS[recipe.palette]
	_continents.seed = WorldSeed.noise_seed(WorldSeed.sub(recipe.seed, &"continents"))
	_continents.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_continents.frequency = 1.0
	_continents.fractal_type = FastNoiseLite.FRACTAL_FBM
	_continents.fractal_octaves = 3
	_hills.seed = WorldSeed.noise_seed(WorldSeed.sub(recipe.seed, &"terrain"))
	_hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hills.frequency = 1.0
	_hills.fractal_octaves = HILL_OCTAVES
	_hills.fractal_type = FastNoiseLite.FRACTAL_RIDGED if archetype == WorldRecipe.Archetype.RIDGED \
		else FastNoiseLite.FRACTAL_FBM
	# The far pattern keeps the sub-seeds it always had, so a world looks as
	# it did from afar.
	_pattern.seed = WorldSeed.noise_seed(WorldSeed.sub(recipe.seed, &"look"))
	_pattern.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_pattern.frequency = 1.0
	_pattern.fractal_type = FastNoiseLite.FRACTAL_FBM
	_pattern.fractal_octaves = 2
	_shades.seed = WorldSeed.noise_seed(WorldSeed.sub(recipe.seed, &"shades"))
	_shades.noise_type = FastNoiseLite.TYPE_CELLULAR
	_shades.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	_shades.frequency = 1.0
	_shades.fractal_type = FastNoiseLite.FRACTAL_NONE
	var rng := WorldSeed.rng(recipe.seed, &"marks")
	band_axis = _direction(rng)
	if archetype == WorldRecipe.Archetype.CRATERED:
		for i in rng.randi_range(CRATERS.x, CRATERS.y):
			craters.append([_direction(rng), rng.randf_range(CRATER_SIZE.x, CRATER_SIZE.y)])
	if archetype == WorldRecipe.Archetype.DUNES:
		wind_axis = _direction(WorldSeed.rng(recipe.seed, &"wind"))
		_wind = _simplex(&"wind", 2)
		_swell = _simplex(&"dunes", 1)
		_tower_gap = _cells(FastNoiseLite.RETURN_DISTANCE)
		_tower_cell = _cells(FastNoiseLite.RETURN_CELL_VALUE)
		_tower_scale = (floorf(PI * 0.25 * radius / TOWER_WAVE) + 0.5) / (PI * 0.25)
	plan = recipe.plan()
	if plan != null:
		_map = plan.map
		_keeps_centre = plan.keeps_centre
		_keeps_cos = plan.keeps_cos
		_fields.resize(WorldPlan.S_SIZE)
		_near_kinds = plan.shapes.kinds
		sea_level = plan.sea_level
		_roll = _simplex(&"plan_roll", 2)
		_wander = _simplex(&"plan_terraces", 2)
		_peaks = _simplex(&"plan_peaks", MOUNTAIN_OCTAVES)
		_peaks.fractal_type = FastNoiseLite.FRACTAL_RIDGED
		_bays = _simplex(&"plan_bays", 1)
		_bay_depth = bay_depth(radius)
		_planned_range()
	_take_stamps()

## A planned desert's lowest and highest: the least and most of the plan's
## bounds over the whole world (each face's node at depth 0); and its relief,
## twice the farther of them from the radius, so its deepest seabed and highest
## peak are within half of it.
func _planned_range() -> void:
	lowest = INF
	highest = -INF
	for face in CubeSphere.FACES:
		var b := plan.bounds_of(Vector4i(face, 0, 0, 0))
		lowest = minf(lowest, b.x)
		highest = maxf(highest, b.y)
	relief = 2.0 * maxf(absf(lowest), absf(highest))

## Copies the recipe's stamps, outer first, and gives each FLATTEN or MESA with
## no level the mean of the ground under its flat part with the stamps before
## it applied; then the cap that holds them all.
## The copies are this terrain's own: the recipe is shared across threads and
## stays as it was.
func _take_stamps() -> void:
	for source in recipe.stamps:
		var s := source.copy()
		if s.has_level() and is_nan(s.level):
			var sum := 0.0
			var points := s.level_samples(radius)
			for p in points:
				sum += height_at(p)
			s.level = sum / points.size()
		stamps.append(s)
		var outer := maxf(s.reach(), s.radius + TerrainStamp.CLEAR_MARGIN)
		_stamp_cos.append(cos(minf(outer / radius + STAMP_CULL_SLACK, PI)))
	var middle := Vector3.ZERO
	for s in stamps:
		middle += s.centre
	if middle.length_squared() < 1e-12:
		return
	var centre := middle.normalized()
	var widest := 0.0
	for i in stamps.size():
		widest = maxf(widest, centre.angle_to(stamps[i].centre) + acos(clampf(_stamp_cos[i], -1.0, 1.0)))
	if widest + STAMP_CULL_SLACK < PI:
		_stamps_centre = centre
		_stamps_cos = cos(widest + STAMP_CULL_SLACK)

## Metres above radius at `dir`, within half the relief either way: the base
## ground with each stamp applied in order.
func height_at(dir: Vector3) -> float:
	if stamps.is_empty():
		return base_height_at(dir)
	var d := dir.normalized()
	# The base ground from `dir` as given, as with no stamps: normalising it a second
	# time would shift far ground by a rounding (bit for bit beyond a stamp's reach).
	var h := base_height_at(dir)
	if d.dot(_stamps_centre) < _stamps_cos:
		return h
	for i in stamps.size():
		if d.dot(stamps[i].centre) < _stamp_cos[i]:
			continue
		var s := stamps[i]
		var m := s.metres_from(d, radius)
		if s.kind == TerrainStamp.Kind.FLATTEN:
			var w := s.weight(m)
			if w > 0.0:
				var surface := s.level + s.raise
				if s.keep > 0.0:
					surface += s.keep * (h - s.level)
				h = lerpf(h, surface, w)
		elif s.kind == TerrainStamp.Kind.MESA:
			var w := s.fall(m, d)
			if w > 0.0:
				h = lerpf(h, s.level + s.height, w)
		else:
			h -= s.dig(m)
	return h

## Whether `dir` is within TerrainStamp.CLEAR_MARGIN of some stamp's flat part
## or rim: where ground cover keeps off.
func stamp_clear(dir: Vector3) -> bool:
	if stamps.is_empty():
		return false
	var d := dir.normalized()
	if d.dot(_stamps_centre) < _stamps_cos:
		return false
	for i in stamps.size():
		if d.dot(stamps[i].centre) < _stamp_cos[i]:
			continue
		var s := stamps[i]
		if s.metres_from(d, radius) <= s.flat_radius(d) + TerrainStamp.CLEAR_MARGIN:
			return true
	return false

## The innermost stamp's ground at `d` if `d` is within its radius, else &"".
func _stamp_ground(d: Vector3) -> StringName:
	var found := &""
	if d.dot(_stamps_centre) < _stamps_cos:
		return found
	for i in stamps.size():
		if d.dot(stamps[i].centre) < _stamp_cos[i]:
			continue
		var s := stamps[i]
		if s.metres_from(d, radius) <= s.flat_radius(d):
			found = s.ground
	return found

## The ground before any stamp, metres above radius within half the relief
## either way. On a planned desert the plan's (_planned_height), but inside a
## kept disc today's, to the bit, eased into the plan's over its blend (the
## wadis land spec §5.6).
func base_height_at(dir: Vector3) -> float:
	var d := dir.normalized()
	if plan != null:
		# _kept(d), written out.
		var w := 0.0 if d.dot(_keeps_centre) < _keeps_cos else plan.keep_weight(d)
		if w < 1.0:
			var planned := _planned_height(d)
			if w == 0.0:
				return planned
			return lerpf(planned, _desert_height(d, _continents.get_noise_3dv(d * CONTINENT_SCALE)), w)
	var continent := _continents.get_noise_3dv(d * CONTINENT_SCALE)
	if archetype == WorldRecipe.Archetype.DUNES:
		return _desert_height(d, continent)
	var hills := _hills.get_noise_3dv(d * (radius / HILL_WAVE))
	match archetype:
		WorldRecipe.Archetype.MESA:
			hills = _terrace(hills)
		WorldRecipe.Archetype.CRATERED:
			hills = hills * CRATERED_HILLS + _crater(d)
	return relief * 0.5 * clampf(CONTINENT_SHARE * continent + HILL_SHARE * hills, -1.0, 1.0)

## The continent layer at `dir`, as a share of half the relief (CONTINENT_SHARE
## of the continents' noise), that a desert's mesas rise from: on a desert
## with MESA_HILLS of the hills in it.
func continent_at(dir: Vector3) -> float:
	var d := dir.normalized()
	var continent := _continents.get_noise_3dv(d * CONTINENT_SCALE)
	if archetype != WorldRecipe.Archetype.DUNES:
		return CONTINENT_SHARE * continent
	return CONTINENT_SHARE * continent + MESA_HILLS * _hills.get_noise_3dv(d * (radius / HILL_WAVE))

## A desert's continent_at, from the continents' noise at `d`. Where the
## hills (within -1 to 1) could not lift it into the tower band, the layer
## without them, which every desert rule treats the same: so the hills are
## only sampled near the mesas.
func _mesa_continent(d: Vector3, continent: float) -> float:
	var layer := CONTINENT_SHARE * continent
	if layer < MESA_FROM - TOWER_BAND - MESA_HILLS:
		return layer
	return layer + MESA_HILLS * _hills.get_noise_3dv(d * (radius / HILL_WAVE))

## Which way the wind blows at `dir` on a desert: the unit tangent from a
## dune's windward side to its lee, the way the dune phase grows (by central
## differences 1 m apart). Vector3.ZERO on any other world.
func wind_at(dir: Vector3) -> Vector3:
	if archetype != WorldRecipe.Archetype.DUNES:
		return Vector3.ZERO
	var d := dir.normalized()
	var e1 := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	var e2 := d.cross(e1)
	var h := 0.5 / radius
	var g := e1 * (_phase_of(d + e1 * h) - _phase_of(d - e1 * h)) \
		+ e2 * (_phase_of(d + e2 * h) - _phase_of(d - e2 * h))
	if g.length_squared() < 1e-20:
		return e1
	return g.normalized()

## Whether `dir` is where a desert's boulders gather: the low ground of the
## tower band below a mesa (which holds the MESA_EDGE the dunes fade over),
## off the towers themselves. On a planned desert, the feet of its ranges,
## plateaus and buttes (_planned_talus), and today's only within a kept disc (over
## the inner half of its blend). False on any other world.
func in_talus(dir: Vector3) -> bool:
	if archetype != WorldRecipe.Archetype.DUNES:
		return false
	var d := dir.normalized()
	if plan != null and _kept(d) <= 0.5:
		return _planned_talus(d)
	var z := _mesa_continent(d, _continents.get_noise_3dv(d * CONTINENT_SCALE))
	return z >= MESA_FROM - TOWER_BAND and z < MESA_FROM and _tower(d, z) == 0.0

## How far `local` (from the world's centre) is above the ground under it.
func altitude_of(local: Vector3) -> float:
	if local.is_zero_approx():
		return -radius
	return local.length() - (radius + height_at(local))

## Metres above radius of the surface at `dir` (the wadis land spec §7.1): the
## higher of the ground and the sea, so the water over a seabed; the ground on a
## world with no sea.
func surface_at(dir: Vector3) -> float:
	return maxf(height_at(dir), sea_level)

## Which of the palette's grounds faces `dir` on ground this steep (radians).
func ground_at(dir: Vector3, slope: float) -> StringName:
	if slope > ROCK_SLOPE:
		return &"rock"
	var d := dir.normalized()
	if not stamps.is_empty():
		var stamped := _stamp_ground(d)
		if stamped != &"":
			return stamped
	if archetype == WorldRecipe.Archetype.DUNES:
		# A kept disc's own over the inner half of its blend, as its heights
		# are mostly its own there.
		if plan != null and _kept(d) <= 0.5:
			return _planned_ground(d, _fields)
		return _desert_ground(d)
	var n := _pattern.get_noise_3dv(d * PATTERN_SCALE)
	match archetype:
		WorldRecipe.Archetype.RIDGED:
			var band := sin(d.dot(band_axis) * BANDS + n * 2.5)
			if band > 0.75:
				return &"rock"
			return &"ground_high" if band > 0.05 else &"ground_low"
		WorldRecipe.Archetype.MESA:
			if absf(n - 0.05) < 0.06:
				return &"rock"
			return &"ground_high" if n > 0.05 else &"ground_low"
		WorldRecipe.Archetype.CRATERED:
			for c: Array in craters:
				var angle := d.angle_to(c[0])
				if angle < float(c[1]) * CRATER_FLOOR:
					return &"rock"
				if angle < float(c[1]):
					return &"ground_high"
			return &"dust" if n > 0.2 else &"ground_low"
	if n < -0.45:
		return &"rock"
	return &"ground_high" if n > 0.1 else &"ground_low"

## The colour of ground facing `dir`, this steep, in shade patches about
## `patch_m` metres across.
func colour_at(dir: Vector3, slope: float, patch_m: float) -> Color:
	var d := dir.normalized()
	var base: Color = palette[ground_at(d, slope)]
	if archetype == WorldRecipe.Archetype.DUNES:
		patch_m *= DESERT_PATCH
	var cell := (_shades.get_noise_3dv(d * (radius / maxf(patch_m, 1.0))) + 1.0) * 0.5
	var k := clampi(floori(cell * SpacePalette.SHADES.size()), 0, SpacePalette.SHADES.size() - 1)
	return SpacePalette.shade(base, k)

## Mesa: flat steps with steep risers.
func _terrace(h: float) -> float:
	var t := (h + 1.0) * 0.5 * TERRACES
	var step := floorf(t)
	var f := t - step
	var rise := 0.0 if f < TERRACE_FLAT else (f - TERRACE_FLAT) / (1.0 - TERRACE_FLAT)
	return (step + rise) / TERRACES * 2.0 - 1.0

## A desert's height at `d`, from the continents' noise there: dunes on the
## continent layer (flattened to DUNE_FLOOR), faded toward the mesas and the
## wind axis's poles; terraces above the mesa line; towers in the band below.
## The dune's stand (_dune_stand) is written out here rather than called: this
## runs per height, on the main thread too, and a GDScript call costs more than
## a noise lookup. The dune itself is _dune's, which the plan's dune seas share.
## Half today's relief throughout (_legacy_half), never a planned desert's.
func _desert_height(d: Vector3, continent: float) -> float:
	var half := _legacy_half
	# _mesa_continent(d, continent), written out.
	var z := CONTINENT_SHARE * continent
	if z >= MESA_FROM - TOWER_BAND - MESA_HILLS:
		z += MESA_HILLS * _hills.get_noise_3dv(d * (radius / HILL_WAVE))
	var ground := half * DUNE_FLOOR * CONTINENT_SHARE * continent
	if z < MESA_FROM:
		# _dune_stand(a, z).
		var a := d.dot(wind_axis)
		var stand := 1.0
		if z > MESA_FROM - MESA_EDGE:
			stand = 1.0 - smoothstep(MESA_FROM - MESA_EDGE, MESA_FROM, z)
		var pole := absf(a)
		if pole > DUNE_POLE:
			stand *= 1.0 - smoothstep(DUNE_POLE, (1.0 + DUNE_POLE) * 0.5, pole)
		if stand > 0.0:
			ground += _dune(d, a, stand)
	else:
		# Terrace k + 1, rising from terrace k (or from the floor for the first).
		var t := (z - MESA_FROM) / MESA_STEP
		var k := mini(floori(t), TERRACES - 1)
		var top := half * (DUNE_FLOOR * MESA_FROM + MESA_RISE * (k + 1))
		var below := ground if k == 0 else top - half * MESA_RISE
		ground = lerpf(below, top, clampf((t - k) / (1.0 - MESA_FLAT), 0.0, 1.0))
	if z >= MESA_FROM - TOWER_BAND and z < MESA_FROM + MESA_STEP:
		var top := half * (DUNE_FLOOR * MESA_FROM + MESA_RISE)
		if top > ground:
			ground = lerpf(ground, top, _tower(d, z))
	return clampf(ground, -half, half)

## A dune's height over the ground it lies on at `d`, whose d . wind_axis is
## `a`, where it stands `stand` of its height: by its phase (_phase, written
## out here), its cross-section over that wave, and its swell along the crest.
## Today's desert (_desert_height) and the plan's dune seas (_planned_height)
## both lay it.
func _dune(d: Vector3, a: float, stand: float) -> float:
	# The phase, within one wave (_phase).
	var t := fposmod(-radius * acos(clampf(a, -1.0, 1.0)) / DUNE_WAVE
		+ DUNE_WARP * _wind.get_noise_3dv(d * (radius / DUNE_TURN)), 1.0)
	# The cross-section over one wave, t from 0 at a trough: rising gently over
	# 1 - DUNE_LEE to the crest, falling over DUNE_LEE; the crest rounded by a
	# parabola tangent to both slopes over DUNE_CREST_EASE either side, the
	# trough over DUNE_EASE. Never below 0.
	var p: float
	if t < _CREST - DUNE_CREST_EASE:
		if t >= DUNE_EASE:
			p = t * _UP
		else:
			var e := t + DUNE_EASE
			p = _DOWN * t + (_UP - _DOWN) * e * e / (4.0 * DUNE_EASE)
	elif t <= _CREST + DUNE_CREST_EASE:
		var e := t - _CREST + DUNE_CREST_EASE
		p = 1.0 + _UP * (t - _CREST) + (_DOWN - _UP) * e * e / (4.0 * DUNE_CREST_EASE)
	elif t <= 1.0 - DUNE_EASE:
		p = (1.0 - t) / DUNE_LEE
	else:
		var x := t - 1.0
		var e := x + DUNE_EASE
		p = _DOWN * x + (_UP - _DOWN) * e * e / (4.0 * DUNE_EASE)
	var swell := clampf(_swell.get_noise_3dv(d * (radius / DUNE_SWELL)) + 0.5, 0.0, 1.0)
	return DUNE_HEIGHT * stand * p * (DUNE_LOW + (1.0 - DUNE_LOW) * swell)

## A planned desert's ground at the unit direction `d`, as the plan lays it,
## kept discs aside: the plan's base (WorldPlan.S_BASE: the open roll, the
## sea's basin, the ranges' and plateaus' lift) with its land's detail, cut
## where a canyon's walls reach to the least of that and the canyon's floor and
## stepped walls (PlanShapes.wall_rise), which rise to meet the ground. At sea the base
## alone, the basin's shelf and deep floor; on plateau country its terraces
## (_terraces) and its top; on a range's mountains its ridged peaks; on open
## ground today's dunes on the dune seas (_plan_dunes, faded toward the wind
## axis's poles as today's are), the plains' roll and a range's fans at its
## foot, and a butte where one stands (_butte). The map's land fields are
## sampled, and a butte or a canyon is asked only in a cell with one near. Written
## out in one function: this runs per height, and a GDScript call costs about
## what a noise lookup does.
func _planned_height(d: Vector3) -> float:
	var f := _fields
	var cell := _map.sample(d, f, WorldPlan.LAND_FIELDS)
	var ground := f[WorldPlan.S_BASE]
	var shore := f[WorldPlan.S_SHORE]
	if shore > 0.0:
		var plateau := f[WorldPlan.S_PLATEAU]
		var mountain := f[WorldPlan.S_MOUNTAIN]
		if plateau >= 1.0:
			ground = f[WorldPlan.S_PLATEAU_TOP]
		elif plateau >= WorldPlan.PLATEAU_FROM:
			ground = _terraces(d, ground, f[WorldPlan.S_PLATEAU_TOP], plateau)
		elif mountain >= WorldPlan.MOUNTAINS_FROM:
			var spine := plan.shapes.ridge_m(d, PlanShapes.cell_key(cell))
			var rough := minf(MOUNTAIN_ROUGH * spine.y, MOUNTAIN_ROUGH_MOST) \
				* smoothstep(WorldPlan.MOUNTAINS_FROM, MOUNTAIN_FULL, mountain)
			if shore < MOUNTAIN_SHORE:
				rough *= smoothstep(0.0, MOUNTAIN_SHORE, shore)
			var crest := maxf(0.0, 1.0 - spine.x / SPINE_CREST)
			ground += rough * (SPINE_SHARE * crest + (1.0 - SPINE_SHARE) * _peak(d))
		else:
			var dunes := f[WorldPlan.S_DUNES]
			# How plain the ground is, for its roll.
			var plain := 1.0
			if dunes > WorldPlan.DUNES_FROM:
				var stand := _plan_dunes(f)
				if stand > 0.0:
					var a := d.dot(wind_axis)
					# pole_fade(a), written out.
					var pole := absf(a)
					if pole > DUNE_POLE:
						stand *= 1.0 - smoothstep(DUNE_POLE, (1.0 + DUNE_POLE) * 0.5, pole)
					if stand > 0.0:
						ground += _dune(d, a, stand)
				plain = 1.0 - smoothstep(WorldPlan.DUNES_FROM, WorldPlan.DUNES_FROM + WorldPlan.DUNES_EDGE, dunes)
			if shore < WorldPlan.BEACH_WIDTH:
				plain *= smoothstep(0.0, WorldPlan.BEACH_WIDTH, shore)
			if plateau > 0.0:
				plain *= 1.0 - smoothstep(0.0, WorldPlan.PLATEAU_FROM, plateau)
			if mountain > 0.0:
				plain *= 1.0 - smoothstep(0.0, WorldPlan.MOUNTAINS_FROM, mountain)
				var fan := smoothstep(0.0, FAN.x, mountain) * (1.0 - smoothstep(FAN.y, WorldPlan.MOUNTAINS_FROM, mountain))
				if shore < MOUNTAIN_SHORE:
					fan *= smoothstep(0.0, MOUNTAIN_SHORE, shore)
				if fan > 0.0:
					ground += FAN_RISE * fan * _peak(d)
			if plain > 0.0:
				ground += PLAINS_ROLL * plain * _roll.get_noise_3dv(d * (radius / PLAINS_ROLL_WAVE))
			if plateau > 0.0:
				# A tower on the edge band's outer half, rising to the first terrace.
				var tower := _tower_stand(d)
				if tower > 0.0:
					var top := f[WorldPlan.S_PLATEAU_TOP]
					var first := top - _FIRST_TERRACE * (top - f[WorldPlan.S_BASE]) / (1.0 - plateau)
					if first > ground:
						ground = lerpf(ground, first, tower * smoothstep(0.0, TOWER_EASE, plateau))
		if shore < CLIFF_LOOK and (mountain > 0.0 or plateau > 0.0):
			ground = _cliff(d, f, ground)
	var near := _near_kinds[cell]
	if near == 0:
		return ground
	if near & _BUTTE_NEAR != 0:
		ground = _butte(d, cell, f[WorldPlan.S_BASE], ground)
	if near & _CANYON_NEAR == 0:
		return ground
	var c := plan.shapes.canyon_parts_at(d, cell)
	if c.x == INF:
		return ground
	return minf(ground, c.z + PlanShapes.wall_rise(c.x - c.y))

## A planned desert's `ground` at the unit direction `d` in cell number `cell`,
## a butte's cell, whose base is `base`, with the butte there if one reaches
## (PlanShapes.butte_at; the wadis land spec §6, Checkpoint 1): the open ground's
## detail, its dunes and roll (all its ground over the base, since a butte's
## cells are open ground with no range's or plateau's weight, past the beach),
## banked down to the face's foot (WorldPlan.BUTTE_BANK), and the butte standing
## over that (PlanShapes.butte_rise): its flat top, its sheer face and its apron.
## The bank cuts the dunes no steeper than it climbs, and by the butte's reach it
## stands over the tallest; so the dunes run up to its foot, never over its top,
## and come back whole, never steeper than their own lee faces or the bank. Its
## top stands level on its middle's base; under its face and apron that base
## eases onto the ground round it, whole by the apron's end, so the butte hands
## the ground back with no step where the base rolls away from its middle's or a
## dune's trough dips under it.
func _butte(d: Vector3, cell: int, base: float, ground: float) -> float:
	var b := plan.shapes.butte_at(d, cell)
	if b.x == INF:
		return ground
	ground = minf(ground, base + WorldPlan.BUTTE_BANK * maxf(b.x - b.y, 0.0))
	var foot := b.y + WorldPlan.BUTTE_APRON * b.w
	if b.x >= foot:
		return ground
	var under := lerpf(b.z - b.w, ground, smoothstep(0.0, foot, b.x))
	return maxf(ground, under + PlanShapes.butte_rise(b.x, b.y, b.w))

## A planned plateau's ground on its edge band's inner half, at the unit
## direction `d` whose base is `base`, whose region's top is `top` and whose
## S_PLATEAU is `plateau` (PLATEAU_FROM to under 1). Over the inner half the
## climb goes from 0 to 1 and the base climbs straight from the foot's level to
## the top; the terraces climb in steps as today's mesas do (a riser first, then
## the flat), by the climb pushed in (_terrace_climb). In front of the first
## riser, the foot's level and today's towers on it, rising to the first
## terrace. The climb still to come from `d`'s, over the base's rise still to
## come, is the climb's whole height (`span`).
func _terraces(d: Vector3, base: float, top: float, plateau: float) -> float:
	var u := (plateau - WorldPlan.PLATEAU_FROM) / (1.0 - WorldPlan.PLATEAU_FROM)
	var v := _terrace_climb(d, u)
	var t := v * TERRACES
	if t >= TERRACES - MESA_FLAT:
		return top
	var span := (top - base) / (1.0 - u)
	if v <= 0.0:
		var foot := top - span
		var stand := _tower_stand(d)
		if stand > 0.0:
			return lerpf(foot, foot + span / TERRACES, stand)
		return foot
	var k := floorf(t)
	return top - span * (1.0 - (k + minf((t - k) / (1.0 - MESA_FLAT), 1.0)) / TERRACES)

## Where a planned plateau's terraces are on their climb at the unit direction
## `d`, whose straight climb is `u` (0 to 1): `u` pushed in by up to
## TERRACE_WANDER of the climb still to come, so it is `u` at the top and at the
## foot's level nowhere outside the inner half; 0 or less in front of the first
## riser.
func _terrace_climb(d: Vector3, u: float) -> float:
	var wander := clampf((_wander.get_noise_3dv(d * (radius / TERRACE_WANDER_WAVE)) + 1.0) * 0.5, 0.0, 1.0)
	return u - TERRACE_WANDER * wander * (1.0 - u)

## The mountains' ridged noise at the unit direction `d`, cubed, 0 to 1: 1 on
## its ridges.
func _peak(d: Vector3) -> float:
	var ridge := clampf((_peaks.get_noise_3dv(d * (radius / MOUNTAIN_WAVE)) + 1.0) * 0.5, 0.0, 1.0)
	return ridge * ridge * ridge

## A planned desert's `ground` at the unit direction `d`, on land within
## CLIFF_LOOK of the water where a range or a plateau may meet it, whose fields
## are `f` (a sample's): on a range's coast its base held to the water's edge
## (PlanMap.held), and where the coast is a cliff (_cliff_share) the face from
## the cliff line (_cliff_line) down over CLIFF_RUN to the beach at its foot
## (_beach). The line stands at least CLIFF_IN inland, so within CLIFF_IN less
## CLIFF_RUN of the water the beach is whole wherever the line stands, and the
## line (seven reads of the field a step) is not found there.
func _cliff(d: Vector3, f: PackedFloat64Array, ground: float) -> float:
	var share := smoothstep(0.0, CLIFF_FADE, f[WorldPlan.S_PLATEAU])
	if f[WorldPlan.S_MOUNTAIN] > 0.0:
		var held := smoothstep(0.0, CLIFF_FADE, _map.held(WorldPlan.S_MOUNTAIN, WorldPlan.S_SHORE, d))
		if held > 0.0:
			ground += held * (_map.held(WorldPlan.S_BASE, WorldPlan.S_SHORE, d) - f[WorldPlan.S_BASE])
		share = maxf(share, held)
	var shore := f[WorldPlan.S_SHORE]
	if shore >= _bay_depth or share <= 0.0:
		return ground
	if shore <= CLIFF_IN - CLIFF_RUN:
		return lerpf(ground, _beach(shore), share)
	var line := _cliff_line(d)
	if shore >= line:
		return ground
	return lerpf(ground, _beach(shore), share * minf((line - shore) / CLIFF_RUN, 1.0))

## Where a sea cliff's line stands at the unit direction `d`: metres of S_SHORE
## inland of the water's edge, CLIFF_IN at a headland to CLIFF_BAY at the back of
## a bay, by the bays' noise (CLIFF_WAVE, BAY_NOISE) read at the water's edge `d`
## faces (_shore_point): so where the coast runs straight the line moves only
## along it, never inland, and the way up from the water crosses it once.
func _cliff_line(d: Vector3) -> float:
	var edge := _shore_point(d)
	var bay := smoothstep(BAY_NOISE.x, BAY_NOISE.y, absf(_bays.get_noise_3dv(edge * (radius / CLIFF_WAVE))))
	return CLIFF_IN + (_bay_depth - CLIFF_IN) * bay

## How far inland of the water's edge (metres of S_SHORE) the back of a bay
## stands on a planned desert of `p_radius`: CLIFF_BAY, or on a world whose plan's
## cells are small BAY_CELL of a cell's edge (CubeSphere.edge_m at
## PlanMap.PLAN_DEPTH) and never under CLIFF_IN.
static func bay_depth(p_radius: float) -> float:
	return clampf(BAY_CELL * CubeSphere.edge_m(p_radius, PlanMap.PLAN_DEPTH), CLIFF_IN, CLIFF_BAY)

## The point of the water's edge a planned desert's unit direction `d` faces: `d`
## moved down the shore's field (S_SHORE) by its metres over the field's fall,
## SHORE_STEPS Newton steps to S_SHORE 0. The fall is by central differences
## SHORE_PROBE metres either way along the three axes, so it turns smoothly
## everywhere, over the shore's cell edges and the cube's face edges alike, and
## with it the point and the line; and on a cell's product by a convex corner
## it is near exact, where differences one way are not, and fold the cliff.
## Each step reads the field seven times: the steps are most of a cliff coast's
## height (about 20 µs each).
func _shore_point(d: Vector3) -> Vector3:
	var h := SHORE_PROBE / radius
	var x := Vector3(h, 0.0, 0.0)
	var y := Vector3(0.0, h, 0.0)
	var z := Vector3(0.0, 0.0, h)
	for step in SHORE_STEPS:
		var rise := Vector3(
			_map.at(WorldPlan.S_SHORE, d + x) - _map.at(WorldPlan.S_SHORE, d - x),
			_map.at(WorldPlan.S_SHORE, d + y) - _map.at(WorldPlan.S_SHORE, d - y),
			_map.at(WorldPlan.S_SHORE, d + z) - _map.at(WorldPlan.S_SHORE, d - z)) / (2.0 * SHORE_PROBE)
		rise -= d * rise.dot(d)
		var shore := _map.at(WorldPlan.S_SHORE, d)
		d = (d - rise * (shore / (maxf(rise.length_squared(), SHORE_FLAT) * radius))).normalized()
	return d

## The height of the beach under a sea cliff `shore` metres (S_SHORE) inland of
## the water's edge: rising from sea level BAY_RISE over BAY_SHORE, then level.
func _beach(shore: float) -> float:
	return sea_level + BAY_RISE * smoothstep(0.0, BAY_SHORE, shore)

## How much of a cliff a planned desert's coast is at the unit direction `d`,
## whose fields are `f` (a sample's): 1 where a range's weight (held to the
## water) or a plateau's is CLIFF_FADE or more, 0 where there is none (_cliff).
func _cliff_share(d: Vector3, f: PackedFloat64Array) -> float:
	var share := smoothstep(0.0, CLIFF_FADE, f[WorldPlan.S_PLATEAU])
	if f[WorldPlan.S_MOUNTAIN] > 0.0:
		share = maxf(share, smoothstep(0.0, CLIFF_FADE, _map.held(WorldPlan.S_MOUNTAIN, WorldPlan.S_SHORE, d)))
	return share

## Whether a planned desert's boulders gather at the unit direction `d`: at a
## range's foot (MOUNTAIN_TALUS), at a plateau's, its edge band's outer half and
## the foot's level in front of its first riser, off the towers on both, and at a
## butte's, from its face's foot WorldPlan.BUTTE_TALUS of its height out. Never at
## sea.
func _planned_talus(d: Vector3) -> bool:
	var f := _fields
	var cell := _map.sample(d, f, WorldPlan.LAND_FIELDS)
	if f[WorldPlan.S_SHORE] <= 0.0:
		return false
	if _near_kinds[cell] & _BUTTE_NEAR != 0:
		var b := plan.shapes.butte_at(d, cell)
		if b.x < INF:
			return b.x > b.y and b.x <= b.y + WorldPlan.BUTTE_TALUS * b.w
	var mountain := f[WorldPlan.S_MOUNTAIN]
	if mountain >= MOUNTAIN_TALUS.x and mountain < MOUNTAIN_TALUS.y:
		return true
	var plateau := f[WorldPlan.S_PLATEAU]
	if plateau <= 0.0 or plateau >= 1.0:
		return false
	if plateau < WorldPlan.PLATEAU_FROM:
		return _tower_stand(d) == 0.0
	var u := (plateau - WorldPlan.PLATEAU_FROM) / (1.0 - WorldPlan.PLATEAU_FROM)
	return _terrace_climb(d, u) <= 0.0 and _tower_stand(d) == 0.0

## A planned desert's kept discs' weight at the unit direction `d`
## (WorldPlan.keep_weight), by one dot where no disc reaches.
func _kept(d: Vector3) -> float:
	if d.dot(_keeps_centre) < _keeps_cos:
		return 0.0
	return plan.keep_weight(d)

## How much of today's dunes stand on the plan's ground, from its fields `f`
## (a sample's). None stand on the gravel plains (S_DUNES at DUNES_FROM or
## under). They rise over a dune sea's edge, WorldPlan.DUNES_EDGE of S_DUNES
## past DUNES_FROM, and stand whole across the rest of it, as today's open
## dunes do. They stand only on open ground, fading out down a beach to the
## water and up onto a range's or a plateau's land, so no dune lies under the
## sea or on a peak and none ends in a step.
func _plan_dunes(f: PackedFloat64Array) -> float:
	var dunes := f[WorldPlan.S_DUNES]
	if dunes <= WorldPlan.DUNES_FROM or f[WorldPlan.S_SHORE] <= 0.0:
		return 0.0
	return smoothstep(WorldPlan.DUNES_FROM, WorldPlan.DUNES_FROM + WorldPlan.DUNES_EDGE, dunes) \
		* smoothstep(0.0, WorldPlan.BEACH_WIDTH, f[WorldPlan.S_SHORE]) \
		* (1.0 - smoothstep(0.0, WorldPlan.MOUNTAINS_FROM, f[WorldPlan.S_MOUNTAIN])) \
		* (1.0 - smoothstep(0.0, WorldPlan.PLATEAU_FROM, f[WorldPlan.S_PLATEAU]))

## A planned desert's colours at the unit direction `d` as the plan lays them,
## where its kept discs weigh half or less (steep ground is rock before this is
## asked), the plan's fields sampled into `out` (S_SIZE long, the caller's own):
## a canyon's floor ground_low and, where its walls are the ground, their risers
## rock and ledges ground_high; a cliff's face rock (CLIFF_IN, CLIFF_RUN); a
## plateau's as _terrace_ground has it, and the towers on its edge band's outer
## half rock; wet sand (damp) along the sea's waterline (DAMP_BAND); a butte's top
## ground_high and its face rock; a standing dune's lee face, crest to trough,
## dust, as today's (DUST_STAND), where the dunes stand (_butte clears them by a
## butte's foot); the rest, a range's mountains too, ground_low, so the colour
## changes only where the ground folds or past ROCK_SLOPE.
func _planned_ground(d: Vector3, out: PackedFloat64Array) -> StringName:
	var cell := _map.sample(d, out, WorldPlan.LAND_FIELDS)
	# The ground's height (_planned_height), once it has been worked out.
	var height := NAN
	if _near_kinds[cell] & _CANYON_NEAR != 0:
		var c := plan.shapes.canyon_parts_at(d, cell)
		if c.x < INF:
			var past := c.x - c.y
			if past <= 0.0:
				# The floor, or by a mouth the beach where it lies lower.
				var floor_h := c.z
				if floor_h - sea_level <= DAMP_LOOK:
					floor_h = _planned_height(d)
				return &"damp" if _damp(floor_h) else &"ground_low"
			# The walls are the ground where the ground is their cut, the
			# least of it and the land's.
			var cut := c.z + PlanShapes.wall_rise(past)
			height = _planned_height(d)
			if height == cut:
				var step := past / (WorldPlan.CANYON_WALL_STEP * WorldPlan.CANYON_WALL_RUN)
				return &"rock" if step - floorf(step) < 1.0 - WorldPlan.CANYON_WALL_LEDGE else &"ground_high"
	var plateau := out[WorldPlan.S_PLATEAU]
	var shore := out[WorldPlan.S_SHORE]
	if shore > 0.0:
		# Seaward of a cliff's line, its face and the beach at its foot.
		var under := false
		if shore < _bay_depth and (plateau > 0.0 or out[WorldPlan.S_MOUNTAIN] > 0.0):
			var share := _cliff_share(d, out)
			if share > 0.0:
				# Nearer the water than any line's face, under it wherever it stands.
				var line := CLIFF_IN if shore < CLIFF_IN - CLIFF_RUN else _cliff_line(d)
				under = shore < line
				if under and share >= 0.5:
					if shore >= line - CLIFF_RUN:
						return &"rock"
					if is_nan(height):
						height = _planned_height(d)
					return &"damp" if _damp(height) else &"ground_low"
		if not under and plateau >= WorldPlan.PLATEAU_FROM:
			return _terrace_ground(d, plateau)
		if plateau > 0.0 and plateau < WorldPlan.PLATEAU_FROM and _tower_stand(d) > 0.0:
			return &"rock"
	if sea_level > -INF and absf(out[WorldPlan.S_BASE] - sea_level) <= DAMP_LOOK:
		if is_nan(height):
			height = _planned_height(d)
		if _damp(height):
			return &"damp"
	var stand := _plan_dunes(out)
	if _near_kinds[cell] & _BUTTE_NEAR != 0:
		var b := plan.shapes.butte_at(d, cell)
		if b.x < INF:
			if b.x <= 0.0:
				return &"ground_high"
			if b.x < b.y:
				return &"rock"
			stand *= smoothstep(b.y, b.y + WorldPlan.BUTTE_SAND, b.x)
	if stand < DUST_STAND:
		return &"ground_low"
	var a := d.dot(wind_axis)
	if stand * pole_fade(a) >= DUST_STAND and fposmod(_phase(d, a), 1.0) > _CREST:
		return &"dust"
	return &"ground_low"

## A planned plateau's colours at the unit direction `d` whose S_PLATEAU is
## `plateau` (PLATEAU_FROM or more), as _terraces lays it: its risers and towers
## rock, its terraces and top ground_high, the foot's level in front of the
## first riser ground_low.
func _terrace_ground(d: Vector3, plateau: float) -> StringName:
	if plateau >= 1.0:
		return &"ground_high"
	var u := (plateau - WorldPlan.PLATEAU_FROM) / (1.0 - WorldPlan.PLATEAU_FROM)
	var t := _terrace_climb(d, u) * TERRACES
	if t <= 0.0:
		return &"rock" if _tower_stand(d) > 0.0 else &"ground_low"
	if t < TERRACES - MESA_FLAT and t - floorf(t) < 1.0 - MESA_FLAT:
		return &"rock"
	return &"ground_high"

## Whether ground `height` metres above radius is in the damp band along a
## planned desert's waterline (DAMP_BAND).
func _damp(height: float) -> bool:
	return height >= sea_level - DAMP_BAND.x and height <= sea_level + DAMP_BAND.y

## How much of its height a dune stands at a point whose d . wind_axis is `a`
## and whose continent layer is `z`: 1 on the open dunes, fading to 0 toward
## the mesas and the wind axis's poles (_desert_height writes it out).
static func _dune_stand(a: float, z: float) -> float:
	var stand := 1.0
	if z > MESA_FROM - MESA_EDGE:
		stand = 1.0 - smoothstep(MESA_FROM - MESA_EDGE, MESA_FROM, z)
	if absf(a) > DUNE_POLE:
		stand *= pole_fade(a)
	return stand

## How much of the dunes stands, and of the sand blows (BlowingSand), at a
## point whose d . wind_axis is `a`: 1 up to DUNE_POLE, fading to 0 halfway on
## to the pole, where the ridges would close into rings and the wind's way
## spins round the pole.
static func pole_fade(a: float) -> float:
	var pole := absf(a)
	if pole <= DUNE_POLE:
		return 1.0
	return 1.0 - smoothstep(DUNE_POLE, (1.0 + DUNE_POLE) * 0.5, pole)

## The dune phase (see _phase) at `dir`, which need not be unit length.
func _phase_of(dir: Vector3) -> float:
	var d := dir.normalized()
	return _phase(d, d.dot(wind_axis))

## Where the unit direction `d` (whose d . wind_axis is `a`, which the caller
## has already) lies in the dune waves, in waves: its distance round the world
## from the wind axis's pole, in DUNE_WAVEs, so the crests are level lines of
## d . wind_axis a true DUNE_WAVE apart at every latitude; growing toward the
## pole, the way the wind blows; warped by up to DUNE_WARP waves so they turn
## across the world. The warp's slope stays well under one wave per DUNE_WAVE,
## so the ridges never fold back. The dunes' heights (written out there),
## their colours and wind_at all use it.
func _phase(d: Vector3, a: float) -> float:
	return -radius * acos(clampf(a, -1.0, 1.0)) / DUNE_WAVE \
		+ DUNE_WARP * _wind.get_noise_3dv(d * (radius / DUNE_TURN))

## How much of a tower stands at `d`, whose continent layer is `z`: 1 on its
## top, 0 off it. Towers stand in the band below the mesa line and merge into
## the first terrace above it, shorter toward the band's floor.
func _tower(d: Vector3, z: float) -> float:
	var floor_z := MESA_FROM - TOWER_BAND
	if z < floor_z or z >= MESA_FROM + MESA_STEP:
		return 0.0
	return _tower_stand(d) * smoothstep(floor_z, floor_z + TOWER_BAND * 0.25, z)

## How much of a tower stands at the unit direction `d` by its cells alone,
## wherever it may stand: 1 on its top, 0 off it. Today's towers (_tower) and
## a planned plateau's (_terraces) both stand on it. The cells are laid out
## flat on each cube face in equal angles, so the towers keep their size, and a
## face is a whole number of cells across: every tower lies inside its own cell
## (TOWER_JITTER), and so inside its face, and none is cut. (The face is worked
## out here rather than through CubeSphere: this runs per height.)
func _tower_stand(d: Vector3) -> float:
	# The cube face `d` lies on, and its two angles across that face.
	var a := d.abs()
	var face := 0.0
	var x: float
	var y: float
	if a.x >= a.y and a.x >= a.z:
		face = 0.0 if d.x > 0.0 else 1.0
		x = atan(d.y / a.x)
		y = atan(d.z / a.x)
	elif a.y >= a.z:
		face = 2.0 if d.y > 0.0 else 3.0
		x = atan(d.x / a.y)
		y = atan(d.z / a.y)
	else:
		face = 4.0 if d.z > 0.0 else 5.0
		x = atan(d.x / a.z)
		y = atan(d.y / a.z)
	x = x * _tower_scale + face * TOWER_FACE_CELLS
	y *= _tower_scale
	var cell := (_tower_cell.get_noise_2d(x, y) + 1.0) * 0.5
	if cell >= TOWER_SHARE:
		return 0.0
	var r := lerpf(TOWER_RADIUS.x, TOWER_RADIUS.y, cell / TOWER_SHARE)
	var gap := (_tower_gap.get_noise_2d(x, y) + 1.0) * radius / _tower_scale
	return clampf((r * TOWER_FOOT - gap) / (r * (TOWER_FOOT - 1.0)), 0.0, 1.0)

## A desert's colours: mesa tops ground_high, their risers and the towers
## rock, a standing dune's lee face (crest to trough) dust, the rest of the
## sand ground_low. Steep ground is rock before this is asked.
func _desert_ground(d: Vector3) -> StringName:
	var z := _mesa_continent(d, _continents.get_noise_3dv(d * CONTINENT_SCALE))
	if z >= MESA_FROM:
		var t := (z - MESA_FROM) / MESA_STEP
		if t < TERRACES and fposmod(t, 1.0) < 1.0 - MESA_FLAT:
			return &"rock"
		return &"ground_high"
	if z >= MESA_FROM - TOWER_BAND and _tower(d, z) > 0.0:
		return &"rock"
	var a := d.dot(wind_axis)
	if _dune_stand(a, z) >= DUST_STAND and fposmod(_phase(d, a), 1.0) > _CREST:
		return &"dust"
	return &"ground_low"

func _simplex(concern: StringName, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = WorldSeed.noise_seed(WorldSeed.sub(recipe.seed, concern))
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 1.0
	n.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	n.fractal_octaves = octaves
	return n

func _cells(returns: FastNoiseLite.CellularReturnType) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = WorldSeed.noise_seed(WorldSeed.sub(recipe.seed, &"towers"))
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	n.cellular_return_type = returns
	n.cellular_jitter = TOWER_JITTER
	n.frequency = 1.0
	n.fractal_type = FastNoiseLite.FRACTAL_NONE
	return n

## Every crater's bowl and rim at `d`.
func _crater(d: Vector3) -> float:
	var out := 0.0
	for c: Array in craters:
		var t := d.angle_to(c[0]) / float(c[1])
		if t >= 1.0:
			continue
		if t < CRATER_FLOOR:
			var k := t / CRATER_FLOOR
			out -= CRATER_DEPTH * (1.0 - k * k)
		else:
			out += CRATER_RIM * sin(PI * (t - CRATER_FLOOR) / (1.0 - CRATER_FLOOR))
	return out

static func _direction(rng: RandomNumberGenerator) -> Vector3:
	while true:
		var v := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		if v.length() > 0.2 and v.length() <= 1.0:
			return v.normalized()
	return Vector3.UP
