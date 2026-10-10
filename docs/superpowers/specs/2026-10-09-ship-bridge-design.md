# Ship bridge — a command bridge for big ships

**Date:** 2026-10-09
**Status:** Designed with the owner on 2026-10-09; built on branch `bridge` the same day (§8).
**Depends on:** branch `ship-designer` at `f702cb9` (the ship designer project; not yet on `main`)
**Amends:** the cockpit pod spec (`2026-09-23-cockpit-pod-design.md`) §4–§5: a ship flown from the
new `helm` builds no pod; the ship library spec's `NO_POD` rule (§4) becomes `NO_HELM`
**Governed by:** `docs/design/visual-style.md` (binding: palettes, the three-shader interior budget,
renders at eye height), `CLAUDE.md` (every ship is usable; every ship lives in `data/ships/`)

---

## 1. Why

The owner judged the first two designed ships (2026-10-09): "The exteriors look pretty cool. I
think biggest complaint is the cockpit. The cockpit seems like it is being just copied and pasted
from the starter model. These big ships would benefit from more of a bridge with a wide looping
view and a pilot seat kind of set back with other control seats included. Think about how larger
ship bridges are usually designed in media." The reference was a film starship bridge: a wide
forward view, a pilot's seat at the front, a raised command chair behind, crew stations, warm
beige walls, wood-toned consoles and soft cove light, which already sits inside the style guide.

Today every ship has one seat, `pilot_seat`, and a helm facing a canopy always builds the
starter's cockpit pod: a 2 m alcove jutting through the glass. It suits a shuttle and nothing
bigger.

**Success:** the Warden, rebuilt with a bridge, puts you at a forward helm behind a wide band of
glass that wraps the bow's corners, a captain's chair raised behind you, crew stations either
side; you can sit in each, look out, stand and walk the bridge; it flies as before; and the
owner finds it reads as a warship's bridge.

## 2. Decisions

| # | Decision | Why |
|---|---|---|
| 1 | **New bridge blocks, placed one by one** (approach A of three) | The owner's choice. The designer agent places them as it places every block, and the rules check the result; a bridge fits each ship's shape (B, a `bridge` room template, fought odd shapes; C, a flag to switch the pod off, hid a mode and gave no stations) |
| 2 | **The pilot sits forward; the raised chair is the captain's** | The owner's words: "The pilot would have a forward seat. The raised area would be for a captain not a pilot." |
| 3 | **Only the pilot's seat flies** | The owner's choice. One flying seat per ship, as today: nothing about who flies changes in flight, the camera, saving or the HUD |
| 4 | **The other seats are sittable, with jobs later** | The owner's words: "They are just sittable but may have jobs in the future, things like weapon controls, damage control." Each has an empty job slot (§3.3) |
| 5 | **Wraparound windows, real glass** | The owner's choice over a viewscreen: a continuous band across the bridge's front, round the corners and down the sides, looking at real space |
| 6 | **The pod stays for small ships** | The starter and every ship flown from a `pilot_seat` look and work exactly as now |
| 7 | **The dais is reached by a ramp** | The avatar (a `CharacterBody3D`, 45° floor limit) has no step-up; a 0.25 m rise over 0.5 m is 27° |

Rejected: a viewscreen instead of windows (the owner's choice, §2.5); the captain's chair flying
too (two helms touch flight, camera, saving and the HUD; §2.3); set-dressing-only seats (a stage
set, and no room for jobs); a 45° chamfered glass corner (the grid has no diagonal faces).

## 3. The blocks and the seats

### 3.1 Three new blocks

Each is a MOUNT fixture (walkable furniture, like `computer`), with a `.tres` in `data/blocks/`, a
base token in `ShipPlan.BASE` (§6.3) and its props in `InteriorProps`, built from
`(kit, frame, variety)` in the palettes.

| Block | What it is | Flies | t | MW |
|---|---|---|---|---|
| `helm` | The pilot's forward station: a seat at a low desk set just behind the glass. The same flight wiring, stick, throttle pads and HUD as `pilot_seat`; **never a pod** | yes | 0.6 | 0.5 |
| `captain_chair` | A bigger chair on a dais (§5.1), looking out over the front row. Armrest pads, no stick | no | 0.8 | 0.2 |
| `crew_station` | A seat at a console of glowing screens, all decoration for now; the console faces the way the block does | no | 0.5 | 0.3 |

The masses and draws are the plan's to tune; the HP follows `pilot_seat` (60) for all three.

### 3.2 Seats generalise

A new base class `Seat` (`src/avatar/seat.gd`, a `StaticBody3D`) holds what every seat shares: the
eye, `STAND_SPOTS` and `stand_spot(avatar)`, the prompt, `interact`, and the frame it is placed
from (`InteriorDressing.fixture_frame`). `PilotSeat` becomes a `Seat` with `flies := true`;
`CaptainChair` and `CrewStation` are `Seat`s with `flies := false`, their own eyes and stand spots.

`CameraDirector.sit(seat: Seat)` and `sit_now(seat)` take any seat. **Only a seat that flies**
hands over the ship's controls, emits `piloting_changed(true)` and shows the cockpit view. At a seat
that does not fly:

- **the mouse looks around** from the seat's eye, within ±100° of yaw and ±60° of pitch of the
  way it faces; nothing else moves;
- the flight keys and the stick do nothing; the HUD shows the ship's readouts (speed, heading, QE,
  hull) and no flight controls;
- **F stands you up** to the seat's stand spot, as at the helm, with the same camera move.

The ship builds one `Seat` node per seat fixture (`Ship._place_seat` today places the one
`PilotSeat`; it places them all), each named for its cell, rebuilt with the interior.

### 3.3 The job slot

Every seat that does not fly has `job: SeatJob` (`src/avatar/seat_job.gd`), null in this project.
A `SeatJob` is told `sat(avatar)` and `stood(avatar)`, may own the console's screens, and may take
input while someone sits. Weapon controls and damage control will be `SeatJob`s; nothing in this
project makes one. A test pins that a seat with a job set calls it.

### 3.4 One helm

A ship has **exactly one** flying seat: a `pilot_seat` or a `helm`. Everything that names the helm
by id names a list, `InteriorLayout.HELM_IDS := [&"pilot_seat", &"helm"]`: the validator's
`HAS_PILOT_SEAT`, `ShipRules`, `Ship.helm_cell()`, `DeckPaths` (never past the helm), the droid's
routes, `ShipDamage`'s cockpit component, F8 boarding, the stand cell, and the flight scene's
avatar start (`_deck_spot`). Captain's chairs and crew stations may be any number.

### 3.5 Saving

A ship's save records the seat you sit in by its cell (`seat_cell`), and loading sits you there
with `sit_now`, as it does for the helm today; a save from before this project, with no
`seat_cell`, sits you at the helm when it says you were seated.

## 4. The wraparound windows

### 4.1 The switch is the helm

A ship flown from a **`helm`** has every canopy group glazed as a **band** (§4.2). A ship flown from
a `pilot_seat` keeps today's pod, shoulders and rounded nose exactly. Every ship in the library
today has a `pilot_seat`, so none of them changes.

### 4.2 A band, inside

- Each canopy face gets **one tall pane, from a 0.85 m sill to 2.3 m**, under the 2.5 m headroom,
  filling the cell between chunky posts at the cell edges, so a row of canopy cells reads as one
  continuous strip of glass.
- A sill ledge runs under it with a lit strip; the posts, sill and header are the existing glass,
  frame and trim materials and colours (`InteriorPalette`).
- **Round the corners:** canopy cells down the bridge's sides make side bands. Where a front band
  meets a side band the walls meet at a right angle, with one heavy corner post, so the view turns
  the corner with a post in it. The grid has no diagonal faces, so there is no 45° glass corner.
- The `helm` sits about 1.2 m behind the glass, its desk below the sightline; the captain's eye is
  0.25 m higher on its dais, over the front row.

### 4.3 A band, outside

Each pane gets its matching window on its canopy cell's outer face, sized to it, on the canopy's
slope as windows already sit (`HullLayout._window_on`). The agent orients side canopy cells so their
slopes face outward. `WINDOW_UNMATCHED` (existing) breaks a ship whose band has glass inside and
solid hull outside.

### 4.4 What it costs

Every window looks through the one shared outside render (`CanopyPortal`), so more glass costs fill,
not a second render; your own hull never shows, as through every window today. **No new shader**
(the style guide's interior budget is three). A bridge ship's worst view holds **120 fps** in the
probe, as every ship must.

## 5. The layout

### 5.1 The dais

A `captain_chair` cell gets a **platform 0.25 m high** over its 2 m cell: a **rail** on the side the
chair faces and on both flanks, and a **0.5 m ramp across its back edge** (27°, under the avatar's
45°). The chair stands centred on it. The platform is the floor collider: you walk up the ramp,
stand on the dais and sit. The cell stays walkable, a fixture the droid and the routes go round,
not through, like the bridge computer.

### 5.2 How a bridge is drawn

The design skill's worked example, and the rule of thumb:

- **the glass:** a row of canopy cells across the bow, wrapping one or two cells down each side;
- **the front row**, just behind the glass: the `helm` at its centre, `crew_station`s either side,
  all facing forward;
- **an open row behind it** to walk along (the front row is fixtures, and routes never cross one);
- **the `captain_chair`** on the centreline behind that, facing forward, open floor round it and
  behind its ramp;
- at least **5 cells wide and 3 deep**, on the one walkable storey.

A ship over about 150 blocks should have a bridge; the starter's size and below, a pod.

## 6. The rules and the rest of the game

### 6.1 Rules (`ShipRules`; the catalog test holds every ship to them)

| Rule | Breaks when |
|---|---|
| `NO_HELM` (replaces `NO_POD`) | no `pilot_seat` looks straight at a canopy face (a pod), and no `helm` has a canopy face straight ahead of it (a bridge) |
| `TWO_HELMS` | more than one flying seat |
| `NO_STAND` (now every seat) | a seat with nowhere to stand up to: behind and beside it no open floor |
| `SEAT_FACES_WALL` | a crew station or captain's chair facing a wall or a solid block within one cell (a station at the glass faces glass, which is fine) |
| `DAIS_BLOCKED` | a captain's chair whose ramp side is not open floor |
| `UNREACHABLE` (extended) | a seat you cannot walk to from the airlock |

### 6.2 The rest

- **The droid** tends crew stations' and the captain's chair's screens as it tends consoles.
- **Damage:** the `helm` is in the cockpit component with the canopy, so a hurt or wrecked bridge
  weakens or stops flight assist as a hurt pod does; stations and the chair are hull blocks for now.
- **F8** boards to a ship's helm.
- **The probe** (`ship_probe.gd`) sits in every seat in turn and stands back up (flagging `STUCK`),
  renders the view from each seat and the bridge from the dais at eye height, and prints a `seats`
  line (helm, chairs, stations).

### 6.3 The designer

`ShipPlan.BASE` gains tokens for the three blocks (`Hm`, `Cc`, `Cs`), checked by its test.
The `designing-a-ship` skill gains a section on bridges (§5.2) with a worked example; the agent
file says a big ship gets a bridge.

## 7. Proof

- **GUT:**
  - `Seat`, `PilotSeat`, `CaptainChair` and `CrewStation`: sitting, standing, looking round within
    the limits, only the pilot's seat piloting, a job slot called when set;
  - the save: seated at a station round-trips; an older save seats you at the helm;
  - the layout: a `helm` ship has bands and no pod; a `pilot_seat` ship is unchanged (the starter's
    pins and renders);
  - the dais: walkable up its ramp, its collider where it is drawn;
  - every new rule broken by its own copy of a bridge fixture ship, and the starter breaking none.
- **A bridge fixture** (`test/fixtures/bridge/`): the smallest ship with a full bridge (helm, two
  stations, a captain's chair, a band round the corners), proven usable (`ship_use.gd`).
- **The Warden rebuilt** with a bridge, by the designer agent, re-proven (catalog, probe, arrival),
  on its own branch `ship-warden` rebased onto `bridge` (a revision: `to-plan warden` first); the
  owner judges it. That is the acceptance.
- **Renders for the owner,** eye height: the bridge from the helm, from each station, from the
  captain's chair, and from the bridge's back; outside, the band from the bow quarters.

## 8. What was built (2026-10-09)

Built natively from `docs/superpowers/plans/2026-10-09-ship-bridge.md` (14 tasks; the 14th is the
Warden's rebuild, after the review).

- **The blocks:** `helm`, `captain_chair`, `crew_station` (MOUNT, 60 hp; tokens `Hm`, `Cc`, `Cs`).
- **One list of helms**, `InteriorLayout.HELM_IDS`, everywhere the helm was named; the chairs and
  stations are quiet fixtures.
- **The band** inside (a pane per canopy face, half a post at each edge so neighbours share one)
  and outside (a window per pane); a band ship's lights panel on the helm desk.
- **The dais** (platform, 27° ramp, rails, colliders) and the captain's and crew station's props.
- **`Seat`**, `PilotSeat`, `CaptainChair`, `CrewStation`, `SeatJob`; the ship builds a seat per
  chair and station; the director sits you in any seat, handing over the controls only at the
  helm; the mouse looks round elsewhere; the save remembers the seat.
- **The rules** `NO_HELM`, `TWO_HELMS`, every seat's `NO_STAND`, `SEAT_FACES_WALL`,
  `DAIS_BLOCKED`, seats `UNREACHABLE`.
- **The bridge fixture** (`test/fixtures/bridge/`, 127 blocks, 117.5 t): no rule broken, usable,
  every seat sat in and stood up from. **Probed:** 125 fps in the worst view (the starter 129), 124
  with a second ship; 15 windows outside for 15 inside.

**The HUD at a seat that does not fly** is the walking HUD (hull and QE): the plan's reading of
§3.2's "readouts"; speed and heading at a station come with its job.

**Rulings made in the build** (the ledger's):

- The plan's `task-start`/`task-done` scripts cannot run under the worktree guard; each task's
  final run was made by hand and ledgered.
- Three tests named `InteriorLayout.HELM_ID` meaning the pod helm; renamed `POD_HELM`.
- `InteriorDressing.build` puts its root under the body itself; the tests do not add it again.
- The plan's hull-window test passed before the change (a nose's windows make the same count on
  this ship); it was strengthened to one window per pane at the pane's width.
- A built seat's shape is counted with `find_children(..., owned = false)`.
- The test helper `_set` clashed with `Object._set`: renamed `_set_block`.
- The starter's `NO_POD` test now expects `NO_HELM`.
- The fixture broke `NO_PIECES` (its bow had nothing outside the shell to lose): wedges at the
  empty bow corners, so 127 blocks, not 125.
- **Standing from the captain's chair** put you at dais height on the ramp's edge, to drop 0.25 m:
  `CaptainChair.DAIS_STAND_SPOTS` put you on the floor past the ramp (a test failed first).
- The probe flagged the captain's chair `STUCK`: the droid stood in the corridor behind it; the
  probe now prints where you stood and the nearest npc, and says so instead.
- **Tuned at the renders:** one shared post between panes (whole posts at both edges made a double
  post in the pilot's view), and the sill's lit strip dimmed (a hard white bar).

**Changed at the final review** (a fresh reviewer, Opus): seats survive a rebuild (a block hit
had freed the camera on a station's eye), a game loaded at a station hands over no controls, the
prompt clears on any sit, and the band's windows outside stop at the canopy slope's top edge with
their frames inside the cell (they had lain over the blocks above and crossed at the corners).

**Acceptance** (Task 14, 2026-10-09): the `ship-designer` agent (sent by type) rebuilt the Warden
with a command bridge on `ship-warden` (`2e12fa9`, rebased onto `bridge`): 311 blocks, 262.0 t;
the helm forward at the glass, crew stations at both corners of the glass and one more to
starboard, the captain's chair on its dais two rows back with the holo table to port; the band
across the bow and three cells down each flank (20 windows outside for 20 inside); turns 1.13 /
0.59 / 1.40, forward 21.8 (was 1.08 / 0.61 / 1.39, 21.9); no rule broken; worst view 123 fps.
Its lessons are in the designing-a-ship skill's §4b. The owner's verdict: not yet given.

## 9. Not in this project

- **Jobs for the seats** (weapons, damage control): the slot is built, nothing fills it.
- **Crew NPCs** sitting at stations.
- **A viewscreen** (§2, rejected for now).
- **A bridge for the Lamplighter:** its crossbar suits a pod; the owner may ask for one later.
- **Merging `ship-designer` to `main`:** the push was refused by this session's permission check
  (2026-10-09) and waits for the owner.
