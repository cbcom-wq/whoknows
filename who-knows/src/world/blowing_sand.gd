class_name BlowingSand
extends GPUParticles3D

## Blowing sand (the desert world spec §7.3; phase 2 plan, call 10): thin pale
## streaks of sand close to you, on foot and flying low, over a desert's
## ground, blowing along the world's wind (WorldTerrain.wind_at). Full in
## thick air below SAND_LOW over the ground, thinning to nothing by SAND_TOP,
## never off a desert or in air under SAND_AIR (strength()).
##
## One emitter for the whole system, made by StarSystem beside SpaceDust and
## fed by Whereabouts. Each physics tick it sets how many streaks blow
## (amount_ratio), and lays the slab they are born in -- SAND_BOX, as a disc
## SAND_BOX.x across and SAND_BOX.y thick, the only emission shape the engine
## can turn -- turned to the local up, its middle on the ground under the
## focus, with the streaks flying along the wind. On foot that is the focus
## itself; flying low the sand stays on the ground below you, not round the
## hull. Half of it is under the ground there, but the ground under a dune's
## slope 30 m off is metres above or below yours, and the half above reaches
## no higher than SAND_BOX.y / 2: a slab resting on the ground drew streaks
## overhead, against the sky (Task 6's render).
##
## The floating origin (CLAUDE.md): a member of Universe.EXTERIOR_SPACE whose
## parent never moves, with local_coords, so the shift carries the node and
## its live streaks together, and the slab, set relative to the node, is the
## same after a shift. It is NOT in Universe.HOLDS_SHIFT: an emitter that never
## stops would hold the origin back until the forced shift (the plan's
## ruling). The node itself is put onto the focus only when the sand starts,
## or once you are SAND_RECENTRE from it, so the streaks never jump as you go.
##
## Transparent and close to the camera (style guide §2.6): kept to
## SAND_AMOUNT thin quads, faded out within FADE_WHOLE of the eye. Its one
## colour is the desert palette's `streak`; the fade over a streak's life is
## its alpha only. No shader (§3.9).

## No sand in air thinner than this.
const SAND_AIR := 0.3
## At SAND_AIR the sand blows at this share of its full strength, rising to
## full in the thickest air.
const SAND_AIR_LEAST := 0.4
## Full at or below this many metres over the ground; gone at or above
## SAND_TOP, smoothly between (the focus's altitude).
const SAND_LOW := 15.0
const SAND_TOP := 60.0
## The slab streaks are born in round the focus, metres: across, thick, across.
const SAND_BOX := Vector3(60.0, 6.0, 60.0)
## How fast a streak flies along the wind, m/s.
const SAND_SPEED := Vector2(8.0, 14.0)
## The node is put back onto the focus once the focus is this far from it, m.
const SAND_RECENTRE := 8000.0
const SAND_AMOUNT := 160
## A streak's life, seconds.
const SAND_LIFE := Vector2(1.2, 2.0)
## A streak's size, metres: SAND_WIDTH at its longest, SAND_LENGTH long (a
## shorter one is thinner in proportion).
const SAND_WIDTH := 0.05
const SAND_LENGTH := Vector2(1.5, 3.0)
## How opaque a streak is at its thickest.
const SAND_ALPHA := 0.3
## How far a streak's heading wanders off the wind, degrees.
const SAND_SPREAD := 4.0
## Streaks fade out closer to the eye than FADE_WHOLE, gone by FADE_GONE:
## one blowing through your head never draws across the screen.
const FADE_GONE := 0.5
const FADE_WHOLE := 2.0
## The world's render layer, as the RCS puffs: what the canopy camera sees.
const LAYER := 1

var whereabouts: Whereabouts
var universe: Universe

func _init() -> void:
	name = "BlowingSand"
	amount = SAND_AMOUNT
	lifetime = SAND_LIFE.y
	local_coords = true
	emitting = false
	amount_ratio = 0.0
	layers = LAYER
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	draw_pass_1 = streak_mesh()
	process_material = _process_material()
	add_to_group(Universe.EXTERIOR_SPACE)

func setup(p_whereabouts: Whereabouts, p_universe: Universe) -> void:
	whereabouts = p_whereabouts
	universe = p_universe

## How strongly sand blows, 0 to 1: on a `desert`, in `air` of SAND_AIR or
## more, at `altitude` metres over its ground. Pure.
static func strength(desert: bool, air: float, altitude: float) -> float:
	if not desert or air < SAND_AIR:
		return 0.0
	var low := 1.0 - smoothstep(SAND_LOW, SAND_TOP, altitude)
	return low * lerpf(SAND_AIR_LEAST, 1.0, clampf(inverse_lerp(SAND_AIR, 1.0, air), 0.0, 1.0))

func _physics_process(_delta: float) -> void:
	tick()

## Sets how much sand blows, and where and which way, for the focus now.
func tick() -> void:
	var terrain := _desert_here()
	var altitude := INF
	var ratio := 0.0
	if terrain != null:
		altitude = whereabouts.altitude()
		ratio = strength(true, whereabouts.air(), altitude)
	if ratio <= 0.0:
		if emitting or amount_ratio != 0.0:
			amount_ratio = 0.0
			emitting = false
		return
	var focus := universe.focus.global_position
	amount_ratio = ratio
	if not emitting or focus.distance_to(global_position) > SAND_RECENTRE:
		global_transform = Transform3D(Basis.IDENTITY, focus)
		restart()
	emitting = true
	_lay(focus, whereabouts.up(), altitude, terrain)

## The desert's ground under the focus, or null off a desert (and with no
## focus, or no well).
func _desert_here() -> WorldTerrain:
	if whereabouts == null or universe == null or not is_instance_valid(universe.focus) \
			or not universe.focus.is_inside_tree():
		return null
	var body := whereabouts.well()
	if body == null:
		return null
	var terrain := whereabouts.terrain_of(body)
	if terrain == null or terrain.archetype != WorldRecipe.Archetype.DUNES:
		return null
	return terrain

## Lays the slab's middle on the ground under `focus` (engine space),
## `altitude` over it, turned to `up`, the streaks flying along the wind there.
func _lay(focus: Vector3, up: Vector3, altitude: float, terrain: WorldTerrain) -> void:
	var wind := terrain.wind_at(up)
	if wind.is_zero_approx():
		wind = up.cross(Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT).normalized()
	var to_node := global_basis.inverse()
	var m := process_material as ParticleProcessMaterial
	var middle := to_local(focus - up * altitude)
	m.emission_shape_offset = middle
	m.emission_ring_axis = (to_node * up).normalized()
	m.direction = (to_node * wind).normalized()
	# The slab, a streak's whole flight and its length, round the middle.
	var reach := SAND_BOX.x * 0.5 + SAND_SPEED.y * SAND_LIFE.y + SAND_LENGTH.y
	visibility_aabb = AABB(middle - Vector3.ONE * reach, Vector3.ONE * reach * 2.0)

## One streak: a thin quad in the desert's streak colour, unshaded, see-through
## and depth-tested, its alpha from each particle's (the fade).
static func streak_mesh() -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(SAND_WIDTH, SAND_LENGTH.y)
	var look := StandardMaterial3D.new()
	var colour: Color = SpacePalette.WORLDS[SpacePalette.DESERT_PALETTE][&"streak"]
	colour.a = SAND_ALPHA
	look.albedo_color = colour
	look.vertex_color_use_as_albedo = true
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.cull_mode = BaseMaterial3D.CULL_DISABLED
	look.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	look.distance_fade_min_distance = FADE_GONE
	look.distance_fade_max_distance = FADE_WHOLE
	mesh.material = look
	return mesh

## Streaks born in a disc, flying straight along `direction` (set each tick),
## their long side along their flight, fading in and out over their life.
static func _process_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	m.emission_ring_radius = SAND_BOX.x * 0.5
	m.emission_ring_inner_radius = 0.0
	m.emission_ring_height = SAND_BOX.y
	m.emission_ring_cone_angle = 90.0
	m.emission_ring_axis = Vector3.UP
	m.direction = Vector3.FORWARD
	m.spread = SAND_SPREAD
	m.initial_velocity_min = SAND_SPEED.x
	m.initial_velocity_max = SAND_SPEED.y
	m.gravity = Vector3.ZERO
	m.particle_flag_align_y = true
	m.lifetime_randomness = 1.0 - SAND_LIFE.x / SAND_LIFE.y
	m.scale_min = SAND_LENGTH.x / SAND_LENGTH.y
	m.scale_max = 1.0
	m.alpha_curve = _fade()
	return m

## Clear at birth and death, whole between.
static func _fade() -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.0))
	c.add_point(Vector2(0.2, 1.0))
	c.add_point(Vector2(0.7, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	var tex := CurveTexture.new()
	tex.curve = c
	return tex
