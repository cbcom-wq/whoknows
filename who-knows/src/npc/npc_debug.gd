class_name NpcDebug
extends Node3D

## The NPC overlay (docs/superpowers/specs/2026-09-26-npc-foundation-design.md
## §17.3), toggled with F4: above each live NPC, what it is doing, its top
## three scores, its needs as bars, and its surest percepts. Utility AI can
## only be tuned if you can see the scores. Off by default, and nothing is
## built while off.

const KEY := KEY_F4
const RAISE := 0.35
const FONT_SIZE := 28
const PIXEL := 0.0022

var directors: Array[NpcDirector] = []
var shown := false:
	set(value):
		shown = value
		if not shown:
			_clear()

var _labels := {}   # Npc -> Label3D

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY:
		shown = not shown

func _process(_delta: float) -> void:
	if not shown:
		return
	var seen := {}
	for director in directors:
		if not is_instance_valid(director):
			continue
		for npc: Npc in director.live_npcs():
			if not is_instance_valid(npc) or not npc.is_inside_tree():
				continue
			seen[npc] = true
			var label: Label3D = _labels.get(npc)
			if label == null:
				label = _make_label()
				_labels[npc] = label
			label.global_position = npc.global_position + npc.global_basis.y * (npc.species.height + RAISE)
			label.text = describe(npc)
	for npc in _labels.keys():
		if not seen.has(npc):
			_labels[npc].queue_free()
			_labels.erase(npc)

## What the overlay says about `npc`.
static func describe(npc: Npc) -> String:
	var lines := PackedStringArray()
	var brain := npc.brain
	lines.append("%s  %s" % [npc.record.id, brain.current.id if brain != null and brain.current != null else "-"])
	if brain != null:
		var ranked: Array = brain.scores.keys()
		ranked.sort_custom(func(a, b) -> bool: return float(brain.scores[a]) > float(brain.scores[b]))
		var top := PackedStringArray()
		for id in ranked.slice(0, 3):
			top.append("%s %.2f" % [id, float(brain.scores[id])])
		lines.append(" ".join(top))
		for n in brain.needs:
			lines.append("%-9s %s" % [n, bar(float(brain.needs[n]))])
	if npc.memory != null and npc.last_context != null:
		var t := npc.last_context.time
		var fresh: Array = npc.memory.percepts.duplicate()
		fresh.sort_custom(func(a, b) -> bool: return npc.memory.sure_of(a, t) > npc.memory.sure_of(b, t))
		for p in fresh.slice(0, 2):
			lines.append("~ %s %.2f" % [p.kind, npc.memory.sure_of(p, t)])
	return "\n".join(lines)

## A need as five blocks.
static func bar(value: float) -> String:
	var filled := clampi(roundi(value * 5.0), 0, 5)
	return "▮".repeat(filled) + "▯".repeat(5 - filled)

func _make_label() -> Label3D:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false
	label.pixel_size = PIXEL
	label.font_size = FONT_SIZE
	label.modulate = HudPalette.READOUT
	label.outline_modulate = HudPalette.BACKDROP
	label.layers = 1 | 2
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(label)
	return label

func _clear() -> void:
	for label: Label3D in _labels.values():
		if is_instance_valid(label):
			label.queue_free()
	_labels.clear()
