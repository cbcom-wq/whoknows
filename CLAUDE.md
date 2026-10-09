# CLAUDE.md

Repo-wide conventions and gotchas for Claude Code / agents working in this project.

## Visual style: `docs/design/visual-style.md` is binding

**Read it before any visual work**: interiors, props, rooms, lighting, materials, shaders,
palettes, screens. The look is **stylized, warm and dim**: chunky bevelled low-poly shapes in flat
colour, lit by warm practical lights, "fun and real enough" (think *Astroneer*, a little more
serious). It was chosen by the owner on 2026-09-23 after three prototyped directions. Do not drift
back toward realism, procedural surface detail, dark blue sci-fi or bright lighting; §7 of the
guide records why each was rejected.

- **Colours come only from the palettes:** `InteriorPalette` inside, `HullPalette` on the hull,
  `SpacePalette` for rocks in space. Props build from `(kit, frame, variety)` and never
  see the grid. The interior shader budget is three. `test_visual_style_rules.gd` enforces all
  three rules. If it fails, fix the code, not the test.
- **Verify visual work by rendering the real scene** at eye height (1.6 m) and showing the owner.
  Green tests prove structure, not looks.
- **Changing a rule needs the owner's approval**, and the guide, code and tests change together.

## Ship building: keep the `building-a-ship` skill current

`.claude/skills/building-a-ship/` is how ships are built here; use it for any ship work. **When a
ship-building design or implementation is finished, update the skill in the same branch before
calling the work done.** That covers a blueprint, a block, anything that changes how a ship is
laid out, flies, looks, sounds or is walked, or a system it has to fit (engine room, power,
thrusters):
- put new checks in its checklist;
- put new lessons in *Mistakes already made*;
- put new numbers and APIs in `reference.md`;
- make anything checkable a line in `ship_probe.gd`.

If a name in the skill no longer exists, fix the skill. The owner asked for this on 2026-09-25.

**Every ship lives in `data/ships/`** (`<id>.json` plus `<id>.md`) and passes `ShipRules`:
`test_ship_catalog.gd` checks every one, and `.claude/skills/building-a-ship/ship_check.gd` checks a
draft in seconds (`docs/superpowers/specs/2026-10-02-ship-library-design.md`).

**A new ship is designed by the `ship-designer` agent** (`.claude/agents/ship-designer.md`, with
the `designing-a-ship` skill): from a description or "be creative", start to finish, never merged
by the agent; at most 400 blocks (`docs/superpowers/specs/2026-10-09-ship-designer-design.md`).
**To send it,** make its worktree first (`git worktree add ../whoknows-design-<n> -b design-<n>
main`), then dispatch `ship-designer` with the brief and that path; it works there by
`Set-Location`, never in your checkout, and renames the branch `ship-<id>`. Several can run at once
in separate worktrees, but their probes then share the GPU: a reading under 120 fps is re-run
alone. A session started before `.claude/agents/ship-designer.md` existed does not know the agent
type; send a general-purpose Opus agent told to follow that file instead.

## NPCs: use and keep the `building-an-npc` skill current

`.claude/skills/building-an-npc/` is how NPCs are built here: creatures, droids, crew, and new
behaviours, senses, locomotors, looks or populations. It has templates, and
`test_npc_catalog.gd` checks every species in `data/npcs/` automatically. **When NPC work is
finished, update the skill in the same branch**:
- put new checks in its checklist;
- put new lessons in *Mistakes already made*;
- put new numbers and APIs in `reference.md`.

If a name in the skill no longer exists, fix the skill.

## Exterior space has a floating origin

The outside world is re-centred on you every 2 km (`src/world/universe.gd`,
`docs/superpowers/specs/2026-09-24-asteroids-design.md` §4). **Anything you put outside the ship
must either join group `Universe.EXTERIOR_SPACE` (a node whose parent never moves; it is moved
itself, never through a parent) or listen to `Universe.shifted(delta)` and subtract `delta` from
any engine position it remembers.** World-space particles outside join `Universe.HOLDS_SHIFT`.
The interior never moves and is never a member. `test_floating_origin_scene.gd` fails if a body
or mesh outside the interior is not covered. Positions that must survive a shift (seeds, homes,
saved places) are `UniversePoint`s, never engine `Vector3`s. A ship asleep, more than 20 km off, is
the one exception: it leaves the group, is held as a `UniversePoint`, and is in group
`Fleet.ASLEEP`.

## Every ship is usable

The owner's rule (2026-10-02): **any ship in the game can be boarded, flown and saved**, never a
look-only prop. Ships come and go through `Fleet` (`src/ship/fleet.gd`): the starter is `/Ship`,
an instance of `scenes/ship.tscn`; any other is `fleet.spawn(grid, place)`, from the library (F6 in
the game) or a save. The ship you are in
is the flight scene's `aboard`, and `board(ship)` is the one place it changes
(`docs/superpowers/specs/2026-10-02-many-ships-design.md`). Never author a second `Ship` in a
`.tscn` or instance `ship.tscn` any other way. `test/probes/fleet_play.gd` plays a trip between
two ships in real time; run it after any change to boarding, airlocks or the suit.

## Godot `.tscn`/`.tres`: no `#` comments inside `[node]`, `[sub_resource]`, or `[resource]` blocks

**Never put a `#` comment line adjacent to a property assignment or to a `[node]`/`[sub_resource]`/
`[resource]` tag** in a hand-authored `.tscn` or `.tres` file — including a comment isolated by
blank lines on both sides, and a same-line trailing comment (which corrupts the *next* line
instead of the one it's on). Put comments between blocks only, never touching a tag or property
line — or, safer still, keep narrative explanation out of `.tscn`/`.tres` files entirely and put
it in the corresponding `.gd` script's doc comments, or in the task report.

Confirmed in Godot 4.5.1: the text-scene parser silently corrupts whatever is adjacent to the
comment, with **zero warning or error output**. Found during Task 6c of the Slice 1 build and
independently reproduced by a reviewer in a clean isolated project. Three confirmed failure
shapes:

1. **Comment immediately before a property line** — that property is silently dropped; the node
   gets its class default instead of the authored value.
2. **Comment as the only content in a node with no properties**, followed by the next
   `[node]`/`[sub_resource]` tag — **the next node is dropped from the tree entirely.**
3. **Comment immediately after a node's last property**, followed by the next tag — the parser
   **hangs** (does not return).

**Checking for load-time warnings does not catch this.** A `--headless --quit-after N` scene load
reports a completely clean exit in all three cases — that is precisely how this survived two prior
task reviews in this project before being caught by chance while proving a feature was actually
live at runtime, not by any load check. To verify a `.tscn`/`.tres` edit is safe, load the real
scene and read the property back at runtime (`node.property_name`), not just check for the
absence of load errors.
