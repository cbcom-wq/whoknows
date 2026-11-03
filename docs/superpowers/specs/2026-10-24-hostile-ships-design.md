# Hostile ships — an AI pilot that flies and fights

**Date:** 2026-10-24
**Status:** approved and built (approved 2026-10-24; §17 records what was built and what it left open)
**Depends on:** `main` at `1a58d32` (weapons, ship damage sections, many ships, the ship library merged)
**Amends:** the ship weapons spec (`2026-10-11-ship-weapons-design.md`) §4.3 *Hostile* (filled here),
§4.4 *Your own*, §7.1 the gunner hold; the ship damage sections spec
(`2026-10-03-ship-damage-sections-design.md`) §2.1 (HULL % at 0 now destroys; a section at 0 spills
into its neighbours), §4 (pieces off sooner
for big hits); the health and damage spec (`2026-09-29-health-and-damage-design.md`) §7 (downed with
nowhere to wake); the saving spec (`2026-09-26-saving-design.md`) §5 (no save under attack); the many
ships spec (`2026-10-02-many-ships-design.md`) §6.2 (the starter can be destroyed); the rock creatures
spec (`2026-10-10-rock-creatures-design.md`) §8.1 (a light bolt's damage, §17.1 here).
**Governed by:** `docs/design/visual-style.md` (binding: palettes, the three-shader interior budget,
120 fps on the GTX 960, renders at eye height), `CLAUDE.md` (floating origin; every ship is usable;
every ship lives in `data/ships/`; keep `building-a-ship` current)

---

## 1. Why

The owner (2026-10-23): *"I want to start introducing hostile entities in the game … We want to be
able to spawn hostile ships that attack the user and the user has to battle them."*

On what a hostile wants: *"A hostile is probably going to have 1 of 2 objectives. Either destroy you
or disable you so they can loot or steal your ship … We can start with just an objective to destroy.
Hostile would appear and engage you in battle."*

On what has to exist: *"primarily an AI pilot that can fly and fight. We can start with running from
a ship computer as this could even apply to the user's own ship. It would also need to run targeting
control of the ship weapons. We also need to hone what hitting and getting hit from ship weapons looks
and feels like. And how damage is applied. And what constitutes being destroyed."*

The weapons project built turrets that aim and fire themselves, bolts that can be dodged at range, and
a fire control "an enemy ship will drive … the same way, its list written by its AI"
(`fire_control.gd`). `Weapons.is_hostile` is false for everything and the HUD's hostile red is
unused. This project puts someone on the other side.

**Success:** you press the dev key; a starter, marked red, turns toward you from 3 km and opens up.
You fly the dance: swing so both your turrets bear, jink when its bursts come, close or open the
range. Bolts striking your hull jolt the cabin and blink its lights; yours burst bright on its hull,
knock plates loose, and as it weakens it sparks and vents gas. About five minutes later its core goes
up and it breaks apart. Another time, you lose: the screen goes, and the game picks up at the autosave
from before the fight. Another time, you hand your own ship to its pilot and man the Warden's heavy
gun while it dodges for you. The game holds 120 fps through all of it.

## 2. Decisions

The owner's (2026-10-23/24), in their words where they gave them:

| # | Decision |
|---|---|
| 1 | **Objective: destroy.** "Disable so they can loot or steal your ship" is the second objective, later. |
| 2 | **A dev key brings a hostile in.** How hostiles appear in real play is not this project's concern. |
| 3 | **The AI pilot runs on the ship's computer**, so it can fly any ship, **your own included**: you can hand your ship to it. |
| 4 | **It flies the ship as you do**, through the flight computer, under the same thrust, power and damage, and **it runs the ship's fire control**. |
| 5 | **Pilots range in skill** "depending on the opponent". |
| 6 | **Pilots fight in styles:** "some may choose to keep a distance and fire long shots and avoiding heavy contact, others may come hard and heavy to overwhelm an opponent", chosen by "how you perceive your ship's and enemy ships' strengths and weaknesses". |
| 7 | **A good, intense 1v1 lasts about 5 minutes**, varying a lot with how it is fought. |
| 8 | **Taking a hit, inside:** "maybe jolts, lights might darken or flicker briefly". **Outside:** "a brighter explosion of light at the impact site. Pieces could break off." **"The impact would depend on the strength of the hit."** |
| 9 | **A damaged ship shows it:** "the more damaged a ship's hull is the more sparks it gives off and leaks gases in areas." No health bar over the enemy; you read it from the ship (and its HULL % on the target bracket). |
| 10 | **Damage is applied as now** (sections and components, ship damage sections spec), **except that a section at 0 passes further hits on to its neighbours** (§8.1; the owner's choice, 2026-10-24, of three put to them after the builder check). **Shields come later.** |
| 11 | **Destroyed is HULL % at 0:** "they would break apart, the quantum engine would explode. Anything inside is dead." |
| 12 | **When your ship is destroyed, you go back to the last save,** "a last safe point". |
| 13 | **You can escape.** A hostile chases where it last saw you for about a minute, then gives up; no save is made while it chases (§5.5, §8.4; the owner, 2026-10-24, after the builder check). |

The designer's calls, agreed in conversation (the owner: "looks good"); the builder may refine them but
not reverse them without asking:

| # | Call |
|---|---|
| A | The objective is a swappable piece of the pilot, so *disable* is a new objective, not a new pilot (§5.5). |
| B | A wrecked **computer** takes the pilot with it (§5.6). |
| C | A wrecked core alone still only cripples, as today; only HULL % at 0 destroys (§8.1). |
| D | No save while a hostile is engaging you, so the last save is always from before the fight (§8.4). |
| E | A destroyed ship leaves no wreck to board or loot: that belongs with *disable* (§8.2). |
| F | Enemies fight to the end; a losing brawler may stand off, but nobody flees or surrenders (§5.3). |
| G | Enemy turrets may hit you on a spacewalk (they already target a suit). |
| H | The core's blast hurts what is near (§8.2). |
| I | Enemies carry no crew; the computer is the pilot. |
| J | With your ship's pilot on, the weapons station no longer holds the ship: the pilot flies while you man the gun (§9.2). |
| K | Gas venting and stronger hit feel apply to every ship, yours or theirs. |

## 3. What exists, and what is missing

Built, and used as it is:

- **Fire control** (`src/combat/fire_control.gd`): `HOLD`/`ENGAGE`, a list of three ids, every 0.2 s
  each turret given the first entry it can engage, else **the nearest hostile it can**. Turrets lead,
  slew, burst and recharge on their own (`turret.gd`, `weapon_values.gd`).
- **Bolts** (`bolt.gd`, `phaser_bolt.gd`, `bolt_pool.gd`): pooled, ray-per-tick, carry the shooter's
  velocity, amber with trails. Light 15 hp at 600 m/s in bursts of 4 (55 hp at 350 m/s, 3.6 s life, since T16); heavy 120 hp at 450 m/s.
- **Hits on a ship** (`Ship._on_hull_hit`): the cell's section or component takes the damage, a small
  push (light 20 N·s, heavy 400 N·s), and aboard a `hull_thump` scaled by damage.
- **The damage model** (`ship_damage.gd`, `damage_show.gd`): six sections, components (engines, core,
  computer, cockpit, each turret), pieces off below 50% section health, sparks from damaged blocks,
  the cabin scorched and flickering by HULL % (`LightFlicker`).
- **The flight computer** (`src/flight/flight_computer.gd`): `set_pilot_input(translate, rotate,
  boost)`, `set_heading(dir)`, the assist and its limits, the boost's QE, the damaged cockpit's half
  assist. `PilotControls` is today its only driver.
- **Ships** come and go through `Fleet` (`spawn`, `remove`, sleep past 20 km); the F6 spawn panel
  (`src/ui/spawn_panel.gd`) spawns library ships. Every library ship (starter, Lamplighter, Warden)
  has a computer and turrets.
- **Saving** (`src/save/save_gate.gd`): one autosave slot, written only when no source is busy;
  `Ship.busy()` already waits 5 s after a strike.
- **Downed** (`flight_test.gd` `_rescue`): you black out and wake aboard for 50 QE.

Missing: anything that flies a ship but you; any notion of sides; any end for a ship but crippled;
hit feel beyond a thump; gas.

## 4. Sides

### 4.1 A ship has a side

`Ship.side: StringName`, saved with the ship: `&"crew"` (yours: the starter and every ship spawned
or loaded as now) or `&"hostile"`. Only ships have a side in this project; creatures, bases and items
keep today's rules.

### 4.2 Hostile, now relative

`Weapons.is_hostile` gains the shooter: `is_hostile(shooter_ship, node) -> bool`, true when the
node's ship (`Weapons._ship_of`) has a side hostile to the shooter's: `crew` and `hostile` are
hostile to each other, a side never to itself. Fire control passes its own ship. The test stub
(`hostile_rule`) stays for tests. The HUD and the target brackets ask with the ship you are aboard.

The **avatar on a spacewalk** counts as `crew` for a hostile's fire control: it may be engaged (the
pilot's target is your ship; the turrets' nearest-hostile pass may pick your suit when it is nearer
and bears). The avatar is not a target today (`Weapons` spec §4.1: "your own avatar does not" join);
for hostiles it joins `Weapons.TARGETS` with id `&"you"` and is hostile only to hostile ships, so
your own turrets never see it.

### 4.3 What a side changes

- Your turrets in `ENGAGE` fire on a hostile ship unmarked (the nearest-hostile pass, already built).
  Your orders stay yours: a hostile does not flip you out of `HOLD`. While a hostile is engaging and
  your orders are `HOLD`, the HUD shows *HOSTILE · WEAPONS ON HOLD* in `WARNING` (the designer's call).
- Brackets on a hostile are `HudPalette.HOSTILE` red. A hostile within contact range (5 km,
  `TargetContacts`) is bracketed whether listed or not, so you see it coming.
- Each bracket on a ship shows its **HULL %** as a small number under its distance (decision 9).
- F8 (`board_nearest`, a dev key) refuses a hostile ship: boarding a live enemy is the *disable*
  project's (the designer's call; every ship stays usable, and a dev may still flip a ship's side in
  the dev readout, §10.2).

## 5. The AI pilot

### 5.1 Where it lives

`ShipPilot` (new, `src/combat/ship_pilot.gd` or a new `src/pilot/`; the builder's choice), one per
ship, a sibling of `FlightComputer` and `FireControl`, built by the ship with them. It is **off** on
a `crew` ship until you hand it the ship (§9) and **on** on a `hostile` one. While on, it is the
flight computer's driver in `PilotControls`' place: it calls only `set_pilot_input`, `set_heading`,
`clear_heading` and the assist toggle, and writes fire control's list and orders. It never moves the
hull, sets velocities or touches turrets directly. That is decision 4: no cheating on thrust, turn
rate, QE or damage. A damaged cockpit's sluggish assist, half engines and low power slow it exactly
as they slow you.
A **wrecked** cockpit refuses the assist but leaves the ship flyable (damage spec §2.2), for it as for
you: the hold is gone, so it pushes `set_pilot_input`'s stick itself toward the velocity it wants,
with no more thrust than the stick gives (built in T16; before, it coasted for the rest of the fight).

**What it may know** is what your ship could: contacts within 5 km (`TargetContacts`), their
positions and velocities, their HULL % (shown on your brackets too), its own ship's state, and
**bolts in flight** within a short reach (it "sees" them as you see the trails). It does not read
your inputs or your future.

### 5.2 Layers

Built in three layers, each testable alone (the designer's suggestion; the builder may reshape the
code but keep the separation of *what to do* from *how to fly it*):

1. **Assessment** (every ~1 s): sizes up the fight, its ship against the target's — firepower that can
   bear (turret count, damage per second, range: light 1.2 km, heavy 1.5 km), hull and its HULL %,
   speed and thrust, QE in store and how long it lasts at full fire, damaged components. From that it
   picks a **style** (§5.3) and a **preferred range**.
2. **Tactics** (every ~0.2 s): from the style, where it wants to be relative to the target (range band,
   which side to present so most turrets bear — the sky maps already say which turrets can bear on a
   direction), when to boost, when to hold fire to save QE, when to jink.
3. **Flying** (every physics tick): turns that wish into stick, translation and heading through the
   flight computer, **steering clear of rocks and other ships** (it must never fly into an asteroid;
   the weapons probe found rocks everywhere), and the **jink**: a change of velocity across the line of
   fire when bolts are inbound or at intervals while in the target's range. Changing velocity is how a
   bolt is dodged (weapons spec §5.2): the turrets assume the target holds its velocity.

### 5.3 Styles

Two in this project (decision 6), more later:

- **Stand-off:** holds near the edge of its own engagement range (or past the target's, when its
  reach is longer), presents its broadside, jinks constantly, and plays the long game on QE. Good for
  a ship with more reach, or one outgunned up close.
- **Brawler:** closes hard to a few hundred metres, where hit rates are 85–95% (weapons spec §16.2),
  boosting in, and keeps its strongest face on the target. Good for a ship with more firepower or hull.

The assessment re-runs through the fight: a brawler whose HULL % falls well below the target's, or
whose QE runs short, may switch to stand-off. Nobody flees or surrenders (call F). A pilot may be
given a fixed style; by default it chooses.

### 5.4 Skill

One number per pilot, **0 to 1**, setting several knobs (the builder tunes which and how far):

- **reaction:** how long after bolts appear it starts a jink (a novice ~1 s, an ace ~0.2 s);
- **jink quality:** how hard, how varied and how well-timed its changes of velocity are;
- **positioning:** how well it keeps the range it wants and the face that bears;
- **judgement:** how well its assessment reads the fight (a novice may brawl a Warden);
- **fire discipline:** whether it wastes QE on shots past the dodge window.

Aim is not a knob: the turrets aim themselves for everyone. A novice should be beatable by a new
player in the starter; an ace should beat a careless one in the same ship.

### 5.5 The objective

A small piece the pilot holds, which says what it is trying to do and when it is done. This
project builds one, **Destroy(target)**: fight the target until it is destroyed (§8). Its target is
your ship (the one you are aboard) on a dev spawn; if that is destroyed or gone, the nearest crew ship
in contact range; failing that the pilot holds station.

**Escape (decision 13).** When its target leaves contact range (5 km), the pilot **pursues**: it
flies at its best speed toward where it last saw the target, along that target's last seen velocity
(a direction, never a stored engine position, so the floating origin cannot move it; or a
`UniversePoint`). If the target comes back into contact, the fight resumes. After **60 s** without
contact it **gives up**: the objective ends, and the pilot holds station where it is (it does not go
home; there is no home yet). A hostile that gave up is still hostile and engages again if you come
back within 5 km. While pursuing is the only state in which a pilot leaves the fight's area; it does
not travel otherwise. *Disable* (stop when the target's engines or
core are wrecked, then close) is the next objective and should drop in without changing the layers
(call A).

### 5.6 The computer

The pilot runs on the ship's **computer** component (decision 3). **Damaged** (under 50%): its
assessment and reactions are slower, as a lower skill (the designer's call). **Wrecked**: the pilot is
gone. The flight computer is given no input (it coasts, the assist damping it if allowed); fire control
keeps whatever orders and list it had, so a hostile with a wrecked computer is a drifting gun platform
whose turrets still fire on the nearest crew ship in reach. Mended above wrecked, the pilot comes back.
A lucky shot on the 300 hp computer is a real tactic.

## 6. Hits: how they look and feel

Every ship, yours or theirs (call K). Scaled by the hit's **damage**: a light bolt (15) is the small
end, a heavy bolt (120) the big; crash damage uses the same scale.

### 6.1 Aboard, taking a hit (decision 8)

- **The jolt:** the camera you see through aboard (walking, seated, the gun camera) is shaken: a
  short, sharp knock away from the hit's side, a few centimetres and a degree or two for a light bolt,
  enough to feel for a heavy one, settling in a fraction of a second. Bursts of four stack into a
  rattle, not a blur. The view never loses the horizon; nothing that steers changes (the stick and
  aim are untouched). The existing `hull_thump` plays with it.
- **The lights:** the cabin's ceiling lights **dim and flicker** for a moment: a light bolt a quick
  dip of ~0.1 s, a heavy one a stutter of up to ~0.5 s with a near-dark beat. They come back to what
  HULL % says (steady, or `LightFlicker`'s flicker under 20%). The screens and glow plinths keep
  their light (the style guide §2.3: light is practical; a blackout is not wanted).
- Both are capped so a Warden's six turrets on you read as a hammering, not a strobe: at most one
  flicker running, and the shake's amplitude adds up to a ceiling.

### 6.2 Outside, landing a hit (decision 8)

- **A bright burst** at the impact point: the existing `ImpactFlash`, made brighter and larger,
  warm (`SpacePalette.PHASER`'s family, never blue), with a brief light for a heavy bolt (as the heavy
  bolt already carries one). It must read clearly at 1 km from the helm.
- **Pieces off:** today a section sheds its structural buffer only below 50% health. A **heavy** bolt
  (or any single hit over a threshold the builder sets, around 100 hp) may knock off the exposed piece
  it lands on at any health, with the existing burst, chunks and shed plate. The section's damage
  model stays the truth: a piece knocked off early is counted as one of the section's lost pieces and
  comes back with the torch in the same order (`ShipDamage.lost`). The builder decides how, keeping
  the torch's rebuild working.
- **The sound:** the existing impact *crack* within 200 m.

## 7. Damage you can read (decision 9)

- **Sparks:** `DamageShow`'s spits grow with the **section's** damage: more often and more of them as
  a section falls, so a dying ship fizzes all over. Today a damaged block spits every 0.8–2.5 s; at
  the low end of health it should be near continuous.
- **Gas:** a section under about **50%** **vents gas** from a few of its most exposed damaged cells:
  chunky puffs streaming off the hull, like the airlock's steam (the style guide §3.4: built-in
  particles, foggy never a whiteout), pale and flat-lit, drawn from `HullPalette`/`SpacePalette`. More
  vents and thicker puffs as it falls. The puffs are in the hull's own frame (so they ride the floating
  origin with it, as `DamageShow`'s spits do), and inherit no world velocity. Mended above 50%, a vent
  stops.
- **Watch the budget:** transparent overdraw is the cost (the style guide §2.6). A probe measures a
  ship at 10% HULL venting from all six sections, seen close from the chase view and from your helm.
- **No health bar:** the bracket's HULL % is the only number (§4.3).

## 8. Destroyed

### 8.1 When

A ship is **destroyed** when its **HULL %** reaches **0** (decision 11). A wrecked core alone
cripples as today (call C). Crash damage counts: flying into a rock at speed can destroy you.

**Spill-over (decision 10).** Today `ShipDamage._hurt` caps each section at its hp, and turrets aim at
the hull's centre of mass, so hits pile on the face toward the shooter: a ship that kept one face to
you would stall at 50–80% and never die. Instead, **damage a section at 0 cannot take passes to its
neighbouring sections** — along the length (bow ↔ midship ↔ stern) and across (port ↔ starboard) —
split between those still standing, and on outward from them if they too are at 0. Every hit counts
toward HULL %, the face you hammer breaks open first, and the damage then goes deeper. The same holds
for crash and blast damage. Components are unchanged: a component at 0 stays capped and passes
nothing on. The bracket's HULL % therefore falls steadily under fire, and §11's pool of about 12,400
hp is real.

### 8.2 What happens

In about a second:

1. **The core explodes:** a big warm flash and light at the core, the brightest thing in the scene for
   a moment, a deep *boom* (heard as a thump through the hull of a ship within ~500 m, the suit's bus
   outside). A **blast** hurts what is near: ships, NPCs, items and you on a spacewalk within a radius
   (call H; the builder sets it, around 100 m, falling off with distance, scaled by the ship's mass or
   its QE in store).
2. **The ship breaks apart:** its blocks go as a handful of large chunks (groups of cells, flat-shaded
   in its livery, scorched and charred) and many small ones, flung out from the core with a spin,
   carrying the hull's velocity. Chunks are loose bodies in `Universe.EXTERIOR_SPACE`; they collide
   with nothing but rocks, never with each other, and fade and free over 20–60 s. Bursts of sparks and
   a puff of gas as it goes.
3. **Everything inside dies** (decision 11): NPCs aboard die and are written to the `NpcLedger`; items
   aboard are lost; your avatar, if aboard (walking, seated, at the gun, in its airlock), dies (§8.3).
4. **The ship is gone:** `Fleet.remove`, its interior slot freed. No wreck is left to board or loot
   (call E). Fire control entries naming it fall off as gone entries do.

The starter is the one ship `Fleet` never removes today (many ships spec §6.2). The build must let a
destroyed starter go, or keep it in a *destroyed* state that is hidden, collisionless and saved as
destroyed; the builder chooses and amends that spec.

### 8.3 You

- **Aboard a ship that is destroyed:** you die. The screen whites out in the core's flash and fades to
  black, a line reads *SHIP LOST*, and the game **reloads the last save** (decision 12) — the same path
  as launching the game, which resumes the save.
- **On a spacewalk when your ship goes:** you live, unless the blast downs you. If you are downed
  with **nowhere to wake** (no ship you were aboard, no base), it is the same: back to the last save.
  While your suit lasts you may still reach and board another ship (every ship is usable).
- **Downed aboard a ship that still stands:** as today, you wake aboard for 50 QE.

### 8.4 No save under attack (call D)

`SaveGate` gains a source: **busy while a hostile is engaging** — any awake hostile ship whose pilot's
objective targets a ship you are aboard (or you), **including while it pursues you out of contact**
(§5.5), or that fired on you in the last 10 s, plus the existing 5 s after any strike. Once every
pursuer has given up, saving resumes: escaping is a way out of a fight. So the save you return to is from before the fight; winning, the calm
after the last hostile is destroyed lets saving resume. A hostile saved far off and not yet engaging is
saved like any ship, with its side, its pilot's skill, style and objective.

## 9. Your ship's pilot (decision 3)

### 9.1 Handing it over

At the helm, a new action (`pilot_ai`, a free key the builder picks) hands the ship to its pilot, and
the same key, or **any stick or translation input**, takes it back. The bridge computer's WEAPONS page
gains the same switch and a style choice (*AUTO*, *STAND-OFF*, *BRAWLER*). While on, the HUD says
*AI PILOT · <STYLE>*. Your pilot's skill is a fixed middling value in this project (the designer's
call); ships' pilots getting better is a later idea.

It **fights only**: with an objective of Destroy on the hostile listed first (or the nearest hostile),
and with none it holds station (assist on, speed locked at zero). It does not travel, follow, or warp
(non-goals). It sets your fire control to `ENGAGE` while it fights and leaves the orders as it found
them when it is handed back.

### 9.2 The weapons station (call J)

Today sitting at the weapons station holds the ship (`FlightComputer.gunner_hold`, weapons spec §7.1).
With the pilot on, the hold is not applied: the pilot keeps flying and dodging while you aim the heavy
turret. Pilot off, the hold works as it does now.

## 10. The dev key and the dev readout

### 10.1 Spawning a hostile (decision 2)

In the F6 spawn panel, **Shift + 1–9** spawns that library ship as a hostile (plain 1–9 is as now).
It appears **3 km** from you, off to one side and facing you, at rest, with a random skill (0.2–0.8)
and style *AUTO*; the panel's last line says what came, e.g. *HOSTILE STARTER · SKILL 0.6 · AUTO*.
Pressing again adds another; the tuning is for 1v1. Delete removes the nearest spawned ship, hostile
or not, as now. (The designer's call on the keys; the builder may move them if they clash.)

### 10.2 The pilot readout

A debug overlay in the plain F3 style (a free key), for tuning: for each hostile in contact, its
style, skill, preferred range and actual range, its intent (*CLOSING*, *HOLDING RANGE*, *JINKING*,
*BOOSTING*, *HOLDING FIRE*), its QE, its HULL %, and its last assessment's numbers. It can set a
selected ship's side, skill and style. NpcDebug (F4) is the model.

## 11. Tuning and the 5-minute fight

Decision 7. Today's numbers, as a sanity check (to be measured, not trusted):

- A starter's hull is about **12,400 hp** (sections 1,430–2,760). Its two light turrets each deal up
  to **30 hp/s** (4 × 15 hp per 2 s cycle).
- Two starters brawling (both turrets bearing, ~85% hits): about **4 minutes** to destroy one. At
  stand-off ranges, where most bolts are dodged, **10 minutes or more**.
- A starter's 1,200 QE lasts **about 5 minutes** of both turrets firing (4 QE/s), so QE is a real
  pressure: a stand-off pilot can try to outlast you.
- A Warden on a starter: about a minute. Mismatches are meant to be mismatched.

So the target is near today's numbers. `WeaponValues` and the pilot's knobs move, in that order of
preference, until the **duel probe** (§12.2) shows an even fight — starter against starter, both pilots
at skill 0.5 — lasting **4 to 6 minutes** on average, with neither style always winning. The as-built
notes record what changed.

## 12. Testing

### 12.1 Automated (GUT, headless; only the files covering each change — never the full suite per task)

- **Sides:** `is_hostile(shooter, node)` both ways and never to itself; fire control's nearest-hostile
  pass picks a hostile ship unmarked and never a crew ship; the avatar is a target only to hostiles;
  side round-trips a save.
- **Pilot, assessment:** given two ships' numbers it picks brawler for the stronger-up-close ship and
  stand-off for the longer-reach one; it re-picks when HULL % or QE falls.
- **Pilot, flying:** it drives only through the flight computer's calls (a test flight computer
  records them); it turns to bring the most turrets to bear; it keeps a preferred range within a band;
  it steers round a rock placed in its path; it jinks within its reaction time of a bolt inbound.
- **Pilot and computer:** damaged slows it; wrecked stops input and leaves fire control running;
  mended brings it back.
- **Objective:** Destroy ends when its target is destroyed and retargets to the nearest crew ship;
  a target leaving 5 km is pursued, re-engaged on contact, and given up after 60 s (saving busy until
  then).
- **Spill-over:** damage on a section at 0 goes to its neighbours, on outward when they are at 0 too;
  HULL % reaches 0 under hits on one face only; components never spill.
- **Hit feel:** shake amplitude and flicker length scale with damage and are capped under a burst
  storm; the heavy-hit piece knock-off goes into the section's lost pieces and comes back with the
  torch.
- **Damage you can read:** spit rate rises with section damage; vents start under 50% and stop above.
- **Destroyed:** HULL % 0 removes the ship (and the starter, per the builder's §8.2 choice), kills NPCs
  aboard (ledger), frees the slot, drops the target from lists; the blast damages a ship and an NPC in
  range and not out of it; your death aboard asks for a reload; downed with nowhere to wake asks for a
  reload.
- **Saving:** busy while a hostile engages; calm after it is destroyed; a far hostile saves and loads
  with its pilot settings.
- **Your pilot:** the key hands over and any stick input takes back; orders restored; the gunner hold
  not applied with the pilot on.
- **Floating origin:** `test_floating_origin_scene.gd` covers chunks, gas, the explosion; the pilot
  holds no engine positions across a shift (ids and directions only).
- **Visual style:** any new look file is in `test_visual_style_rules.gd`'s painting files; no new
  shader.

### 12.2 In the real scene (mandatory; renders and numbers shown to the owner)

- **`test/probes/duel_probe.gd`** (new): two ships, each with a pilot, fight in real time in a clear
  patch of space. Reports per fight: duration, winner, each side's hit rate by range band, QE spent,
  style switches, and the **frame rate** throughout. Runs starter vs starter (skills 0.5/0.5, and
  0.2 vs 0.8), each style against each, and Warden vs starter. Pass: even fights 4–6 minutes on
  average; the higher skill wins most of 0.2 vs 0.8; **at least 120 fps** on the GTX 960 seated at
  the helm during a starter fight; no pilot ever hits a rock. A fight with a **Warden** in it is held
  to the Warden's own accepted figure (weapons spec §16.2: 109–117 fps with every gun firing, the
  Warden's frame cost a separate task), not to 120 — the designer's call after the builder check; it
  must be no worse than that.
- **Playing it:** the probe also runs a fight with you "aboard" the losing ship, to the reload, and
  one with your ship on its pilot.
- **Renders at eye height (1.6 m):** a hit seen from your helm (the flash on the enemy at 400 m and
  1 km); the cabin during a heavy hit (a frame of the dip); the enemy at 30% venting and sparking;
  the core going up and the break-apart, from the helm and from a chase view. The owner judges the
  look.
- **`fleet_play.gd`** re-run (a ship may now leave the fleet by being destroyed).
- **`ship_probe.gd`** on all three library ships (unchanged blueprints, but the rules run).

## 13. Build order

Each phase is playable at its end.

1. **Sides and a pilot that fights.** `Ship.side`, `is_hostile(shooter, node)`, the brackets and
   warning, Shift+F6 spawning, `ShipPilot` with assessment, the two styles, flying, the jink, rock
   avoidance, Destroy, the computer rule, the pilot readout. You can fight a hostile starter; it never
   dies yet.
2. **Hit feel.** The jolt, the lights' dip, the brighter burst, heavy hits knocking pieces off.
3. **Damage you can read.** Sparks by section, gas vents.
4. **Destroyed.** The explosion, the blast, the break-apart, deaths aboard, *SHIP LOST* and the reload,
   no save under attack, the starter's removal.
5. **Your ship's pilot.** The key, the WEAPONS page switch, the station without the hold.
6. **Proof and upkeep.** The duel probe and its tuning, renders, the skills, the as-built notes here.

## 14. Not in this project

The *disable* objective, looting, stealing ships, boarding a live enemy; shields; factions beyond
crew and hostile, and sides for creatures or bases; hostiles appearing in real play (encounters,
patrols, pirates); enemy crew; hostiles fleeing or surrendering (you may escape them, §5.5); wrecks to salvage; fixed guns and fighters
(weapons spec §11); missiles; the AI pilot travelling, following or warping; pilots improving over
time; more than two styles; using rocks as cover.

**Anti-goals** (it would be a failure even if it worked):

- a pilot that cheats: thrust, turn rate, QE, aim or knowledge you do not have;
- a fight that is a slog — an enemy that sits still and trades, or takes 20 minutes;
- an enemy that is unbeatable, or one that just flies at you in a line;
- hits that blind or nauseate: a strobe, a whiteout, a shake that hides the fight;
- dropping under 120 fps, or drifting from the visual style (blue sci-fi, realism).

## 15. Risks

- **The dance never appears.** A pilot that either never misses a jink or never jinks makes fights
  flat. The duel probe measures hit rates by range against the weapons spec's curve (85% at 400 m,
  ~30% at 1 km).
- **Pilots fly into rocks.** Space here is full of them; avoidance is phase 1, and the probe fails on
  any rock contact.
- **Frame budget.** Two ships firing, gas from many vents, an explosion with hundreds of chunks. Pool
  chunks and puffs; measure each phase.
- **The starter's removal.** `Fleet` and several systems assume `/Ship` always exists; the destroyed
  starter path needs care and its own tests.
- **The reload path.** Reloading the save mid-scene must leave nothing of the old fight behind;
  `get_tree().reload_current_scene()` (as F9 uses) is the model.

## 16. Upkeep (CLAUDE.md)

This project changes how ships fly, fight and end. Before it is done, in the same branch:

- **`building-a-ship`:** the pilot and what it needs from a blueprint (a computer, turrets with sky
  coverage on more than one face); the destroyed state; new numbers in `reference.md`; a line in
  `ship_probe.gd` for anything checkable (for example, which faces' turrets can bear together).
- **`designing-a-ship`:** what makes a ship a brawler or a stand-off fighter, for the designer agent.
- **`building-an-npc`:** NPCs aboard a destroyed ship die; the blast reaches creatures.

## 17. As built (2026-11-02)

The plan ran in 17 tasks (`docs/superpowers/plans/2026-10-24-hostile-ships/`). The APIs and every
number are in the `building-a-ship` skill's `reference.md`, *The pilot and the end of a ship*. This
section keeps what differs from the text above, what the proof showed, and what it left open.

**Not proved at the end of the build:** the full test suite was not run by any task (the owner's call
at the end). Targeted tests passed task by task. The final duel run was on `hostiles-t16`.

### 17.1 Numbers that moved

| What | The text above | As built | Why |
|---|---|---|---|
| Light bolt speed | 600 m/s | **350 m/s** | At 600 m/s a jink dodged little: 76% landed at 1 km against the 40% mark. It is now slower than the heavy bolt, 450 m/s. The owner chose this ("option B") and it stands |
| Light bolt life | 3 s | **3.6 s** | Keeps the reach at 1,260 m, past the turret's 1,200 m range |
| Light bolt damage | 15 hp | **55 hp** | §11's sum was wrong: a ship spawns with half its store (a starter 600 QE) that nothing refills, so 480 usable bolts, and at 15 hp they cannot take 12,330 hp. 50 hit the 720 s cap too often; 60 came in under 4 minutes once losers flew to the end |
| A light turret's firepower | 30 hp/s | **110 hp/s** | Follows. A heavy stays 40 hp/s for 5 QE/s against a light's 2 QE/s, so a heavy now buys reach, not firepower |
| Starter's hull | about 12,400 hp | **12,330 hp** | The turrets' cells took 80 hp off the midship sections |
| A stand-off's range | near the edge of its reach | **0.7 of it** (`STAND_OFF_SHARE`; 840 m on light turrets) | At 0.9 it sat past the hold-fire line, and a stand-off low on QE never fired |
| A disarmed ship | | keeps `KEEP_AWAY` −150 m, just inside the foe's reach (1,050 m from a starter) | Past the reach it flew off with its foe at its heels and the duel never ended (nobody flees, call F) |
| Fight speed | the limit | **`FIGHT_SPEED` 80 m/s**, the full limit only on a foe with no live turret | Equal top speeds made every stern chase permanent |
| Blast | around 100 m | **120 m and 400 hp** × `SCALE` 0.5..2 (the scale moves the radius only) | The starter is about 1. A spacewalker within about 90 m of a starter's core is downed |

**What the light bolt's 55 hp does elsewhere.** Two light bolts down a spacewalker (100 hp; at 15 hp
it took seven). One kills a Skitter (40 hp), a Glinter (20) or a Limpet (15); a Delver (60) takes two.
The rock creatures spec's §8.1 "A light turret bolt is 15 hp" is stale; its heavy-bolt line stands.
Its "60 hp, six bolts" is the Delver and "20 hp (two bolts)" the Glinter, both counted in the pistol's
10 hp bolts, and both still true.

### 17.2 What differs from the text

- **The pilot's flying.** It flies by a velocity hold (`FlightComputer.hold_velocity`, built for it),
  not `set_heading` and the assist toggle, and the hold's correction may boost. §5.1's list is
  otherwise kept: it writes only the stick, the hold, `clear_heading` and fire control.
- **The face.** The pilot flies `ShipPilot.sure_face`, not `Broadside.best_face`: a turret counts only
  where it still bears 10° off the face every way. `best_face` picks the nose on all three ships, on
  the rim of every half-sky, where the muzzles' height then takes the shot away.

  | Ship | `best_face`, bearing | Flown, bearing |
  |---|---|---|
  | starter | nose, 2 of 2 | forward-down 45°, 1 of 2 |
  | lamplighter | nose, 1 of 1 | forward-up 45°, 1 of 1 |
  | warden | nose, 7 of 7 | forward, up and to port, 4 of 7 |

- **The numbers' home.** The turn gain, jink push and the rest moved from `ShipPilot` into
  `PilotValues` in T16. `Broadside.DAMPING`, `RockAvoid.FEELER_ANGLE` and `RockAvoid.URGENCY` stayed in
  their own files.
- **Judgement noise** is drawn per ship and target, a steady misjudgement. A fresh draw each second
  flipped equal starters' style every second.
- **The first read.** An even fight is closed on: `BRAWL_FROM` 0.9 on a first read, and a foe with no
  live turret is always brawled.
- **The PILOT page beside WEAPONS.** §9.1 put the switch on the WEAPONS page. It is a page of its own,
  after WEAPONS, on any ship with turrets: `PILOT · ON/OFF`, `STYLE · <choice>`, and while on its
  intent and target. The key is P.
- **The pilot readout** is on F2 at the top right, not an F3-style overlay. It lists every other ship
  in contact, crew too, so H can make a crew ship hostile.
- **§8.2 step 4, for the ship you are in.** `fleet.destroy` is not called: freeing the interior would
  free your avatar, and the scene reloads anyway. `lose("SHIP LOST")` comes first, so the white comes
  with the flash.
- **The starter is held, not removed** (many ships spec §6.2 amended): asleep, hidden, out of the
  weapons group, saved `"destroyed": true`, never woken.
- **The blast lands on a ship's nearest hull-section cell,** not its nearest cell: that is often a
  component, which never moves HULL %.
- **Chunks** are `RigidBody3D`s with a `MultiMesh` of one shared block, touching only rocks. The
  break-up's gas is local to a node drifting with the hull, in `EXTERIOR_SPACE`, not world-space
  particles. The white of *SHIP LOST* is the core flash's warm white.
- **Your pilot never pursues** (§9.1 "does not follow"): out of contact it holds station and looks
  again every second.

### 17.3 Built beyond the plan

All in T16, each found by the duel probe.

- **The slower light bolt** (§17.1).
- **A wrecked cockpit is flown on the raw stick** (`ShipPilot.raw_stick`, 1692c8b). A wrecked cockpit
  refuses the assist, so a loser coasted for good; most duels lose the cockpit by about 120 s. It now
  pushes the stick toward the velocity it wants, as you would. A wrecked *computer* still ends the
  pilot (§5.6).
- **The creature launch fix** (21c26cf). `NpcDirector.promote` added a body at the holder's origin,
  your hull under the floating origin, then moved it to its site. A skitter touched the hull for a step
  from about 1 km off, and once flew it off at about 9,900 m/s. This was very likely the T6 crash with
  the hull at 0. `promote` now sets the transform first.
- **The rubble fixes** (fe43f25). A pilot's rays see only bodies, and rubble became a body 1.5 s
  ahead: the Warden flew into one at 76 m/s. A pilot sets `AsteroidStream.ANCHOR_AHEAD` so rocks are
  solid as far as it looks, `RockAvoid` also sweeps the hull's sphere, and a rock that loads inside the
  look stays a picture until it has left every look (`AsteroidBubble.cell_loaded`).

### 17.4 The duel probe (§12.2)

`duel_probe.gd`, real time, windowed at 1280×720, 20 fights, 2026-10-31 (run17). The even fight's fps is
from the same fight re-run alone, the rule in CLAUDE.md for a reading under 120.

| Mark | Needed | Result | |
|---|---|---|---|
| Starter v starter, 0.5/0.5 | mean 4–6 min | **5.95 min** (219, 315, 336, 720, 195 s; 4 of 5 decided) | pass, at the edge |
| 0.8 pilot v 0.2 | wins most | **3 of 5** (one loss, one draw) | **miss** against the plan's 4 of 5 |
| Styles | neither wins all six | brawler 5, **stand-off 0**, one draw | pass, on the letter only |
| Rock contacts, flying | 0 | **0** over 20 fights (one adrift, computer wrecked) | pass |
| Seated fps, starter duel | ≥ 120 | **131** alone; 92 in the full run | pass, see below |
| Seated fps, Warden | ≥ 109 | **128**, **127** | pass |
| Seated fps, yours / ship lost | ≥ 120 | **125**, **129** | pass |
| Light hits, 400 m | ≥ 70% | **95%** (5951/6236) | pass |
| Light hits, 1 km | ≤ 40% | **36%** (763/2133) | pass |
| Your pilot | | lost in 222 s, flown to the end | |
| Ship lost | | *SHIP LOST*, finished 3.65 s after; reload called | OK |

Light hits by band: 200 m 100%, 400 m 95%, 600 m 86%, 800 m 36%, 1 km 36%, 1.2 km 11%.

**What passed narrowly or missed, and why:**

- **The even mean, 5.95 min,** holds one 720 s draw at full value. The four decided fights average
  266 s. A second draw in five would miss. In that draw (even 3) ship a's computer was wrecked before
  60 s, so it coasted (§5.6); ship b lost both turrets by 80 s and stayed out at 1.1 km. Ship a hit a
  rock at 49 m/s and stopped firing with 119 QE left. *Why it stopped was not traced.*
- **Skill, 3 of 5.** The spread between runs is wide (1 of 5 to 3 of 5), so five fights show little.
  Fights settle at 400–600 m, where 86–95% of bolts land whoever flies, and a jink moves about 2 m. A
  turret goes at about 25 s, and a loser spends only 27–95 QE after that. A better number will not fix
  it: the miss needs a change to what decides a fight.
- **Stand-off won 0 of 6.** Its bolts land about one in three at its 840 m; a brawler's land nine in
  ten at 350–450 m. The mark passes only because one fight drew. As tuned, standing off is a losing
  choice, and the assessment still makes it. (The pass table's "chosen 1,050 m" is a misreading: in
  the logs 1,050 is a *disarmed* ship's range, still shown as STAND-OFF, and it fires nothing.)
- **Both Warden fights were 720 s draws:** stand-off v stand-off at about 960 m, the starter out of
  usable QE at 481. The Warden's reach makes it stand off and neither gives up the range. Its fps and
  rocks pass, but **no Warden fight has decided**, so §11's "a Warden on a starter: about a minute" is
  unproved against a pilot (it took 36 s against a hull worn to 4%).
- **The skill and style draws:** a ship with the upper hand spends its 600 QE at 800–1,000 m against a
  foe that will not close, and has nothing left to finish it.
- **The 92 fps reading** (even 0, in the full run) came a few minutes after the machine woke. What took
  the frames was not traced. Alone the same fight read 131, minimum second 35. Spawns and blasts take
  the seated minimum seconds to 3–12 fps.

**`ship_probe.gd` on the three library ships** (§12.2, 2026-11-02): 0 rules broken and no line
flagged. The first run read under 120 in the rock views, so each ship was run again alone. Seated by a
rock with both light groups on, then with a second ship 300 m off:

| Ship | First run | Alone | In its `.md` when designed |
|---|---|---|---|
| starter | 114, 81 | **128, 123** | 130, 130 (2026-10-02) |
| warden | 121, 89 | **117, 109** | 123, 122 |
| lamplighter | 125, 101 | **126, 104** | 127, 126 |

**The second-ship reading has fallen** and was not traced: the Lamplighter's 104 is under the 120
floor, and the Warden's 109 and 117 are under the 122–123 its `.md` records, though inside the 109–117
accepted with its guns firing. No fight or pilot is running in that view. The one-ship reading held
on the Lamplighter and the starter, so look at what a second awake ship now costs.

**`fleet_play.gd`** (§12.2), after every task: ALL OK, exit 0, 2026-11-02.

### 17.5 Known edges

- **The burst at 1 km (§6.2 "must read clearly").** At 400 m a starter is about 16 px and the burst a
  few warm pixels; at 1 km it is one yellow pixel. With the HUD on, the contact diamond sits over the
  ship and hides the burst. The owner has the renders to judge; nothing was tuned.
- **Spawn and blast hitches.** A blast frame's work is 12–22 ms. A tool that one-shots a whole hull
  costs about 465 ms in `_apply_view`; a fight wears the hull first, so play never does.
- **S on the open F2 readout** cycles a style and, being `move_back`, also takes your ship back from its
  pilot. Not exercised by the probe.
- **P is not on the controls card** (nor are T and B).
- **Your suit can tie to a hostile** within 500 m (`SuitTie` predates this project), and you would wake
  there. Not exercised by the probe.
- **A hostile bolt that hits you on a spacewalk** does not start the 10 s calm (the avatar records no
  hit source). A hostile out for you still holds the save through `targets()`.
- **A ship with no `computer` block** has a pilot nothing can kill. Every library ship has one.
- **The dorsal and ventral turrets of a starter never both bear,** so it always fights with one: a
  blueprint matter, left as it is. Task 4 suggested a flank; `sure_face` chose forward-down 45°.
- **The white of *SHIP LOST*** passes through a warm grey going to black. The owner may want it warmer
  or quicker.
- **`test_hull_lights`:** T16's accidental wide run failed one test here (light counts), on files T16
  does not touch. It was not looked into.
