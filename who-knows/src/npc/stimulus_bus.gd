class_name StimulusBus
extends Node

## What one space gives off that its NPCs might notice (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §6.1): vibrations, sounds, touches and
## shakes, each short lived. One per space, beside its director: the exterior,
## and each ship's interior.
##
## Emitters never hold a bus: they call StimulusBus.send(self, stimulus), which
## finds the bus whose space they are in, or does nothing if there is none.
## Lights are not emitted: they are nodes in group LIGHTS, looked at when an
## NPC thinks, because they shine for as long as they are on.

const GROUP := &"stimulus_bus"
## Lights NPCs can see: each answers light_reach() (0 while off),
## light_cone_deg() (180 for all round), light_origin() (shining along -z)
## and light_kind() (&"lamp", &"flare").
const LIGHTS := &"npc_light"

## Everything under this is in its space.
var space_root: Node
## Its clock, seconds.
var now := 0.0

var _live: Array[Stimulus] = []

## Serves the space under `root`. Outside, pass the universe: live stimuli
## move with the floating origin.
func setup(root: Node, universe: Universe = null) -> void:
	space_root = root
	add_to_group(GROUP)
	if universe != null and not universe.shifted.is_connected(_on_shifted):
		universe.shifted.connect(_on_shifted)

func emit(s: Stimulus, lasts := 0.5) -> void:
	s.at = now
	s.until = now + lasts
	_live.append(s)

## Live stimuli emitted at or after `t`.
func since(t: float) -> Array[Stimulus]:
	var out: Array[Stimulus] = []
	for s in _live:
		if s.at >= t:
			out.append(s)
	return out

func count() -> int:
	return _live.size()

## The lights in this space that are on.
func lights() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if not is_inside_tree() or space_root == null:
		return out
	for node in get_tree().get_nodes_in_group(LIGHTS):
		var light := node as Node3D
		if light != null and light.is_inside_tree() and float(light.call(&"light_reach")) > 0.0 \
				and for_node(light) == self:
			out.append(light)
	return out

func _physics_process(delta: float) -> void:
	now += delta
	var kept: Array[Stimulus] = []
	for s in _live:
		if s.until > now:
			kept.append(s)
	_live = kept

func _on_shifted(delta: Vector3) -> void:
	for s in _live:
		s.position -= delta

## The bus of the space `n` is in: the one whose space_root is the nearest
## ancestor (an interior's bus beats the exterior's for anything aboard, since
## the interior is under the scene too). Null if none.
static func for_node(n: Node) -> StimulusBus:
	if n == null or not n.is_inside_tree():
		return null
	var best: StimulusBus = null
	for node in n.get_tree().get_nodes_in_group(GROUP):
		var bus := node as StimulusBus
		if bus == null or bus.space_root == null or not is_instance_valid(bus.space_root):
			continue
		if bus.space_root != n and not bus.space_root.is_ancestor_of(n):
			continue
		if best == null or best.space_root.is_ancestor_of(bus.space_root):
			best = bus
	return best

## Gives off `s` in the space `from` is in, if it has a bus.
static func send(from: Node, s: Stimulus, lasts := 0.5) -> void:
	var bus := for_node(from)
	if bus != null:
		bus.emit(s, lasts)
