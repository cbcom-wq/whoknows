class_name ThrusterFlame
extends RefCounted

## The exhaust flame behind a thruster, and how big it is at a given throttle.
##
## One mesh serves every flame on every ship: a chunky low-poly plume with a
## hot inner core, pointing along +Z from the nozzle. It is authored at the
## largest flame, which no throttle quite reaches, in nozzle radii.
## ExteriorBuilder places one per nozzle and scales it by that radius, and
## thruster_flame.gdshader shrinks it to the size `size_for()` gives, read from
## the instance's custom data. The shader only ever shrinks it, so the flame
## never leaves the bounds that culling sees.

const MATERIAL: ShaderMaterial = preload("res://data/materials/thruster_flame.tres")

## The largest flame, in nozzle radii. Width is at the nozzle; the plume
## bulges past it (BULGE).
const MAX_LENGTH := 9.0
const MAX_WIDTH := 1.0
## The inner core, as a fraction of the plume around it.
const CORE_LENGTH := 0.55
const CORE_WIDTH := 0.5
## How fast the flame grows with throttle. Width saturates early, so a flame is
## soon as wide as its nozzle, while length keeps growing on into boost: full
## throttle is 59% of the largest flame's length (3.7 m on a 0.7 m nozzle),
## boost 90% (5.6 m).
const LENGTH_RATE := 0.9
const WIDTH_RATE := 2.5
## The plume's profile: radius goes as (1 - along)^TAPER * (1 + BULGE * along).
## A cone with a shoulder: it swells an eighth wider than the nozzle a third of
## the way out -- so even seen straight up the exhaust, as the chase camera
## does, it haloes past the bell's rim -- then tapers to a rounded tip.
const TAPER := 0.7
const BULGE := 1.5
const SIDES := 10
const RINGS := 6

static var _mesh: ArrayMesh

## Length and width as fractions of the largest flame. Zero at zero throttle,
## and it never reaches one however hard the engine pushes.
static func size_for(throttle: float) -> Vector2:
	var t := maxf(throttle, 0.0)
	return Vector2(1.0 - exp(-LENGTH_RATE * t), 1.0 - exp(-WIDTH_RATE * t))

static func mesh() -> ArrayMesh:
	if _mesh == null:
		_mesh = _build()
	return _mesh

static func _build() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_shell(st, MAX_LENGTH, MAX_WIDTH, 0.0)
	_add_shell(st, MAX_LENGTH * CORE_LENGTH, MAX_WIDTH * CORE_WIDTH, 1.0)
	var built := st.commit()
	built.surface_set_material(0, MATERIAL)
	return built

## One shell, open at the nozzle and closed at its tip. UV.x says which shell
## a vertex is on (0 the plume, 1 the core), UV.y how far along it (0 at the
## nozzle, 1 at the tip). The shader shades from both.
static func _add_shell(st: SurfaceTool, length: float, width: float, core: float) -> void:
	for ring in RINGS:
		var u0 := float(ring) / RINGS
		var u1 := float(ring + 1) / RINGS
		for side in SIDES:
			var a0 := TAU * side / SIDES
			var a1 := TAU * (side + 1) / SIDES
			# Clockwise seen from outside, which Godot draws as the front.
			for corner in [[u0, a0], [u1, a0], [u0, a1], [u1, a0], [u1, a1], [u0, a1]]:
				_add_vertex(st, corner[0], corner[1], length, width, core)

static func _add_vertex(st: SurfaceTool, along: float, angle: float, length: float,
		width: float, core: float) -> void:
	var radius := width * pow(1.0 - along, TAPER) * (1.0 + BULGE * along)
	var normal := Vector3(0, 0, 1)
	if along < 1.0:
		# Outward normal of a surface of revolution: the radial direction,
		# tipped along Z against the way the radius changes down the length.
		var shrink := width * pow(1.0 - along, TAPER - 1.0) \
			* (TAPER * (1.0 + BULGE * along) - BULGE * (1.0 - along))
		normal = Vector3(cos(angle), sin(angle), shrink / length).normalized()
	st.set_normal(normal)
	st.set_uv(Vector2(core, along))
	st.add_vertex(Vector3(cos(angle) * radius, sin(angle) * radius, along * length))
