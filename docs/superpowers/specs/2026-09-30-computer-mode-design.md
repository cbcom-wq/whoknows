# Computer mode — stepping up to the bridge computer to use it

**Date:** 2026-09-30
**Status:** Design approved section by section by the owner on 2026-09-30. **Built 2026-10-03** on
branch `computer-mode`; §11 is what was built and how it differs. The renders await the owner's
word.

> **Amended 2026-10-02 by the owner, before planning:** `main` moved to the world scale
> (`2026-09-30-world-scale-design.md`) and many ships (`2026-10-02-many-ships-design.md`) after
> this was approved. The map's numbers are rescaled to the new world (§4: 1 km to 9,000 km, the
> stops 2, 10, 50, 500 km and SYSTEM, the centre sliding from 500 to 3,000 km), warp limits are
> drawn at every scale, and a station finds the game's one camera director through a group (§3.1).
> The design is otherwise as approved.
**Depends on:** the bridge computer (`2026-09-25-bridge-computer-design.md`), the system skeleton
(`2026-09-27-system-skeleton-design.md`) and the warp (`2026-09-28-warp-design.md`), all on `main`
at `1282fc5`, plus the button fix on this branch (`a6e7fa8`, §1).
**Governed by:** `docs/design/visual-style.md`, and CLAUDE.md's floating-origin rule (nothing here
is outside the ship).
**Amends, once built:**
- the bridge computer spec's decision 4 (turned with the ship), decision 5 (three fixed ranges)
  and §3.4 (the rim is the only way to use the table);
- the warp spec §7.1 (the SYSTEM range as a separate framing);
- the visual style guide §3.7.

---

## 1. Why

The owner, 2026-09-29:

> I really don't seem to be able to interact with the ship computer at all. My vision is that you
> press something to start then get a interactive view brought up where you are kind of locked
> into the view to do various tasks until you exit. Here I have concepted a solar system map view.
> Right now we are trying to support selecting a destination to warp to, but the ship computer in
> general seems inoperative.

The concept image shows an orrery-style system map, a list of the system's bodies, a destination
card (distance, travel time, fuel), a route, and Zoom, Rotate, Set Waypoint and Clear Route
controls.

**Why it seemed inoperative:** the rim console's collider was an upright box round the whole
tilted console, and it enclosed all five buttons. The Interactor's ray hit the table, every prompt
was empty, and nothing could be pressed. The tests pressed the buttons in code and only measured
distance. Fixed on this branch (`a6e7fa8`): the console's collider is now in its own frame, no
farther out than its face, and a test casts the Interactor's ray at each button from the
operator's spot.

Fixing it restores the table as designed, but the design itself is the second problem. Five small
buttons, a three-line screen and ◀ ▶ through a list are a slow way to choose between a dozen
worlds 80 km apart.

### 1.1 The pitch

You walk up to the table and look at it: *[F] Use computer*. The view glides forward and down, as
it does when you sit at the helm, until you are leaning over the holo, and a cursor appears. On
the left a list reads *SYSTEM · KORVA*: the star, its planets with their moons tucked under them,
a cluster in the belt. You scroll, and the holo swells from the orrery down to the rocks around
you, then back out. You drag, and the system turns under your hand. You point at a dim world and a
tag reads *ZESU · 140 KM*. You click a bright one: an amber bracket closes round it, and the card
on the right reads *TESVOSS-68 · PLANET · LARGE*, *82 KM · 11 MIN FLYING · 41 S WARP*,
*WARP 302 QE · IN REACH*, over a button: **CHART WARP**. You press it, hear the course chime, and
press Esc. The view glides back to your head, and you walk to the helm.

### 1.2 What this adds

- **A mode** you enter at the table and leave with Esc or F, with the camera over the holo and the
  mouse free.
- **One continuous map** from 1 km to the whole system, replacing four fixed ranges.
- **Free orbit and zoom** while you are in the mode.
- **Picking with the mouse**, in the holo or from a list.
- **An overlay** with the list, the selected target's card, tabs and hints.

---

## 2. Decisions

Every row was decided by the owner on 2026-09-29/30, as recommended.

| # | Question | Decision | Alternatives |
|---|---|---|---|
| 1 | What you look at in the mode | **The holo, up close:** the camera glides to look down into the table's own 3D holo. | A full-screen flat UI; a big in-world screen. |
| 2 | Colours | **Warm, per the style guide.** The concept's layout, in the table's palette. The concept's blue is the direction rejected in style guide §7. | Blue for screens only (a rule change). |
| 3 | Mouse in the holo | **Free while locked in:** drag to orbit, scroll to zoom, R to recentre. On leaving, the holo is turned with the ship again. | Zoom only, ship-aligned; the fixed ranges. |
| 4 | Scope | **The whole map and the status page, as tabs.** The physical buttons stay. | System map and warp only; plus multi-hop routes. |
| 5 | Where the readable parts go | **A flat overlay at the screen's edges** round the holo. | Labels in the room only. |
| 6 | In and out | **F at the table; Esc or F to leave.** The five buttons keep working without entering. | Replace the buttons. |
| 7 | How zoom works | **One continuous map (approach A):** the scale is smooth, the centre eases from the ship to the star, and content shrinks in and out by scale. | Animated fixed ranges (B); focus-and-zoom on any world (C). |

---

## 3. The mode

### 3.1 Getting in

- **`ComputerStation`**, a new interactable (`Area3D` on `InteriorKit.LAYER`, in group
  `interactable`), covers the table's top and rim. Its prompt is *Use computer*. The dressing
  builds it with the `ShipComputer` at the table's fixture frame, and it holds its computer.
- **The buttons still win.** They stand proud of the station's shape, so looking straight at one
  still offers that button. The station's shape stops short of the buttons' faces.
- **Pressing F** calls `CameraDirector.use_station(station)`, as `PilotSeat.interact` calls
  `sit`. Tables are rebuilt with their ship and ships come and go (`Fleet`), so a station is never
  handed the director: it finds the game's one director in group `CameraDirector.GROUP`. The
  director:
  - turns off the avatar's control, so there is no walking, grasping or Interactor;
  - moves the camera, with the same 0.75 s cubic move as sitting, to the station's **eye**;
  - makes the mouse visible;
  - sets `is_at_station` and emits `station_changed(station)`.
- **The body stays** where it stood. Only the camera moves.
- **Not while** seated, mid-move, or in the suit (the same guards as `sit`).

### 3.2 The eye

`InteriorProps.holo_table_station_eye() -> Transform3D`, in the table's fixture frame: on the
operator's side (−z), **0.9 m back from the holo's centre and 0.5 m above it** (1.85 m up),
looking at the holo's centre, which is about 29° down, from 1.03 m away. From there the 1.0 m
holo fills most of the default view, with room at its edges for the overlay. Props still never see the grid.

While in the mode the camera orbits the holo's centre at that distance (§4.4). The eye is where it
starts, and where R returns it.

### 3.3 Locked in

`ComputerModeInput`, a node beside the `CameraDirector`, owns input while `is_at_station`. It marks
every event it uses as handled, so neither the avatar nor anything else sees it.

| Input | Does |
|---|---|
| Left click on the holo | Picks the mark nearest the cursor (§4.5) |
| Left click on the overlay | The overlay's own controls: a list row, a tab, the action button |
| Left drag (more than 4 px) | Orbits (§4.4); a drag never also picks |
| Scroll | Zooms, ×1.3 the scale a notch (§4.1) |
| R | Recentre: spin 0, elevation back to the eye's, scale unchanged |
| Tab | Next tab (MAP, STATUS) |
| Enter | The action button (§5.3) |
| Esc or F | Leave |

- **Esc.** Everywhere else, Esc releases the mouse (`Avatar._unhandled_input`). In the mode it
  means *leave*. The avatar leaves Esc, and its click-to-recapture, alone while the director
  `is_at_station`.
- **The HUD** stays out of the way: the pilot HUD is already faded out on foot, and the on-foot
  reticle and interaction prompt hide while you are in.

### 3.4 Getting out

- **Esc or F** calls `CameraDirector.leave_station()`. The camera makes the same move back to the
  head, the mouse is captured, the avatar's control returns, and `station_changed(null)` fires.
- **The holo's spin is dropped** on leaving (§4.4), so walking past, it is turned with the ship.
- **The page's state stays:** tab, selection and scale are kept and saved (§4.6).

### 3.5 Edge cases

- **Saving** waits while the camera moves (`is_moving()`, as for the helm). A game saved in the
  mode loads with you standing at the table, not in the mode.
- **A rebuild** of the ship while you are in the mode, or the table wrecked (health and damage
  spec), drops you out at once, with no move. The station is rebuilt with the table, if it still
  stands.
- **Warp:** the mode works during a warp. Charting is already allowed from anywhere (warp spec
  §4.1).
- **Another ship's table** works the same way once you are aboard it (CLAUDE.md: every ship is
  usable).
- **Two tables** on one ship: each has its own station. Only one can be used at a time, since
  there is one camera.

---

## 4. One continuous map

### 4.1 Scale

- `MapPage.range_index` becomes **`scale_m`**, the metres the holo's radius (0.5 m) shows, from
  **1 km to 9,000 km** (`SYSTEM_REACH`).
- **Scroll** multiplies or divides it by 1.3 a notch, clamped: about 35 notches end to end.
- **The five stops** stay: 2, 10, 50, 500 km and SYSTEM (9,000 km). The physical RANGE button steps to
  the next stop above the current scale, wrapping from SYSTEM to 2 km. It glides there over 0.4 s,
  smooth in log scale, instead of cutting.
- **The title** reads *MAP · 12 KM* (rounded to 1 km, or 0.1 km under 2 km), or *MAP · SYSTEM*
  once the centre is fully on the star (§4.2).

### 4.2 Centre

The holo's centre eases from the ship to the star as you zoom out:

```
w = smoothstep(ln 500 km, ln 3,000 km, ln scale_m)
centre = ship + w · (star − ship)       (in the map's frame)
```

At 500 km and nearer the map is round the ship, as today's nearer ranges are: your planet and its
moons round you. From 3,000 km it is round the star, as today's SYSTEM range is. Between, it slides. The ship's pip and heading tick are
drawn at every scale, so you can always find yourself. Without a system (a test scene), `w` is 0.

### 4.3 What is drawn at each scale

The holo's glow material is shared, so one mark cannot fade on its own. Marks leave by shrinking
to nothing across a band, as a ping already shrinks (bridge computer spec §5.2). The shrink is
`1 − smoothstep(ln full, ln gone, ln scale_m)` times the mark's size. A mark shrunk below 1 mm is
not placed.

| Content | Full size up to | Gone by |
|---|---|---|
| Salvage, signs of life | 10 km | 20 km |
| Big rocks (the sensors know them to 30 km) | 50 km | 100 km |
| Worlds, moons, clusters, the course, the charted line, warp limits | always, while inside the holo | — |
| Belts, 2,500 km scale rings | grow in from 500 km | full by 1,000 km |

- **Worlds** are drawn when they fall inside the holo. As today, only the course is pinned to the
  edge when it is outside.
- **Marks by class** (warp spec §7.1) apply once `w` > 0.5. Nearer than that, worlds use today's
  near-range sizing.
- **Reach colouring** (lit if your QE reaches it, dim if not) applies once `w` > 0.5, where warping
  is what you are choosing.
- **Contacts** are asked of the sensors out to the whole system (today's SYSTEM range,
  20,000 km) at every scale. Each source already stops at its own reach (rocks 30 km), and the
  bands decide what is drawn.

### 4.4 Orbit

Only in the mode:
- **A horizontal drag spins** the holo's contents about its upright axis, 0.4° a pixel, on top of
  the ship's turn: `HoloVolume.set_turn(ship_turn * Basis(UP, spin))`. The table stays level, and
  no mark is ever tilted out of the cylinder.
- **A vertical drag moves the camera,** not the holo. It orbits the holo's centre at the eye's
  distance, with elevation from 10° to 75°, 0.3° a pixel. At 75° the camera is 2.34 m up, under
  the 2.5 m ceiling (`InteriorProps.HEADROOM`) and its lights. Horizontal drag never moves the
  camera, so the room does not swing round you.
- **R** returns the spin to 0 and the elevation to the eye's.
- **Leaving** clears the spin.

### 4.5 Picking

- Each time it places marks, `MapPage` records what it placed as `{id, position}` pairs in the
  holo's frame: every contact mark, not stalks, ticks or rings.
- **`ShipComputer.pick(screen_pos, camera) -> StringName`** projects each through the camera
  (`unproject_position`, skipping any behind it). It takes the nearest within **24 px**, with the
  one nearer the camera winning a tie within 2 px. It sets `page.selected` and returns the id, or
  returns `&""` and leaves the selection alone.
- **Hover** uses the same search, for the tag (§5.2).
- **There are no colliders in the holo.** You can still put your hand into it.
- **◀ ▶ and the list** step through what is drawn at full size (shrink 1) at the current scale,
  nearest first, as today.

### 4.6 Save

`MapPage.save()` writes `{"scale": scale_m, "selected": ...}`. An old save with `"range": i` loads
as stop `i`, so saves from before this build keep working.

### 4.7 Placement rate

Today the marks are placed at most twice a second on the far ranges (`PLACE_EVERY`), and the turn
between placements is handled by `set_turn`. **While the scale is changing** (a scroll, or a RANGE
glide), they are placed every frame, then at the usual rate again. `PLACE_EVERY` becomes a function
of `scale_m`: 0 up to 10 km, 0.5 s beyond.

**Risk:** the 50 km scale places hundreds of marks. The probe (§8.2) times a sweep from 1 km to
9,000 km against the holo's budget (style guide §2.6). If it is over, placement while zooming drops
to 15 Hz. (As built: it was over, and the 15 Hz fallback went in; once the placing was made cheap,
it came out again. §11 has the figures.)

---

## 5. The overlay

### 5.1 Look

`ComputerOverlay` is a `CanvasLayer` with plain `Control`s. It is not a `HudElement`, because it
follows the station, not piloting telemetry.

It is the table talking, so it is drawn in the rim screen's look (style guide §2.8), not the pilot
HUD's cyan:
- `LIGHT_WARM` text;
- panels of `SCREEN_BACK` at 85% opacity, ruled in `TRIM`;
- accents by kind from `MapPage.colour_for`: worlds `WORLD`, rocks `SKY`, salvage `QUANTUM`,
  life `SIGNAL_GO`, the course `AMBER`;
- dim entries in `HOLO_DIM`.

Every colour comes from `InteriorPalette`. It uses the project's default font at a size that reads
at 1080p, with capitalised labels as on the rim.

### 5.2 Layout

```
┌─────────────────────────────────────────────────────────────┐
│ [ MAP ]  [ STATUS ]                          ESC  LEAVE     │
│                                                             │
│ SYSTEM · KORVA          (the holo, in the room)  TESVOSS-68 │
│  ● Korva                                         PLANET·LARGE│
│  ○ Tesvoss-68  ◄                                 1.6 KM ACROSS│
│     ∘ Tesvoss-68 a                               82 KM       │
│  ○ Zesu                                          11 MIN FLY  │
│  ⁘ Trell cluster                                 41 S WARP   │
│                                                  302 QE ·    │
│                                                  IN REACH    │
│                                                [CHART WARP] │
│ drag orbit · scroll zoom · R recentre · ENTER act   · 30 KM │
└─────────────────────────────────────────────────────────────┘
```

- **Top:** the tabs, left, clickable, with the current one lit. *ESC LEAVE* on the right.
- **Left, the list:**
  - with `w` > 0.5, **the system**: its name, the star, each planet with its moons indented under
    it, and each cluster. Rows are in the kind's colour, dim when out of reach;
  - otherwise, **nearby**: what is drawn at full size, nearest first, each with its distance;
  - the selected row is marked, the course's row is amber, and a click selects. The list and the
    holo's bracket always agree, because both read `page.selected`.
- **Right, the card:**
  - for the selected contact, the lines the rim screen shows (`MapPage.lines`, `warp_lines`), one
    per row;
  - under them, **the action button**: *SET COURSE*, *CLEAR COURSE*, *CHART WARP* or *CLEAR WARP*.
    It is exactly what the big button would do, and it is disabled with the reason as its label
    (*FLY · TOO CLOSE TO WARP*, *NEED 512 QE*) when it would do nothing.
- **Hover tag:** beside the cursor over a mark, the contact's name and distance, e.g.
  *ZESU · 140 KM*.
- **Bottom:** the control hints, and the scale on the right.
- **The STATUS tab:** the holo shows the miniature as today, and the card shows `StatusPage.lines`.
  There is no list.

### 5.3 The action

`ShipComputer.act()` is `press(&"big")`: the same course setting, warp charting and sounds as the
button. The overlay reads the label from `page.prompt(&"big", ctx)` and whether it is lit from
`page.lit(ctx)`.

### 5.4 The rim, meanwhile

The rim screen and the five buttons keep showing and doing what they did, reading the same page
state. Someone standing beside you sees what you are doing.

---

## 6. Architecture

### 6.1 Files

| File | Change |
|---|---|
| `src/ship/computer/computer_station.gd` | **New.** The interactable, the eye, and its `ShipComputer`. |
| `src/ship/computer/computer_mode_input.gd` | **New.** The mode's input (§3.3). |
| `src/ui/computer_overlay.gd` | **New.** The overlay (§5). Reads the page every frame and keeps no state of its own beyond hover. |
| `src/ship/computer/ship_computer.gd` | `station`, `pick()`, `hover()`, `act()`, `set_spin()`, `tab()`. |
| `src/ship/computer/map_page.gd` | `scale_m`, `zoom(notches)`, `step_range()`, the centre blend, the shrink bands, the placed list, save migration. |
| `src/ship/computer/holo_volume.gd` | `set_turn` takes the spin. |
| `src/camera/camera_director.gd` | `use_station()`, `leave_station()`, `is_at_station`, `station_changed`, orbit of the camera round the station's holo. |
| `src/avatar/avatar.gd` | Leaves Esc and click-recapture alone while at a station. |
| `src/ship/interior/interior_props.gd` | `holo_table_station_eye()`, and the station's shape. |
| `src/ship/interior/interior_dressing.gd` | Builds the station with the table. |
| `scenes/flight_test.tscn` | The `ComputerModeInput` node and the overlay layer. |

`ShipComputer` still knows nothing about ships. The station knows its computer and its frame, and
nothing else.

### 6.2 Flow

```
F at the table ─► ComputerStation.interact ─► CameraDirector.use_station
                                                  │ station_changed(station)
                         ┌────────────────────────┴───────────────┐
                 ComputerModeInput on                     ComputerOverlay shown
                         │ click ─► ShipComputer.pick ─► page.selected
                         │ drag  ─► set_spin / director orbit
                         │ wheel ─► page.zoom
                         │ Enter ─► ShipComputer.act ─► press(&"big")
                         │ Esc/F ─► CameraDirector.leave_station ─► station_changed(null)
```

---

## 7. Style

- No new shader. The holo is unchanged kit geometry on the glow batch.
- No new palette entry. The overlay uses `InteriorPalette` only, and
  `test_visual_style_rules.gd` must still pass.
- The style guide §3.7 gains a paragraph on the mode and the overlay's look (§5.1).

---

## 8. Testing

### 8.1 Automated (GUT, headless, output pristine)

**`test_computer_station.gd` (new):**
- the station is an interactable with *Use computer*, and a button looked at straight on still wins;
- entering: the avatar's control off, the mouse visible, the camera at the eye after the move, and
  `station_changed` fires;
- Esc and F each leave: the control back, the mouse captured, the camera at the head;
- no entering while seated, in the suit, or mid-move;
- a rebuild while in the mode drops you out;
- saving waits during the move.

**`test_map_page.gd` additions:**
- the scale's bounds, and 1.3 a notch;
- the centre is the ship at ≤ 500 km and the star at ≥ 3,000 km, and moves only one way between;
- each band's shrink is 1 at its full size and 0 by its gone size;
- RANGE steps the stops in order and wraps;
- the pick takes the nearest within 24 px, and nothing beyond;
- an old `"range"` save loads as its stop;
- marks are placed every frame while the scale changes.

**`test_computer_overlay.gd` (new):**
- the list is the system when `w` > 0.5 and nearby otherwise;
- a row click and a holo pick select the same contact;
- the action button's label and enabled state for each warp status and course state;
- the STATUS tab shows no list.

**Kept:** `test_looking_at_a_button_from_its_operator_s_spot_finds_the_button`.

### 8.2 Real-scene probes and renders

- **`test/probes/computer_mode_render.gd`:** the real flight scene, in the mode, rendered at about
  5 km, 500 km and 9,000 km, with the overlay. Sent to the owner.
- The same probe **times a zoom sweep** from 1 km to 9,000 km and back, and reports the worst frame
  against the holo budget.

### 8.3 Playtest checklist

- Walk up, F, and land over the holo without a jolt.
- Zoom from the rocks round you out to the system and back without a cut.
- Pick a world in the holo and in the list, and chart a warp from the card.
- Esc out, and the HUD's course diamond points at it from the helm.
- Esc and F both leave, and the mouse works afterwards.

---

## 9. Skills and docs to update in the same branch

- **`building-a-ship`:**
  - checklist: a `computer` needs room at its eye (1.85 m up, 0.9 m behind the holo's centre, and
    up to 2.34 m while orbiting) clear of the ceiling and walls;
  - `reference.md`: the eye, the scale bounds and bands, and the pick radius;
  - `ship_probe.gd`: prints each station's eye, and whether it is clear.
- **The bridge computer spec** and **the warp spec:** amendment notes at the top.
- **The visual style guide** §3.7.

---

## 10. Not in this build

- **Multi-hop routes** (the concept's Route panel). The warp charts one hop.
- **Focus on any world** (approach C): re-centring on a distant planet to see its moons.
- **Gamepad** control of the mode.
- **Picking in the holo without entering** the mode.
- **More tabs** (log, trade, messages). A new `ComputerPage` gets a tab for free.

---

## 11. As built

Built on `computer-mode` (2026-10-02 to 2026-10-03, nine tasks, plan
`docs/superpowers/plans/2026-10-02-computer-mode.md`). Everything in §3 to §9 is in, with these
differences, each ruled during the build:

- **Drawn and picked are two sets.** `MapPage.shown()` is what is drawn at the scale shown, marks
  shrinking across their band included; `targets()` is what ◀ ▶, the list and the mouse step
  through, full size at the scale chosen (§4.5). The plan drew only targets, which left the shrink
  bands dead: a mark popped out instead of shrinking. The course is always drawn at full size and
  never shrinks away.
- **Only targets are pickable** (`placed_marks` records a mark only if it is a target), so a
  shrinking rock can be seen but not clicked.
- **A station yields to items.** Its box covers the table's top, so the Interactor, landing on a
  station, first offers an item near the line of sight (a mug set down on the table).
- **Dropping out** (§3.5) is wider than a rebuild or a wrecked table: the director drops you out
  whenever the avatar can no longer be at the station, blacked out, blown into the suit, or no
  longer in the station's ship. F8 refuses at the station with *AT THE COMPUTER*.
- **A drag cannot outlive its button.** Mouse motion with the left button up ends a drag, so a
  release swallowed elsewhere leaves no phantom orbit.
- **Overlay buttons take no keyboard focus** (a focused `Button` takes Tab and Enter before the
  mode sees them), and the hover tag hides while the cursor is over a panel.
- **A far world picked in the list** (one outside the holo between about 1,200 and 9,000 km, where
  it is no target) zooms the map out to the whole system first, then selects it.
- **The action button** reads the big button's own prompt (*SET COURSE*, *CHART WARP*...), lit
  whenever the big button is, and says *NO ACTION* only when the big button is dark. The reason a
  warp would not go (*FLY · TOO CLOSE TO WARP*, *NEED 512 QE · STORE 300*) is the card's third
  line (`warp_lines`), not the button's label, as on the rim.
- **The eye** is `InteriorProps.holo_station_eye(elevation)` with `HOLO_STATION_DISTANCE` 1.03 m
  and `HOLO_STATION_ELEVATION` 29°, not `holo_table_station_eye()`; the station's box is
  `HOLO_STATION_SIZE` (1.1 × 0.14 × 1.1 m, 0.93 m up).
- **RANGE glides** in log scale with a 0.1 s time constant (`MapPage.GLIDE`), about half a second
  to settle, rather than a fixed 0.4 s ease.
- **The overlay's text is outlined** in `SCREEN_BACK`, and the action button is ruled in `TRIM`.
  Both came from the first renders: the tabs and *ESC LEAVE* were cream on the bridge's cream
  ceiling, and the action read as one more line of the card.

**The zoom's cost** (§4.7, `test/probes/computer_mode_render.gd`, 1280 × 720 windowed on the
build machine, the computer's own processing paused so each frame's holo update is the timed
one). A placing costs more the farther out it is, mostly the belts', scale rings' and warp limits'
ticks. As first built, every tick made a UniversePoint, worked the star's offset out again and
undid the frame's basis: a placing took about 1 ms at 500 km, 4.5 ms at 1,000 km, 8 ms at 3,000
km and 11.5 ms at 9,000 km (headless), and the sweep from 1 km to 9,000 km and back, one notch a
frame, was:

| Placement while gliding (as first built) | Worst frame | Where | Mean over the sweep |
|---|---|---|---|
| every frame (as planned) | 12.0-15.3 ms | 3,700-8,200 km drawn | 3.2 ms |
| 15 Hz past 10 km (`GLIDE_PLACE_EVERY`, the fallback) | 10.1-10.3 ms | 3,800-5,200 km drawn | 1.1 ms |

A still SYSTEM placing then cost 12 ms (14.8 ms at worst) twice a second, a rhythmic stutter.

**The placing made cheap** (the final review). `MapPage._place` works out once a placing what
every mark reads (`MapPage.Placing`: the frame, the centre, metres to the holo, whether the map is
round the star, the ship's place). The map's frame is orthonormal, so a ring's or a limit's tick
is its centre plus a unit circle times its radius, from static tables, with no UniversePoint and no
basis undone; a belt's circle is turned into the map's frame once a placing; a scale ring wholly
outside the holo is skipped; ticks go to the holo a ring at a time (`HoloVolume.add_ticks`), and
`HoloVolume.inside` is `place`'s pin test without a Dictionary. A guard in `test_map_page.gd`
holds every mark at SYSTEM and at 500 km where the old placing put it, to 1e-4. A placing now takes
(headless) about 0.5 ms at 500 km, 0.7 ms at 1,000 km, 1.2 ms at 3,000 km and 1.9 ms at 9,000 km:

| Windowed, three runs | Worst frame | Where | Mean |
|---|---|---|---|
| the sweep, placed every frame | 2.2-2.6 ms | 1,000-5,200 km drawn | 1.0-1.1 ms a frame |
| a still SYSTEM placing (twice a second) | 2.8-3.4 ms | | 2.2-2.6 ms |

The worst frame placing every frame is under 4 ms, so the 15 Hz fallback is gone and a glide
places every frame, as §4.7 planned; the tick cache it allowed for was not needed.

**Renders** (`computer_mode_render.gd`): `mode_5km`, `mode_500km`, `mode_system`, `mode_world`
(the system, the nearest planet selected and the cursor's tag on it), `mode_orbit` and
`mode_status`. The starter starts inside a belt cluster with no world within 500 km, so the
500 km shot shows the ship and the cluster only. `fleet_play.gd` passes (ALL OK) on the branch.
