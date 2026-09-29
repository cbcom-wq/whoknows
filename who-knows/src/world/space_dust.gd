class_name SpaceDust
extends MultiMeshInstance3D

## Dust drifting past, so even in open space you can see you are moving (the
## system skeleton spec §9): a few hundred chunky flecks in a box round the
## focus. Each has a place fixed in the universe, so flecks hold still while
## you pass them and wrap round to the far side as you leave them behind.
##
## They shrink to nothing over the box's outer edge, so the wrap never pops,
## and dither out close to the camera, so none sits on the canopy. Lit by the
## sun, in rock colours; never glowing. How many show is `density`, which
## Whereabouts sets from where you are. At warp the flecks stretch into streaks
## along the ship's velocity (the warp spec §5.2): the only streaks in space.
##
## The floating origin (CLAUDE.md): a member of Universe.EXTERIOR_SPACE whose
## parent never moves. Flecks are worked out from the focus's UniversePoint,
## so they are exact however far you go, and only once you have moved REWORK_AFTER:
## between times the node stays where it was put, and the shift moves it with
## everything else.

const COUNT := 400
## The box's edge, metres: whole metres, so a UniversePoint's own whole
## metres wrap exactly.
const BOX := 200
## Flecks shrink to nothing over this much of the box's edge.
const EDGE := 20.0
const SIZE := Vector2(0.2, 0.5)
## Gone within FADE_GONE of the camera, whole beyond FADE_WHOLE.
const FADE_GONE := 1.0
const FADE_WHOLE := 3.0
const SEED := 0x5D057
## The flecks are worked out again once the focus is this far from where
## they last were: the box drifts at most this far off centre.
const REWORK_AFTER := 20.0
## At warp each fleck stretches along `streak` (the warp spec §5.2), up to
## this many metres, against a fleck of about STREAK_BASE across.
const STREAK_MAX := 40.0
const STREAK_BASE := 0.35

## The share of COUNT drawn, 0 to 1.
var density := 0.25:
	set(value):
		density = clampf(value, 0.0, 1.0)
		if multimesh != null:
			multimesh.visible_instance_count = roundi(COUNT * density)
## Metres to stretch every fleck along, from the warp; zero for none. A
## change reworks the flecks on the next place().
var streak := Vector3.ZERO:
	set(value):
		if value != streak:
			streak = value
			_anchor = null

## Each fleck's place in the box, its turn and size, and its colour.
var _homes := PackedVector3Array()
var _shapes: Array[Basis] = []
var _colours: Array[Color] = []
var _buf := PackedFloat32Array()
## Where the flecks were last worked out for; null for never.
var _anchor: UniversePoint

static var _material: StandardMaterial3D

func _init() -> void:
	name = "SpaceDust"
	layers = 1
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material_override = material()
	add_to_group(Universe.EXTERIOR_SPACE)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for i in COUNT:
		_homes.append(Vector3(rng.randf() * BOX, rng.randf() * BOX, rng.randf() * BOX))
		var size := rng.randf_range(SIZE.x, SIZE.y)
		var turn := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
		_shapes.append(turn * Basis.from_scale(Vector3.ONE * size))
		_colours.append(SpacePalette.ROCKS[rng.randi_range(0, SpacePalette.ROCKS.size() - 1)])
	_buf.resize(COUNT * 16)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = RockMesh.mesh(RockMesh.Shape.BOULDER, 0)
	mm.instance_count = COUNT
	multimesh = mm
	density = density

## Forgets where the flecks were worked out, so the next place() does it.
func rework() -> void:
	_anchor = null

## Where fleck `home` is from the focus at `focus`, wrapped into the box
## centred on it: exact at any distance, as it uses the whole metres.
static func offset(home: Vector3, focus: UniversePoint) -> Vector3:
	var f := Vector3(posmod(focus.x, BOX) + focus.fx, posmod(focus.y, BOX) + focus.fy, posmod(focus.z, BOX) + focus.fz)
	var half := BOX * 0.5
	var rel := home - f
	return Vector3(fposmod(rel.x + half, BOX) - half, fposmod(rel.y + half, BOX) - half, fposmod(rel.z + half, BOX) - half)

## How big fleck at `rel` from the focus is drawn: shrinking to nothing over
## the box's outer EDGE.
static func edge_scale(rel: Vector3) -> float:
	var inside := BOX * 0.5 - maxf(absf(rel.x), maxf(absf(rel.y), absf(rel.z)))
	return clampf(inside / EDGE, 0.0, 1.0)

## Places the dust for `focus`: at once the first time, then only once you
## have moved REWORK_AFTER.
func place(universe: Universe, focus: UniversePoint) -> void:
	if _anchor != null and focus.minus(_anchor).length() < REWORK_AFTER:
		return
	_anchor = focus
	global_transform = Transform3D(Basis.IDENTITY, universe.to_engine(focus))
	var s := streak.limit_length(STREAK_MAX)
	var pull := Basis.IDENTITY if s.is_zero_approx() else stretch(s.normalized(), 1.0 + s.length() / STREAK_BASE)
	for i in COUNT:
		var rel := offset(_homes[i], focus)
		AsteroidStream.write(_buf, i, pull * _shapes[i] * edge_scale(rel), rel, _colours[i])
	multimesh.buffer = _buf

## Where fleck `i` is drawn, from the node: for tests.
func fleck(i: int) -> Vector3:
	var k := i * 16
	return Vector3(_buf[k + 3], _buf[k + 7], _buf[k + 11])

## The basis fleck `i` is drawn with, read back from AsteroidStream.write's
## rows: for tests.
func fleck_basis(i: int) -> Basis:
	var k := i * 16
	return Basis(Vector3(_buf[k], _buf[k + 4], _buf[k + 8]), Vector3(_buf[k + 1], _buf[k + 5], _buf[k + 9]),
		Vector3(_buf[k + 2], _buf[k + 6], _buf[k + 10]))

## Stretches by `k` along the unit `dir` only: I + (k - 1) dir dirT.
static func stretch(dir: Vector3, k: float) -> Basis:
	var a := k - 1.0
	return Basis(Vector3(1.0 + a * dir.x * dir.x, a * dir.y * dir.x, a * dir.z * dir.x),
		Vector3(a * dir.x * dir.y, 1.0 + a * dir.y * dir.y, a * dir.z * dir.y),
		Vector3(a * dir.x * dir.z, a * dir.y * dir.z, 1.0 + a * dir.z * dir.z))

## Rock colour times each fleck's instance colour, dithering out close in.
static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 1.0
		_material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
		_material.distance_fade_min_distance = FADE_GONE
		_material.distance_fade_max_distance = FADE_WHOLE
	return _material
