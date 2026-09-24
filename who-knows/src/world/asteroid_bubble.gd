class_name AsteroidBubble
extends RefCounted

## The rocks you could touch (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §7): every physics tick, rocks near the path of an anchor over the next
## LOOKAHEAD seconds become AsteroidBodies, asleep until something hits them.
## Untouched bodies turn back into pictures once you have passed; touched ones
## are adrift, and last until they are out of sight.

const PAD := 24.0
const LOOKAHEAD := 1.5
const LET_GO_AFTER := 2.0
const MAX_ADRIFT := 96

var stream: AsteroidStream
var holder: Node3D
## Adrift bodies allowed at once; over it, the farthest goes.
var max_adrift := MAX_ADRIFT
## id -> AsteroidBody
var live := {}

var _pool: Array[AsteroidBody] = []

func _init(p_stream: AsteroidStream, p_holder: Node3D) -> void:
	stream = p_stream
	holder = p_holder

func step(delta: float) -> void:
	var near := _near_paths()
	for id: Vector4i in near:
		if not live.has(id):
			_promote(near[id])
	var focus: Node3D = stream.universe.focus if stream.universe != null else null
	var adrift: Array[AsteroidBody] = []
	for id: Vector4i in live.keys():
		var body: AsteroidBody = live[id]
		if not body.adrift and body.moved_from(stream.rock_pose(body.rock)):
			body.adrift = true
		if body.adrift:
			var seen_to := AsteroidStream.FADE_END[body.rock.tier]
			if focus != null and body.global_position.distance_to(focus.global_position) > seen_to:
				_drop(id)
			else:
				adrift.append(body)
		elif near.has(id):
			body.outside_for = 0.0
		else:
			body.outside_for += delta
			if body.outside_for >= LET_GO_AFTER:
				_let_go(id)
	if adrift.size() > max_adrift and focus != null:
		var at := focus.global_position
		adrift.sort_custom(func(a: AsteroidBody, b: AsteroidBody) -> bool:
			return a.global_position.distance_squared_to(at) > b.global_position.distance_squared_to(at))
		push_warning("AsteroidBubble: %d rocks adrift, over %d: dropping the farthest" % [adrift.size(), max_adrift])
		for i in adrift.size() - max_adrift:
			_drop(adrift[i].rock.id())

## Its cell has gone: untouched bodies there go with it.
func cell_unloaded(tier: int, cell: Vector3i) -> void:
	for id: Vector4i in live.keys():
		var body: AsteroidBody = live[id]
		if body.rock.tier == tier and body.rock.cell == cell and not body.adrift:
			_release(id)

## Frees every pooled body (they are out of the tree).
func clear() -> void:
	for body in _pool:
		body.free()
	_pool.clear()

static func segment_distance(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := 0.0
	if ab.length_squared() > 1e-9:
		t = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)

## Rocks within reach of an anchor's path: id -> rock.
func _near_paths() -> Dictionary:
	var out := {}
	for node in stream.get_tree().get_nodes_in_group(AsteroidStream.SPACE_ANCHOR):
		var anchor := node as Node3D
		if anchor == null or not anchor.is_inside_tree():
			continue
		var a := anchor.global_position
		var b := a + AsteroidStream.velocity_of(anchor) * LOOKAHEAD
		var reach := PAD + float(anchor.get_meta(AsteroidStream.ANCHOR_RADIUS, 1.0))
		for tier in AsteroidRecipe.TIERS:
			var grow := reach + AsteroidRecipe.BOUND * AsteroidRecipe.D_MAX[tier] * AsteroidRecipe.STRETCH_MAX
			var box := AABB(a, Vector3.ZERO).expand(b).grow(grow)
			for rock in stream.rocks_in(tier, box):
				var id := rock.id()
				if out.has(id) or (not live.has(id) and stream.is_hidden(rock)):
					continue
				if segment_distance(stream.rock_pose(rock).origin, a, b) <= reach + rock.radius:
					out[id] = rock
	return out

func _promote(rock: AsteroidRock) -> void:
	var body: AsteroidBody = _pool.pop_back() if not _pool.is_empty() else AsteroidBody.new()
	var detail: int = AsteroidStream.DETAIL[rock.tier]
	body.setup(rock, RockMesh.mesh(rock.shape, detail), stream.rock_material(rock.tier, rock.colour),
		RockMesh.hull_points(rock.shape, detail))
	holder.add_child(body)
	body.global_transform = stream.rock_pose(rock)
	body.sleeping = true
	stream.hide_rock(rock)
	live[rock.id()] = body

## Untouched and passed: back to a picture.
func _let_go(id: Vector4i) -> void:
	var rock: AsteroidRock = live[id].rock
	_release(id)
	stream.show_rock(rock)

## Adrift and out of sight: gone. Its home stays empty while its cell is
## loaded, so no second copy appears.
func _drop(id: Vector4i) -> void:
	_release(id)

func _release(id: Vector4i) -> void:
	var body: AsteroidBody = live[id]
	live.erase(id)
	holder.remove_child(body)
	_pool.append(body)
