class_name BodyProxy
extends Node3D

## One star, planet or moon as you see it (the system skeleton spec §7): at
## its true place and size when within PROXY_AT of the focus, and beyond that
## along the same direction at PROXY_AT, scaled so its angular size is exact.
## From the cockpit it looks just as the real thing would, and no camera needs
## to see further than the rocks already make it.
##
## Within surface_at() of its centre a world is drawn by its WorldSurface, at
## its true place, and the far mesh gives way (the world scale spec §5.1). The
## surface is this proxy's sibling, under the same parent that never moves.
## The surface's own collision makes it solid where anything touches it (§5.5).
##
## The floating origin (CLAUDE.md): a member of Universe.EXTERIOR_SPACE whose
## parent never moves, placed afresh every physics tick from its
## UniversePoint.

## Beyond the giant rocks' fade and inside VIEW_FAR: a body farther than this
## is drawn here, along its true direction, scaled to its true angular size.
const PROXY_AT := 350000.0
## The cameras' far plane outside (the world scale spec §5.2). It must hold
## every proxy whole: its centre at PROXY_AT plus its drawn radius, which just
## past PROXY_AT is nearly the body's true one, at most the star's full radius
## (a proxy poking past the far plane is clipped away almost entirely). It
## must also hold a world's horizon, about 120 km from its warp limit.
## Godot 4.5's Forward+ draws with reversed depth, so this far costs no
## precision up close.
const VIEW_FAR := PROXY_AT + SystemRecipe.STAR_RADIUS.y + 50000.0
## Physics layer 4, `terrain` (Planetfall §4.2).
const LAYER := 8
## The far and near looks cross-fade over this, by the built-in visibility
## ranges.
const FADE_MARGIN := 500.0
## Within SURFACE_RADII radii of its centre, and never beyond SURFACE_MOST
## (inside the far plane), a world is drawn by its surface; it goes back to
## its far mesh SURFACE_HYSTERESIS times farther out.
const SURFACE_RADII := 10.0
const SURFACE_MOST := 300000.0
const SURFACE_HYSTERESIS := 1.1
## Within this of its surface it casts shadows; beyond, shadows reach nothing.
const SHADOW_WITHIN := AsteroidStream.SHADOW_REACH

var body: SystemBody
## How far the focus is from its centre, as of the last place().
var distance := INF
## While a warp carries you no surface starts (the world scale spec §5.1): a
## synchronous first build mid-warp would be a hitch, for a world gone in a
## second.
var frozen := false

var _universe: Universe
var _surface: WorldSurface
var _far: MeshInstance3D

func setup(p_body: SystemBody) -> void:
	body = p_body
	name = String(body.id).replace(".", "_")
	add_to_group(Universe.EXTERIOR_SPACE)
	var star := body.kind == SystemBody.Kind.STAR
	_far = _look(BodyLook.STAR_DETAIL if star else BodyLook.FAR_DETAIL, star)
	_far.name = "Far"
	add_child(_far)
	if body.ring != null:
		var ring := RingLook.new()
		ring.setup(body)
		add_child(ring)

## Where the proxy goes and how big it is drawn, for a body at `point` seen
## from `focus`: [engine position, scale].
static func placement(point: UniversePoint, focus: UniversePoint, universe: Universe) -> Array:
	var off := point.minus(focus)
	var d := off.length()
	if d <= PROXY_AT:
		return [universe.to_engine(point), 1.0]
	var s := PROXY_AT / d
	return [universe.to_engine(focus) + off * s, s]

## Places it for `focus`, and swaps its look, collider and shadows for how
## near that is.
func place(universe: Universe, focus: UniversePoint) -> void:
	_universe = universe
	var at := placement(body.point, focus, universe)
	distance = body.point.minus(focus).length()
	var s: float = at[1]
	global_transform = Transform3D(Basis.from_scale(Vector3.ONE * s), at[0])
	if body.kind == SystemBody.Kind.STAR:
		return
	if distance < surface_at() and _surface == null and not frozen:
		_make_surface()
	elif distance > surface_at() * SURFACE_HYSTERESIS and _surface != null:
		_drop_surface()
	if _surface != null:
		_surface.update(focus)
	_far.visible = _surface == null
	var height := distance - body.radius
	_far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if height < SHADOW_WITHIN \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Where the surface takes over, metres from the centre.
func surface_at() -> float:
	return minf(body.radius * SURFACE_RADII, SURFACE_MOST)

## Its surface while it is near, else null.
func surface() -> WorldSurface:
	return _surface

func _look(detail: int, star: bool) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = BodyLook.mesh(body, detail)
	m.material_override = BodyLook.material(star)
	m.scale = Vector3.ONE * body.radius
	m.layers = 1
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m

func _make_surface() -> void:
	_surface = WorldSurface.new()
	_surface.setup(body, _universe)
	get_parent().add_child(_surface)
	_surface.build_roots()

func _drop_surface() -> void:
	_surface.queue_free()
	_surface = null

func _exit_tree() -> void:
	if _surface != null:
		_surface.queue_free()
		_surface = null
