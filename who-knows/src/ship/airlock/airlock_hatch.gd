class_name AirlockHatch
extends Node3D

## An airlock hatch (docs/superpowers/specs/2026-09-24-airlock-design.md §3.3):
## two heavy leaves that part sideways into the jambs, four bolts across their
## meeting edge, a round window in the port leaf, a light strip and a warning
## lamp on the header. Solid whenever it is not fully open -- unlike a
## SlidingDoor, which is only a picture. It never opens by itself: whoever owns
## it sets open_amount and bolts_out.
##
## Knows nothing about ships. Its frame: origin at the opening's centre at
## floor level on the wall's mid-plane, +x along the wall, +z into the room it
## is seen from. InteriorProps.hatch_frame builds the fixed parts round it.

const LEAF_THICKNESS := 0.1
## How far a bolt slides from bridging the seam to clear of it.
const BOLT_TRAVEL := 0.1
const BOLT_HEIGHTS: Array[float] = [0.35, 0.8, 1.25, 1.62]
const WINDOW_HEIGHT := 1.42
const WINDOW_HOLE := 0.12
const WINDOW_RADIUS := 0.12
const WINDOW_FRAME := 0.18
const STRIPS := [&"go", &"cycling", &"vacuum"]

## Render layer for everything the hatch draws: the interior's by default, the
## own hull's for the copy on the hull (airlock spec §7.2).
var render_layer := InteriorKit.LAYER
## 0 shut .. 1 fully open.
var open_amount := 0.0: set = set_open_amount
## 0 driven home across the seam .. 1 retracted clear of it.
var bolts_out := 0.0: set = set_bolts_out
var collider: CollisionShape3D

var _width := 1.0
var _leaves: Array[Node3D] = []
var _bolts: Node3D
var _strips: Dictionary = {}   # StringName -> MeshInstance3D
var _lamps: Array[MeshInstance3D] = []

## Builds the hatch for an opening `width` by `height`, at `xf` in `body`'s
## frame -- the hatch's parent must share that frame, because its collider
## goes straight on the body. `portal_window` makes the window portal glass
## (the real outside; airlock spec §7.3), drawn with `portal_material`, or the
## kit's black fallback without one.
func setup(width: float, height: float, body: CollisionObject3D, xf: Transform3D,
		portal_window := false, portal_material: Material = null) -> void:
	_width = width
	transform = xf
	var half := width * 0.5
	for i in 2:
		var leaf := Node3D.new()
		leaf.name = "LeafPort" if i == 0 else "LeafStarboard"
		add_child(leaf)
		_leaves.append(leaf)
		var kit := _kit(leaf, portal_material)
		_leaf(kit, half, height, i == 0, portal_window)
		kit.commit()

	_bolts = Node3D.new()
	_bolts.name = "Bolts"
	_leaves[1].add_child(_bolts)
	var bolt_kit := _kit(_bolts)
	for y in BOLT_HEIGHTS:
		for face in [-1.0, 1.0]:
			bolt_kit.bevel_box(InteriorKit.Batch.SOLID,
				InteriorKit.at(Vector3(-half * 0.5, y, face * (LEAF_THICKNESS * 0.5 + 0.018))),
				Vector3(0.13, 0.05, 0.035), 0.012, InteriorKit.solid(InteriorPalette.GUNMETAL))
	bolt_kit.commit()

	var strips := {&"go": InteriorPalette.SIGNAL_GO, &"cycling": InteriorPalette.AMBER,
		&"vacuum": InteriorPalette.CORAL}
	for state: StringName in STRIPS:
		var strip_kit := _kit(self)
		for face in [-1.0, 1.0]:
			strip_kit.box(InteriorKit.Batch.GLOW, InteriorKit.at(Vector3(0, height + 0.02, face * 0.155)),
				Vector3(width * 0.8, 0.03, 0.012), InteriorKit.lit(strips[state], 2.2))
		var mesh: MeshInstance3D = strip_kit.commit()[0]
		mesh.name = "Strip_%s" % state
		_strips[state] = mesh
	for side in [-1.0, 1.0]:
		var lamp_kit := _kit(self)
		for face in [-1.0, 1.0]:
			lamp_kit.bevel_box(InteriorKit.Batch.GLOW,
				InteriorKit.at(Vector3(side * (half + 0.08), height - 0.06, face * 0.16)),
				Vector3(0.09, 0.06, 0.03), 0.01, InteriorKit.lit(InteriorPalette.AMBER, 2.4, 0.5))
		var lamp: MeshInstance3D = lamp_kit.commit()[0]
		lamp.name = "WarningLamp"
		_lamps.append(lamp)

	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, LEAF_THICKNESS + 0.02)
	collider = CollisionShape3D.new()
	collider.name = "HatchCollider"
	collider.shape = shape
	collider.transform = xf * InteriorKit.at(Vector3(0, height * 0.5, 0))
	if body != null:
		body.add_child(collider)

	set_open_amount(0.0)
	set_bolts_out(0.0)
	set_strip(&"off")
	set_warning(false)

func set_open_amount(amount: float) -> void:
	open_amount = clampf(amount, 0.0, 1.0)
	var slide := lerpf(0.25, 0.75, open_amount)
	for i in _leaves.size():
		var side := -1.0 if i == 0 else 1.0
		_leaves[i].position = Vector3(side * _width * slide, 0, 0)
	if collider != null:
		collider.disabled = is_fully_open()

func set_bolts_out(amount: float) -> void:
	bolts_out = clampf(amount, 0.0, 1.0)
	if _bolts != null:
		_bolts.position = Vector3(BOLT_TRAVEL * bolts_out, 0, 0)

func is_fully_open() -> bool:
	return open_amount >= 0.999

## Shows the strip for `state` -- &"go", &"cycling" or &"vacuum" -- or none,
## for &"off".
func set_strip(state: StringName) -> void:
	for key: StringName in _strips:
		_strips[key].visible = key == state

func set_warning(on: bool) -> void:
	for lamp in _lamps:
		lamp.visible = on

## Where the leaves are, port then starboard, along the wall.
func leaf_offsets() -> Array[float]:
	var out: Array[float] = []
	for leaf in _leaves:
		out.append(leaf.position.x)
	return out

## How far the bolts have slid from the seam.
func bolt_offset() -> float:
	return _bolts.position.x

func visible_strips() -> Array:
	var out := []
	for key: StringName in STRIPS:
		if _strips[key].visible:
			out.append(key)
	return out

func warning_shown() -> bool:
	return _lamps[0].visible

func _kit(root: Node3D, portal_material: Material = null) -> InteriorKit:
	var kit := InteriorKit.new(root, null, portal_material)
	kit.layer = render_layer
	kit.light_mask = render_layer
	return kit

## One leaf, centred on its own origin: a heavy slab in four pieces round the
## window hole on the port leaf, a coral hazard band, ribs, and the window.
static func _leaf(kit: InteriorKit, w: float, h: float, window: bool, portal: bool) -> void:
	var slab := InteriorKit.solid(InteriorPalette.WALL_LOW)
	var trim := InteriorKit.solid(InteriorPalette.TRIM)
	var t := LEAF_THICKNESS
	var inner_w := w - 0.01
	if window:
		var lo := WINDOW_HEIGHT - WINDOW_HOLE
		var hi := WINDOW_HEIGHT + WINDOW_HOLE
		kit.bevel_box(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(0, lo * 0.5, 0)), Vector3(inner_w, lo, t), 0.02, slab)
		kit.bevel_box(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(0, (hi + h) * 0.5, 0)),
			Vector3(inner_w, h - hi - 0.01, t), 0.02, slab)
		var side_w := (inner_w - WINDOW_HOLE * 2.0) * 0.5
		for side in [-1.0, 1.0]:
			kit.box(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(side * (WINDOW_HOLE + side_w * 0.5), WINDOW_HEIGHT, 0)),
				Vector3(side_w, WINDOW_HOLE * 2.0, t), slab)
		for face in [-1.0, 1.0]:
			var ring := Transform3D(Basis.IDENTITY if face > 0.0 else Basis(Vector3.UP, PI),
				Vector3(0, WINDOW_HEIGHT, face * (t * 0.5 + 0.004)))
			kit.annulus(InteriorKit.Batch.SOLID, ring, WINDOW_RADIUS - 0.005, WINDOW_FRAME, trim)
		if portal:
			kit.disc(InteriorKit.Batch.PORTAL, InteriorKit.at(Vector3(0, WINDOW_HEIGHT, 0)), WINDOW_RADIUS,
				InteriorKit.solid(InteriorPalette.GLASS))
		else:
			kit.disc(InteriorKit.Batch.GLASS, InteriorKit.at(Vector3(0, WINDOW_HEIGHT, 0)), WINDOW_RADIUS,
				InteriorPalette.GLASS)
	else:
		kit.bevel_box(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(0, h * 0.5, 0)), Vector3(inner_w, h - 0.01, t), 0.02, slab)
	for face in [-1.0, 1.0]:
		var z: float = face * (t * 0.5 + 0.005)
		kit.box(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(0, 0.95, z)), Vector3(inner_w - 0.04, 0.09, 0.012),
			InteriorKit.solid(InteriorPalette.CORAL))
		for y in [0.3, h - 0.22]:
			kit.box(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(0, y, z)), Vector3(inner_w - 0.08, 0.05, 0.012), trim)
