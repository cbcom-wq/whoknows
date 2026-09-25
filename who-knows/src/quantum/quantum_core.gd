class_name QuantumCore
extends Node3D

## The quantum core's moving parts (docs/superpowers/specs/
## 2026-09-24-quantum-energy-design.md §6.2): a faceted violet heart that turns
## and breathes, three rings turning round it, each on its own axis, and the
## gauge's ten bars up the spine. InteriorProps.quantum_core builds the fixed
## parts round it.
##
## It only shows what it is told: set_fill() for the gauge, set_state() for
## the pace, flash() when QE arrives. The plant drives it (Task 4); until then
## it can be driven by hand.
##
## Knows nothing about ships, like AirlockHatch: it takes a fixture frame
## (origin on the floor under the core, -z the way it faces) and a render
## layer. Everything it draws is kit geometry on the glow batch or the props
## material -- no new shader -- and the heart and rings are their own small
## meshes so they can turn and scale.

## Each steady state's pace: rings in revolutions a second, and the heart's
## pulse in Hz (spec §6.2's table).
const RATES := {
	&"full": Vector2(0.25, 0.5),
	&"boost": Vector2(0.75, 2.0),
	&"low_power": Vector2(0.05, 0.2),
}
## How long power restored takes to spin the rings back up to full, the heart
## flaring meanwhile (spec §8.3).
const RESTORE_TIME := 1.5
## The heart breathes by this fraction of its size either way.
const BREATH := 0.04
## How long flash() brightens the heart.
const FLASH_TIME := 0.25
## The heart turns at this share of the rings' rate.
const HEART_TURN := 0.4
const HEART_ENERGY := 1.15
const FLARE_ENERGY := 1.9
const BAR_ENERGY := 1.3
## The lowest bar lit amber at 0 is at half brightness, so the gauge never
## reads as dead.
const EMPTY_ENERGY := 0.65
const BAR_LOOKS: Array[StringName] = [&"lit", &"amber", &"amber_dim"]

## How each ring sits before it turns, and which way it turns: tilted apart so
## no two tumble together.
const _RING_TILTS: Array[Vector3] = [Vector3(0.0, 0.0, 20.0), Vector3(0.0, 60.0, 72.0), Vector3(0.0, 120.0, 46.0)]
const _RING_TURNS: Array[float] = [1.0, -1.0, 1.0]
const _RING_PHASE: Array[float] = [0.0, 1.1, 2.3]
## The direction the heart's facets are shaded from, so it reads as a cut gem
## even on the unshaded glow batch.
const _FACET_LIGHT := Vector3(0.3, 0.8, 0.5)

var state: StringName = &"full"
var heart: MeshInstance3D
var rings: Array[Node3D] = []

var _flare: MeshInstance3D
var _bars: Array[Dictionary] = []   # per bar: StringName look -> MeshInstance3D
var _rates: Vector2 = RATES[&"full"]
var _restore_from := Vector2.ZERO
var _restore_t := 0.0
var _flash_left := 0.0
var _ring_angle := 0.0
var _heart_angle := 0.0
var _pulse := 0.0
var _layer := InteriorKit.LAYER

## Builds the heart, the rings and the gauge at fixture frame `frame`, on
## render layer `layer`. Call once, before it enters the tree.
func setup(frame: Transform3D, layer: int) -> void:
	transform = frame
	_layer = layer
	heart = _heart_mesh("Heart", HEART_ENERGY)
	_flare = _heart_mesh("HeartFlare", FLARE_ENERGY)
	for i in InteriorProps.QUANTUM_RINGS.size():
		rings.append(_ring(i))
	_gauge()
	set_fill(0.5, 0.1)
	_apply()

## Lights the gauge for a store `fraction` full, whose low-power line is at
## `line_fraction`. The lowest bar is the line itself: lit whenever there is
## anything at all, AMBER when it is all that is left, and AMBER at half
## brightness at 0. The other nine share what lies above the line.
func set_fill(fraction: float, line_fraction: float) -> void:
	var line := clampf(line_fraction, 0.0, 0.99)
	var step := (1.0 - line) / float(_bars.size() - 1)
	var lit := 1
	for i in range(1, _bars.size()):
		if fraction > line + (i - 1) * step + 1e-6:
			lit = i + 1
	var lowest := &"lit"
	if fraction <= 0.0:
		lowest = &"amber_dim"
	elif lit == 1:
		lowest = &"amber"
	for i in _bars.size():
		var look: StringName = &"dark"
		if i == 0:
			look = lowest
		elif i < lit:
			look = &"lit"
		for key: StringName in _bars[i]:
			_bars[i][key].visible = key == look

## &"full", &"boost", &"low_power" or &"restoring" (spec §6.2). Restoring
## spins up from wherever the rings are to full power over RESTORE_TIME, then
## settles into &"full" by itself.
func set_state(new_state: StringName) -> void:
	if new_state == &"restoring":
		_restore_from = _rates
		_restore_t = 0.0
	elif RATES.has(new_state):
		_rates = RATES[new_state]
	else:
		return
	state = new_state
	_apply()

## A short brightening of the heart, when QE arrives.
func flash() -> void:
	_flash_left = FLASH_TIME
	_apply()

## The crown's centre, in the parent's space: where a conduit ends.
func crown() -> Vector3:
	return transform * InteriorProps.quantum_core_crown()

func lit_bars() -> int:
	var n := 0
	for bar in _bars:
		for key: StringName in BAR_LOOKS:
			if bar.has(key) and bar[key].visible:
				n += 1
	return n

## What bar `i` shows: &"dark", &"lit", &"amber" or &"amber_dim".
func bar_look(i: int) -> StringName:
	for key: StringName in BAR_LOOKS:
		if _bars[i].has(key) and _bars[i][key].visible:
			return key
	return &"dark"

## The rings' pace now, in revolutions a second.
func ring_rate() -> float:
	return _rates.x

## The heart's pulse now, in Hz.
func pulse_rate() -> float:
	return _rates.y

## Whether the heart is showing its flare: a flash, or power being restored.
func flaring() -> bool:
	return _flare.visible

func _process(delta: float) -> void:
	if state == &"restoring":
		_restore_t += delta
		var t := clampf(_restore_t / RESTORE_TIME, 0.0, 1.0)
		_rates = _restore_from.lerp(RATES[&"full"], t)
		if t >= 1.0:
			state = &"full"
	_flash_left = maxf(_flash_left - delta, 0.0)
	_ring_angle = fposmod(_ring_angle + TAU * _rates.x * delta, TAU)
	_heart_angle = fposmod(_heart_angle + TAU * _rates.x * HEART_TURN * delta, TAU)
	_pulse = fposmod(_pulse + _rates.y * delta, 1.0)
	_apply()

func _apply() -> void:
	for i in rings.size():
		rings[i].basis = _tilt(i) * Basis(Vector3.RIGHT, _RING_PHASE[i] + _RING_TURNS[i] * _ring_angle)
	var breath := 1.0 + BREATH * sin(TAU * _pulse)
	var turn := Basis(Vector3.UP, _heart_angle).scaled(Vector3.ONE * breath)
	for mesh in [heart, _flare]:
		mesh.basis = turn
	var flare := _flash_left > 0.0 or state == &"restoring"
	heart.visible = not flare
	_flare.visible = flare

static func _tilt(i: int) -> Basis:
	var t := _RING_TILTS[i]
	return Basis(Vector3.UP, deg_to_rad(t.y)) * Basis(Vector3.BACK, deg_to_rad(t.z))

func _kit(root: Node3D) -> InteriorKit:
	var kit := InteriorKit.new(root)
	kit.layer = _layer
	kit.light_mask = _layer
	return kit

## The heart: an icosahedron split once into 80 facets, each shaded from
## _FACET_LIGHT into its glow colour, so it turns like a cut gem.
func _heart_mesh(mesh_name: String, energy: float) -> MeshInstance3D:
	var kit := _kit(self)
	var r := InteriorProps.QUANTUM_HEART_RADIUS
	var light := _FACET_LIGHT.normalized()
	for face in _facets():
		var n: Vector3 = (face[0] + face[1] + face[2]).normalized()
		var shade := 0.55 + 0.45 * (0.5 + 0.5 * n.dot(light))
		kit.tri(InteriorKit.Batch.GLOW, face[0] * r, face[1] * r, face[2] * r, n,
			InteriorKit.lit(InteriorPalette.QUANTUM, energy * shade))
	var mesh: MeshInstance3D = kit.commit()[0]
	mesh.name = mesh_name
	mesh.position = InteriorProps.QUANTUM_HEART
	return mesh

## An icosahedron's faces, each split in four, on the unit sphere.
static func _facets() -> Array:
	var p := (1.0 + sqrt(5.0)) * 0.5
	var v: Array[Vector3] = [
		Vector3(-1, p, 0), Vector3(1, p, 0), Vector3(-1, -p, 0), Vector3(1, -p, 0),
		Vector3(0, -1, p), Vector3(0, 1, p), Vector3(0, -1, -p), Vector3(0, 1, -p),
		Vector3(p, 0, -1), Vector3(p, 0, 1), Vector3(-p, 0, -1), Vector3(-p, 0, 1),
	]
	var faces := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4],
		[11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var out := []
	for f in faces:
		var a := v[f[0]].normalized()
		var b := v[f[1]].normalized()
		var c := v[f[2]].normalized()
		var ab := (a + b).normalized()
		var bc := (b + c).normalized()
		var ca := (c + a).normalized()
		out.append_array([[a, ab, ca], [b, bc, ab], [c, ca, bc], [ab, bc, ca]])
	return out

## One ring, flat in its pivot's xz plane round the heart: a trim band with a
## violet-lit inner edge. The pivot turns it about its own x axis.
func _ring(i: int) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "Ring%d" % i
	pivot.position = InteriorProps.QUANTUM_HEART
	add_child(pivot)
	var kit := _kit(pivot)
	var radii: Vector2 = InteriorProps.QUANTUM_RINGS[i]
	var h := InteriorProps.QUANTUM_RING_THICKNESS * 0.5
	var trim := InteriorKit.solid(InteriorPalette.TRIM)
	var edge := InteriorKit.lit(InteriorPalette.QUANTUM, 1.4)
	var up := Vector3(0, h, 0)
	for k in InteriorKit.SEGMENTS:
		var a0 := TAU * float(k) / InteriorKit.SEGMENTS
		var a1 := TAU * float(k + 1) / InteriorKit.SEGMENTS
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var out := (d0 + d1).normalized()
		var i0 := d0 * radii.x
		var i1 := d1 * radii.x
		var o0 := d0 * radii.y
		var o1 := d1 * radii.y
		kit.quad(InteriorKit.Batch.SOLID, i0 + up, i1 + up, o1 + up, o0 + up, Vector3.UP, trim)
		kit.quad(InteriorKit.Batch.SOLID, i0 - up, i1 - up, o1 - up, o0 - up, Vector3.DOWN, trim)
		kit.quad(InteriorKit.Batch.SOLID, o0 - up, o1 - up, o1 + up, o0 + up, out, trim)
		kit.quad(InteriorKit.Batch.GLOW, i0 - up, i1 - up, i1 + up, i0 + up, -out, edge)
	for mesh in kit.commit():
		mesh.name = "Ring%d%s" % [i, "Edge" if mesh.material_override == InteriorMaterials.glow() else ""]
	return pivot

## The gauge: every bar dark in QUANTUM_DEEP, always there, and over each a
## lit bar shown when it is lit -- the lowest with its two amber looks too.
func _gauge() -> void:
	var frames := InteriorProps.quantum_core_bars()
	var size := InteriorProps.QUANTUM_GAUGE_BAR
	var dark_kit := _kit(self)
	for f in frames:
		dark_kit.bevel_box(InteriorKit.Batch.SOLID, f, size, 0.01, InteriorKit.solid(InteriorPalette.QUANTUM_DEEP))
	dark_kit.commit()[0].name = "GaugeDark"
	var looks := {
		&"lit": InteriorKit.lit(InteriorPalette.QUANTUM, BAR_ENERGY),
		&"amber": InteriorKit.lit(InteriorPalette.AMBER, BAR_ENERGY),
		&"amber_dim": InteriorKit.lit(InteriorPalette.AMBER, EMPTY_ENERGY),
	}
	for i in frames.size():
		var bar := {}
		for key: StringName in BAR_LOOKS:
			if i > 0 and key != &"lit":
				continue
			var kit := _kit(self)
			kit.bevel_box(InteriorKit.Batch.GLOW, frames[i] * InteriorKit.at(Vector3(0, 0, 0.003)),
				size + Vector3(0.004, 0.004, 0.0), 0.01, looks[key])
			var mesh: MeshInstance3D = kit.commit()[0]
			mesh.name = "Bar%d_%s" % [i, key]
			bar[key] = mesh
		_bars.append(bar)
