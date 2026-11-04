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
## or take the band, m. Under every skill's hold-fire line (HOLD_FIRE_ACE
## of its reach at skill 1), or a stand-off low on QE never fires.
const STAND_OFF_SHARE := 0.7
const STAND_OFF_BAND := 150.0
## Hysteresis on the brawl score: from brawler it stands off under 1 − this,
## from stand-off it brawls over 1 + this.
const SWITCH_MARGIN := 0.15
## Judgement noise at skill 0: the brawl score is scaled by 1 ± this.
const NOISE_AT_ZERO := 0.5
## Store share above which even a disciplined pilot fires at long range.
const HOLD_FIRE_QE := 0.5
## The share of its reach past which an ace holds fire with its store low; a
## novice holds only past all of it (PilotSkill). Not much under 1: a shot at
## 1 km still lands more often than not, and an ace holding at its own
## stand-off range out-fired by a novice lost (the duel probe).
const HOLD_FIRE_ACE := 0.9
## A first read of the fight brawls from this brawl score; later reads switch
## either way only past SWITCH_MARGIN about 1. Under 1, so an even fight is
## closed on: at 1, an ace's slight noise sent it standing off half the time.
const BRAWL_FROM := 0.9
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
## With no live turret it keeps the foe's reach plus this, m: less, so just
## inside it. Nobody flees (spec §5.3, call F):
## kept past the reach, a disarmed ship flew off at the speed limit with its
## foe at its heels, never caught, and the duel never ended.
const KEEP_AWAY := -150.0
## A brawler with less than this share of its store, while the foe has more,
## stands off (§5.3).
const DRY_SHARE := 0.25

# Flying (moved from ShipPilot for the duel probe's tuning, Task 16).

## Seconds it means to close the gap to the range it wants in, at full
## positioning: the wanted speed along the line of sight is the gap over this.
const CLOSE_TIME := 2.0
## The share of its foe's velocity it holds on top of that. Under 1, so the
## drift two pilots share dies away: matched in full, each holding the
## other's, they race off together at the speed limit.
const MATCH_SHARE := 0.6
## A jink's change of velocity is this many seconds of lateral thrust, and is
## held this long.
const JINK_PUSH := 2.5
## Jinks at intervals come every jink_every, give or take this share.
const JINK_JITTER := 0.3
## A bolt is inbound when it passes within INBOUND_MISS m of the hull within
## INBOUND_HORIZON s.
const INBOUND_MISS := 60.0
const INBOUND_HORIZON := 3.0
## The turn's gain, 1/s, at full positioning (Broadside.rotate_input).
const TURN_GAIN := 2.0
## The fastest it flies in a fight, m/s, keeping the rest of the limit to
## close on a foe that cannot fire back. At the limit itself every fight
## became a race (the duel probe): a stand-off backing off and a brawler
## following both reached it, and a foe whose cockpit went then coasted at it
## forever, out of reach of a pursuer no faster.
const FIGHT_SPEED := 80.0
## A brawler boosts while it is more than this many BRAWL_BANDs off its range.
const BOOST_BANDS := 2.0
## A turret counts toward a face only if it still bears this far off it, every
## way: a face on the very edge of a sky (the starter's nose, on the rim of both
## its turrets' half-skies) bears for neither once the muzzles' height shows.
const FACE_MARGIN := deg_to_rad(10.0)
