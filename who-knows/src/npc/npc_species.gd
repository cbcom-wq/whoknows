class_name NpcSpecies
extends Resource

## One kind of NPC, as data (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §8): its body, senses, needs, mind and
## where it lives. A new creature is one of these, a look, and at most a
## behaviour or two. Ids name code: NpcBehaviours, Npc.make_locomotor and
## NpcLooks turn them into objects.

@export var id: StringName
@export var display_name: String
@export_group("Body")
## Its longest side, metres.
@export var size := 1.0
## Standing height and width, metres: with size, its body's box.
@export var height := 0.5
@export var width := 0.5
## For bumps, kg.
@export var mass := 25.0
## m/s at speed 1.0.
@export var top_speed := 2.0
## The first is the one it starts with.
@export var locomotors: Array[StringName] = []
@export var look: StringName
@export_group("Senses")
@export var sight_range := 20.0
@export var sight_cone_deg := 180.0
## Sight in the dark as a fraction of sight_range (outside only; inside is lit).
@export var dark_sight := 1.0
## 0 feels no vibration; 1 feels a stimulus to its full radius.
@export var feels_vibration := 0.0
@export var hears := 0.0
@export var feels_shake := 0.0
## -1 freezes or flees in light ... +1 is drawn to it.
@export var light_response := 0.0
@export_group("Needs")
## Need -> how fast it rises by itself, per second.
@export var needs: Dictionary = {}
## Need -> the range it starts in, Vector2(min, max).
@export var need_start: Dictionary = {}
@export_group("Mind")
@export var behaviours: Array[StringName] = []
## Behaviour -> weight; missing means 1.
@export var behaviour_weights: Dictionary = {}
@export_group("Disposition")
@export var fear_of_player := 0.0
@export var curiosity_about_player := 0.0
@export_group("World")
@export var population: StringName
## Live within this of an anchor (outside); 0 for a site-wide population.
@export var live_radius := 0.0
## Fully drawn within x, gone beyond y; (0, 0) for no fade (inside).
@export var fade := Vector2.ZERO
@export_group("Interactions")
## What the player can do to it. Empty in this build (spec §12.4).
@export var interactions: Array[StringName] = []
