class_name DelverLook
extends Node3D

## The delver as you see it (docs/superpowers/specs/
## 2026-10-10-rock-creatures-design.md §5, §9): a 3 m armoured worm -- six chunky
## plates, each a bevelled hexagon that steps up toward the tail like a
## pangolin's, trailing a blunt head with two pale eyes and a snout of lavender
## crystal, a lavender crystal standing on each plate. No legs: it
## crawls on its belly and goes under the ground. Plates in the scrap colours
## (not its rock's, so it reads against any ground), alternating light and
## dark so the segments show from afar. Eating brightens the snout to the
## crystal's brightest step. Surfacing plays a ring of vapour puffs round the
## body, made in the look's own space (so the floating origin and the rock's
## own never leave them behind). Flat-shaded, no texture, colours from
## SpacePalette only; it fades in with distance as the rocks do. Silent. At
## most 300 triangles.

## Built at the species' size: 3 m long, 0.4 m high, 0.5 m wide. The head is at
## -z (where it goes), the tail at +z; its origin is on the ground at the middle.
const LENGTH := 3.0
const PLATES := 6
## The plates' two colours, taken as scree (the palette's dark step), so the
## creature is darker than the ground it crawls on: they alternate along the
## body, so the segments band from afar. (Scree is as dark as the palette goes:
## about 0.7 of the ground on screen. What stands out from afar is the crystal.)
const PLATE_A := SpacePalette.UMBER
const PLATE_B := SpacePalette.RUST
## The head is RUST, as plate B is but at the head's own shade (not scree), so it
## is lighter than the plates and reads as a head.
const HEAD := SpacePalette.RUST
## The snout's tip, z, and the length of its long crystal along its (slightly
## raised) axis, which reaches the tip from the head's face; and the head's own
## front and back.
const SNOUT_TIP := -1.5
const SNOUT_LENGTH := 0.465
const HEAD_FRONT := -1.06
const HEAD_BACK := -0.55
## A plate's pitch along the body, its length, and its gap to the next.
const PLATE_FIRST := -0.55
const PLATE_PITCH := 0.34
const PLATE_LENGTH := 0.33
## Half-width at the ground of the first plate and of the last; height of the
## rear edge of the first and the last. A plate's front edge is FRONT_LOW of its
## rear edge's height, so its top slopes up toward the tail.
const HALF_WIDTH := Vector2(0.25, 0.16)
const HEIGHT := Vector2(0.26, 0.19)
const FRONT_LOW := 0.7
## The hexagon's shoulder: how high up the side it is, and how far in the top
## edge is, as shares of the plate's height and half-width.
const SHOULDER := Vector2(0.55, 0.94)
const TOP_IN := 0.58
## The crystal on each plate's back: its height (alternate plates a little
## shorter), its base half-width, and how far it leans toward the tail.
const SPIKE_HEIGHT := 0.16
const SPIKE_SHORT := 0.75
const SPIKE_HALF := 0.06
const SPIKE_LEAN := 0.3
## The head's height at its back and front, and half-width at its back and front.
const HEAD_HEIGHT := Vector2(0.32, 0.2)
const HEAD_HALF := Vector2(0.21, 0.15)
## The eyes: how far back from the head's front, how high, how big.
const EYE_BACK := 0.14
const EYE_HEIGHT := 0.2
const EYE_SIZE := Vector2(0.07, 0.045)
## Puffs in the ring on surfacing, how long they last, how far out they go.
const PUFFS := 10
const PUFF_TIME := 1.4
const PUFF_OUT := 0.9
## The ring of puffs: half its width and half its length, metres.
const RING := Vector2(0.7, 1.9)

var action: StringName = &""
var fade := Vector2(180, 230)
var _snout: MeshInstance3D
var _resting: ArrayMesh
var _eating: ArrayMesh

## Builds it. `variety` picks which colour the banding starts with. Its colours
## are the scrap palette whatever its rock: `colour` is the rock's, which it does
## not borrow.
func build(variety: float, _colour: Color, p_fade: Vector2) -> void:
	fade = p_fade
	var material := _material()
	_part("Plates", plates_mesh(variety), material)
	_part("Crest", crest_mesh(), material)
	_part("Head", head_mesh(), material)
	_resting = snout_mesh(false)
	_eating = snout_mesh(true)
	_snout = _part("Snout", _resting, material)

func _part(part_name: String, mesh: ArrayMesh, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = mesh
	mi.material_override = material
	add_child(mi)
	return mi

func _material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = SpacePalette.UNTINTED
	m.roughness = 1.0
	if fade.y > 0.0:
		# Reversed (min beyond max): whole within fade.x, gone past fade.y.
		m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
		m.distance_fade_min_distance = fade.y
		m.distance_fade_max_distance = fade.x
	return m

## What it is doing: &"eat" brightens the snout, anything else and it dims;
## &"emerge" puffs a ring (every time: it comes up again and again).
func act(p_action: StringName) -> void:
	if p_action == &"emerge":
		puff_ring()
		action = p_action
		return
	if p_action == action:
		return
	action = p_action
	_snout.mesh = _eating if p_action == &"eat" else _resting

## The ring of vapour puffs, round the body at the ground, each drifting out and
## fading. Children of the look, in its space: nothing in the world's.
func puff_ring() -> void:
	if not is_inside_tree():
		return
	var mesh := Puffs.mesh(false)
	for i in PUFFS:
		var a := TAU * (i + 0.5) / float(PUFFS)
		var out := Vector3(sin(a) * RING.x, 0.0, cos(a) * RING.y)
		var p := MeshInstance3D.new()
		p.name = "Puff%d" % i
		p.mesh = mesh
		p.position = out + Vector3(0, 0.12, 0)
		p.scale = Vector3.ONE * 0.35
		p.transparency = 0.3
		add_child(p)
		var drift := Vector3(sin(a), 0.0, cos(a)).normalized() * PUFF_OUT + Vector3(0, 0.35, 0)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(p, "position", p.position + drift, PUFF_TIME)
		t.tween_property(p, "scale", Vector3.ONE * 1.1, PUFF_TIME)
		t.tween_property(p, "transparency", 1.0, PUFF_TIME)
		t.chain().tween_callback(p.queue_free)

## The k'th plate's half-width and rear height, tapering toward the tail.
static func _taper(k: int) -> Vector2:
	var s := float(k) / float(PLATES - 1)
	return Vector2(lerpf(HALF_WIDTH.x, HALF_WIDTH.y, s), lerpf(HEIGHT.x, HEIGHT.y, s))

## The six points of a hexagonal section at `z`: half-width `half` at the ground,
## shoulder, top; height `height`. Left foot, left shoulder, left top, right top,
## right shoulder, right foot.
static func _section(z: float, half: float, height: float) -> Array[Vector3]:
	return [
		Vector3(-half, 0.0, z), Vector3(-half * SHOULDER.y, height * SHOULDER.x, z),
		Vector3(-half * TOP_IN, height, z), Vector3(half * TOP_IN, height, z),
		Vector3(half * SHOULDER.y, height * SHOULDER.x, z), Vector3(half, 0.0, z)]

## The plates: six bevelled hexagonal tubes in a row, a gap apart, each lower at
## its front than its rear. Banded light and dark, and each face one of the
## palette's three shades, the top lightest.
static func plates_mesh(variety: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var first := int(variety * 2.0) % 2
	for k in PLATES:
		var colour := SpacePalette.scree(PLATE_A if (k + first) % 2 == 0 else PLATE_B)
		var size := _taper(k)
		var z := PLATE_FIRST + PLATE_PITCH * k
		var front := _section(z, size.x, size.y * FRONT_LOW)
		var back := _section(z + PLATE_LENGTH, size.x, size.y)
		_tube(st, front, back, colour)
	return st.commit()

## The head: a blunt wedge in the same section, its top sloping down to the
## front, with a pale eye on each side.
static func head_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var front := _section(HEAD_FRONT, HEAD_HALF.y, HEAD_HEIGHT.y)
	var back := _section(HEAD_BACK - 0.01, HEAD_HALF.x, HEAD_HEIGHT.x)
	_tube(st, front, back, HEAD, true)
	var inside := Vector3(0, HEAD_HEIGHT.x * 0.4, (HEAD_FRONT + HEAD_BACK) * 0.5)
	# The eyes sit on the slope of each side, a hair proud of it.
	var z := HEAD_FRONT + EYE_BACK
	var along := inverse_lerp(HEAD_FRONT, HEAD_BACK, z)
	var half := lerpf(HEAD_HALF.y, HEAD_HALF.x, along)
	var height := lerpf(HEAD_HEIGHT.y, HEAD_HEIGHT.x, along)
	var low := EYE_HEIGHT - EYE_SIZE.y * 0.5
	var high := EYE_HEIGHT + EYE_SIZE.y * 0.5
	for side in [-1.0, 1.0]:
		var x_low: float = side * (_side_x(half, height, low) + 0.004)
		var x_high: float = side * (_side_x(half, height, high) + 0.004)
		var a := Vector3(x_low, low, z - EYE_SIZE.x * 0.5)
		var b := Vector3(x_low, low, z + EYE_SIZE.x * 0.5)
		var c := Vector3(x_high, high, z + EYE_SIZE.x * 0.5)
		var d := Vector3(x_high, high, z - EYE_SIZE.x * 0.5)
		_tri(st, a, b, c, SpacePalette.SKITTER_EYE, inside)
		_tri(st, a, c, d, SpacePalette.SKITTER_EYE, inside)
	return st.commit()

## How far out a section's side is at height `y`: the lower side, then the slope
## up to the top edge.
static func _side_x(half: float, height: float, y: float) -> float:
	var shoulder := height * SHOULDER.x
	if y <= shoulder:
		return lerpf(half, half * SHOULDER.y, y / shoulder)
	return lerpf(half * SHOULDER.y, half * TOP_IN, (y - shoulder) / (height - shoulder))

## The crest: a lavender crystal standing on the back of each plate, swept a
## little toward the tail, its faces the palette's two brighter steps.
static func crest_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces: Array[Color] = [SpacePalette.shade(SpacePalette.CRYSTAL, 1), SpacePalette.shade(SpacePalette.CRYSTAL, 2)]
	for k in PLATES:
		var size := _taper(k)
		var z := PLATE_FIRST + PLATE_PITCH * k + PLATE_LENGTH * 0.72
		var top := lerpf(size.y * FRONT_LOW, size.y, 0.72) - 0.01
		var tall := SPIKE_HEIGHT * (1.0 if k % 2 == 0 else SPIKE_SHORT)
		_crystal(st, Vector3(0.0, top, z), Vector3(0.0, 1.0, SPIKE_LEAN).normalized(), SPIKE_HALF, tall, faces)
	return st.commit()

## The snout: a long lavender crystal and a shorter one on each side, pointing
## forward from the head's face. `bright` is eating: the palette's brightest
## step all over, where at rest the faces alternate its two darkest.
static func snout_mesh(bright: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var brightest := SpacePalette.SHADES.size() - 1
	var faces: Array[Color] = [SpacePalette.shade(SpacePalette.CRYSTAL, brightest if bright else 0),
		SpacePalette.shade(SpacePalette.CRYSTAL, brightest if bright else 1)]
	var root := Vector3(0, 0.1, HEAD_FRONT + 0.02)
	# (base, direction, half-width, length)
	var crystals := [
		[root, Vector3(0, 0.12, -1.0), 0.1, SNOUT_LENGTH],
		[root + Vector3(-0.1, -0.03, 0.0), Vector3(-0.35, 0.05, -1.0), 0.065, 0.32],
		[root + Vector3(0.1, -0.03, 0.0), Vector3(0.35, 0.05, -1.0), 0.065, 0.32],
	]
	for c in crystals:
		_crystal(st, c[0], (c[1] as Vector3).normalized(), c[2], c[3], faces)
	return st.commit()

## A four-sided crystal from `base` along `axis`: a prism that narrows to a point
## over its last third, its faces alternating `faces`.
static func _crystal(st: SurfaceTool, base: Vector3, axis: Vector3, half: float, length: float,
		faces: Array[Color]) -> void:
	var u := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := axis.cross(u)
	var foot: Array[Vector3] = []
	var neck: Array[Vector3] = []
	for i in 4:
		var turn := u * cos(TAU * (i + 0.5) / 4.0) + v * sin(TAU * (i + 0.5) / 4.0)
		foot.append(base + turn * half)
		neck.append(base + axis * length * 0.62 + turn * half * 0.85)
	var tip := base + axis * length
	var inside := base + axis * length * 0.4
	for i in 4:
		var j := (i + 1) % 4
		_tri(st, foot[i], foot[j], neck[j], faces[i % 2], inside)
		_tri(st, foot[i], neck[j], neck[i], faces[i % 2], inside)
		_tri(st, neck[i], neck[j], tip, faces[(i + 1) % 2], inside)

## A hexagonal tube from section `front` to section `back` (both from _section),
## closed at the back (and at the front if `closed_front`) and below. Each face
## one of the three shades: the top lightest, the sides darker, the shoulders in
## between.
static func _tube(st: SurfaceTool, front: Array[Vector3], back: Array[Vector3], colour: Color,
		closed_front := false) -> void:
	var inside := Vector3.ZERO
	for p in front + back:
		inside += p
	inside /= float(front.size() + back.size())
	inside.y = 0.1
	# Left side, left shoulder, top, right shoulder, right side: darkest at the
	# ground, lightest on top.
	var shades := [0, 1, 2, 1, 0]
	for i in 5:
		var c := SpacePalette.shade(colour, shades[i])
		_tri(st, front[i], front[i + 1], back[i + 1], c, inside)
		_tri(st, front[i], back[i + 1], back[i], c, inside)
	var floor_c := SpacePalette.scree(colour)
	_tri(st, front[0], front[5], back[5], floor_c, inside)
	_tri(st, front[0], back[5], back[0], floor_c, inside)
	_cap(st, back, SpacePalette.shade(colour, 0), inside)
	if closed_front:
		_cap(st, front, SpacePalette.shade(colour, 1), inside)

## A section's hexagon, filled, as a fan.
static func _cap(st: SurfaceTool, ring: Array[Vector3], colour: Color, inside: Vector3) -> void:
	for i in range(1, 5):
		_tri(st, ring[0], ring[i], ring[i + 1], colour, inside)

## A triangle facing away from `inside`. Godot's front faces wind clockwise
## seen from the front.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, colour: Color, inside: Vector3) -> void:
	var n := (c - a).cross(b - a).normalized()
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	for p in [a, b, c]:
		st.set_color(colour)
		st.set_normal(n)
		st.add_vertex(p)
