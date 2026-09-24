class_name AsteroidBody
extends RigidBody3D

## One rock you can touch (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §7.3): put exactly where its picture was, asleep until something hits it,
## then as heavy as it looks. Pooled: the bubble hands one node rock after rock.

const LAYER := 64
## The hull, the avatar, items and other rocks.
const MASK := 1 | 4 | 32 | 64
## Past this the solver gains nothing but trouble: a rock this heavy is a wall
## to anything that can hit it.
const MASS_CAP := 1.0e8
## Moved this far, or turned this much, from where it was put: adrift.
const MOVE := 0.01
const TURN := deg_to_rad(0.5)

static var _surface: PhysicsMaterial

var rock: AsteroidRock
var adrift := false
## Seconds out of every anchor's reach, while untouched.
var outside_for := 0.0

var _shape: CollisionShape3D
var _look: MeshInstance3D

func _init() -> void:
	collision_layer = LAYER
	collision_mask = MASK
	can_sleep = true
	gravity_scale = 0.0
	if _surface == null:
		_surface = PhysicsMaterial.new()
		_surface.friction = 0.6
		_surface.bounce = 0.2
	physics_material_override = _surface
	# Its shape comes with its rock, in setup: the physics server refuses a
	# convex shape with no points.
	_shape = CollisionShape3D.new()
	add_child(_shape)
	_look = MeshInstance3D.new()
	_look.layers = 1
	add_child(_look)
	add_to_group(Universe.EXTERIOR_SPACE)

## Becomes `p_rock`: its shape and mesh at its size, its mass, at rest.
func setup(p_rock: AsteroidRock, mesh: Mesh, material: Material, points: PackedVector3Array) -> void:
	rock = p_rock
	var id := rock.id()
	name = "Rock_%d_%d_%d_%d" % [id.x, id.y, id.z, id.w]
	adrift = false
	outside_for = 0.0
	mass = minf(rock.mass, MASS_CAP)
	continuous_cd = rock.tier == AsteroidRecipe.Tier.RUBBLE
	var scaled := PackedVector3Array()
	for p in points:
		scaled.append(p * rock.size)
	var hull := ConvexPolygonShape3D.new()
	hull.points = scaled
	_shape.shape = hull
	_look.mesh = mesh
	_look.material_override = material
	_look.transform = Transform3D(Basis.from_scale(rock.size), Vector3.ZERO)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

## True once it has moved or turned off the spot it was put on.
func moved_from(home: Transform3D) -> bool:
	if global_position.distance_to(home.origin) > MOVE:
		return true
	var turned := home.basis.get_rotation_quaternion().inverse() * global_basis.get_rotation_quaternion()
	return turned.get_angle() > TURN
