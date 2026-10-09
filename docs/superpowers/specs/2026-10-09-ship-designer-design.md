# Ship designer — an agent that designs, builds and proves a ship

**Date:** 2026-10-09
**Status:** Designed with the owner on 2026-10-09; amended while planning the same day (§9);
built 2026-10-09 on branch `ship-designer` (§11).
**Project 3 of 3** toward a ship-designer agent (many ships spec §1.2). Projects 1 (many ships,
`docs/superpowers/specs/2026-10-02-many-ships-design.md`) and 2 (the ship library,
`docs/superpowers/specs/2026-10-02-ship-library-design.md`) are built and merged.
**Depends on:** `main` at `a639e7a` (the ship library merged)
**Amends:** the ship library spec §2's rejection of a deck-plan format (§2 below); the ship skill
(`.claude/skills/building-a-ship/`): its probe and render tools take any library ship
**Governed by:** `docs/design/visual-style.md`, `CLAUDE.md` (every ship is usable; every ship lives
in `data/ships/`; the floating origin)

---

## 1. Why

The owner's ask (2026-10-02): an agent that designs and builds a ship from start to finish, from a
description or "be creative", that the game can then spawn. The owner's rule holds for every ship
it makes:

> we are building a usable ship so we need to be able to board and fly, this is a rule of any
> ship in the game

Projects 1 and 2 built everything a ship needs to exist and be checked: many ships in the world,
the library in `data/ships/`, `ShipRules`, `ship_check.gd`, the catalog test that boards, flies and
saves every ship, and the F6 spawn. What is missing is the designer: the judgment that turns "a
slow freighter with a long hold" into a layout, and the tools that let an agent see the layout it
is drawing.

**Success:** the owner asks for a ship (or says "be creative"), the agent works unattended, and
comes back with a ship on its own branch, proven, with pictures. The owner presses F6, picks it,
watches it arrive, boards it, flies it, and it feels like what was asked for.

## 2. Decisions

| # | Decision | Why |
|---|---|---|
| 1 | **Existing blocks only** | The owner's choice. The agent designs with the blocks in `data/blocks/`; new blocks are separate work the owner commissions. A ship that wanted something missing says so in its report |
| 2 | **Start to finish, no check-in** | The owner's choice. The agent designs, builds, proves and renders without stopping; the owner judges the finished ship |
| 3 | **Each ship on its own branch** | The owner's choice. A sibling worktree, branch `ship-<id>`, committed and never merged by the agent. A bad ship never touches `main`. As built (§11): the sending session makes the worktree, `D:/git/whoknows-design-<n>` on `design-<n>`, before the id is known, and the agent renames the branch |
| 4 | **The agent draws deck plans** (§4) | The owner's choice of three. A ship is 100–400 blocks with 24 orientations each; as JSON rows the agent cannot see symmetry, a continuous cabin or a mirrored RCS pair. A map shows them |
| 5 | **The JSON stays the one canonical file** | The plan is the agent's scratch; `ship_plan.gd` converts both ways and round-trips byte for byte, so the two never drift. The `.md` holds the printed maps for people |
| 6 | **Up to 400 blocks** | The owner's choice (2026-10-09): "I want to allow for pretty large ships. I'd set the first limit to 600 and see how that goes". At the build 600 fell under the 120 fps floor (§9), and the owner lowered it to 400 the same day. The starter is 110 |
| 7 | **It can revise a library ship** as well as design a new one | "Make the hauler longer" starts from that ship's plan |
| 8 | **One walkable storey** while ladders don't climb | `ShipRules`' `CUT_OFF` already refuses a second walkable storey with the reason; equipment decks above and below are fine. The plan format and the agent are storey-agnostic, so multi-level ships need no change here once climbing exists |

**Amends the library spec §2,** which rejected "a new deck-plan text format (a parser, and
orientations are awkward to draw)". It was rejected as the library's format. Here it is the
agent's scratch format beside the JSON, and the legend (§4.2) is what makes orientations drawable.

Rejected: the agent writing JSON rows directly (blind to shape; the struggle would be retries);
a generator script per ship (each ship becomes code to review, and code is a worse medium than a
map for "is this cabin walkable?"); a concept check-in before building (the owner's choice, §2.2);
letting the agent add blocks (§2.1).

## 3. The pieces

| Piece | Where | What it is |
|---|---|---|
| The agent | `.claude/agents/ship-designer.md` | A Claude Code subagent definition: its tools, its model (Opus), the rules it cannot break, the steps of a run (§5) |
| The design skill | `.claude/skills/designing-a-ship/` | Brief to concept to deck plan (§6). Hands off to `building-a-ship` to build and prove |
| The plan tool | `.claude/skills/building-a-ship/ship_plan.gd` | Plan to library JSON and back (§4) |
| `--ship <id>` | `scenes/flight_test.gd`, `ship_probe.gd`, `test/probes/arrival_render.gd` | Starts you aboard library ship `<id>` instead of the starter, so the probe and the renders work on any ship (§7.2) |
| The size proof | a fixture as big as a ship may be (400 blocks) in `test/fixtures/size/` (not `ships/`, which `test_ship_library.gd` loads as a library) and its test | §7.4 |

`ship_plan.gd` sits beside `ship_check.gd` because building a ship by hand uses it too; the
`building-a-ship` skill documents it.

## 4. The deck plan

### 4.1 A plan file

Plain text, one header, one legend, one map per storey. `#` starts a comment to the end of the
line.

```
ship   hauler
name   Long hauler
desc   A slow freighter with a long hold and a bridge on top.

legend              # token = block [orientation]; "." is empty
  F2  fairing_half 2

deck y=1    x: -2 .. 2      # bow at the top, port on the left
z -4   .  R^ R^ R^ .
z -3   H  H  K  H  H

deck y=0    x: -3 .. 3
z -4   .  W3 C  C  C  W1 .
z -3   W3 D  S  D  D  D  W1
```

- **A map is the storey seen from above, bow up, port on the left:** rows run z from the bow (−z)
  to the stern, columns x from port (−x) to starboard. Each row starts `z <n>`; each deck gives
  its `y` and its x range, so storeys can differ in size. A row holds exactly as many tokens as the
  range is wide.
- **Tokens are separated by spaces**, so they can be one to three characters; `to-plan` pads them
  into columns so the map lines up.
- **Header:** `ship` (the id: the file name, lower case, digits and `_`), `name`, `desc`.

### 4.2 The legend

A token is a block and an orientation (reference.md's codes). **A default legend** covers the
common pairs, so most plans declare nothing:

| Token | Block, orientation | Token | Block, orientation |
|---|---|---|---|
| `H` | hull 0 | `D` | deck 0 |
| `K` | core 0 | `S` | pilot_seat 0 |
| `C` | canopy 0 | `A` | airlock 0 |
| `B` | bulkhead 0 | `O` | door 0 |
| `T` | thruster 0 (pushes forward) | `T4` | thruster 4 (pushes aft) |
| `R<` | rcs 8 (pushes to port) | `R>` | rcs 12 (pushes to starboard) |
| `R^` | rcs 16 (pushes up) | `Rv` | rcs 20 (pushes down) |
| `Rb` | rcs 4 (retro, pushes aft) | `R` | rcs 0 (pushes forward) |
| `W1` / `W3` | hull_wedge 1 / 3 (chamfer to starboard / port) | `W` / `W4` | hull_wedge 0 / 4 (nose / tail taper) |

The rcs arrows (`R<`, `R>`, `R^`, `Rv`, `Rb`) stand in for `R8`, `R12`, `R16`, `R20` and `R4`,
which are never used.

and a **base token** for every other block, meaning that block at orientation 0:

| Token | Block | Token | Block | Token | Block |
|---|---|---|---|---|---|
| `Bk` | bunk_room | `Gy` | galley | `Ba` | bathroom |
| `Wr` | weapon_room | `Cl` | closet | `Cp` | computer |
| `Qk` | quantum_core | `Qm` | quantum_machine | `Qc` | quantum_cell |
| `G` | grav_plating | `Ar` | armour | `L` | ladder |
| `Fs` | fairing_slope | `Fh` | fairing_half | `Fi` | fairing_corner_in |
| `Fo` | fairing_corner_out | `Fl` | fairing_slope_long_high | `Fk` | fairing_slope_long_low |

(The first table's blocks have their base tokens there: `H`, `D`, `K`, `S`, `C`, `A`, `B`, `O`,
`T`, `R`, `W`.) **Any pair the tables lack is its base token followed by its orientation:** `Fh2` is fairing_half at 2, `W2` hull_wedge at 2, `R17` rcs at 17. So every block
and orientation has exactly one default token, and `to-plan` needs no legend lines for library
ships. A test checks that every base token names a block in the catalog and every block has one;
a new block needs a token before it can be drawn.

**A plan's own `legend`** adds a token of the author's choosing for any pair, or overrides a
default. An override is allowed but `to-json` prints it, so a token is never silently redefined.

### 4.3 `ship_plan.gd`

A headless tool beside `ship_check.gd`, run as it is:

- **`to-json <plan> <out.json>`** writes the library file through `ShipLibrary.write`, so its rows
  are sorted and formatted exactly as every ship file. It refuses, naming the line and column, on:
  an unknown token; a row with too many or too few tokens; a row's z repeated in a deck, or a deck
  whose rows skip a z; two decks with the same y; a legend line naming a block not in the catalog
  or an orientation outside 0–23; a missing or malformed header. It does not judge whether the
  ship flies: that is `ShipRules`', and `ship_check` runs next.
- **`to-plan <id or path.json>`** prints a ship as a plan in default tokens (no legend lines),
  each deck cropped to the ship's extent on that storey. How the
  agent reads the starter as its worked example, and how a revision starts.
- **The round trip is exact:** `to-plan` then `to-json` reproduces the JSON byte for byte. A test
  pins it on the starter and on the size fixture (§7.4).

The parse and print live in a class (`ShipPlan`, `src/ship/ship_plan.gd`) the tool calls, so they
are tested by GUT like `ShipLibrary`.

## 5. A run

The agent's file lists these steps; the design skill says how to do the hard ones.

1. **The brief.** From the owner's description, or for "be creative" a role and a twist chosen from
   the skill's lists (§6.3). Pick an id and a name (for a revision, the ship's own). Write down
   **feel targets as numbers** (§6.2): what each axis turns, how hard it brakes, how fast it
   slides onto the nose, how big.
2. **The worktree.** Made by the sending session before the agent starts (a subagent cannot leave
   the session's checkout here): `D:/git/whoknows-design-<n>` on branch `design-<n>` from `main`,
   the session moved into it and the path in the brief; the agent renames the branch `ship-<id>`
   and keeps its plan, logs and renders in the worktree's git-ignored `.superpowers/ship/`. A
   revision prints the ship's plan with `to-plan` first. An id already in the library is a revision only if
   the owner asked for one; otherwise the agent picks another id.
3. **The design loop.** Draw the plan, `to-json`, `ship_check`; read the broken rules and the feel
   numbers; change the plan; again. Done when no rule is broken and every target is met or its
   miss is explained. **At most 12 rounds** (§5.1).
4. **Write** `data/ships/<id>.json` and `data/ships/<id>.md`: the concept, the printed deck maps,
   the targets beside the numbers, and why each unusual block is where it is (as `starter.md`
   does).
5. **Prove** (§7.1), in order, each passing before the next. A failure goes back to step 3 and
   counts as a round.
6. **Look.** The agent reads its own renders and judges them against the style guide: chunky,
   warm and dim, the shape it meant, the windows where it meant them. Unhappy, back to step 3.
7. **Commit** on the branch and **report** (§5.2). Never merge or push.

### 5.1 Stopping

Twelve rounds without zero broken rules, or a proof step that keeps failing: the agent stops,
commits what it has with the subject line starting `wip:`, and reports what blocks it. A rate
limit or a crash mid-run leaves the branch and the plan in the worktree; a run told to resume
reads the branch and carries on.

### 5.2 The report

What the agent returns to the session, which relays it to the owner:

- the concept in a few lines, and the ship's id, name, size (blocks, tonnes);
- the deck maps;
- a table of each feel target against the number it reached;
- the renders, as paths, which the session sends the owner as files;
- anything it gave up on or could not reach, and why;
- **blocks I wished for:** what a block the game lacks would have done for this ship;
- the branch and commit.

## 6. The design skill

`.claude/skills/designing-a-ship/SKILL.md` (and a `reference.md` if it grows), the judgment half.
`building-a-ship` stays the how-to-build-and-prove half; this skill points to it and never repeats
it.

### 6.1 Role to shape

What a role needs from the blocks, as a short table per role: **hauler** (a long hold of open
deck or rooms, heavy, slow to turn, big side thrust so it doesn't slide), **fighter** (small,
canopy forward, high turn rates, little inside), **explorer** (bunks, galley, a computer, long
warp reach from quantum cells), **yacht** (rooms, windows, comfort over speed), **shuttle** (the
starter). Each with the blocks it leans on and the mistakes it invites (a hauler's mass above the
thrust line; a fighter too small for the airlock and the stand cell).

### 6.2 Feel to numbers

The `building-a-ship` table *What the blueprint decides about flying* turned around: from a word
to a target. "Nimble" is turn rate above the starter's on every axis; "heavy" below it; "drifts"
is low lateral thrust per tonne. The starter's numbers are the yardstick. Each target names the
`ShipStats` figure and the blocks that move it.

### 6.3 Be creative

A list of roles and a list of twists (a ventral bridge, a ring of rooms round the core, twin
hulls joined by a corridor, a long spine, a stubby brick with huge engines...). The agent picks one
of each and says which; two "be creative" runs should not make the same ship.

### 6.4 The method

Draw the walkable storey first (helm, the stand cell, the corridor, the airlock, the rooms, the
droid's dock and every job it tends reachable), then the equipment storey over it (core, power,
grav plating, cells), then the outside (fairings, wedges), then engines and RCS sized to the
targets, opposed in pairs, exhaust faces open. Mirror port and starboard unless the twist says
otherwise. Check after each layer, not only at the end.

### 6.5 Worked example

The starter, printed by `to-plan`, with what each part of the map is for.

## 7. Proof

### 7.1 Of each ship (the agent's step 5)

1. **`ship_check`:** zero broken rules.
2. **The catalog test** (`test_ship_catalog.gd`, `-gselect`): covers the new ship by itself, since
   it checks every file in `data/ships/`: loads, no rules broken, has its note, and usable
   (spawned, F8 aboard, a burn, stand and walk, save and reload).
3. **The probe** with `--ship <id>`, windowed: sit, stand and walk (`STUCK`); rooms, pods and
   airlocks; windows in against out; lights; the droid's jobs (`UNREACHABLE`); hull renders
   (quarters, profile, above, below; fill-lit, and dark with the lights); eye-height views inside;
   **fps in the worst view at or above 120** (seated by a big rock's night side, both light groups
   on). Its two-ship pass parks the real starter beside the new ship.
4. **An F6 arrival** (`arrival_render.gd --ship <id>`): the new ship spawned through
   `spawn_from_library`, coming in out of warp, from the starter's seat.

### 7.2 `--ship <id>`

`flight_test.gd` gets a `starter_ship: StringName` (default `ShipLibrary.STARTER`), set before the
scene enters the tree; `_starter_grid()` returns that ship's grid. Everything about the starter
(the avatar's deck spot, the seat, the HUD, the lights) is already derived from the grid. Saving
is off whenever it is not the starter, so a probe never writes the owner's game. A probe or
render script passes it from `--ship <id>` on its command line; an id not in the library is an
error and the script exits 1. The probe's two-ship pass spawns the real starter as the second
ship. Never a player feature: there is no key for it.

### 7.3 Of the tools (GUT)

- **`ShipPlan`:** every refusal in §4.3 with its line and column; the default legend's tokens all
  name real blocks; a plan legend adds and overrides; the starter round-trips byte for byte; a
  plan with two storeys of different extents converts and prints back.
- **`starter_ship`:** the scene starts aboard the chosen ship (its grid, the avatar on its deck,
  the seat at its helm) with saving off; an unknown id is refused.
- **The agent and the skill** are prose; they are proven by the acceptance runs (§7.5).

### 7.4 The size limit

A fixture ship as big as a ship may be (`test/fixtures/size/big.json`, made with `ship_plan`, not
in the library) that passes `ShipRules`. Measured and pinned: `ship_check` time; spawn and build
time (a hitch the owner would feel); save size; probe fps in the worst view. Anything that fails at
the limit is fixed in this project, or, if the fix is large, the limit is lowered with the owner's
agreement and the reason recorded here. It was: 600 to 400 (§9).

### 7.5 Acceptance

After the build, the agent runs twice for real: once on "be creative", once on a description the
owner gives. Both ships land on their own branches; the owner judges them, and what the runs
teach goes into the two skills' *Mistakes already made* before this project is called done.

## 8. What changes outside the new files

- `scenes/flight_test.gd`: `starter_ship` (§7.2).
- `.claude/skills/building-a-ship/ship_probe.gd` and `test/probes/arrival_render.gd`: `--ship`.
- `.claude/skills/building-a-ship/`: `SKILL.md` and `reference.md` document `ship_plan.gd`, the
  legend and `--ship`; the worked example points to `to-plan`.
- `CLAUDE.md`: one line that ships are designed with the `ship-designer` agent and the
  `designing-a-ship` skill.

## 9. Amended while planning (2026-10-09)

Measured on a 600-block draft, a stretched starter with a second quantum core (it became the §7.4
fixture): it breaks no rule; `ShipRules.check` takes 0.6 s (`ship_check` 2.7 s with the engine's
start); its save is 63 KB (the starter's 13 KB); **a spawn builds it in 1.9 s, one frame** (the
starter 0.3 s).

- **The freeze is accepted for now** (the owner, 2026-10-09). A guard fails above 3 s; faster or
  spread-out builds are a later project, when big ships are common.
- **Power limits size.** Only `quantum_core` makes power (36 MW); every walkable cell draws 0.1,
  grav plating 1.5, an rcs 1 and a thruster 3. A big ship needs a second quantum core, which the
  quantum plant already runs (it holds any number). The design skill says so.
- **Long ships turn slowly:** inertia grows with length squared; the draft turns 0.06 / 0.03 /
  0.42 rad/s² with the starter's bow RCS. The design skill says to put RCS at both ends.
- **`TOO_BIG`:** a ship over the limit breaks a new `ShipRules` rule, so the catalog test holds
  the limit, not only the agent.
- **Lowered to 400 at the build** (the owner, 2026-10-09). Probed windowed, the 600-block fixture
  held 116 fps in the worst view (seated by a big rock's night side, both light groups on) and 109
  with a second ship 300 m off, under the 120 floor; the starter held 130 and 130 the same
  session. Rebuilt at 400 blocks (20 rows stretched, the second quantum core kept), it holds 121
  and 122, and measures: the rules 0.3 s, a spawn 1.2 s, a save 42 KB. Faster rendering of big
  ships joins the faster builds as later work; the limit can rise then.
- **`starter_ship` takes a ship file as well as an id** (`ShipLibrary.resolve`), so the fixture
  and a draft can be probed before they are in the library. `arrival_render --ship` takes a
  library id only, since it spawns through the F6 path.
- **`#` is not a comment in the `name` and `desc` lines**, which take the rest of the line as
  written, so a name can hold one and still round-trip.

## 10. Not in this project

- **New blocks** (§2.1): separate work, commissioned by the owner from the agent's wish lists.
- **Ladders that climb** and so walkable multi-level ships (§2.8).
- **A shipyard in the game** or player-drawn plans: the plan format may serve one later.
- **NPC ships flying themselves:** the arrival is reusable, the pilot is not built.

## 11. What was built (2026-10-09)

Built natively from `docs/superpowers/plans/2026-10-09-ship-designer.md` (11 tasks; the 11th is
acceptance, after the review).

- **`ShipPlan`** (`src/ship/ship_plan.gd`): the tokens (every block and orientation one token;
  `R8` and `W0` are refused with the token meant), `parse` (every refusal of §4.3 with
  file:line:column, comments, CRLF and tabs), `to_text`. The starter prints as the design skill
  shows it and round-trips byte for byte; 35 tests.
- **`ship_plan.gd`** beside `ship_check.gd`, and `ShipLibrary.resolve` (an id or a ship file).
  `to-plan starter` then `to-json` reproduces `starter.json` exactly (`fc /b`).
- **`TOO_BIG`** and `ShipRules.MOST_BLOCKS`, now **400** (§9); the size fixture
  `test/fixtures/size/big.plan` and `big.json` (400 blocks, 351 t, a second quantum core), and
  `test_big_ship.gd`: as big as a ship may be, its plan, no rule broken in under 3 s, one block more
  is `TOO_BIG`, a spawn under 3 s and a save under 256 KB, usable. The usable check is shared with
  the catalog test (`test/unit/helpers/ship_use.gd`).
- **`starter_ship`** on the flight scene, saving off for anything but the starter; an unknown ship
  starts you in the starter with one error.
- **`--ship`** on the probe (an id or a ship file; checked before the scene is made) and on the
  arrival render (a library id); `ProbeArgs`. The probe's two-ship pass parks the real starter
  beside the ship probed.
- **The `designing-a-ship` skill** and **the `ship-designer` agent**; the ship skill, its
  reference, and `CLAUDE.md` name them.

**Figures at 400 blocks** (probe, windowed, this machine): 286 fps standing, 138 seated, 133 seated
with both light groups, 121 seated by a rock with both (the starter 130 the same session), 208
and 221 in the chase views, 122 with a second ship 300 m off. Rules 0.3 s, a spawn 1.2 s, a save
42 KB.

**Rulings made in the build** (the ledger's):

- The skill's `task-start`/`task-done` scripts cannot run under the worktree guard; each task's
  final test run was made by hand and ledgered.
- Script `.uid` files the plan's commit lists missed (`test_ship_plan.gd`, and `arrival_render.gd`
  since the ship library) were committed: the repository tracks every one.
- The probe checks `--ship` before making the scene, not after as the plan had it: quitting with
  the scene made but never in the tree crashed the engine on the way out (exit -1073741819, not 1).
- The limit went from 600 to 400 (the owner's call, §9); the skill and the agent say 400 where
  the plan's text said 600.

**Changed at the final review** (a fresh reviewer, Opus):

- **A `--ship` naming nothing is refused** (last, empty, or followed by another flag:
  `ProbeArgs.refused`): the probe and the arrival render had fallen back to the starter and exited
  0, which would pass the starter's renders off as the agent's ship.
- **The agent's probe gate is every failure the probe prints** (`<--`, `MISMATCH`, `MISSING`,
  `REFUSED`, `NOT FOUND`, `UNREACHABLE`, `SHADER ERROR`, `SCRIPT ERROR`) and the `probing <id>`
  line, not four of them; the starter's and the fixture's logs pass it.
- **The sending session makes the worktree** (§5 step 2): the agent could not, under this
  harness's guard, and for "be creative" the id is not known when it is sent.

**Acceptance:** not yet run (Task 11).