# Rock Creatures Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Three new species on the big rocks (a Glinter, a Delver and a Limpet), every species on a rock coming from one recipe and one site, plus an F10 dev spawner.

**Architecture:** `RockLife` (pure) runs each species' recipe in a fixed order and numbers groups across species, so the skitters' records and ids do not change. One generalised `RockSite` per rock fills what all species share and hands each species' extras to one `match`; it also carries the Callables through which the body's reports (a sip, a surfacing, a death) reach the flight scene. `RockLifeSource` replaces `RockHerdSource`. The creatures are made from the foundation's layers: data in `data/npcs/`, small behaviours, one new locomotor (`Burrower`), looks built like `SkitterLook`.

**Tech Stack:** Godot 4.5.1 GDScript, GUT. No new shaders and no sound (silent outside, style guide §2.9).

**Spec:** `docs/superpowers/specs/2026-10-10-rock-creatures-design.md` (refreshed 2026-10-18). Read it with this plan: it has the why and every first value. Also read `.claude/skills/building-an-npc/` (SKILL.md, reference.md, templates) before Task 1.

## Global Constraints

- **Skitter records and ids are identical to today's** for every seed (spec §3.1). A golden file, written before anything changes, pins them (Task 2). The ledger's dead stay dead.
- **Record ids** `"<species>:<site>:<group>:<n>"`, homes in the rock's frame; dev records `"dev:<species>:<n>"` (spec §3.1, §7.2).
- **Recipe salts** are distinct from every `AsteroidRecipe.cell_seed` salt in use (the `Tier` values 0–2, rock detail's 7, the herds' 11): Glinter **13**, Delver **17**, Limpet **19**.
- **Spacing:** each recipe keeps its homes **30 m** clear (surface point to surface point) of homes already taken.
- **Colours only from `SpacePalette`** for creatures, `InteriorPalette` for items; a new colour needs the owner's approval from a render. Each new look file joins `PAINTING_FILES` in `test_visual_style_rules.gd`. No new shader.
- **Floating origin (CLAUDE.md):** every live NPC is already an `EXTERIOR_SPACE` member under a holder that never moves. No world-space particles: the Delver's puffs are part of its look. Placed salvage items and drops are members through `SalvageField` and `StrayField`, as today.
- **The mind never touches the world:** a behaviour asks with an intent action (`&"bite"`, `&"sip"`, `&"leap"`, `&"burrow"`); the body (`Npc`) or its site delivers it.
- **A Limpet never drains the ship's store or touches a ship's hull**; a base only while it is awake and you are near (Task 6).
- **No `#` comments in `.tscn`/`.tres`** (CLAUDE.md). The new `.tres` files have none; read a value back at runtime to prove a file loads as authored.
- **GDScript warnings are errors:** type every `var`; `var x: Variant = ...` for a Variant.
- **Targeted tests only** (project rule). The full suite is the owner's call at the end.
- **Each creature ends with a render shown to the owner before the next begins** (spec §12), from a spacewalk at 40–100 m, eye on "would I notice it?". Windowed scripts set `scene.save_enabled = false`.

## Calls made while planning (tell the owner)

These are not in the spec; each is the smallest thing that makes it work. The spec is amended with them in Task 13.

1. **A Limpet grips a base's walls through a new species field, `grips_bases`.** The crawler's rays see only rock (`AsteroidBody.LAYER`), and a base's shell shares layer 1 with ships' hulls, so the spec's "skitters already treat [walls] as terrain" is not so. With `grips_bases`, the crawler also looks at layer 1 and keeps only hits on a collider with meta `&"base"`, never a ship's hull.
2. **A base is raided only while you are near.** An awake base is itself an anchor (`AsteroidStream.SPACE_ANCHOR`), so a bed beside it would stay live, and sip, with you 10 km away. A Limpet goes for a base only while an anchor that is not a base is within **300 m** of its bed.
3. **A raid starts over each time the bed wakes:** records keep their homes, so a demoted Limpet wakes on its bed.
4. **The Glinter's leap aims at the avatar:** `SurfaceCrawler.aim_leap` also looks at the avatar's layer (4), or a leap at a spacewalker floating over the crater finds nothing to land on and never happens.
5. **The nest's shared beat runs off the engine clock**, so Glinters woken at different times still flash together.
6. **Dev groups do not show on the life sensor** (they are not in the rock's recipe).

## Review Focus

Failure modes the spec implies that no task's main tests reach, most likely first. Each has a test in the task that owns the code.

1. **A Limpet bed beside your base while you are 5 km away:** nothing is drained (Task 6, `test_a_base_is_not_sipped_with_no_one_near`).
2. **F6 and F10 both open, then 1 is pressed:** opening one shuts the other, so one key asks once (Task 4, `test_opening_one_dev_panel_shuts_the_other`).
3. **A rock leaves detail and comes back** (distance, a warp): its nest's salvage comes back once, with no duplicates, and taken items stay taken (Task 8, `test_a_nest_registered_again_loads_once_and_keeps_what_was_taken`).
4. **A Delver demoted, or killed, while under:** the pooled node comes back solid, visible and a target when it is next made live (Task 11, `test_a_pooled_delver_comes_back_solid_and_a_target`).
5. **A Limpet crawling next to a ship's hull** (layer 1, no `&"base"` meta): it never grips the hull (Task 6, `test_a_ship_hull_is_not_ground_for_a_limpet`).

## Commands

PowerShell, from `D:\git\whoknows-rock-creatures` (the worktree, branch `rock-creatures`; keep `D:\git\whoknows` on `main`). `$godot` is what `who-knows/run_tests.ps1` uses:

```powershell
$godot = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { "D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe" }
```

- **After adding a `class_name`** (new file): `& $godot --headless --path who-knows --import`
- **One test file:** `& .\who-knows\run_tests.ps1 '-gselect=test_rock_life'`
- Commit `.gd.uid` files with their scripts.
- Commit messages end with the session's `Co-Authored-By:` line.

All paths below are under `who-knows/` unless they start with `docs/` or `.claude/`.

---

## File Structure

| File | Responsibility |
|---|---|
| `src/npc/populations/rock_life.gd` (new) | `RockLife`: pure; every group and record on a rock, species in a fixed order |
| `src/npc/populations/glinter_nests.gd`, `delver_burrows.gd`, `limpet_beds.gd` (new) | each species' pure recipe: groups and member directions |
| `src/npc/populations/rock_site.gd` | generalised: every group, the shared fill, the species hand-over, the body's reports out through Callables |
| `src/npc/populations/rock_life_source.gd` (new; replaces `rock_herd_source.gd`) | offers a rock's records; per-species `quiet`; hands the flight scene's Callables to each site |
| `src/npc/populations/dev_creatures.gd` (new) | `DevCreatures`: a director source of session-only records |
| `src/ui/creature_panel.gd` (new) | `CreaturePanel`: F10, only asks |
| `src/npc/npc_species.gd`, `src/npc/npc.gd`, `src/npc/npc_site.gd` | species fields; bite from data; sip, surfacing and death reported to the site; `set_solid` |
| `src/npc/surface_crawler.gd` | `grips_bases`; leap aims at the avatar too; hands over to `burrower` |
| `src/npc/burrower.gd` (new) | `Burrower`: sink, under, emerge |
| `src/npc/behaviours/` | `cling`, `creep`, `sip`, `lure`, `ambush`, `feed`, `delve`, `dive` (new) |
| `src/npc/glinter_look.gd`, `delver_look.gd`, `limpet_look.gd` (new); `src/npc/npc_looks.gd` | the looks |
| `src/items/hit.gd`, `src/quantum/suit_cell.gd`, `src/avatar/avatar.gd` | a drain on a hit; the suit cell spends it, capped |
| `src/habitat/bases.gd` | `sip`, `place_of` |
| `src/world/salvage_field.gd` | `add_placed_cloud` |
| `src/world/stray_field.gd` | `count_of` |
| `src/items/item_looks.gd`, `data/items/crystal_grit.tres`, `limpet_husk.tres` | the two items; a clock-driven glint |
| `src/sensors/life_contacts.gd` | groups of any species |
| `data/npcs/limpet.tres`, `glinter.tres`, `delver.tres` (new) | the species |
| `scenes/flight_test.gd` | wiring: the source and its Callables, the panel, the spawn |

---

### Task 1: Bite and drain as species data

**Files:**
- Modify: `src/npc/npc_species.gd`, `src/npc/npc.gd` (`bite()`, the `BITE_*` constants)
- Modify: `test/unit/test_npc_death.gd` (it reads `Npc.BITE_DAMAGE`)
- Test: `test/unit/test_npc_species.gd`

**Interfaces:**
- Produces on `NpcSpecies`, in a new `@export_group("Bite and drain")`: `bite_damage := 15.0`, `bite_push := 40.0`, `bite_reach := 1.6`, `drain_rate := 0.0` (QE/s), `drain_reach := 0.0` (m), `shy_of_drills := true`, `grips_bases := false`.
- `Npc.bite()` reads `species.bite_damage`, `bite_push`, `bite_reach`; `Npc.BITE_DAMAGE`, `BITE_PUSH`, `BITE_REACH` are removed.

- [ ] **Step 1: Write the failing test** (append to `test_npc_species.gd`)

```gdscript
func test_the_skitter_keeps_its_bite_as_data():
	var s := NpcCatalog.load_from_dir("res://data/npcs").get_def(&"skitter")
	assert_eq(s.bite_damage, 15.0)
	assert_eq(s.bite_push, 40.0)
	assert_eq(s.bite_reach, 1.6)
	assert_eq(s.drain_rate, 0.0)
	assert_true(s.shy_of_drills)
	assert_false(s.grips_bases)

func test_a_new_species_defaults_to_the_skitters_bite():
	var s := NpcSpecies.new()
	assert_eq([s.bite_damage, s.bite_push, s.bite_reach], [15.0, 40.0, 1.6])
```

- [ ] **Step 2: Run it to see it fail**

Run: `& .\who-knows\run_tests.ps1 '-gselect=test_npc_species'`
Expected: FAIL (`bite_damage` not found).

- [ ] **Step 3: Add the fields; make `bite()` read them; drop the three constants.** `grep -rn "BITE_DAMAGE\|BITE_PUSH\|Npc.BITE_REACH" src test` and change each use to the species' field (`defend.gd`'s own `BITE_REACH` is the behaviour's lunge distance; leave it).

- [ ] **Step 4: Run** `test_npc_species`, `test_npc_death`, `test_skitter_behaviours`. Expected: PASS.

- [ ] **Step 5: Commit** — `feat: a species' bite and drain are data; the skitter's are unchanged`

---

### Task 2: `RockLife`, with the skitters pinned

**Files:**
- Create: `src/npc/populations/rock_life.gd`
- Create: `test/unit/golden/rock_life_skitters.json` (written by Step 1, before any code changes)
- Test: `test/unit/test_rock_life.gd`

**Interfaces:**
- Produces: `RockLife.ORDER: Array[StringName] = [&"skitter", &"glinter", &"delver", &"limpet"]`; `RockLife.SPACING := 30.0`.
- `RockLife.groups(rock: AsteroidRock, data: RockDetail, world_seed: int) -> Array[Dictionary]`: every group, each with at least `index: int`, `species: StringName`, `home_dir: Vector3`, `count: int`, `seed: int`. Skitter groups are exactly `RockHerds.herds(...)` plus `"species": &"skitter"`, indices `0…n−1`; later species continue the numbering.
- `RockLife.records(rock, data, world_seed, p_groups: Array[Dictionary] = []) -> Array[NpcRecord]`: skitter records are exactly `RockHerds.records(...)`; others are `"<species>:<site>:<index>:<n>"` at `data.surface_point(dir)` with `herd = index`.
- `RockLife.member_dirs(g: Dictionary, data: RockDetail) -> Array[Vector3]`: by species (skitter: `RockHerds.member_dirs`).
- `RockLife.clear_of(data: RockDetail, dir: Vector3, taken: Array[Vector3], metres := SPACING) -> bool`: `dir`'s surface point is `metres` from every taken direction's.
- A species recipe (Tasks 5, 8, 9) is a class with `static func groups(rock, data, world_seed, taken: Array[Vector3], first_index: int) -> Array[Dictionary]` and `static func member_dirs(g: Dictionary, data: RockDetail) -> Array[Vector3]`. `RockLife.groups` calls them in `ORDER`, passing every home taken so far; a species with no recipe class yet is skipped.

- [ ] **Step 1: Write the golden file from today's code**, before touching anything. A throwaway script in the scratchpad (not committed) that, for world seed 1337 and the first 6 giant rocks found as `test_rock_herds.gd`'s `before_all` finds them, plus seeds 7 and 90210 the same way, writes `[{seed, rock: [cell.x, cell.y, cell.z, index], records: [{id, home: [x, y, z], seed, herd}]}]` to `test/unit/golden/rock_life_skitters.json` from `RockHerds.records`. Run it with `& $godot --headless --path who-knows -s <script>`; check the file has records for at least 10 rocks; commit it alone: `test: the skitters' records as they are, to pin through the rock life change`.

- [ ] **Step 2: Write the failing test**

```gdscript
extends GutTest

## One rock, one ecology (rock creatures spec §3.1): every group of every
## species from one recipe, the skitters exactly as before.

const GOLDEN := "res://test/unit/golden/rock_life_skitters.json"

func test_skitter_records_match_the_golden_file():
	var golden: Array = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	for entry: Dictionary in golden:
		var rock := _rock(int(entry["seed"]), entry["rock"])
		var data := RockDetail.build(rock, int(entry["seed"]))
		var skitters := RockLife.records(rock, data, int(entry["seed"])).filter(
			func(r: NpcRecord) -> bool: return r.species == &"skitter")
		assert_eq(skitters.size(), (entry["records"] as Array).size())
		for i in skitters.size():
			var want: Dictionary = entry["records"][i]
			assert_eq(String(skitters[i].id), want["id"])
			assert_almost_eq(skitters[i].home, Vector3(want["home"][0], want["home"][1], want["home"][2]), Vector3.ONE * 0.0001)
			assert_eq(skitters[i].seed, int(want["seed"]))
			assert_eq(skitters[i].herd, int(want["herd"]))

func test_the_same_rock_gives_the_same_life():
	# Two calls: same ids, homes, seeds, in the same order.

func test_ids_are_unique_and_groups_number_on_across_species():
	# Over the 6 rocks: no id twice; skitter groups are 0..n-1; every other
	# group's index is >= the skitter count and unique on its rock.

func test_every_home_lies_on_the_surface():
	# data.surface_point(record.home.normalized()) is within 0.5 m of record.home.
```

`_rock(seed, [x, y, z, index])` finds that rock with `AsteroidRecipe.new(seed).cell_rocks(T.GIANT, Vector3i(x, y, z))[index]`. Write the three bodies as their comments say.

- [ ] **Step 3: Run it to see it fail** — `& $godot --headless --path who-knows --import; & .\who-knows\run_tests.ps1 '-gselect=test_rock_life'`. Expected: FAIL (`RockLife` not declared).

- [ ] **Step 4: Implement `RockLife`** as the Interfaces say. Pure (`extends RefCounted`), no nodes. Skitters come straight from `RockHerds`, which does not change.

- [ ] **Step 5: Run** `test_rock_life`, `test_rock_herds`. Expected: PASS.

- [ ] **Step 6: Commit** — `feat: RockLife lists every group on a rock, skitters pinned to the golden file`

---

### Task 3: One site and one source for every species on a rock

**Files:**
- Modify: `src/npc/populations/rock_site.gd`, `src/npc/npc_site.gd`, `src/npc/npc.gd`
- Create: `src/npc/populations/rock_life_source.gd`; Delete: `src/npc/populations/rock_herd_source.gd` (+ `.uid`)
- Modify: `src/sensors/life_contacts.gd`, `scenes/flight_test.gd` (`_wire_npcs`)
- Modify every other user of `RockHerdSource`, `RockSite.herds` and `RockSite.herd_of` (`grep -rn "RockHerdSource\|\.herds\b\|herd_of(" src scenes test`; `NpcDirector.herd_of` is a different function and stays)
- Test: `test/unit/test_exterior_npcs.gd`, `test/unit/test_life_contacts.gd`, `test/unit/test_rock_life.gd`

**Interfaces:**
- `RockSite`: `groups: Array[Dictionary]` (was `herds`), `records`, `dirs`, `group_of(record: NpcRecord) -> Dictionary` (was `herd_of`). `start_pose` is unchanged for a group with `"round_dirs"`; for any other group it is `pose_at(dirs[record.id])`, cached per record id (it is asked every review and `pose_at` casts a ray).
- `RockSite.fill(ctx, npc)` does what every species shares (mates from `director.herd_of(npc)`, `places[&"shelter"]`), then `match npc.species.id` for the rest: `&"skitter"` keeps today's round, `extra[&"graze"]`, company and fear easing exactly. Later tasks add a branch each.
- `RockSite` Callables, all optional (`is_valid()` checked), set by its source: `place_salvage(cloud_id: StringName, centre: Vector3, entries: Array[Dictionary])`, `base_place(site_id: StringName, from: Vector3) -> Variant`, `base_sip(site_id: StringName, point: Vector3, qe: float) -> float`, `drop(kind: StringName, at: Vector3, up: Vector3, count: int)`, `count_near(kind: StringName, at: Vector3, radius: float) -> int`. Points are engine space.
- `NpcSite` gains no-op hooks the body calls: `died(npc: Npc)`, `surfaced(npc: Npc)`, `sip_source(npc: Npc, dt: float) -> float` (returns 0.0), `group_seed(record: NpcRecord) -> int` (returns `record.seed`). `RockSite.group_seed` returns its group's `seed`.
- `Npc._go_down`: on death (the `else` branch), after marking the ledger, calls `site.died(self)`.
- `RockLifeSource.new(stream: AsteroidStream, catalog: NpcCatalog)`: `records(director) -> Array` and `site_for(rock) -> RockSite` as `RockHerdSource` had them; `reach` = the largest `live_radius` of the catalog's species whose `population` is in `RockLifeSource.POPULATIONS := [&"rock_herds", &"glinter_nests", &"delver_burrows", &"limpet_beds"]`, plus `NpcDirector.DEMOTE_MARGIN`; the same five Callables as `RockSite` plus `quiet`, copied onto each site it builds. `quiet` is asked only for records whose species has `shy_of_drills`.
- `LifeContacts` reads `RockLife.groups`; `herd_id(site, g)` keeps its name and its `"life:%s:%d"` ids. Asleep, a group with `"round_dirs"` is where its round has got to; any other is at `surface_point(home_dir)`.

- [ ] **Step 1: Write the failing tests**

In `test_exterior_npcs.gd`, change `RockHerdSource.new(...)` to `RockLifeSource.new(stream, catalog)`, and add:

```gdscript
func test_the_source_reaches_as_far_as_the_widest_rock_species():
	var src := RockLifeSource.new(_stream, _catalog)
	assert_eq(src.reach, 350.0 + NpcDirector.DEMOTE_MARGIN)   # the skitter's, until Task 5
```

In `test_rock_life.gd`:

```gdscript
func test_a_site_keeps_every_group_and_each_records_direction():
	# RockSite.new(detail, 1337).groups == RockLife.groups(...) by index and
	# species; every record id is a key of site.dirs.
```

`test_life_contacts.gd` must pass unchanged: its ids and regions do not move.

- [ ] **Step 2: Run them to see them fail** — `test_exterior_npcs`, `test_rock_life`. Expected: FAIL (`RockLifeSource` not declared).

- [ ] **Step 3: Implement** as the Interfaces say; rename `herds`/`herd_of` at every caller; wire `_wire_npcs` with `RockLifeSource.new(_stream, exterior_npcs.catalog)` and `quiet = bases.quiet` (the drop Callables come in later tasks).

- [ ] **Step 4: Run** `test_exterior_npcs`, `test_life_contacts`, `test_rock_life`, `test_rock_herds`, `test_npc_director`, `test_floating_origin_scene`. Expected: PASS.

- [ ] **Step 5: Commit** — `feat: one site and one source hold every species on a rock`

---

### Task 4: The dev spawner (F10)

**Files:**
- Create: `src/ui/creature_panel.gd`, `src/npc/populations/dev_creatures.gd`
- Modify: `src/ui/spawn_panel.gd` (closes the other dev panel on opening), `src/npc/populations/rock_site.gd` (`add_group`), `scenes/flight_test.gd`
- Test: `test/unit/test_creature_panel.gd`, `test/unit/test_dev_creatures.gd`

**Interfaces:**
- `CreaturePanel extends Label`, built like `SpawnPanel`: `signal creature_asked(index: int)`; `KEY := KEY_F10`; `GROUP := &"dev_panels"`; `entries: Array[String]`; `say(text: String)`. Open, `1`–`9` ask for that entry; a held key's repeats never ask. Both panels join `GROUP`; opening either hides every other member. Title line: `CREATURES            F10 closes`.
- `CreaturePanel.ORDER: Array[StringName] = [&"skitter", &"glinter", &"delver", &"limpet", &"maintenance_droid"]`; the flight scene lists those its catalog has, in that order.
- `DevCreatures`: `records(director: NpcDirector) -> Array` (its `[record, site]` entries); `add(record: NpcRecord, site: NpcSite)`; `next_id(species: StringName) -> StringName` (`"dev:<species>:<n>"`, `n` from 1 for the session). An entry is dropped once its site is not alive, or once its record has been live and no longer is (demoted or dead).
- `RockSite.add_group(species: StringName, dir: Vector3, count: int, ids: Array[StringName]) -> Array[NpcRecord]`: a group with index `1000 + k` (k counts this site's dev groups), `home_dir = dir`, members `RockLife.member_dirs`-style round `dir`; each record also goes in `dirs`.
- Flight scene: `spawn_creature(species: StringName) -> String` returns the panel's last line. Counts `{&"skitter": 3, &"glinter": 4, &"limpet": 6}`, else 1. On a rock: a ray from the current camera through the screen centre, at most **60 m**, onto `AsteroidBody.LAYER`; the rock's site from `RockLifeSource.site_for`; the direction is the hit point in the rock's frame, normalised. The droid: aboard, a ray onto the interior's floor; its site is `aboard.crew_site`. One `DevCreatures` is appended to the exterior director's sources and one to each ship's `npc_director.sources` when that ship is wired. Lines: `"<Name> x<n> on the rock"`, `"needs a big rock in view"`, `"needs to be aboard"`.

- [ ] **Step 1: Write the failing tests**

```gdscript
# test_creature_panel.gd
func test_f10_opens_and_shuts_it():
func test_shut_the_number_keys_do_nothing():
func test_open_2_asks_for_the_second_entry_once_even_held():
	# press KEY_2, then an echo of KEY_2: creature_asked emitted once with 1.
func test_opening_one_dev_panel_shuts_the_other():
	# A SpawnPanel and a CreaturePanel in the tree: F6, then F10 -> the spawn
	# panel is hidden; KEY_1 then asks only the creature panel.
```

```gdscript
# test_dev_creatures.gd
func test_records_are_offered_until_demoted_then_forgotten():
func test_records_go_with_their_site():
	# site.alive() false -> records(director) is empty.
func test_ids_count_up_and_never_look_like_a_rocks():
	# next_id(&"limpet") twice -> &"dev:limpet:1", &"dev:limpet:2".
func test_spawning_a_skitter_group_on_the_start_rock():
	# The flight scene, a spacewalk facing the start rock within 60 m (as
	# test_exterior_npcs places the avatar): spawn_creature(&"skitter") says
	# "Skitter x3 on the rock"; after a review, three live NPCs with ids
	# beginning "dev:skitter:" stand within 1 m of the rock's surface.
func test_no_rock_in_view_says_why():
	# Facing open space: "needs a big rock in view"; nothing new is live.
```

- [ ] **Step 2: Run them to see them fail** (import first). Expected: FAIL.
- [ ] **Step 3: Implement** as the Interfaces say. In `flight_test.gd`, add the panel under `$Prompt` next to `spawn_panel` and connect `creature_asked` to `spawn_creature(ORDER-filtered[i])` with `say`.
- [ ] **Step 4: Run** `test_creature_panel`, `test_dev_creatures`, `test_spawn_panel`. Expected: PASS.
- [ ] **Step 5: Commit** — `feat: F10 spawns a creature at the crosshair, for the session only`

---

### Task 5: The Limpet on its bed

**Files:**
- Create: `src/npc/populations/limpet_beds.gd`, `src/npc/limpet_look.gd`, `data/npcs/limpet.tres`, `src/npc/behaviours/cling.gd`
- Modify: `src/npc/populations/rock_life.gd` (calls `LimpetBeds`), `src/npc/npc_looks.gd`, `test/unit/test_visual_style_rules.gd` (`PAINTING_FILES`), `test/unit/test_npc_catalog.gd` (it counts two species)
- Test: `test/unit/test_limpet_beds.gd`, `test/unit/test_limpet_behaviours.gd`, `test/unit/test_npc_looks.gd`

**Interfaces:**
- `LimpetBeds.SPECIES := &"limpet"`, `SALT := 19`, `MOST := 2`, `MEMBERS := Vector2i(8, 12)`, `SPREAD := 2.5` (m, members round the home). `groups(...)`: 0–2 beds; on a `VEINED` rock homes are directions where `RockMesh.in_vein(d)`; otherwise crater rims (`RockHerds.tilted(centre, angular, bearing)` with the crater's angular radius). Each bed is `RockLife.clear_of` the taken homes and the beds before it.
- `limpet.tres`: every value in spec §7.3's Limpet column, `population = &"limpet_beds"`, `behaviours = [&"cling", &"creep", &"sip"]` (Task 6 adds the last two; until then list only `&"cling"`), `look = &"limpet"`, `needs = {&"appetite": 0.01, &"fear": 0.0}` with `need_start` for each, `drain_rate = 0.4`, `drain_reach = 5.0`, `shy_of_drills = false`, `grips_bases = true`, `bite_damage = 0.0`.
- `cling`: score `0.2`, never done, thinks `Intent.idle(&"cling")`.
- `LimpetLook extends Node3D`: `build(variety: float, colour: Color, p_fade: Vector2)`, `act(action: StringName)`; a low flat cone of chunky facets in `colour`, underside `SpacePalette.CRYSTAL`, **≤ 80 triangles**; `act(&"sip")` swaps the crystal facets to the brightest `SpacePalette.SHADES` step, any other action swaps back. Its distance fade and render layer copy `SkitterLook`'s (spec §9: reversed, layer 1). `NpcLooks.build` and `built_size` know `&"limpet"`.

- [ ] **Step 1: Write the failing tests**

```gdscript
# test_limpet_beds.gd: over the 6 rocks test_rock_herds finds, and a VEINED one found the same way
func test_beds_are_few_and_full():          # 0..2 beds; 8..12 members each
func test_on_a_veined_rock_beds_sit_on_the_vein():   # RockMesh.in_vein(home_dir)
func test_beds_keep_30_m_from_every_other_home():   # via RockLife.groups: no limpet home within 30 m of another group's
func test_adding_limpets_leaves_the_skitters_alone():   # test_rock_life's golden test still passes (run it)
func test_a_drill_does_not_clear_limpets():
	# Through RockLifeSource with quiet returning true everywhere: the rock's
	# limpet records are offered, its skitters are not (shy_of_drills).
```

```gdscript
# test_limpet_behaviours.gd (from templates/test_behaviours.gd)
func test_every_behaviour_exists():
func test_cling_is_the_quiet_default():   # score 0.2; think action &"cling", no move_to
```

In `test_npc_looks.gd`: `test_the_limpet_is_built_low_and_cheap` (not a placeholder; triangles ≤ 80; `act(&"sip")` changes the crystal facets' colour to `SpacePalette.SHADES[-1]`).

- [ ] **Step 2: Run them to see them fail.** Expected: FAIL.
- [ ] **Step 3: Implement.** Update `test_npc_catalog.gd`'s species count and `RockLifeSource.reach` stays the skitter's 450 m (the Limpet's 100 m is smaller).
- [ ] **Step 4: Run** `test_limpet_beds`, `test_limpet_behaviours`, `test_npc_looks`, `test_npc_catalog`, `test_rock_life`, `test_visual_style_rules`. Expected: PASS.
- [ ] **Step 5: Render** a bed from a spacewalk at 40 m and 100 m (dev-spawn one with F10 if the start rock has none) and show the owner. A new colour, if any, waits for their approval.
- [ ] **Step 6: Commit** — `feat: Limpet beds on the vein and crater rims`

---

### Task 6: The Limpet sips

**Files:**
- Modify: `src/items/hit.gd`, `src/quantum/suit_cell.gd`, `src/avatar/avatar.gd`, `src/habitat/bases.gd`, `src/npc/npc.gd`, `src/npc/populations/rock_site.gd`, `src/npc/surface_crawler.gd`, `scenes/flight_test.gd`, `data/npcs/limpet.tres`
- Create: `src/npc/behaviours/creep.gd`, `src/npc/behaviours/sip.gd`
- Test: `test/unit/test_limpet_sip.gd`, `test/unit/test_limpet_behaviours.gd`, `test/unit/test_suit_cell.gd`, `test/unit/test_surface_crawler.gd`

**Interfaces:**
- `Hit.drain := 0.0` (QE asked) and `Hit.drained := 0.0` (QE the receiver gave). Kind `&"sip"`.
- `SuitCell.drain(qe: float) -> float`: takes up to `qe`, down to 0; returns what it took.
- `Avatar.SIP_CAP := 1.2` (QE/s). A budget refills at `SIP_CAP` per second up to `SIP_CAP`. In `receive_hit`, a hit with `drain > 0` while `mode == Mode.SUIT` takes `minf(drain, budget)` through `suit_cell.drain` and writes `hit.drained`. Seated or downed, `receive_hit` already returns early.
- `Bases.SIP_REACH := 4.0`. `sip(site_id: StringName, point: Vector3, qe: float) -> float`: for the awake base on `site_id` (`on(site_id)`, then `named(site.id)`), if `point` is within `SIP_REACH` of a module cell's centre (reuse the cell-to-local conversion `BaseSite.centre_of` uses, through `frame_of`), `base.quantum.store.spend_continuous(qe, &"limpet")` and return `qe` (0.0 if refused, asleep or out of reach). `place_of(site_id: StringName, from: Vector3) -> Variant`: the nearest module cell centre of that awake base, engine space, or null.
- `RockSite` consts `SUIT_DRAW := 20.0`, `RAID := 100.0`, `RAID_NEAR := 300.0`, `BASE_RATE := 0.05` (QE/s). Its `&"limpet"` fill: `places[&"quantum"]` = the player's site-local position if `ctx.player` is within `SUIT_DRAW`; else, if `base_place` gives a point within `RAID` of the record's home and some anchor without meta `&"base"` (from `director.anchors()`) is within `RAID_NEAR` of the bed's home, that point (site-local). `sip_source(npc, dt)` returns `base_sip.call(id, npc.global_position, BASE_RATE * dt)` or 0.
- `Npc.sipped := 0.0` (reset in `setup`). `Npc.sip(dt: float) -> float`: if the avatar is within `species.drain_reach` of the body's middle, a `Hit` with `drain = species.drain_rate * dt`, kind `&"sip"`, delivered by `Hit.deliver`, takes `hit.drained`; otherwise it takes `site.sip_source(self, dt)`. Adds to `sipped`; returns it. `think` calls `sip(dt)` when the intent's action is `&"sip"`, as it calls `bite()`.
- `creep`: score `Curves.ramp(appetite, 0.3, 0.8)` with `places[&"quantum"]` known, else 0; thinks `Intent.go(quantum, 0.8)` (0.2 m/s at top speed 0.25); done within `species.drain_reach` of it.
- `sip`: score `0.9` while `places[&"quantum"]` is within `species.drain_reach`; thinks `Intent.idle(&"sip")` and eases appetite `0.02`/s; done once out of reach.
- `SurfaceCrawler`: with `species.grips_bases`, its rays' mask is `AsteroidBody.LAYER | 1`, and a hit on layer 1 whose collider has no meta `&"base"` counts as no hit.

- [ ] **Step 1: Write the failing tests**

```gdscript
# test_suit_cell.gd
func test_drain_takes_what_it_can_and_says_how_much():
	var c := SuitCell.new(); c.charge = 1.0
	assert_eq(c.drain(0.4), 0.4)
	assert_eq(c.drain(5.0), 0.6)
	assert_true(c.is_dry())
```

```gdscript
# test_limpet_sip.gd
func test_one_limpet_sips_0_4_qe_a_second_from_your_suit():
	# A spacewalking avatar, 2 m from a live dev limpet in its sip behaviour,
	# suit at 100: after 10 s of physics the cell holds 96 (+-0.2).
func test_a_whole_bed_takes_no_more_than_1_2_qe_a_second():
	# Six limpets within reach for 10 s: the cell loses 12 (+-0.3), not 24.
func test_a_dry_suit_brings_you_home():
	# Charge 0.5 with a bed on you: the cell runs dry and the suit's homing
	# starts (whatever avatar.gd's dry check sets, read in Step 3).
func test_the_ships_store_is_never_touched():
	# The aboard ship's quantum store amount is unchanged after the above.
func test_an_awake_base_is_sipped_at_0_05_qe_a_second_each():
	# A base planted on the start rock (as test_bases does), six limpets
	# within 4 m of a module, the avatar 50 m off: 60 s costs 18 QE (+-1).
func test_a_base_is_not_sipped_with_no_one_near():
	# The same, with the avatar and the ship moved 5 km away (the base still
	# awake): its store is unchanged.
func test_an_asleep_base_is_not_sipped():   # Bases.sip on a slept base returns 0
```

```gdscript
# test_surface_crawler.gd
func test_a_limpet_grips_a_base_wall():
func test_a_ship_hull_is_not_ground_for_a_limpet():
	# A limpet set on the starter's hull: it never grips (it hands over to
	# zero_g_drift within LOST_AFTER).
```

In `test_limpet_behaviours.gd`: `test_creep_goes_for_the_quantum_when_hungry`, `test_sip_holds_while_in_reach`.

- [ ] **Step 2: Run them to see them fail.** Expected: FAIL.
- [ ] **Step 3: Implement**; add `&"creep"`, `&"sip"` to `limpet.tres`; wire `base_place = bases.place_of` and `base_sip = bases.sip` on the source in `_wire_npcs`. Read `avatar.gd` around its `suit_cell.is_dry()` checks for what a dry suit triggers (the two dry-route fixes on `quantum-energy`, `330f1df` and `898f26b`, are not on `main`: test `main`'s behaviour, spec §16).
- [ ] **Step 4: Run** `test_limpet_sip`, `test_limpet_behaviours`, `test_suit_cell`, `test_surface_crawler`, `test_bases`, `test_hit`. Expected: PASS.
- [ ] **Step 5: Commit** — `feat: Limpets sip your suit and raid a base while you are near`

---

### Task 7: The Limpet's husks

**Files:**
- Create: `data/items/limpet_husk.tres`
- Modify: `src/items/item_looks.gd` (look `limpet_husk`, in `LOOKS` and `GLINTS`), `src/npc/populations/rock_site.gd` (`died`), `src/world/stray_field.gd` (`count_of`, used again in Task 11), `scenes/flight_test.gd` (the `drop` and `count_near` Callables)
- Test: `test/unit/test_limpet_sip.gd`, `test/unit/test_item_looks.gd`, `test/unit/test_item_catalog.gd`

**Interfaces:**
- `limpet_husk.tres`: `quantum_value = 20`, small, `look = &"limpet_husk"` (a shell half, lavender from `InteriorPalette`).
- `RockSite.died(npc)`, `&"limpet"`: `drop.call(&"limpet_husk", npc.global_position, npc.global_basis.y, 1 + mini(floori(npc.sipped / 40.0), 3))`.
- `StrayField.count_of(kind: StringName, at: Vector3, radius: float) -> int`: strays of `kind` within `radius` of engine point `at`, unloaded ones too (`sync()` first, then the ledger's places).
- Flight scene `_drop(kind, at, up, count)`: `count` items from the catalog, each `set_space(true)`, set `0.15 m` up `up` and `0.3 m` apart round `at`, at rest, `strays.adopt(item)`. `count_near` = `strays.count_of`.

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_a_lean_limpet_leaves_one_husk_and_a_fat_one_up_to_four():
	# A live dev limpet with sipped = 0 killed (take_damage(100)): one
	# limpet_husk stray within 1 m. Another with sipped = 95: three. With
	# sipped = 400: four.
func test_a_dead_limpet_stays_dead():
	# After the kill, NpcLedger.is_dead(id) and a review does not wake it.
```

In `test_item_looks.gd`, the husk is built, glints, and is inside its size.

- [ ] **Step 2: Run them to see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `test_limpet_sip`, `test_item_looks`, `test_item_catalog`, `test_stray_ledger`. Expected: PASS.
- [ ] **Step 5: Render** a Limpet sipping beside a spacewalker, a bed on a base's wall, and husks after a kill; show the owner. The Limpet is done when they approve.
- [ ] **Step 6: Commit** — `feat: a killed Limpet gives back husks for what it sipped`

---

### Task 8: Salvage placed in a nest

**Files:**
- Modify: `src/world/salvage_field.gd`
- Test: `test/unit/test_placed_cloud.gd`

**Interfaces:**
- `SalvageField.add_placed_cloud(cloud_id: StringName, centre: Vector3, entries: Array[Dictionary])`: `centre` engine space, stored as a `UniversePoint`; each entry `{index: int, kind: StringName, variety: float, pose: Transform3D}` with `pose` relative to `centre`. `cloud_items` returns a placed cloud's entries with `tumble = Vector3.ZERO`. Registering an id already loaded keeps its loaded items and replaces only the stored centre and entries. `is_placed(cloud_id) -> bool`.
- `to_dict` leaves placed clouds out (they are registered again when their rock comes into detail); the ledger keeps what was taken from them. `VERSION` stays 1.

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_placed_items_load_where_they_were_put_and_at_rest():
	# Two entries at known poses near the focus: after update(), two items at
	# centre + pose.origin (within 0.001), angular_velocity zero.
func test_a_nest_registered_again_loads_once_and_keeps_what_was_taken():
	# Load, consume index 0, register the same id again, free beyond 4 km and
	# come back: one item (index 1), never two.
func test_placed_clouds_are_not_saved_but_their_ledger_is():
	# to_dict() has no centre for the placed id; "taken" holds its index 0.
func test_a_placed_cloud_keeps_its_place_through_a_shift():
```

- [ ] **Step 2: Run to see it fail.** — **Step 3: Implement.** — **Step 4: Run** `test_placed_cloud`, `test_salvage_field`, `test_salvage_ledger`. Expected: PASS.
- [ ] **Step 5: Commit** — `feat: a salvage cloud can be placed item by item`

---

### Task 9: The Glinter's nest

**Files:**
- Create: `src/npc/populations/glinter_nests.gd`, `src/npc/glinter_look.gd`, `data/npcs/glinter.tres`, `src/npc/behaviours/lure.gd`
- Modify: `src/npc/populations/rock_life.gd`, `rock_site.gd` (registers the nest's salvage; the `&"glinter"` fill), `src/npc/npc.gd` (`_build_look` passes the group seed), `src/npc/npc_looks.gd`, `src/items/item_looks.gd` (clock-driven glint), `test/unit/test_visual_style_rules.gd`, `scenes/flight_test.gd` (`place_salvage = salvage.add_placed_cloud`)
- Test: `test/unit/test_glinter_nests.gd`, `test/unit/test_glinter_behaviours.gd`, `test/unit/test_npc_looks.gd`

**Interfaces:**
- `GlinterNests.SPECIES := &"glinter"`, `SALT := 13`, `CHANCE := 1.0 / 3.0`, `MEMBERS := Vector2i(3, 5)`, `SALVAGE := Vector2i(2, 4)`, `SPREAD := 3.0` (m), `GAP := 1.0` (m). `groups(...)`: only rocks with craters; one nest with chance `CHANCE` on a crater floor (`home_dir` = the crater's centre direction) clear of taken homes; the group adds `salvage: Array[Dictionary]` of `{index, kind, variety, dir}` with kinds weighted by `SalvageField.MIX`, every Glinter and item `GAP` apart.
- `RockSite`, when built with a nest and a valid `place_salvage`: `place_salvage.call(StringName("nest:%s:%d" % [id, index]), frame() * pose_at(home_dir).origin, entries)`, each entry's `pose` = `frame() * pose_at(dir)` made relative to that centre (rock orientation kept: the rock never turns).
- `RockSite.group_seed(record)` feeds `Npc._build_look`: `if look.has_method(&"set_group_seed"): look.call(&"set_group_seed", site.group_seed(record))`.
- `ItemLooks.Glint.clock_phase: Variant = null`: when a float, `_process` shows it while `fposmod(Time.get_ticks_msec() / 1000.0 + clock_phase, period) < GLINT_FLASH`.
- `GlinterLook`: `BEAT := 1.6`; `build(variety, colour, p_fade)`, `act(action)`, `set_group_seed(s: int)` sets its glint's `period = BEAT`, `clock_phase = fposmod(float(s & 0xFFFF) / 65535.0, 1.0) * BEAT`. A scrap-coloured lump on short legs, **≤ 120 triangles**; `act(&"leap")`/`act(&"bite")` shows two `SpacePalette.SKITTER_EYE` facets, `act(&"shut")` hides them.
- `glinter.tres`: spec §7.3's Glinter column; `population = &"glinter_nests"`; `behaviours = [&"lure", &"hide"]` (Task 10 adds `&"ambush"`); `needs = {&"fear": 0.0}`; `bite_damage = 8.0`, `bite_push = 25.0`, `bite_reach = 0.8`.
- `lure`: score `0.2`, thinks `Intent.idle(&"shut")`; it eases fear `0.05`/s.

- [ ] **Step 1: Write the failing tests**

```gdscript
# test_glinter_nests.gd
func test_about_a_third_of_cratered_rocks_have_a_nest():
	# Over 60 cratered giant rocks: between 10 and 30 nests.
func test_a_nest_holds_3_to_5_glinters_and_2_to_4_items_of_the_mix():
func test_nests_keep_30_m_from_skitter_herds():
func test_glinters_and_items_keep_apart():
```

```gdscript
# test_npc_looks.gd
func test_a_nests_glinters_flash_on_one_beat_outside_the_salvage_band():
	# Two GlinterLooks with the same group seed, built a frame apart: their
	# glints' period is 1.6, below ItemLooks.GLINT_EVERY.x, and visible on
	# the same frames over 4 s of _process. A different seed flashes apart.
func test_the_glinter_is_built_and_cheap():   # <= 120 triangles, not a placeholder
```

Plus, in `test_glinter_behaviours.gd`, `test_lure_sits_shut`; and in `test_placed_cloud.gd`, `test_a_nests_salvage_lies_on_the_crater_floor` (a rock with a nest in detail through `RockLifeSource`: its `nest:` cloud's items within 0.5 m of the surface).

- [ ] **Step 2: Run to see them fail.** — **Step 3: Implement.** — **Step 4: Run** `test_glinter_nests`, `test_glinter_behaviours`, `test_npc_looks`, `test_placed_cloud`, `test_rock_life`, `test_npc_catalog`, `test_visual_style_rules`. Expected: PASS.
- [ ] **Step 5: Commit** — `feat: Glinter nests of real salvage, flashing on one beat`

---

### Task 10: The Glinter springs

**Files:**
- Create: `src/npc/behaviours/ambush.gd`
- Modify: `src/npc/surface_crawler.gd` (`aim_leap` also hits the avatar's layer 4), `data/npcs/glinter.tres`
- Test: `test/unit/test_glinter_behaviours.gd`, `test/unit/test_surface_crawler.gd`; probe `test/probes/glinter_leap.gd` (new)

**Interfaces:**
- `ambush`: reflex, `threshold = 0.5`, `AMBUSH := 5.0`, `CALM := 0.4`, `AFTER_FEAR := 0.8`, `GIVE_UP := 4.0` (s). Score `1.0` when `ctx.player` is within `AMBUSH` and fear `< CALM`, else 0. First think: `Intent.idle(&"leap")` with `leap_to = ctx.player`. Then: within `ctx.species.bite_reach + 0.3` of the player, `Intent.go(player, 1.0, &"bite")` once and `ctx.raise(&"fear", AFTER_FEAR)`; otherwise `Intent.go(player, 1.0, &"lunge")`. Done once it has bitten, or after `GIVE_UP`.
- `hide` (reused) then takes it to the crater floor until fear fades below 0.2; `lure` eases it back.

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_ambush_springs_within_5_m_when_calm():
	# player at 4.9 m, fear 0.1 -> score >= threshold; at 5.1 m -> 0; fear 0.5 -> 0.
func test_ambush_leaps_at_you_then_bites_once_and_is_afraid():
	# first think: action &"leap", leap_to == player; player moved to 0.5 m:
	# action &"bite", fear >= 0.8, done() true.
func test_a_leap_aims_at_a_spacewalker_over_open_space():
	# test_surface_crawler: a crawler on the start rock, the avatar 4 m above
	# it with nothing beyond: aim_leap returns a point within 0.6 m of the avatar.
```

- [ ] **Step 2: Run to see them fail.** — **Step 3: Implement.**
- [ ] **Step 4: The leap check (spec §16).** Write `test/probes/glinter_leap.gd` (windowed, `save_enabled = false`, like `skitter_render.gd`): a spacewalker drifting at 0.5 m/s 4 m over a dev-spawned nest; over 20 tries report how many leaps end within `bite_reach` of the suit and bite. Most (at least 15 of 20) must. **If not**, the spec's fallback: the leap becomes a lunge along the surface (`Intent.go(player, 1.0, &"lunge")` only) and `AMBUSH` drops to **3 m**; change the test values to match and tell the owner.
- [ ] **Step 5: Run** `test_glinter_behaviours`, `test_surface_crawler`, `test_skitter_behaviours`. Expected: PASS.
- [ ] **Step 6: Render** a nest at 40 m and 100 m (the shared beat across frames, beside real salvage's own blinks), and a spring-and-bite from a spacewalk; show the owner. The Glinter is done when they approve.
- [ ] **Step 7: Commit** — `feat: a calm Glinter springs at a spacewalker within 5 m and bites once`

---

### Task 11: The `Burrower`

**Files:**
- Create: `src/npc/burrower.gd`
- Modify: `src/npc/npc.gd` (`make_locomotor`, `set_solid`, `surfaced_at`, `surfaced()`; `setup` makes it solid), `src/npc/surface_crawler.gd` (hands over on `&"burrow"`)
- Test: `test/unit/test_burrower.gd`, `test/unit/test_npc_catalog.gd` (the locomotor exists)

**Interfaces:**
- `Burrower extends Locomotor`, id `&"burrower"`: `SINK := 1.5` (s), `UNDER_SPEED := 2.0` (m/s), `RISE := 1.5` (s). Only on a `RockSite`; elsewhere it hands straight back. `enter`: the target is `npc.intent.move_to` (site-local); sinking, the look drops by `species.height` over `SINK`; then `npc.set_solid(false)`, the look hidden and `Weapons.leave(npc)`. Under: the body's site-local point moves along the surface (`site.data.surface_point` of directions slerped from its own toward the target's, no rays) at `UNDER_SPEED`. At the target: `site.pose_at(target.normalized())` once, `Weapons.join(npc, Weapons.npc_id(npc.record.id))` if the director has `targets`, look shown and rising over `RISE`, then `npc.set_solid(true)`, `npc.surfaced()`, and `handover` returns `&"surface_crawler"`. `grounded()` is true. Resting (nothing to do) does nothing.
- `Npc.set_solid(on: bool)`: the body's and the skin's shapes disabled or not. `setup` calls `set_solid(true)` and shows the look (a pooled node may have been demoted under).
- `Npc.surfaced_at := 0.0` (set to the director's time in `setup` and on surfacing); `think` adds `ctx.extra[&"surfaced_ago"]`. `Npc.surfaced()`: sets `surfaced_at`, `site.surfaced(self)`, `look.act(&"emerge")`.
- `SurfaceCrawler.handover`: `&"burrower"` when `npc.intent.action == &"burrow"` and the NPC has that locomotor.

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_it_sinks_travels_hidden_and_comes_up_at_the_target():
	# A dev Delver-shaped test species (crawler + burrower) on the start rock,
	# intent go(point 20 m away, 1.0, &"burrow"): within 1.6 s it is not
	# solid and not a target; its look hidden; at ~2 m/s it reaches the point;
	# it emerges within 1 m of it, solid, back on surface_crawler; surfaced()
	# was called once.
func test_a_pooled_delver_comes_back_solid_and_a_target():
	# Demote it while under, promote the node again: solid, look shown, in
	# Weapons' targets.
func test_resting_does_nothing():
	# No intent: 120 ticks of step() move it 0 m and cast no ray (count rays
	# with a spy site whose pose_at counts calls: zero).
```

- [ ] **Step 2: Run to see them fail.** — **Step 3: Implement.** — **Step 4: Run** `test_burrower`, `test_surface_crawler`, `test_npc_layers`, `test_npc_director`. Expected: PASS.
- [ ] **Step 5: Commit** — `feat: the burrower sinks, travels under the rock and comes up elsewhere`

---

### Task 12: The Delver and its pay

**Files:**
- Create: `src/npc/populations/delver_burrows.gd`, `src/npc/delver_look.gd`, `data/npcs/delver.tres`, `data/items/crystal_grit.tres`, `src/npc/behaviours/feed.gd`, `delve.gd`, `dive.gd`
- Modify: `src/npc/populations/rock_life.gd`, `rock_site.gd` (the `&"delver"` fill, `surfaced`, `died`), `src/npc/npc_looks.gd`, `src/items/item_looks.gd` (look `crystal_grit`, in `LOOKS` and `GLINTS`), `test/unit/test_visual_style_rules.gd`
- Test: `test/unit/test_delver_burrows.gd`, `test/unit/test_delver_behaviours.gd`, `test/unit/test_delver_pay.gd`, `test/unit/test_npc_looks.gd`

**Interfaces:**
- `DelverBurrows.SPECIES := &"delver"`, `SALT := 17`, `POINTS := Vector2i(6, 10)`, `CYCLE := Vector2(180.0, 360.0)` (s). `groups(...)`: only `RockMesh.Shape.VEINED` rocks; one Delver whose home is a vein direction clear of taken homes; the group adds `burrows: Array[Vector3]`, 6–10 vein directions (each `RockMesh.in_vein`), at least 15 m apart on the surface.
- `RockSite` `&"delver"` fill: `extra[&"burrows"]` = the burrow points (site-local), `places[&"crystal"]` = the nearest, `places[&"burrow"]` = the next one round after the nearest, `extra[&"cycle"]` = `lerpf(CYCLE.x, CYCLE.y, randf from record.seed)`.
- `RockSite` consts `GRIT := Vector2i(2, 4)`, `SHARD_ODDS := 12`, `GRIT_CAP := 8`, `CAP_RADIUS` = the rock's radius + 50 m. `surfaced(npc)`, `&"delver"`: unless `count_near(&"crystal_grit", rock centre, CAP_RADIUS) >= GRIT_CAP`, drops 2–4 `crystal_grit`; 1 in `SHARD_ODDS` also drops a `quantum_shard` unless one already lies within `CAP_RADIUS`. Rolls come from an RNG seeded by `record.seed` and a count of its surfacings. `died(npc)`, `&"delver"`: one `quantum_shard` and six `crystal_grit`.
- `feed`: score `Curves.ramp(hunger, 0.3, 0.8)`; goes to `crystal` at 0.5; there, `Intent.idle(&"eat")` and eases hunger `0.05`/s; done below 0.1.
- `delve`: score `0.7` when hunger `< 0.3` and `extra[&"surfaced_ago"] >= extra[&"cycle"]`; thinks `Intent.go(places[&"burrow"], 1.0, &"burrow")`; done once `surfaced_ago < running(ctx)`.
- `dive`: reflex, threshold 0.5; score `1.0` on a `Stimulus.VIBRATION` or `Stimulus.TOUCH` within the last 1 s while grounded; thinks `Intent.go(Behaviour.farthest_from(extra[&"burrows"], position, position), 1.0, &"burrow")`; done as `delve`.
- `DelverBurrows.round_near(data: RockDetail, dir: Vector3, rng: RandomNumberGenerator) -> Array[Vector3]`: 6–10 directions within 0.5 rad of `dir`, 15 m apart, vein or not. `RockSite.add_group` gives a dev `&"delver"` group `burrows` from it, so a Delver spawned on any rock has a round. Behaviours that read `places[&"burrow"]` or `extra[&"burrows"]` score 0 without them.
- `delver.tres`: spec §7.3's Delver column; `population = &"delver_burrows"`; `needs = {&"hunger": 0.004, &"fear": 0.0}`.
- `DelverLook`: about six chunky plates trailing a blunt head with a `SpacePalette.CRYSTAL` snout, no legs, **≤ 300 triangles**; `act(&"emerge")` plays a ring of puffs, made in its own local space (no world-space particles).
- `crystal_grit.tres`: `quantum_value = 15`, small, lavender from `InteriorPalette`, glints.
- If the probe in Task 13 shows the 3 m body snagging, the spec's fallback: a 1.2 m collider at the head with the look trailing.

- [ ] **Step 1: Write the failing tests**

```gdscript
# test_delver_burrows.gd
func test_only_veined_rocks_have_a_delver():
func test_its_round_is_6_to_10_points_on_the_vein_15_m_apart():
```

```gdscript
# test_delver_behaviours.gd
func test_feed_goes_to_the_crystal_when_hungry_and_eats_there():
func test_delve_waits_out_its_cycle_then_burrows_to_the_next_point():
func test_dive_sends_it_to_the_farthest_point_at_once():
```

```gdscript
# test_delver_pay.gd (live dev Delver on a VEINED rock found as Task 2 finds rocks)
func test_each_surfacing_leaves_2_to_4_grit():
func test_grit_stops_at_8_near_the_rock_and_one_shard_at_a_time():
	# count_near stubbed at 8: a surfacing drops nothing; with a shard already
	# near, no second shard over 60 surfacings.
func test_about_one_surfacing_in_12_leaves_a_shard():
	# Over 600 rolls with the caps stubbed off: 30..70 shards.
func test_a_dead_delver_leaves_a_shard_and_six_grit():
func test_drills_keep_delvers_away():
	# quiet true at its home: its record is not offered (shy_of_drills).
```

- [ ] **Step 2: Run to see them fail.** — **Step 3: Implement.** — **Step 4: Run** `test_delver_burrows`, `test_delver_behaviours`, `test_delver_pay`, `test_burrower`, `test_npc_looks`, `test_item_looks`, `test_item_catalog`, `test_npc_catalog`, `test_rock_life`, `test_visual_style_rules`. Expected: PASS.
- [ ] **Step 5: Render** a Delver sinking and rising, its puffs and heap, from 40 m and 100 m; show the owner. The Delver is done when they approve.
- [ ] **Step 6: Commit** — `feat: the Delver burrows on veined rocks and pays in grit, sometimes a shard`

---

### Task 13: The frame budget, the scene checks and the documents

**Files:**
- Modify: `test/probes/npc_probe.gd`, `test/unit/test_exterior_npcs.gd`, `test/unit/test_floating_origin_scene.gd`
- Modify: `.claude/skills/building-an-npc/SKILL.md`, `reference.md`; `docs/design/visual-style.md` §3.6; `docs/superpowers/specs/2026-09-26-habitat-modules-design.md` §8.4; `docs/superpowers/specs/2026-10-10-rock-creatures-design.md` (*As built*, and the planning calls above)

- [ ] **Step 1: Extend `test_exterior_npcs.gd`**: each new species, dev-spawned on the start rock, wakes unseen beyond its fade, holds its place through `Universe.shift`, and is gone with no orphans after a warp moves the ship 50 km (as the skitters' tests do); `quiet` is asked per species (`shy_of_drills`). Run it. Expected: PASS.
- [ ] **Step 2: Run `test_floating_origin_scene`** with a nest, a Delver and a bed live. Expected: PASS with no new members missing.
- [ ] **Step 3: The frame probe.** Add a `--rock-creatures` mode to `npc_probe.gd`: fill the exterior director on the worst rock (three skitter herds, a nest, a Delver and two Limpet beds, dev-spawned where the rock lacks them), time 600 frames, report the NPC milliseconds per frame and the machine. Under **1 ms** passes. Over: lower a wake radius or `max_live` and measure again; the measurement is not skipped. Run it alone (no other probe on the GPU).
- [ ] **Step 4: Documents, in this branch (CLAUDE.md).** The skill: checklist lines (a rock holds many species and group numbers carry on; `shy_of_drills`; `grips_bases`; the body delivers every drain and drop through its site); *Mistakes already made* (what this build learnt: at least the crawler seeing only rock, and an awake base being an anchor); `reference.md` (the new species fields, `RockLife` and the recipe contract, `RockSite`'s Callables, `Burrower`, the `&"sip"` hit kind, F10, `DevCreatures`). Fix any name in the skill that no longer exists (`RockHerdSource`). The style guide §3.6: a bullet per creature, as approved. Habitat modules §8.4: Limpets raid; Delvers keep away from a drill. The spec: *As built*, with the six planning calls.
- [ ] **Step 5: Commit** — `docs: rock creatures as built -- the skill, the style guide, habitat §8.4, the spec`
- [ ] **Step 6: Ask the owner** whether to run the full suite before the branch is finished.
