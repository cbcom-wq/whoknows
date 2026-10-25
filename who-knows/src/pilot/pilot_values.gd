class_name PilotValues
extends RefCounted

## Every number the AI pilot uses (docs/superpowers/specs/
## 2026-10-24-hostile-ships-design.md §5), in one place, as WeaponValues is
## for the turrets. Starting points: the duel probe (Task 16) tunes these
## first, WeaponValues only if the fight needs it.

## How often it sizes up the fight and how often it picks where to be, s (§5.2).
const ASSESS_EVERY := 1.0
const TACTICS_EVERY := 0.2
## A target out of contact this long, s, and the pilot gives up (§5.5).
const PURSUE_FOR := 60.0
## A brawler's range and how far either side of it it lets the range drift, m.
const BRAWL_RANGE := 350.0
const BRAWL_BAND := 150.0
## A stand-off holds this share of its own longest live turret range, give
## or take the band, m.
const STAND_OFF_SHARE := 0.9
const STAND_OFF_BAND := 150.0
## Hysteresis on the brawl score: from brawler it stands off under 1 − this,
## from stand-off it brawls over 1 + this.
const SWITCH_MARGIN := 0.15
## Judgement noise at skill 0: the brawl score is scaled by 1 ± this.
const NOISE_AT_ZERO := 0.5
## Store share above which even a disciplined pilot fires at long range.
const HOLD_FIRE_QE := 0.5
## A damaged computer reads as this share of the pilot's skill (§5.6).
const COMPUTER_DAMAGED_SKILL := 0.5
## A dev-spawned hostile: how far off, m, and its skill's span (§10.1).
const SPAWN_RANGE := 3000.0
const SPAWN_SKILL := Vector2(0.2, 0.8)
## Your own ship's pilot when you hand it over (§9.1).
const YOUR_SKILL := 0.5
## No save for this long after a hostile bolt hits you, s (§8.4).
const ENGAGED_CALM := 10.0
## Reach longer than the foe's by more than this, m, and it stands off: it can
## hit from where it cannot be hit (§5.3).
const REACH_EDGE := 100.0
## A stand-off keeps this far past the foe's reach when its own allows, m.
const PAST_REACH := 50.0
## With no live turret it keeps this far past the foe's reach, m.
const KEEP_AWAY := 300.0
## A brawler with less than this share of its store, while the foe has more,
## stands off (§5.3).
const DRY_SHARE := 0.25
