class_name WeaponValues
extends RefCounted

## Every number the ship weapons use (docs/superpowers/specs/
## 2026-10-11-ship-weapons-design.md §3.1), in one place, as QuantumValues and
## HabitatValues are. Starting points: the combat probe (§10.2) tunes them and
## the spec's as-built notes record what they became.

const LIGHT := &"turret_light"
const HEAVY := &"turret_heavy"
const TURRET_IDS: Array[StringName] = [LIGHT, HEAVY]
const STATION := &"weapons_station"

## Per turret: slew deg/s; bolts a burst, seconds between them, recharge after
## a burst; bolt speed m/s, damage hp, life s, push N·s; engagement range m,
## and how far a gunner may fire it by hand; spread deg; QE a bolt; the bolt's
## length and thickness, m; its impact flash against a pistol bolt's; and the
## barrel's length from its pivot, m, where bolts leave.
const SPECS := {
	LIGHT: {"slew": 90.0, "burst": 4, "gap": 0.125, "recharge": 1.5, "speed": 600.0, "damage": 15.0,
		"life": 3.0, "push": 20.0, "range": 1200.0, "manned_range": 1200.0, "spread": 0.4, "qe": 1,
		"length": 2.0, "thickness": 0.25, "flash": 1.5, "barrel": 1.0},
	HEAVY: {"slew": 30.0, "burst": 1, "gap": 0.0, "recharge": 3.0, "speed": 450.0, "damage": 120.0,
		"life": 7.0, "push": 400.0, "range": 1500.0, "manned_range": 3000.0, "spread": 0.0, "qe": 15,
		"length": 4.0, "thickness": 0.5, "flash": 3.0, "barrel": 2.4},
}

## A turret fires when its barrel is this close to its solution (spec §5.3).
const AIM_TOLERANCE := deg_to_rad(1.0)
## Fire control hands out targets this often, s (spec §5.1).
const ASSIGN_EVERY := 0.2
## The most targets you may mark.
const LIST_MOST := 3
## A listed target unseen this long, s, leaves the list.
const MISSING_GRACE := 2.0
## Other ships and bases are contacts within this, m (spec §4.2); T marks
## within it, and within MARK_CONE of the crosshair (spec §9.1).
const CONTACT_RANGE := 5000.0
const MARK_CONE := deg_to_rad(10.0)
## From a turret cell's centre to its mount face, and from the face up to the
## barrels' pivot, m.
const FACE_OUT := 1.0
const MUZZLE_UP := 0.6
## Where a turret with no target rests: ahead, a little raised.
const PARK_ELEVATION := deg_to_rad(10.0)
## How much of its path a bolt's trail shows, s, and how long it takes to run
## up to where the bolt ended (spec §6.2).
const TRAIL_TIME := 0.4
## The sky map (spec §3.3): yaw by elevation bins, how far each ray marches
## and in what steps, m, and the clear share under which TURRET_BLIND warns.
const SKY_YAW := 32
const SKY_PITCH := 16
const SKY_REACH := 40.0
const SKY_STEP := 0.5
const BLIND_BELOW := 0.25
## Damaged (spec §3.4): slews at this share, recharges this many times longer.
const DAMAGED_SLEW := 0.5
const DAMAGED_RECHARGE := 2.0
## The ray each shot casts against its own hull, m.
const HULL_CHECK := 40.0
## The heavy bolt's practical light, m.
const HEAVY_LIGHT_RANGE := 30.0

static func spec(kind: StringName) -> Dictionary:
	return SPECS.get(kind, SPECS[LIGHT])

static func is_turret(block_id: StringName) -> bool:
	return TURRET_IDS.has(block_id)
