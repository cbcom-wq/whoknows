class_name PilotPage
extends ComputerPage

## The bridge computer's PILOT page (hostile ships spec §9.1): the switch that
## hands the ship to its pilot and takes it back, and the style it fights in.
## The spec put these on the WEAPONS page, whose buttons are all in use, so
## they have a page of their own beside it on an armed ship. The big button
## switches the pilot, prev and next step the style choice: AUTO, STAND-OFF,
## BRAWLER. Every line fits the table's screen (WeaponsPage.PAGE_COLUMNS).

func title() -> String:
	return "PILOT"

func lines(ctx: ComputerContext) -> PackedStringArray:
	var pilot := _pilot(ctx)
	if pilot == null:
		return PackedStringArray(["NO PILOT"])
	var out := PackedStringArray(["PILOT · %s" % ("ON" if pilot.on else "OFF"),
		"STYLE · %s" % ShipPilot.style_name(pilot.style_choice)])
	if pilot.on:
		out.append(_fit(_doing(pilot)))
	return out

## What it is doing, and to whom: "CLOSING · STARTER SHUTTLE".
static func _doing(pilot: ShipPilot) -> String:
	var doing := String(pilot.intent).to_upper().replace("_", " ")
	if pilot.objective == null or pilot.objective.done() or pilot.intent == &"holding_station" \
			or pilot.ship == null or not pilot.ship.is_inside_tree():
		return doing
	var node := Weapons.find(pilot.ship.get_tree(), pilot.objective.target_id())
	return doing if node == null else "%s · %s" % [doing, Weapons.label_of(node).to_upper()]

static func _fit(text: String) -> String:
	var columns := WeaponsPage.PAGE_COLUMNS
	return text if text.length() <= columns else text.left(columns - 2) + ".."

func lit(ctx: ComputerContext) -> Array[StringName]:
	if _pilot(ctx) == null:
		return []
	return [&"prev", &"big", &"next"]

func big_colour(ctx: ComputerContext) -> StringName:
	var pilot := _pilot(ctx)
	if pilot == null:
		return &"dark"
	return &"go" if pilot.on else &"amber"

func prompt(button: StringName, ctx: ComputerContext) -> String:
	var pilot := _pilot(ctx)
	match button:
		&"big":
			return "Take the ship back" if pilot != null and pilot.on else "Hand the ship to its pilot"
		&"prev":
			return "Previous style"
		&"next":
			return "Next style"
	return ""

func press(button: StringName, ctx: ComputerContext) -> void:
	var pilot := _pilot(ctx)
	if pilot == null:
		return
	match button:
		&"big":
			if pilot.on:
				pilot.on = false
			else:
				pilot.fight_for_you()
		&"prev":
			pilot.style_choice = posmod(pilot.style_choice - 1, ShipPilot.Style.size()) as ShipPilot.Style
		&"next":
			pilot.style_choice = posmod(pilot.style_choice + 1, ShipPilot.Style.size()) as ShipPilot.Style

static func _pilot(ctx: ComputerContext) -> ShipPilot:
	return ctx.ship_pilot if ctx != null else null
