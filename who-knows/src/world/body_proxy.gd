class_name BodyProxy
extends Node3D

## One star, planet or moon as you see it (the system skeleton spec §7): at
## at its true place and size when within PROXY_AT of the focus, and beyond that
## along the same direction at PROXY_AT, scaled so its angular size is exact.
## From the cockpit it looks just as the real thing would, and no camera needs
## to see further than the rocks already make it.
##
## Up close it swaps its 320-face look for a 5,120-face one and grows a convex
## collider on the `terrain` layer, exactly the shell you see: you bump off it.
## Planetfall replaces both with terrain.
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
## Within this of its surface, a body is drawn in detail and is solid.
const NEAR_WITHIN := 6000.0
## ... and it stops being so this much farther out.
const NEAR_HYSTERESIS := 500.0
## The far and near looks cross-fade over this, by the built-in visibility
## ranges.
const FADE_MARGIN := 500.0
## Within this of its surface it casts shadows; beyond, shadows reach nothing.
const SHADOW_WITHIN := AsteroidStream.SHADOW_REACH

var body: SystemBody
## How far the focus is from its centre, as of the last place().
var distance := INF

var _far: MeshInstance3D
var _near: MeshInstance3D
var _collider: StaticBody3D

func setup(p_body: SystemBody) -> void:
	body = p_body
	name = String(body.id).replace(".", "_")
	add_to_group(Universe.EXTERIOR_SPACE)
	var star := body.kind == SystemBody.Kind.STAR
	_far = _look(BodyLook.STAR_DETAIL if star else BodyLook.FAR_DETAIL, star)
	_far.name = "Far"
	if not star:
		_far.visibility_range_begin = body.radius + NEAR_WITHIN - FADE_MARGIN
		_far.visibility_range_begin_margin = FADE_MARGIN
		_far.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
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
	var at := placement(body.point, focus, universe)
	distance = body.point.minus(focus).length()
	var s: float = at[1]
	global_transform = Transform3D(Basis.from_scale(Vector3.ONE * s), at[0])
	if body.kind == SystemBody.Kind.STAR:
		return
	var height := distance - body.radius
	if height < NEAR_WITHIN and _near == null:
		_make_near()
	elif height > NEAR_WITHIN + NEAR_HYSTERESIS and _near != null:
		_drop_near()
	var shadows := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if height < SHADOW_WITHIN \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_far.cast_shadow = shadows
	if _near != null:
		_near.cast_shadow = shadows

## True while it is drawn in detail and solid.
func is_near() -> bool:
	return _near != null

func collider() -> StaticBody3D:
	return _collider

func _look(detail: int, star: bool) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = BodyLook.mesh(body, detail)
	m.material_override = BodyLook.material(star)
	m.scale = Vector3.ONE * body.radius
	m.layers = 1
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m

func _make_near() -> void:
	_near = _look(BodyLook.NEAR_DETAIL, false)
	_near.name = "Near"
	_near.visibility_range_end = body.radius + NEAR_WITHIN + FADE_MARGIN
	_near.visibility_range_end_margin = FADE_MARGIN
	_near.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(_near)
	_collider = StaticBody3D.new()
	_collider.name = "Shell"
	_collider.collision_layer = LAYER
	_collider.collision_mask = 0
	var shape := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for p in BodyLook.points(BodyLook.NEAR_DETAIL):
		points.append(p * body.radius)
	hull.points = points
	shape.shape = hull
	_collider.add_child(shape)
	add_child(_collider)

func _drop_near() -> void:
	_near.queue_free()
	_near = null
	_collider.queue_free()
	_collider = null
