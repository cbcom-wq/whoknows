class_name ComputerPage
extends RefCounted

## One page of the bridge computer
## (docs/superpowers/specs/2026-09-25-bridge-computer-design.md §3.5). The
## table shows one at a time and PAGE steps through them; a later feature adds
## a page, not a new machine. The buttons a page may use are &"range",
## &"prev", &"big" and &"next" -- PAGE is the table's own.

func title() -> String:
	return ""

## Up to three lines under the title.
func lines(_ctx: ComputerContext) -> PackedStringArray:
	return PackedStringArray()

## The buttons this page uses right now; the rest stay dark.
func lit(_ctx: ComputerContext) -> Array[StringName]:
	return []

## The big button's colour: &"go", &"amber" or &"dark".
func big_colour(_ctx: ComputerContext) -> StringName:
	return &"dark"

func prompt(_button: StringName, _ctx: ComputerContext) -> String:
	return ""

func press(_button: StringName, _ctx: ComputerContext) -> void:
	pass

## Called when PAGE brings this page up.
func opened(_ctx: ComputerContext) -> void:
	pass

## What the holo shows this frame.
func holo(_volume: HoloVolume, _ctx: ComputerContext, _delta: float) -> void:
	pass

## What survives a rebuild, and putting it back.
func save() -> Dictionary:
	return {}

func restore(_state: Dictionary) -> void:
	pass
