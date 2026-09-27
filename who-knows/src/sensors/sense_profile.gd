class_name SenseProfile
extends RefCounted

## How the ship's sensors read one kind of thing (NPC foundation spec §22.2,
## quantum energy spec §10.4): out to `reach` a vague ping in its rough
## direction; within `region_within` a region, a sphere round it that it lies
## inside but seldom at the middle of; inside the region, nothing, and you
## look.

var kind: StringName
var label: String
## Farthest it is sensed at all, metres.
var reach := 0.0
## Nearer than this, a region instead of a ping.
var region_within := 0.0
var region_radius := 0.0
## How far the region's centre may sit from the thing, metres: at most the
## radius less the thing's own spread, so all of it stays inside.
var region_offset := 0.0
## A ping is this many degrees off at most, re-drawn every `ping_period` s.
var ping_error_deg := 10.0
var ping_period := 4.0

static func make(p_kind: StringName, p_label: String, p_reach: float, p_region_within: float,
		p_radius: float, p_offset: float) -> SenseProfile:
	var p := SenseProfile.new()
	p.kind = p_kind
	p.label = p_label
	p.reach = p_reach
	p.region_within = p_region_within
	p.region_radius = p_radius
	p.region_offset = p_offset
	return p

## Signs of life: herds within 4 km (as far as big rocks are held in detail),
## a region 30 m across within 1 km (the owner, 2026-09-27).
static func life() -> SenseProfile:
	return make(&"life", "LIFE?", 4000.0, 1000.0, 15.0, 7.0)

## Salvage, as the quantum energy spec §10.4 designed it: pings 2-10 km, a
## region 150 m across within 2 km. For its Task 10 to use.
static func salvage() -> SenseProfile:
	return make(&"salvage", "SALVAGE", 10000.0, 2000.0, 75.0, 50.0)
