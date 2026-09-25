# Bridge computer — a holo table that knows what is out there

**Date:** 2026-09-25
**Status:** Design approved section by section by the owner on 2026-09-25. It awaits the owner's
review of the written spec. No code has changed.
**Depends on:** quantum energy, built at least through its Task 10
(`docs/superpowers/specs/2026-09-24-quantum-energy-design.md`, plan
`docs/superpowers/plans/2026-09-24-quantum-energy.md`). The computer is built after quantum
energy. It uses:
- `ReadoutPanel` and the quiet fixtures (quantum Task 3);
- the store (Task 4);
- the suit cell (Task 7);
- salvage, `Contact` and `ShipSensors` (Task 10).

It also builds on `main` at `7609d0f`: the floating origin, the asteroid groups and the flight
controls.
**Governed by:** `docs/design/visual-style.md`, and CLAUDE.md's floating-origin rule
**Plan:** to be written, `docs/superpowers/plans/2026-09-25-bridge-computer.md`
**Amends, once approved:**
- quantum energy §10.4, §12, §14, §15 and §17, and its plan's Task 10 (§13 here);
- the slice spec's §5 (the catalogue);
- the interior redesign's §7.5 (the starter's bridge);
- the visual style guide.

---

## 1. Why

The owner, 2026-09-25, on how to find salvage:

> A HUD marker and an indication on a new bridge ship computer which can show a map. Far away it is
> a general direction ping, as you get closer it becomes a region not a point so the player might
> have to search around a bit to find it.

The quantum energy spec built the HUD marker and left the computer to this spec. The owner wanted
it thought through before anything is built, and chose for it to do more than salvage (§2).

What exists today (once quantum energy is built):
- **The HUD** shows salvage as a ping far off and a region close by (quantum spec §10.4), but only
  the nearest three clouds, and only while you are seated or on a spacewalk.
- **Nothing shows the neighbourhood.** Asteroid groups are 3–6 km apart. You see big rocks through
  the canopy out to 30 km, but nothing tells you which is which, how far, or where the salvage is.
- **The bridge:** the helm is forward, the quantum core at the centre, and the machine against the
  back wall in the starboard corner. The port back corner, (−1, 0, −1), is free.
- **Live-data screens** so far are text: the airlock's panels and the machine's screen, a few
  capitalised words in `Label3D` (style guide §2.8). None shows a picture of anything.

### 1.1 The pitch

You come up the corridor onto the bridge. On your left, a round table stands on a glowing plinth,
and above it hangs a small glowing world: a warm chevron at the centre that is your ship, a bright
dot just ahead of it, the big rock you are parked beside, and a scatter of dots beyond, the other
groups. Every few seconds violet dots blink out among them: pings.

Press RANGE twice and the world swells. The dot ahead becomes a big faceted ball, with a soft
violet sphere beside it: salvage, close enough to search. Press RANGE again and you are back among
the groups. Press ▶ until an amber bracket closes round a far ping, *SALVAGE · ~4 KM*, and press the
big button: *COURSE SET*. You step round the core into the chair, and an amber chevron sits on the
HUD, pointing the way.

On the way, press PAGE: the world folds into a small glowing model of your own ship, turning
slowly over the table, with your store and your power on the rim.

### 1.2 What this adds

- **A holo table** on the bridge, a fixture any blueprint can place.
- **Pages:** MAP and STATUS now, and room for more.
- **A map** of what the ship's sensors know, turned as the ship is, at 2, 10 and 30 km.
- **A course:** pick a big rock or a salvage cloud, and the HUD points the way.
- **Your ship in miniature** on the status page.
- **The ship's sensors:** one place every system asks what is out there.

---

## 2. Decisions

Every row was decided by the owner on 2026-09-25, as recommended unless it says otherwise.

| # | Question | Decision | Why | Alternatives |
|---|---|---|---|---|
| 1 | What the computer does | **A map, a course marker, ship status, and room for later pages.** | The owner chose all four. | The map alone. |
| 2 | What it is | **A holo table:** a round console with a small 3D map floating above it. | Space is 3D, and the holo shows height honestly. It is built from the kit, with no new shader. | A wall screen with a 2D top-down map and height stalks. Both. |
| 3 | What the pilot gets | **The course on the HUD.** You plan at the table on foot and fly by the HUD. The helm's screens stay set dressing. | The simplest, and the table stays the place you go to think. | A small map on the helm screens. Picking a course from the seat. |
| 4 | How the map is turned | **With the ship.** The map is the world outside shrunk into the room: a rock at the table's forward edge is dead ahead. | It always answers "which way do I go?". | Fixed to the universe. Switchable. |
| 5 | How far it reaches | **Three ranges: 2, 10 and 30 km,** stepped by a button. | Each range shows what matters at its scale: the group you are at, the salvage sensor's reach, and every big rock loaded. | A fixed 10 km. A smooth zoom. |
| 6 | The course | **Big rocks and salvage clouds on the current range, nearest first.** A course to salvage stays as vague as the salvage marker. It clears itself on arrival, or when pressed again. | The vagueness the owner chose for salvage survives the map. | The same, but the course stays after arrival. Any point, chosen by pointing into the holo. |
| 7 | The status holo | **Your ship in miniature,** from its own hull, slowly turning. | Any blueprint gets its own model, and damage and systems can light up on it later. | The holo goes quiet. The store as a glowing column. |
| 8 | How the computer learns what is out there | **A sensor layer:** `ShipSensors` gathers `Contact`s from sources. | Later features add a source, and the computer never changes. The HUD and the map share one answer. | Reading each system directly. Mirroring the HUD. |

---

## 3. The holo table

### 3.1 The block

| Block | Category | Occupancy | Mass | Power | Notes |
|---|---|---|---|---|---|
| **`computer`** (new) | Interior | MOUNT | 0.3 t | draws 0.3 MW | a fixture, drawn by the dressing; hp 60 |

- **A fixture,** like the helm, the core and the machine: `InteriorDressing.draws_fixture` gains it,
  and it builds from its fixture frame.
- **A quiet fixture:** `InteriorLayout.QUIET_FIXTURES` gains it (quantum spec §6.1), so it leaves the
  bridge's floors, consoles and portholes as they are.
- **Not required.** The validator does not ask for one. A ship without a computer still flies, and
  its sensors still feed the HUD. Rule 4 already holds every MOUNT reachable on foot.
- **Its frame faces its operator:** −z of its fixture frame points toward where you stand to use it.
  The rim screen and the buttons are on that side.

### 3.2 On the starter

```
 z \ x       −1             0              +1
  −3        deck       pilot_seat         deck            ┐
  −2        deck      quantum_core        deck            │ bridge
  −1      computer        deck       quantum_machine      ┘
   0      bunk_room       deck           galley
```

- **At (−1, 0, −1),** the port back corner, mirroring the machine, and facing starboard (+x). You
  use it from (0, 0, −1), looking to port, which is also where you start.
- **Walking round it:**
  - between the table's edge and the core's corner there is 1.4 m clear, so the walk from the
    corridor round the core's port side still works;
  - the table stands 0.45 m off the port wall, a gap nobody walks.
- **The starter's figures move slightly:** 300 kg at cabin level, to port. That eases the yaw
  imbalance the machine's 500 kg to starboard caused. The plan re-measures and pins every figure of
  quantum spec §5.4 in its Task 1.

### 3.3 The look

The 1980s-bridge language: consoles that seem to float on glowing bases, black-glass readouts.

`InteriorProps.holo_table(kit, f, variety)` builds the fixed parts in the fixture frame:
- **the pedestal:** a round `WALL_LOW` column on a glowing plinth disc;
- **the table:** a bevelled round top 1.1 m across at 0.9 m up, with a `TRIM` rim and a black-glass
  (`SCREEN_BACK`) centre, ringed by a soft glowing emitter;
- **the rim console,** on the operator's side:
  - a tilted screen, 0.5 × 0.18 m;
  - five chunky buttons beneath it: PAGE, RANGE, ◀, the big button and ▶;
- **frames it publishes:** `holo_table_volume()` (the holo's centre and axes), `holo_table_screen()`
  and `holo_table_buttons() -> Array[Transform3D]` (PAGE, RANGE, ◀, big, ▶).

Collider: a box 1.0 m square and 0.95 m tall. **The holo has no collider:** you can put your hand
into it.

**The holo volume** is a cylinder 1.0 m across and 0.6 m tall, from 1.05 to 1.65 m up, over the
table's centre. Standing at 1.6 m eye height you look slightly down into it. Everything in it is
chunky glowing kit geometry on the glow batch (§11), so it dims with the rest of the glow in low
power (quantum spec §8.3).

### 3.4 The rim

- **The screen** shows a title line and up to three lines, in `LIGHT_WARM` on the screen black, the
  airlock panels' look (style guide §2.8).
- **The buttons are `ReadoutPanel`s** (quantum spec §14.1): the big button with the screen, the other
  four small, with no screen, like the machine's arrows.
- **A button a page does not use is dark,** and its prompt is empty. The Interactor passes over it.
- **Prompts:** *Next page*, *Range 10 km*, *Previous target*, *Next target*, *Set course* or *Clear
  course*.

### 3.5 Pages

The table shows one page at a time, and PAGE steps through them, wrapping round. **This build has
MAP and STATUS.**

A page is a `ComputerPage`, a small object:
- `title() -> String`;
- `lines(ctx) -> PackedStringArray`, up to three;
- `lit(ctx) -> Array[StringName]`, the buttons it uses (`&"range"`, `&"prev"`, `&"big"`, `&"next"`);
- `big_colour(ctx) -> StringName`: `&"go"`, `&"amber"` or `&"dark"`;
- `press(button, ctx)`;
- `holo(volume, ctx, delta)`: what the holo shows this frame.

`ctx` is the `ComputerContext`: the ship's sensors, its quantum plant, its stats, its hull, the
avatar, and the universe. A later page (a log, messages, trade) is a new `ComputerPage` added to the
table's list. The table itself does not change.

---

## 4. The ship's sensors

### 4.1 Contacts

A **`Contact`** is a small pure record of one thing the ship knows about:

| Field | Meaning |
|---|---|
| `id: StringName` | stable across refreshes: `&"rock:<cell>"`, `&"salvage:near"`, `&"salvage:<cell>"` |
| `kind: StringName` | `&"rock"` or `&"salvage"` today |
| `label: String` | *ROCK* or *SALVAGE* |
| `point: UniversePoint` | where the sensors say it is |
| `precision: StringName` | `&"exact"`, `&"ping"` or `&"region"` |
| `radius: float` | a rock's bounding radius, or a region's 75 m; 0 for a ping |
| `km: int` | a ping's reported distance, to the nearest kilometre |

A contact never carries more than the sensors know. A salvage ping's `point` is where the ping
says, error included; a region's is the region's centre, never the cloud's.

### 4.2 Sources

A source is any object with:
- `contacts(focus: UniversePoint, range_m: float, time: float) -> Array[Contact]`;
- `contact(id: StringName, focus: UniversePoint, time: float) -> Contact`, or null if it is gone.
  This is how a course is followed beyond the current range.

**Two sources in this build:**
- **`SalvageField`** (quantum spec §10): one contact per cloud with something left, from
  `SalvageSense`. A ping beyond 2 km, a region within 2 km. Inside the region it is still a region
  contact; the HUD fades it, and the map still draws the sphere round you.
- **`RockContacts`** (new, pure): one exact contact per big rock within 30 km, read from its own
  `AsteroidRecipe` made with the stream's seed (`cell_rocks(Tier.GIANT, cell)`).
  - It reads about 2,200 regions at scene start, then one slab of 169 as the focus crosses into a
    new 5 km region.
  - A rock you have shoved about is still shown at its recipe position, as salvage placement
    already accepts (quantum spec §10.2).

### 4.3 `ShipSensors`

- **A `Node` under `Ship`, `Ship/Sensors`,** created in code like `Airlocks`. It lives across
  rebuilds. The ship knows nothing about salvage or rocks: the flight scene registers the sources.
- **`add_source(source)`**.
- **`contacts(range_m) -> Array[Contact]`:** every source's contacts within range, sorted nearest
  first. The list is cached and refreshed at 4 Hz from the universe's focus: the hull aboard, you
  on a spacewalk.
- **The course:**
  - `course: StringName`, empty for none;
  - `set_course(id)` and `clear_course()`;
  - `course_contact() -> Contact`, looked up through its source by id, whatever the range;
  - signal `course_changed(id)`.

  There is one course per ship. It lives in the sensors, so the HUD and every table on the ship
  agree.

---

## 5. The map page

### 5.1 Turned with the ship

- **The holo is the world outside, shrunk into the room.** The interior's axes are the ship's axes,
  so a contact's place in the holo is its position relative to the hull, turned into the hull's
  frame, then scaled:

  `local = hull.basis⁻¹ · (to_engine(point) − hull.position) × (0.5 m / range)`.

  Forward in the holo is toward the canopy, whichever way the table faces.
- **Updated every frame,** so the map turns smoothly as the ship does. The contact list comes from
  the sensors' cache.
- **Your ship** is a small `LIGHT_WARM` chevron at the centre, pointing forward, always.
- **Height reads by stalks:** each of the nearest twelve contacts, and the selected one, has a thin
  stalk straight down or up to the chevron's level, ending in a small tick. Farther contacts have
  none, so the far range doesn't bristle.
- **The edge:** a contact beyond the range, or above or below the volume (±0.3 m, which is ±0.6 of
  the range), is pinned to the volume's surface as a hollow pip in its colour. The course is always
  shown, pinned if it must be.
- **A faint ring** marks the volume's edge at the chevron's level.

`HoloVolume.place(relative: Vector3, range_m: float) -> Dictionary` (`{position, pinned}`) is pure
and does the scaling and pinning.

### 5.2 What each range shows

| Range | Big rocks | Salvage |
|---|---|---|
| **2 km** | To scale, as faceted glowing balls: a 600 m rock is 15 cm across; never smaller than 1 cm | Regions, as soft spheres 75 m in radius (1.9 cm) |
| **10 km** | Dots sized by diameter, 0.8–2 cm | Pings, as dots at the pinged direction and distance, bright on each refresh and fading over the 4 s; regions where you are close enough |
| **30 km** | Small uniform dots, 0.6 cm. There are a few hundred, which reads as the shape of the fields round you | None: beyond the salvage sensor's 10 km |

- **Colours** (pinned at the renders): rocks `SKY`, salvage `QUANTUM`, your ship `LIGHT_WARM`, the
  selection and the course `AMBER`.
- **Screen:** *MAP · 10 KM*, then the selected contact (*ROCK · 3.2 KM*, *SALVAGE · ~4 KM* or
  *SALVAGE · 640 M*), then *SET COURSE*, *COURSE SET* or *NO CONTACTS*.

### 5.3 The buttons on the map page

- **RANGE** steps 2 → 10 → 30 → 2 km. The table opens at 10 km.
- **◀ and ▶** step through the contacts on the current range, nearest first, and wrap. The selected
  one gets an amber bracket in the holo: four small corner ticks round it, pulsing gently.
- **The selection** after a change of page or range is the course, if it is on this range, or else
  the nearest contact.
- **The big button** sets the selected contact as the course (`SIGNAL_GO`, *Set course*). On the
  current course it clears it (`AMBER`, *Clear course*). With no contacts it is dark.

---

## 6. The course

### 6.1 On the HUD

- **`CourseMarker`** is a `HudElement` in `AMBER`, created in code as the reticle is. It shows while
  you are seated or on a spacewalk, as the salvage marker does.
- **It follows its contact's current reading:**
  - a big rock: a diamond on its centre, with *COURSE 3.2 KM*;
  - a salvage ping: an amber chevron in the ping's direction, with *COURSE ~4 KM*, refreshing as the
    ping does;
  - a salvage region: an amber ring round the region, with *COURSE 640 M*.
- **Off-screen or behind you,** it pins to the screen's edge through `VelocityMarker.resolve`, as
  the airlock marker does.
- **The salvage marker skips the course's cloud,** so it is never drawn twice.
- **The flight controls' heading marker is unchanged.** Clicking the course to hold a heading
  toward it is a hook (§14).

### 6.2 When it clears

- **You arrive:** inside a salvage region, or within 1 km of a big rock's surface.
- **It is gone:** a salvage cloud emptied, so its source returns null.
- **You clear it** at a table.

When a course clears by arriving, the table's screen reads *ARRIVED* until the selection changes.
The HUD marker fades out over 0.5 s.

---

## 7. The status page

### 7.1 The miniature

- **Your ship, from its own hull.** `ExteriorBuilder` draws the hull as one `MultiMesh` per block
  type. The miniature is one `MultiMeshInstance3D` per block type **sharing those same `MultiMesh`
  resources**, not copies, under one scaled node in the holo:
  - on the interior render layer (2);
  - with one material override: an unshaded `StandardMaterial3D` in `LIGHT_WARM` (pinned at the
    renders), with a little emission for bloom. It is opaque, to keep clear of transparent
    overdraw. It is an engine material, not a new shader (style guide §2.5).
- **Sized** so the hull's longest side is 0.8 m, and centred in the volume.
- **It turns** slowly, at 10°/s, about its vertical.
- **It follows rebuilds:** the ship rebinds the table after each rebuild, and the miniature takes the
  new `MultiMesh`es, so any blueprint gets its own model.
- **Lighting blocks up for damage or systems** is a hook (§14).

### 7.2 The rim

- The title *STATUS*, then:
  - *QE 600 / 1200*, or *QE 96 · LOW POWER* below the line;
  - *POWER 36.0 / 31.4 MW*: generated against drawn (the computer adds 0.3), 18.0 generated in
    low power;
  - *SUIT 64%*: the avatar's suit cell.
- **Only PAGE is lit.** RANGE, ◀, ▶ and the big button stay dark.

---

## 8. HUD

- **`CourseMarker`** (§6.1).
- **`SalvageMarker`** reads salvage contacts from the ship's sensors (§13), not from the salvage
  field, and skips the course's cloud.
- **On foot aboard, the HUD stays dark,** as now. The table is the instrument there.

---

## 9. Sound

Every sound is a new `Synth` builder (style guide §2.9), heard through the Ship bus:

| Sound | What it is | Where |
|---|---|---|
| `holo_hum` | a very soft high shimmer, two close sines; quieter than the core's hum | looped, positional at the table |
| `page` | a short soft blip | the table, on PAGE and RANGE |
| `course_set` | two rising soft notes | the table |
| `course_clear` | the same two notes, falling | the table |
| `course_arrived` | a single soft chime | the Ship bus seated, the Suit bus on a spacewalk |

The buttons' own press sound is `ReadoutPanel`'s, as on the airlock and the machine.

---

## 10. Architecture

```
 SalvageField ──┐  (a source: SalvageSense readings)
                ├──► ShipSensors (Ship/Sensors) ── contacts, course ──┬──► SalvageMarker, CourseMarker (HUD)
 RockContacts ──┘  (a source: big rocks, 30 km)                       │
                                                                       ▼
                         ShipComputer (one per table) ── pages ── MapPage, StatusPage
                            │  screen + buttons (ReadoutPanel)          │
                            └── HoloVolume (grid-blind) ◄───────────────┘  pips, stalks, bracket, miniature
```

- **`ShipSensors` is the only thing that knows what is out there.** Everything that shows a contact
  asks it.
- **`ShipComputer`** is what the dressing built for one table: its screen and buttons, its
  `HoloVolume`, its pages, the current page and range. `InteriorBuilder.computers()` returns them,
  as `airlock_rooms()` does.
  - The ship binds each one after every rebuild to its sensors, quantum plant, stats, hull and the
    avatar.
  - Its page, range and selection survive rebuilds, keyed by its cell, as the machine's cycles do.
- **`HoloVolume` knows nothing about ships,** like the props. It takes a frame and draws what it is
  given: pips by kind, stalks, pins, the bracket, the chevron and a miniature. Each kind is one
  `MultiMesh` whose mesh has its colour baked in by `InteriorKit.lit`, so no instance colours are
  needed.
- **Pure and tested headless:** `Contact`, `RockContacts`, `HoloVolume.place`, and the pages' logic
  (stepping, setting and clearing the course, screen lines and lit buttons).
- **The floating origin cannot touch it.** The table is interior and never moves. Contacts are
  `UniversePoint`s, turned into the ship's frame each frame. The miniature shares the hull's
  `MultiMesh`es, whose transforms are in the hull's own space.

### 10.1 Files

```
src/sensors/
  contact.gd           Contact (pure)                                   (quantum Task 10)
  ship_sensors.gd      ShipSensors: sources, the cache, the course     (quantum Task 10; the course here)
  rock_contacts.gd     RockContacts: big rocks within 30 km (pure)
src/ship/computer/
  ship_computer.gd     ShipComputer: one table's parts, pages, page and range
  computer_page.gd     ComputerPage and ComputerContext
  map_page.gd          MapPage
  status_page.gd       StatusPage
  holo_volume.gd       HoloVolume: what the holo draws, and place() (grid-blind)
src/ui/course_marker.gd
data/blocks/computer.tres
```

**Modified:**
- `interior_props.gd`: `holo_table` and its frames;
- `interior_dressing.gd`: the fixture, and a `ShipComputer` for each;
- `interior_layout.gd`: `QUIET_FIXTURES` gains `computer`;
- `interior_builder.gd`: `computers()`;
- `ship.gd`: binds each computer after a rebuild;
- `exterior_builder.gd`: `multimeshes() -> Array[MultiMesh]`, for the miniature;
- `salvage_marker.gd`: skips the course's cloud;
- `synth.gd`: five sounds;
- `flight_test.gd`: the starter's computer, `RockContacts` registered, the course marker;
- `test_visual_style_rules.gd`.

### 10.2 Layers and palette

- **No new layers.** The table, its buttons and the holo are interior: render layer 2. The buttons
  are on physics layer 2 (`interior_geometry`), like the airlock panels.
- **No new palette entries.** Rocks `SKY`, salvage `QUANTUM`, you and the miniature `LIGHT_WARM`,
  selection and course `AMBER`, all pinned at the renders.
- **The shader set stays at three.**

---

## 11. Performance

- **The holo:** at most a few hundred pips at 30 km, drawn as one `MultiMesh` per kind, with a dozen
  stalks. That is a handful of draw calls.
- **The miniature:** one draw per block type.
- **The sensors:** `RockContacts` reads about 2,200 regions once at scene start (measured in the
  plan; move it to a worker if it costs a visible hitch), then 169 at a time.
- **Measured** in the plan against the 120 fps budget at 1280 × 720: looking into the 30 km map, and
  at the status page.

---

## 12. Testing

### 12.1 Automated (GUT, headless, output pristine)

- **`RockContacts`:** the same seed gives the same contacts; every big rock within 30 km and none
  beyond; stable ids; the slab refresh matches a fresh read.
- **`ShipSensors`:** merges its sources nearest first; the 4 Hz cache; the course set, cleared, and
  looked up beyond range; `course_changed` fires once per change.
- **`HoloVolume.place`:** the scale at each range; pinning beyond the range and above and below the
  volume; the hull's turn is honoured (a contact dead ahead is at the volume's forward edge whatever
  the hull's orientation).
- **`MapPage`:**
  - RANGE cycles 2, 10, 30 and wraps;
  - ◀ and ▶ step nearest first and wrap;
  - the selection after a change is the course, else the nearest;
  - set and clear; the big button's colour and prompt in each state;
  - the screen lines for rocks, pings, regions, no contacts and *ARRIVED*.
- **The course clears** on arriving at a region, within 1 km of a rock's surface, and when a cloud
  empties.
- **`StatusPage`:** its lines at full power and in low power; only PAGE lit.
- **The table:**
  - PAGE wraps through the pages;
  - dark buttons have no prompt;
  - page, range and selection survive a rebuild.
- **Blocks and the starter:** the `computer` block's fields; the starter's figures re-pinned; zero
  validator issues; a ship with no computer validates.
- **Layout and dressing:**
  - the starter's zones and wall variants are unchanged by the computer;
  - one `ShipComputer` at (−1, 0, −1) with every reference set;
  - one light per walkable cell still holds.
- **The prop:** builds in a bare frame; pinned collider count; nothing collides inside the holo
  volume.
- **The miniature:** shares the hull's `MultiMesh` resources, on layer 2, sized to 0.8 m; it follows
  a rebuild.
- **`CourseMarker`:** a diamond, a chevron and a ring for each reading; pinning to the edge;
  hidden on foot aboard.
- **The floating origin:** a shift leaves the holo's contents unchanged.
- **`Synth`:** the five sounds build, are deterministic and are not silent.
- **`test_visual_style_rules.gd`** (extended): the new painting files are held to palette colours;
  `holo_volume.gd` and the prop are grid-blind; the shader set is still three.

### 12.2 Real-scene probes and renders

- **Walk probe:** from the start, to the table, press through every button; round the core's port
  side to the helm.
- **Course probe:** at the table, set a course to the next group's salvage; sit; follow the HUD's
  course marker there across a floating-origin shift; see it clear inside the region.
- **Renders at 1.6 m eye height,** sent to the owner:
  - the bridge from the corridor, with the table on the left and the machine on the right;
  - the table at each range, from the operator's spot;
  - the status page with the miniature;
  - the table in low power;
  - the HUD with a course to a rock, to a ping and to a region.
- **Frame time:** looking into the 30 km map; at the status page.

### 12.3 Playtest checklist

- Does the holo read at a glance: which way, how far, how high?
- Is 10 km the right range to open at?
- Is setting a course quick, or a chore of button presses?
- Does the course marker help without making the search for salvage trivial?
- Is the miniature worth its place?

---

## 13. Amendments to quantum energy

Made in this spec's change, so quantum energy is built with them:

- **§10.4 and its plan's Task 10:** Task 10 builds `Contact` and `ShipSensors` (without the
  course), and `SalvageField` becomes their first source through `contacts()` and `contact()`. The
  flight scene registers it. `SalvageMarker` reads the salvage contacts from the ship's sensors, the
  nearest three, and never asks the field directly. `known_clouds` stays as the field's own list.
- **§12:** `SalvageMarker` binds to the ship's sensors.
- **§14:** the sensors join the architecture and the files.
- **§15:** tests for `ShipSensors` merging and caching, and the marker reading through it.
- **§17:** the bridge computer hook points to this spec.

And to the other documents, applied with the code:
- **The slice spec §5:** the `computer` block joins the catalogue.
- **The interior redesign §7.5:** the starter's bridge gains the computer at (−1, 0, −1).
- **The visual style guide:**
  - a section on the holo table: a quiet fixture, and a holo of glowing kit geometry, no collider;
  - §2.8: the first graphical live-data screen, the holo, and its colours;
  - the frame-time figures.

---

## 14. Hooks left open

- **More pages:** a log, messages, trade, the shipyard. Each is a `ComputerPage`.
- **More sources:** stations, worlds, derelicts, other ships. Each is a sensor source, and the map
  and the course need no change.
- **The status miniature** lighting blocks for damage, power and systems (Slice 2).
- **Steering by the course:** in the flight controls' point mode, clicking the course marker holds
  a heading toward it.
- **A map on the helm's screens,** or picking a course from the seat (§2, row 3).
- **Pointing into the holo** to set a course to any spot (§2, row 6).
- **Sensor upgrades:** a better sensor block narrows the ping's error or widens its reach.
- **Mid-size rocks** on the 2 km map, the moons round a big rock.
- **Other ships' computers:** a derelict's table shows what its own sensors know.

---

## 15. Non-goals

- A map on the helm, or choosing a course from the seat.
- Setting a course to anything but a big rock or a salvage cloud.
- Pointing or reaching into the holo.
- Stations, worlds, derelicts and other ships on the map.
- Showing rubble or mid-size rocks.
- Saving the course.

---

## 16. Risks

| Risk | Mitigation |
|---|---|
| The table crowds the bridge's back corner | 1.4 m clear between it and the core; the walk probe and the corridor render prove it. Shrink the table to 0.9 m if needed. |
| The 30 km map is a cloud of dots that says nothing | It shows where the fields are, which is that range's job. If it reads as noise, thin it to rocks over 300 m across. |
| Tiny contacts are hard to see in a 1 m holo at eye height | Minimum pip sizes per range; the stalks; the bracket. Tuned at the renders. |
| The holo's glow blooms into a blur | Pips are small and few; the glow energy of holo pieces is its own constant, tuned at the renders. |
| The course makes the salvage search trivial | The course follows the same vague readings as the salvage marker; it clears inside the region, where the search begins. |
| `RockContacts`' first read hitches the scene start | Measured in the plan. If it shows, read on a worker, as the asteroid stream does. |
| The glow shader does not take `MultiMesh` instance colours | Not needed: each kind's mesh has its colour baked in (§10). |

---

## 17. Build order and definition of done

After quantum energy is built. Each step ends with something to see:

1. **The block and the table:** the `computer` block, the starter's placement, the prop and a dead
   holo; the starter's figures re-pinned. *Renders to judge its size on the bridge.*
2. **Rock contacts:** `RockContacts` registered with the sensors.
3. **The table, its pages and the status page:** `ShipComputer`, `ComputerPage`, `HoloVolume`,
   the status page and the miniature. *Press PAGE and see your own ship.*
4. **The map page:** placement, stalks, pins and the three ranges. *See the neighbourhood.*
5. **The course:** selection, set and clear, the HUD's `CourseMarker`, and clearing on arrival.
   *Pick salvage at the table and fly there by the HUD.*
6. **Docs:** the amendments (§13), the final renders and frame times.

**Done when:**
1. You launch `flight_test`, come up the corridor, and find the table on your left with the
   neighbourhood hanging over it.
2. RANGE shows 2, 10 and 30 km, and the map turns as the ship turns.
3. You set a course to salvage at the next group, sit, and follow the HUD there; it clears inside
   the region.
4. PAGE shows your ship in miniature, with your store, power and suit on the rim.
5. The GUT suite is green with pristine output, every render in §12.2 has gone to the owner, and
   the bridge holds 120 fps on the GTX 960 looking into the 30 km map.
