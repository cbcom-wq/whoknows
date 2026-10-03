class_name LightFlicker
extends Node

## A wrecked ceiling light (health and damage spec §9, the owner's call on
## 2026-10-02): mostly 90% dark, and every few seconds a short, ragged burst
## at full. It drives the cell's lamp and its own copy of the glow material
## on the light's disc together, so the fixture and the room flicker as one.
## The interior is rebuilt on any stage change, so a mended light simply
## comes back built without one.

## The share of full it sits at between bursts.
const DIM := 0.1
## Seconds from one chance of a burst to the next.
const CYCLE := 3.0
## A burst lasts BURST.x to BURST.y seconds.
const BURST := Vector2(0.25, 0.7)
## The share of cycles that pass with no burst at all.
const QUIET := 0.25
## How long each on-or-off flick inside a burst lasts.
const FLICK := 0.06
## The share of flicks in a burst that are off.
const FLICK_OFF := 0.4

var lamp: OmniLight3D
var material: ShaderMaterial
var lamp_energy := 0.0
var glow_energy := 0.0
## Where in its pattern this light is, so no two flicker together.
var phase := 0.0
var _clock := 0.0

static func attach(lamp_node: OmniLight3D, disc: MeshInstance3D, disc_material: ShaderMaterial) -> LightFlicker:
	var f := LightFlicker.new()
	f.name = "Flicker"
	f.lamp = lamp_node
	f.material = disc_material
	f.lamp_energy = lamp_node.light_energy
	f.glow_energy = float(disc_material.get_shader_parameter(&"energy"))
	var p := lamp_node.position
	f.phase = fposmod(p.x * 0.731 + p.y * 0.197 + p.z * 0.553, 1.0)
	disc.add_child(f)
	f._show(level_at(0.0, f.phase))
	return f

func _process(delta: float) -> void:
	_clock += delta
	_show(level_at(_clock, phase))

func _show(level: float) -> void:
	if lamp != null:
		lamp.light_energy = lamp_energy * level
	if material != null:
		material.set_shader_parameter(&"energy", glow_energy * level)

## The light's share of full at `t` seconds, for a light at `phase` (0..1):
## DIM, or 1.0 in a flick of a burst.
static func level_at(t: float, phase: float) -> float:
	var s := t + phase * 37.0
	var cycle := floorf(s / CYCLE)
	if _hash(cycle * 1.7 + phase * 3.1) < QUIET:
		return DIM
	var burst := lerpf(BURST.x, BURST.y, _hash(cycle + phase * 5.3))
	if s - cycle * CYCLE > burst:
		return DIM
	return DIM if _hash(floorf(s / FLICK) + phase * 7.9) < FLICK_OFF else 1.0

static func _hash(x: float) -> float:
	return fposmod(sin(x * 12.9898) * 43758.5453, 1.0)
