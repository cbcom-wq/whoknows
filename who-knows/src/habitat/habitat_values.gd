class_name HabitatValues
extends RefCounted

## Every number in docs/superpowers/specs/2026-09-26-habitat-modules-design.md,
## in one place: first guesses, tuned at playtest (§3).

# Planting (§5.2).
const PLANT_REACH := 8.0
const LEG_MIN := 0.3
const LEG_MAX := 2.5
## A new hub's body stands this far above the highest ground under its corners,
## beyond LEG_MIN, so its legs start short.
const LEG_SPARE := 0.4
const MAX_TILT := deg_to_rad(25.0)
const FROM_BASE := 24.0
const FROM_SHIP := 20.0
## How often the ghost re-tests where you aim, seconds.
const FIT_EVERY := 0.1
## How far above and below the leg ends the ground is looked for.
const CAST_SPARE := 4.0

# Unfolding (§5.3), seconds.
const FLY := 0.6
const SETTLE := 0.4
const LEGS := 1.0
const WALLS := 2.0
const LIGHTS := 1.5
const UNFOLD := FLY + SETTLE + LEGS + WALLS + LIGHTS

# Stores (§6.1, §6.3).
const HUB_STORE := 400
const STORE_ADDS := 1000

# The link (§6.1).
const LINK_REACH := 1000.0
const LINK_STEP := 50
## QE a second while ◀ or ▶ is held.
const LINK_RATE := 100.0

# The drill (§6.2).
const DRILL_PERIOD := 10.0
const RICHNESS_MIN := 0.5
const RICHNESS_MAX := 3.0
const VEIN_FACTOR := 2.0
const SURVEY := 60.0
## How often an awake base credits its drills.
const CREDIT_EVERY := 5.0

# Skitters (§8.4).
const STAMP_STRENGTH := 1.0
const STAMP_RADIUS := 60.0
const HUM_STRENGTH := 0.2
const HUM_RADIUS := 80.0
const HUM_EVERY := 3.0
## A herd whose home is within QUIET_RADIUS of a drill that has run this long
## has moved away.
const QUIET_AFTER := 600.0
const QUIET_RADIUS := 80.0

# Sleeping (§9.3): as ships do.
const SLEEP_AT := 20000.0
const WAKE_AT := 18000.0
