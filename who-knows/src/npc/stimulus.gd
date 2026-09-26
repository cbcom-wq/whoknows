class_name Stimulus
extends RefCounted

## Something the world gives off that an NPC might notice
## (docs/superpowers/specs/2026-09-26-npc-foundation-design.md §6.1). Short
## lived: the bus drops it at `until`. Position is in engine space; outside,
## the bus moves it with the floating origin.

const LIGHT := &"light"
const VIBRATION := &"vibration"
const SOUND := &"sound"
const TOUCH := &"touch"
const SHAKE := &"shake"

var kind: StringName
var position := Vector3.ZERO
## How strong at its source, 0-1.
var strength := 1.0
## How far it carries, metres. SHAKE ignores it: it reaches the whole space.
var radius := 10.0
## For VIBRATION: the rock it travels through (RockHerds.site_of()).
var site: StringName = &""
var source: Node
## When the bus took it, and when it drops it.
var at := 0.0
var until := 0.0

static func make(p_kind: StringName, p_position: Vector3, p_strength: float, p_radius: float,
		p_source: Node = null, p_site: StringName = &"") -> Stimulus:
	var s := Stimulus.new()
	s.kind = p_kind
	s.position = p_position
	s.strength = p_strength
	s.radius = p_radius
	s.source = p_source
	s.site = p_site
	return s

## How strongly it is felt at `point`: full at the source, nothing at radius.
func felt_at(point: Vector3) -> float:
	if kind == SHAKE:
		return strength
	if radius <= 0.0:
		return 0.0
	return strength * clampf(1.0 - position.distance_to(point) / radius, 0.0, 1.0)
