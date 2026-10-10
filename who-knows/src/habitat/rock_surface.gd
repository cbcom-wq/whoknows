class_name RockSurface
extends PlantSurface

## A big rock in detail as ground to plant on (habitat modules spec §5.1):
## fixed, solid as drawn (asteroids spec §18). A rock not in detail offers no
## surface.

## Rays this far round the aim, averaged, give the rock's up there.
const UP_RING := 3.0
## blocked() looks for the rock's surface this far out from a point of the box.
const BURY_FROM := 40.0

var detail: AsteroidDetail

func _init(p_detail: AsteroidDetail) -> void:
	detail = p_detail

func fixed() -> bool:
	return true

func site_id() -> StringName:
	return RockHerds.site_of(detail.rock)

func rock() -> Vector4i:
	return detail.rock.id()

func ore() -> Dictionary:
	return {"seed": hash(detail.rock.id()), "veined": detail.rock.shape == RockMesh.Shape.VEINED}

func up_at(point: Vector3) -> Vector3:
	var radial := (point - detail.global_position).normalized()
	var side := radial.cross(Vector3.UP if absf(radial.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT).normalized()
	var other := radial.cross(side)
	var sum := Vector3.ZERO
	for offset in [Vector3.ZERO, side, -side, other, -other]:
		var from: Vector3 = point + radial * 6.0 + offset * UP_RING
		var hit := cast(from, -radial, 12.0)
		if not hit.is_empty():
			sum += hit["normal"]
	return sum.normalized() if sum.length() > 0.001 else radial

func cast(from: Vector3, dir: Vector3, reach: float) -> Dictionary:
	if not detail.is_inside_tree():
		return {}
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * reach, AsteroidBody.LAYER)
	var hit := detail.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit["collider"] != detail:
		return {}
	return {"position": hit["position"], "normal": hit["normal"]}

func blocked(box: Transform3D, size: Vector3) -> bool:
	if not detail.is_inside_tree():
		return true
	var shape := BoxShape3D.new()
	shape.size = size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = box
	query.collision_mask = AsteroidBody.LAYER | 1
	if not detail.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		return true
	return _buried(box, size)

## True if the box's centre or any corner is under the rock's surface. The
## rock's collision is a one-sided mesh, so a shape query ignores a box whose
## centre is behind the surface (it is inside the rock, and the faces it
## crosses are back faces). A ray from outside down to the point does hit the
## front face first.
func _buried(box: Transform3D, size: Vector3) -> bool:
	var points: Array[Vector3] = [box.origin]
	for sx in [-0.5, 0.5]:
		for sy in [-0.5, 0.5]:
			for sz in [-0.5, 0.5]:
				points.append(box * (Vector3(sx, sy, sz) * size))
	for p in points:
		var outward := (p - detail.global_position).normalized()
		if not cast(p + outward * BURY_FROM, -outward, BURY_FROM).is_empty():
			return true
	return false
