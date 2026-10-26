class_name CabinDip
extends Node

## The cabin's ceiling lights dipping as a hit lands (hostile ships spec §6.1):
## a light bolt a quick dip, a heavy one a stutter with a near-dark beat
## (HitFeel's DIP_ numbers). One dip runs at a time, and a new one replaces it
## only if stronger, so a hammering is not a strobe. Plain lamps are written
## here; a flickering light (LightFlicker) reads `factor()` itself. Screens and
## glow plinths are never touched: a blackout is not wanted.
##
## The ship keeps one under its interior and binds it after every rebuild.

## A plain lamp and the energy it was built at.
var _lamps: Array[OmniLight3D] = []
var _energies: Array[float] = []
## The running dip: its strength, length, deepest level and flicks, and how
## far in it is. Not running when `_t >= _length`.
var _strength := 0.0
var _length := 0.0
var _level := 1.0
var _flicks := 0
var _t := 0.0

## Starts a dip of `strength` (HitFeel.strength), unless a stronger one runs.
func dip(strength: float) -> void:
	if _running() and strength <= _strength:
		return
	var k := HitFeel.heaviness(strength)
	_strength = strength
	_length = lerpf(HitFeel.DIP_LIGHT_TIME, HitFeel.DIP_HEAVY_TIME, k)
	_level = lerpf(HitFeel.DIP_LIGHT_LEVEL, HitFeel.DIP_HEAVY_LEVEL, k)
	_flicks = roundi(HitFeel.DIP_FLICKS * k)
	_t = 0.0
	_show()

## The share of their built light the ceiling lights give now: 1 at rest.
func factor() -> float:
	if not _running():
		return 1.0
	var stutter := _length * HitFeel.DIP_STUTTER if _flicks > 0 else 0.0
	if _t < stutter:
		# Dark and flick by turns: the slots between flicks are dark.
		var slot := int(_t / (stutter / (2 * _flicks + 1)))
		return HitFeel.DIP_FLICK_LEVEL if slot % 2 == 1 else _level
	return lerpf(_level, 1.0, smoothstep(stutter, _length, _t))

## Takes `lamp` as a plain ceiling lamp, at the energy it has now (as built).
func register(lamp: OmniLight3D) -> void:
	_lamps.append(lamp)
	_energies.append(lamp.light_energy)
	if _running():
		lamp.light_energy *= factor()

## Forgets every lamp, for an interior about to be dressed afresh.
func clear() -> void:
	_lamps.clear()
	_energies.clear()

## How many plain lamps it dims.
func lamps() -> int:
	return _lamps.size()

## Every ceiling light dressed under `root` (InteriorProps.CELL_LIGHT_ROLE):
## a flickering one is told of this dip, a plain one registered.
func bind(root: Node) -> void:
	clear()
	var flickering := {}
	for node in root.find_children("*", "LightFlicker", true, false):
		var f := node as LightFlicker
		f.dip = self
		flickering[f.lamp] = true
	for node in root.find_children("*", "OmniLight3D", true, false):
		if node.get_meta(&"role", &"") == InteriorProps.CELL_LIGHT_ROLE and not flickering.has(node):
			register(node as OmniLight3D)

func _process(delta: float) -> void:
	tick(delta)

## Moves the dip on `delta` seconds and lights the plain lamps by it. Called
## every frame; tests call it directly.
func tick(delta: float) -> void:
	if not _running():
		return
	_t += delta
	_show()

func _running() -> bool:
	return _t < _length

func _show() -> void:
	var f := factor()
	for i in _lamps.size():
		if is_instance_valid(_lamps[i]):
			_lamps[i].light_energy = _energies[i] * f
