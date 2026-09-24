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

## Exterior space has a floating origin

The outside world is re-centred on you every 2 km (`src/world/universe.gd`,
`docs/superpowers/specs/2026-09-24-asteroids-design.md` §4). **Anything you put outside the ship
must either join group `Universe.EXTERIOR_SPACE` (a node whose parent never moves; it is moved
itself, never through a parent) or listen to `Universe.shifted(delta)` and subtract `delta` from
any engine position it remembers.** World-space particles outside join `Universe.HOLDS_SHIFT`.
The interior never moves and is never a member. `test_floating_origin_scene.gd` fails if a body
or mesh outside the interior is not covered. Positions that must survive a shift (seeds, homes,
saved places) are `UniversePoint`s, never engine `Vector3`s.

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
