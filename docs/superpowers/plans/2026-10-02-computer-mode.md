# Computer Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Press F at the bridge computer's table to glide down over its holo, work it with the mouse (pick, orbit, zoom across one continuous map from 1 km to the whole system) and an overlay, and leave with Esc or F.

**Architecture:** The map page's four fixed ranges become one continuous scale whose centre slides from the ship to the star. Marks shrink in and out by scale, and the page keeps a list of what it placed, for picking. A new `ComputerStation` (an interactable built by each `ShipComputer`) gives the camera an orbiting eye. `CameraDirector` gains a station mode beside sitting. `ComputerModeInput` turns mouse and keys into calls on the computer, and `ComputerOverlay` draws the list, the card and the tabs round the holo. Everything is wired in `flight_test.gd`, with no `.tscn` edits.

**Tech Stack:** Godot 4.5.1, GDScript, GUT (headless) via `who-knows/run_tests.ps1`.

**Spec:** `docs/superpowers/specs/2026-09-30-computer-mode-design.md` (as amended 2026-10-02 for the world scale). Read it with this plan.

**Where to work:** the worktree `D:/git/whoknows-computer-mode`, on branch `computer-mode`. Keep `D:/git/whoknows` on `main`.

**Running tests:** from `who-knows/` in PowerShell, `./run_tests.ps1 "-gselect=<file>.gd"` (quote each `-g` argument, or PowerShell splits it). Add `"-gunit_test_name=<part of name>"` for one test. Run only the files a task names; ask the owner before a full-suite run.

## Global Constraints

- Colours come only from `InteriorPalette`. No `Color(...)` or `Color.NAMED` in any file on `test_visual_style_rules.gd`'s `PAINTING_FILES`; set alpha with `c.a = x` on a copy.
- Props and anything on `REUSABLE_FILES` never name `ShipGrid`, `BlockCatalog`, `DeckGraph`, `InteriorLayout` or `InteriorBuilder`.
- No new shader. The holo stays kit geometry on the glow batch.
- No `#` comments inside `[node]`/`[sub_resource]` blocks of any `.tscn`/`.tres`. This plan edits none.
- Map numbers (spec §4): scale 1 km to 9,000 km; ×1.3 a notch; stops 2, 10, 50, 500 km and SYSTEM (9,000 km); the centre slides from 500 km to 3,000 km; salvage and life full ≤ 10 km, gone by 20 km; big rocks full ≤ 50 km, gone by 100 km; belts and scale rings grow in from 500 km, full by 1,000 km; warp limits always.
- Station (spec §3.2, §4.4): eye 1.03 m from the holo's centre, 29° above its level, operator's side; orbit 10°–75°; spin 0.4° a pixel, elevation 0.3° a pixel; pick within 24 px, ties within 2 px to the nearer.
- Every ship is usable (CLAUDE.md): nothing here may assume the starter. A station finds the director by group, never by path.
- Commit after each task, ending the message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **F to leave must not also use what the ray was on.** You enter while looking at the table, so the Interactor's `_current` is the station. F must leave and do nothing else, and must not re-enter. *(Task 6: `test_f_leaves_and_nothing_else_takes_it`.)*
2. **The table going away while you are at it** (a rebuild, a wrecked block) must put the camera back on your head with your controls working. Otherwise you are stuck. *(Task 6: `test_a_rebuild_drops_you_out_with_your_controls_back`.)*
3. **A drag that ends over a mark must not pick it,** and a click on the overlay must not pick the mark behind it. *(Task 7: `test_a_drag_orbits_and_picks_nothing`; Task 8: the overlay's panels stop the mouse, `test_the_panels_take_the_mouse`.)*
4. **V (cycle camera) at the station** must not throw the camera to the interior's origin, because `_apply_view` zeroes the camera's position for the foot views. *(Task 6: `test_the_camera_key_does_nothing_at_the_station`.)*
5. **A game saved at the table** must load you standing, not stuck in a half-mode. *(Task 6: `test_saved_at_the_table_you_are_walking`.)*

---

### Task 1: The map's continuous scale

**Files:**
- Modify: `who-knows/src/ship/computer/map_page.gd`
- Test: `who-knows/test/unit/test_map_page.gd`

**Interfaces:**
- Consumes: nothing new.
- Produces: `MapPage.STOPS: Array[float]`, `SCALE_MIN`, `SCALE_MAX`, `ZOOM_STEP`, `GLIDE`, `QUERY`, `SHIP_CENTRED`, `STAR_CENTRED`; `var scale_m: float`; `range_index: int` (a property: get is the nearest stop, set jumps to a stop with no glide); `shown_m() -> float`; `stop_index() -> int`; `next_stop() -> int`; `zoom(notches: float, ctx: ComputerContext) -> void`; `gliding() -> bool`; `static system_weight(scale: float) -> float`. `RANGES` is removed: use `STOPS`.

- [ ] **Step 1: Write the failing tests.** Append to `test_map_page.gd`:

```gdscript
## Computer mode spec §4.1: one continuous scale, a notch of the wheel at a
## time, between its bounds.
func test_the_scale_zooms_by_a_notch_and_stops_at_its_bounds():
	_page.range_index = 1
	_page.zoom(1.0, _ctx)
	assert_almost_eq(_page.scale_m, 13000.0, 0.01)
	_page.zoom(-2.0, _ctx)
	assert_almost_eq(_page.scale_m, 10000.0 / 1.3, 0.01)
	_page.zoom(-100.0, _ctx)
	assert_eq(_page.scale_m, MapPage.SCALE_MIN)
	_page.zoom(100.0, _ctx)
	assert_eq(_page.scale_m, MapPage.SCALE_MAX)

func test_range_steps_to_the_next_stop_from_any_scale_and_wraps():
	_page.scale_m = 12000.0
	assert_eq(_page.prompt(&"range", _ctx), "Range 50 km")
	_page.press(&"range", _ctx)
	assert_eq(_page.scale_m, 50000.0)
	_page.press(&"range", _ctx)
	assert_eq(_page.scale_m, 500000.0)
	_page.press(&"range", _ctx)
	assert_eq(_page.title(), "MAP · SYSTEM")
	_page.press(&"range", _ctx)
	assert_eq(_page.scale_m, 2000.0)

func test_range_glides_the_drawn_scale_instead_of_cutting():
	_page.range_index = 1
	_page.press(&"range", _ctx)
	assert_eq(_page.shown_m(), 10000.0, "not moved yet")
	assert_true(_page.gliding())
	_page.holo(_holo, _ctx, 0.05)
	assert_between(_page.shown_m(), 10001.0, 49999.0, "part way")
	for i in 30:
		_page.holo(_holo, _ctx, 0.05)
	assert_false(_page.gliding())
	assert_eq(_page.shown_m(), 50000.0)

func test_the_title_names_the_scale_and_the_system_from_3000_km():
	_page.scale_m = 1300.0
	assert_eq(_page.title(), "MAP · 1.3 KM")
	_page.scale_m = 12345.0
	assert_eq(_page.title(), "MAP · 12 KM")
	_page.scale_m = 3100000.0
	assert_eq(_page.title(), "MAP · SYSTEM")

func test_an_old_save_s_range_loads_as_its_stop():
	var again := MapPage.new()
	again.restore({"range": 3, "selected": "body:x"})
	assert_eq(again.scale_m, 500000.0)
	assert_eq(again.shown_m(), 500000.0)
	_page.scale_m = 77000.0
	again.restore(_page.save())
	assert_eq(again.scale_m, 77000.0)

func test_the_centre_weight_is_the_ship_to_500_km_and_the_star_from_3000_km():
	assert_eq(MapPage.system_weight(500000.0), 0.0)
	assert_eq(MapPage.system_weight(3000000.0), 1.0)
	var last := 0.0
	for k in 21:
		var w := MapPage.system_weight(500000.0 * pow(6.0, k / 20.0))
		assert_true(w >= last, "only ever further towards the star")
		last = w
```

- [ ] **Step 2: Run them and see them fail.**
Run: `./run_tests.ps1 "-gselect=test_map_page.gd"`
Expected: FAIL with parse errors such as "Invalid call. Nonexistent function 'zoom'" or "Identifier 'scale_m' not declared".

- [ ] **Step 3: Implement.** In `map_page.gd`:

Replace the `RANGES`/`SYSTEM_RANGE`/`SYSTEM_REACH` block with:

```gdscript
## The map's stops (the world scale spec §3.5): what RANGE steps through, 2,
## 10, 50 and 500 km round the ship, and the whole system round the star.
const STOPS: Array[float] = [2000.0, 10000.0, 50000.0, 500000.0, 9000000.0]
const SYSTEM_RANGE := 4
const SYSTEM_REACH := 9000000.0
## How far in and out the map zooms (computer mode spec §4.1), and how much one
## notch of the wheel changes it.
const SCALE_MIN := 1000.0
const SCALE_MAX := SYSTEM_REACH
const ZOOM_STEP := 1.3
## How quickly the drawn scale catches up with the chosen one, seconds: RANGE
## glides between stops instead of cutting.
const GLIDE := 0.1
## What the sensors are asked for: the whole system (each source stops at its
## own reach).
const QUERY := 20000000.0
## The centre slides from the ship to the star between these scales (computer
## mode spec §4.2): your planet and its moons round you up to 500 km, the
## orrery from 3,000 km.
const SHIP_CENTRED := 500000.0
const STAR_CENTRED := 3000000.0
```

Replace `var range_index := OPEN_AT` with:

```gdscript
## The scale chosen: metres from the holo's centre to its edge.
var scale_m := STOPS[OPEN_AT]
## The nearest stop. Setting it jumps there with no glide (a restore, a test).
var range_index: int:
	get:
		return stop_index()
	set(value):
		scale_m = STOPS[clampi(value, 0, STOPS.size() - 1)]
		_shown_m = scale_m
## The scale the holo is drawn at, easing towards scale_m.
var _shown_m := STOPS[OPEN_AT]
```

Replace `range_m()` and `title()` with:

```gdscript
func range_m() -> float:
	return scale_m

func shown_m() -> float:
	return _shown_m

## How far the centre has slid from the ship to the star at `scale`: 0 up to
## SHIP_CENTRED, 1 from STAR_CENTRED, smooth in log scale between.
static func system_weight(scale: float) -> float:
	return smoothstep(log(SHIP_CENTRED), log(STAR_CENTRED), log(scale))

func title() -> String:
	if system_weight(scale_m) >= 1.0:
		return "MAP · SYSTEM"
	if scale_m < 2000.0:
		return "MAP · %.1f KM" % (scale_m / 1000.0)
	return "MAP · %d KM" % roundi(scale_m / 1000.0)

## The stop nearest the scale, in log terms.
func stop_index() -> int:
	var best := 0
	for i in STOPS.size():
		if absf(log(STOPS[i] / scale_m)) < absf(log(STOPS[best] / scale_m)):
			best = i
	return best

## Where RANGE goes next: the first stop above the scale, or back to the first.
func next_stop() -> int:
	for i in STOPS.size():
		if STOPS[i] > scale_m * 1.001:
			return i
	return 0

## Zooms by `notches` of the wheel: in for negative, out for positive. The
## selection stays while it is still on the map.
func zoom(notches: float, ctx: ComputerContext) -> void:
	scale_m = clampf(scale_m * pow(ZOOM_STEP, notches), SCALE_MIN, SCALE_MAX)
	if selected_contact(ctx) == null:
		reselect(ctx)

## Whether the drawn scale is still catching up with the chosen one.
func gliding() -> bool:
	return absf(log(_shown_m / scale_m)) > 0.001

func _glide(delta: float) -> void:
	if not gliding():
		_shown_m = scale_m
		return
	_shown_m = exp(lerpf(log(_shown_m), log(scale_m), 1.0 - exp(-delta / GLIDE)))
```

In `targets()`: change the cache key to `[Engine.get_process_frames(), scale_m, ctx.sensors]`, and the query to `ctx.sensors.contacts(QUERY if range_index == SYSTEM_RANGE else range_m())`. Task 3 replaces the filtering.

In `prompt()`, the `&"range"` case:

```gdscript
		&"range":
			var next := next_stop()
			if next == SYSTEM_RANGE:
				return "Range system"
			return "Range %d km" % roundi(STOPS[next] / 1000.0)
```

In `press()`, the `&"range"` case:

```gdscript
		&"range":
			scale_m = STOPS[next_stop()]
			reselect(ctx)
```

At the top of `holo()`, add `_glide(delta)`. Change `placing_for` to `[_shown_m, selected, course_id, volume]`. Change the rate check to `_placed_ago >= place_every()` and add:

```gdscript
## How often the marks are placed afresh, seconds: every frame up close, twice
## a second further out, where there are hundreds. Every frame too while the
## scale glides, since placing_for holds the drawn scale.
func place_every() -> float:
	return 0.0 if _shown_m <= STOPS[1] * 1.001 else 0.5
```

Delete the `PLACE_EVERY` constant.

In `_placed()`, use `_shown_m` for the scale: `HoloVolume.place(..., SYSTEM_REACH)` stays for the star-centred branch for now, and the ship branch becomes `HoloVolume.place(ctx.relative_in(frame, point), _shown_m)`. In `_place()`, pass `_shown_m` to `mark_size`.

In `mark_size()`, replace `if range_m >= RANGES[SYSTEM_RANGE]:` with `if system_weight(range_m) > 0.5:`, `RANGES[0]` with `STOPS[0]` and `RANGES[1]` with `STOPS[1]`.

Replace `save()`/`restore()`:

```gdscript
func save() -> Dictionary:
	return {"scale": scale_m, "selected": String(selected)}

## A save from before the computer mode holds a stop's index as "range".
func restore(state: Dictionary) -> void:
	if state.has("scale"):
		scale_m = clampf(float(state["scale"]), SCALE_MIN, SCALE_MAX)
	else:
		scale_m = STOPS[clampi(int(state.get("range", OPEN_AT)), 0, STOPS.size() - 1)]
	_shown_m = scale_m
	selected = StringName(state.get("selected", ""))
	_targets_key = []
	_placed_for = []
```

In `test_map_page.gd`'s `test_between_placements_at_50_km_the_marks_turn_with_the_ship`, replace `MapPage.PLACE_EVERY[2]` with `_page.place_every()`. Update the class doc comment's second paragraph to say the map is one continuous scale (computer mode spec §4).

- [ ] **Step 4: Run the map tests and the files that read the range.**
Run: `./run_tests.ps1 "-gselect=test_map_page.gd"`, then `./run_tests.ps1 "-gselect=test_bridge_computer_scene.gd"`, then `./run_tests.ps1 "-gselect=test_ship_computer.gd"`.
Expected: all PASS. `grep -rn "RANGES\|PLACE_EVERY" who-knows/src who-knows/test` finds nothing.

- [ ] **Step 5: Commit.**

```bash
git add who-knows/src/ship/computer/map_page.gd who-knows/test/unit/test_map_page.gd
git commit -m "feat: the map's one continuous scale -- zoom, glide between stops, old saves load"
```

---

### Task 2: The holo spins, and its chevron stands apart

**Files:**
- Modify: `who-knows/src/ship/computer/holo_volume.gd`
- Test: `who-knows/test/unit/test_holo_volume.gd`

**Interfaces:**
- Produces: `HoloVolume.set_spin(angle: float)`, `spin() -> float`, `show_chevron(shown: bool)`, `chevron_shown() -> bool`, `marks_to_global(position: Vector3) -> Vector3`. `show_map_frame(shown)` still shows or hides the ring and the chevron together.

- [ ] **Step 1: Write the failing tests.** Append to `test_holo_volume.gd`:

```gdscript
## Computer mode spec §4.4: the operator spins the holo's contents about its
## upright, the ship's turn and all; the table and the ring stay put.
func test_spin_turns_the_marks_about_the_holo_s_upright():
	_holo.show_marks([_mark(&"ball", Vector3(0, 0, -0.2), 0.02)])
	_holo.set_spin(PI * 0.5)
	assert_almost_eq(_holo.spin(), PI * 0.5, 0.000001)
	var expected := _holo.global_transform * (Basis(Vector3.UP, PI * 0.5) * Vector3(0, 0, -0.2))
	assert_almost_eq(_holo.marks_to_global(Vector3(0, 0, -0.2)), expected, Vector3.ONE * 0.0001)

func test_spin_comes_on_top_of_the_ship_s_turn():
	_holo.set_turn(Basis(Vector3.UP, 0.3))
	_holo.set_spin(0.2)
	var expected := _holo.global_transform * (Basis(Vector3.UP, 0.5) * Vector3(0, 0, -0.2))
	assert_almost_eq(_holo.marks_to_global(Vector3(0, 0, -0.2)), expected, Vector3.ONE * 0.0001)

func test_the_chevron_hides_while_the_ring_stays():
	_holo.show_map_frame(true)
	_holo.show_chevron(false)
	assert_false(_holo.chevron_shown())
	assert_true(_holo.map_frame_shown())
	_holo.show_map_frame(false)
	_holo.show_chevron(true)
	assert_false(_holo.chevron_shown(), "the frame hidden hides it too")
```

- [ ] **Step 2: Run them and see them fail.**
Run: `./run_tests.ps1 "-gselect=test_holo_volume.gd"`
Expected: FAIL, "Nonexistent function 'set_spin'".

- [ ] **Step 3: Implement.** In `holo_volume.gd`:

Add the vars:

```gdscript
## Turned by the operator at a computer station (computer mode spec §4.4): the
## marks, the bracket and the chevron, on top of the ship's turn.
var _spin_root: Node3D
var _chevron_parts: Array[MeshInstance3D] = []
var _chevron_wanted := true
var _frame_wanted := true
```

In `setup()`, build the ring alone with `_kit()`, and the chevron in its own kit rooted at a new spin root, before `_marks_root`. Parent `_marks_root` to the spin root, not to `self`:

```gdscript
	layer = render_layer
	var kit := _kit()
	_edge_ring(kit)
	_frame_parts = kit.commit()
	for part in _frame_parts:
		part.name = "MapFrame"
	_spin_root = Node3D.new()
	_spin_root.name = "Spin"
	add_child(_spin_root)
	var chevron_kit := _kit(_spin_root)
	_chevron(chevron_kit)
	_chevron_parts = chevron_kit.commit()
	for part in _chevron_parts:
		part.name = "Chevron"
	_marks_root = Node3D.new()
	_marks_root.name = "Marks"
	_spin_root.add_child(_marks_root)
```

The rest of `setup()` (the bracket under `_marks_root`, the miniature pivot under `self`) is unchanged.

Change `_kit()` to `func _kit(root: Node3D = null) -> InteriorKit:` with `InteriorKit.new(root if root != null else self)`.

Replace `show_map_frame` and `map_frame_shown`, and add:

```gdscript
## The ship's chevron and the edge ring, which the map shows and the status
## page doesn't.
func show_map_frame(shown: bool) -> void:
	_frame_wanted = shown
	for part in _frame_parts:
		part.visible = shown
	_show_chevron_parts()

func map_frame_shown() -> bool:
	return not _frame_parts.is_empty() and _frame_parts[0].visible

## The chevron alone: the map hides it once its centre has left the ship, and
## draws the ship as a pip instead (computer mode spec §4.2).
func show_chevron(shown: bool) -> void:
	_chevron_wanted = shown
	_show_chevron_parts()

func chevron_shown() -> bool:
	return not _chevron_parts.is_empty() and _chevron_parts[0].visible

func _show_chevron_parts() -> void:
	for part in _chevron_parts:
		part.visible = _frame_wanted and _chevron_wanted

func set_spin(angle: float) -> void:
	_spin_root.basis = Basis(Vector3.UP, angle)

func spin() -> float:
	return _spin_root.basis.get_euler().y

## A mark's place in the world, from where it was placed: through the ship's
## turn and the operator's spin. For picking marks with the mouse.
func marks_to_global(position: Vector3) -> Vector3:
	return _marks_root.global_transform * position
```

Update the doc comment on `set_turn` to say the chevron spins with the marks but never turns with the ship.

- [ ] **Step 4: Run.**
Run: `./run_tests.ps1 "-gselect=test_holo_volume.gd"`, then `./run_tests.ps1 "-gselect=test_ship_computer.gd"`, then `./run_tests.ps1 "-gselect=test_visual_style_rules.gd"`.
Expected: all PASS.

- [ ] **Step 5: Commit.**

```bash
git add who-knows/src/ship/computer/holo_volume.gd who-knows/test/unit/test_holo_volume.gd
git commit -m "feat: the holo spins under the operator's hand; its chevron can step aside for a pip"
```

---

### Task 3: The centre slides, marks shrink by scale, limits everywhere

**Files:**
- Modify: `who-knows/src/ship/computer/map_page.gd`
- Test: `who-knows/test/unit/test_map_page.gd`

**Interfaces:**
- Consumes: `MapPage.system_weight`, `shown_m`, `QUERY` (Task 1); `HoloVolume.show_chevron` (Task 2).
- Produces: `NEAR_BAND`, `ROCK_BAND`, `WIDE_BAND: Vector2`, `SMALLEST`; `static fade(scale: float, band: Vector2) -> float`; `static shrink(c: Contact, scale: float) -> float`; `reach_colour(ctx: ComputerContext, c: Contact) -> Color` (was `_reach_colour`; now public for the overlay).

- [ ] **Step 1: Write the failing tests.** Append to `test_map_page.gd`:

```gdscript
## Computer mode spec §4.3: what leaves the map as you zoom out leaves by
## shrinking across a band.
func test_salvage_and_life_shrink_away_past_10_km_and_big_rocks_past_50_km():
	var salvage := Contact.new()
	salvage.kind = &"salvage"
	assert_eq(MapPage.shrink(salvage, 10000.0), 1.0)
	assert_between(MapPage.shrink(salvage, 14000.0), 0.01, 0.99)
	assert_eq(MapPage.shrink(salvage, 20000.0), 0.0)
	var rock := Contact.new()
	rock.kind = &"rock"
	assert_eq(MapPage.shrink(rock, 50000.0), 1.0)
	assert_eq(MapPage.shrink(rock, 100000.0), 0.0)
	var world := Contact.new()
	world.kind = &"body"
	assert_eq(MapPage.shrink(world, 9000000.0), 1.0)

func test_a_mark_shrunk_away_is_not_placed():
	_add(&"salvage:b", Contact.PING, Vector3(0, 0, -4000), 0.0, 4)
	_page.range_index = 2
	_refresh()
	_page.holo(_holo, _ctx, 0.0)
	assert_eq(_holo.mark_count(&"diamond"), 0)

func test_targets_are_what_is_inside_the_holo_at_full_size():
	_add(&"rock:near", Contact.EXACT, Vector3(0, 0, -8000), 300.0)
	_add(&"rock:far", Contact.EXACT, Vector3(0, 0, -28000), 300.0)
	_add(&"body:p", Contact.EXACT, Vector3(0, 0, -300000), 30000.0, 0, &"body")
	_page.range_index = 1
	_refresh()
	assert_eq(_page.targets(_ctx).map(func(c: Contact) -> StringName: return c.id), [&"rock:near"])
	_page.restore({"scale": 45000.0})
	_refresh()
	assert_eq(_page.targets(_ctx).map(func(c: Contact) -> StringName: return c.id), [&"rock:near", &"rock:far"])
	_page.range_index = 3
	_refresh()
	assert_eq(_page.targets(_ctx).map(func(c: Contact) -> StringName: return c.id), [&"body:p"], "the rocks are gone")

func test_half_way_out_the_ship_and_the_star_sit_either_side_of_the_centre():
	var s := _with_system()
	_page.restore({"scale": sqrt(MapPage.SHIP_CENTRED * MapPage.STAR_CENTRED)})
	var frame := _ctx.map_frame()
	var star := _page.holo_position(_ctx, frame, s.star.point)
	var ship := _page.holo_position(_ctx, frame, s.entry())
	assert_almost_eq(star, -ship, Vector3.ONE * 0.0001)

func test_the_ship_is_a_chevron_near_and_a_pip_far():
	_page.range_index = 1
	_refresh()
	_page.holo(_holo, _ctx, 0.0)
	assert_true(_holo.chevron_shown())
	_with_system()
	_page.holo(_holo, _ctx, 0.0)
	assert_false(_holo.chevron_shown())
	assert_gt(_holo.mark_count(&"ball", InteriorPalette.LIGHT_WARM), 0, "the pip")

func test_warp_limits_are_drawn_near_a_world_not_only_on_the_system_range():
	var s := _with_system()
	var planet: SystemBody = null
	for b in s.bodies:
		if b.kind == SystemBody.Kind.PLANET:
			planet = b
			break
	_universe.origin = planet.point.plus(Vector3(planet.warp_limit + 20000.0, 0, 0))
	_page.range_index = 3
	_refresh()
	_page.holo(_holo, _ctx, 0.0)
	assert_gt(_holo.mark_count(&"tick", InteriorPalette.HOLO_DIM), 0, "the planet's limit at 500 km")

func test_belts_and_scale_rings_grow_in_past_500_km():
	_with_system()
	_page.range_index = 3
	_refresh()
	_page.holo(_holo, _ctx, 0.0)
	assert_eq(_holo.mark_count(&"tick", MapPage.colour_for(&"rock")), 0, "no belt at 500 km")
	_page.range_index = MapPage.SYSTEM_RANGE
	_refresh()
	_page.holo(_holo, _ctx, 0.0)
	assert_gt(_holo.mark_count(&"tick", MapPage.colour_for(&"rock")), 0, "belts on the system range")

func test_marks_are_placed_every_frame_while_the_scale_glides():
	_add(&"rock:a", Contact.EXACT, Vector3(0, 0, -20000), 300.0)
	_page.range_index = 2
	_refresh()
	_page.holo(_holo, _ctx, 0.0)
	var before := _holo.mark_transform(&"ball", 0).origin
	_page.zoom(-3.0, _ctx)
	_page.holo(_holo, _ctx, 0.016)
	assert_ne(_holo.mark_transform(&"ball", 0).origin, before, "placed afresh while zooming")
```

- [ ] **Step 2: Run them and see them fail.**
Run: `./run_tests.ps1 "-gselect=test_map_page.gd"`
Expected: FAIL, "Nonexistent function 'shrink'", and the targets and centre tests fail on their assertions.

- [ ] **Step 3: Implement.** In `map_page.gd`:

Add the constants:

```gdscript
## The bands things leave the map across as you zoom out (computer mode spec
## §4.3): full size up to x, gone by y.
const NEAR_BAND := Vector2(10000.0, 20000.0)
const ROCK_BAND := Vector2(50000.0, 100000.0)
## Belts and scale rings grow in across this band.
const WIDE_BAND := Vector2(500000.0, 1000000.0)
## A mark shrunk smaller than this is not placed.
const SMALLEST := 0.001
```

Add the pure functions:

```gdscript
## 1 up to band.x, 0 from band.y, smooth in log scale between.
static func fade(scale: float, band: Vector2) -> float:
	return 1.0 - smoothstep(log(band.x), log(band.y), log(scale))

## How much of its size a contact's mark keeps at `scale`.
static func shrink(c: Contact, scale: float) -> float:
	match c.kind:
		&"salvage", &"life":
			return fade(scale, NEAR_BAND)
		&"rock":
			return fade(scale, ROCK_BAND)
	return 1.0
```

Replace `targets()`'s loop (keep the key and early returns):

```gdscript
	var frame := ctx.map_frame()
	var system_view := system_weight(scale_m) > 0.5
	for c in ctx.sensors.contacts(QUERY):
		if system_view and not TARGET_KINDS.has(c.kind):
			continue
		if shrink(c, scale_m) < 0.999:
			continue
		if _from_centre(ctx, frame, c.point, scale_m).length() > scale_m + c.radius:
			continue
		_targets.append(c)
	return _targets
```

Update `targets()`'s doc comment: "What ◀ and ▶ step through, and the overlay lists: the contacts inside the holo at full size, nearest the ship first. Once the map is round the star, worlds only."

Replace `_placed()` and add `_from_centre()`:

```gdscript
## `point` from the holo's centre, in the map's frame, at `scale`: the centre
## slides from the ship to the star as the scale grows (spec §4.2).
func _from_centre(ctx: ComputerContext, frame: Transform3D, point: UniversePoint, scale: float) -> Vector3:
	var rel := ctx.relative_in(frame, point)
	var system := ctx.sensors.system if ctx.sensors != null else null
	var w := system_weight(scale)
	if w > 0.0 and system != null:
		rel -= ctx.relative_in(frame, system.star.point) * w
	return rel

func _placed(ctx: ComputerContext, frame: Transform3D, point: UniversePoint) -> Dictionary:
	return HoloVolume.place(_from_centre(ctx, frame, point, _shown_m), _shown_m)
```

In `_place()`:
- at the top, `var w := system_weight(_shown_m)`;
- make the size `var size := PIN_SIZE if pinned else mark_size(c, _shown_m, time) * shrink(c, _shown_m)`, then `if size < SMALLEST: continue` before any `add_mark` for that contact;
- change the cluster test to `if w > 0.5 and c.kind == &"cluster" and not pinned:`;
- replace the `if range_index == SYSTEM_RANGE:` block with:

```gdscript
	_place_belts(volume, ctx, frame)
	if w > 0.01:
		_place_ship(volume, ctx, frame)
	_place_rings(volume, ctx, frame)
	_place_limits(volume, ctx, frame, list)
	_place_chart(volume, ctx, frame)
```

In `holo()`, after `volume.show_map_frame(true)`, add `volume.show_chevron(system_weight(_shown_m) <= 0.01)`.

In `_place_belts()`, compute `var grow := 1.0 - fade(_shown_m, WIDE_BAND)`, return early if `grow * TICK_SIZE < SMALLEST`, and draw each tick at `TICK_SIZE * grow`.

Split the scale rings out of `_place_ship()` (which keeps only the pip and the heading tick) into:

```gdscript
## Faint rings round the ship every SCALE_RING, growing in past 500 km.
func _place_rings(volume: HoloVolume, ctx: ComputerContext, frame: Transform3D) -> void:
	var focus := ctx.sensors.focus_point() if ctx.sensors != null else null
	var grow := 1.0 - fade(_shown_m, WIDE_BAND)
	if focus == null or grow * TICK_SIZE < SMALLEST:
		return
	var r := SCALE_RING
	while r <= SYSTEM_REACH * 2.0:
		for k in SCALE_TICKS:
			var a := TAU * k / SCALE_TICKS
			var placed := _placed(ctx, frame, focus.plus(frame.basis.inverse() * Vector3(cos(a), 0.0, sin(a)) * r))
			if not placed["pinned"]:
				volume.add_mark(&"tick", InteriorPalette.HOLO_DIM, placed["position"], TICK_SIZE * grow)
		r += SCALE_RING
```

Rename `_reach_colour` to `reach_colour` (update its call in `_place()`) and change its first test to `if system_weight(_shown_m) <= 0.5 or ctx.warp == null or ctx.store == null or ctx.sensors == null:`. Change `_warp_target()`'s first line to `if system_weight(scale_m) <= 0.5 or ctx.warp == null:`.

- [ ] **Step 4: Run.**
Run: `./run_tests.ps1 "-gselect=test_map_page.gd"`, then `./run_tests.ps1 "-gselect=test_bridge_computer_scene.gd"`.
Expected: all PASS. If an existing test that set `range_index = 3` and expected rocks fails, that is the spec's change (rocks are gone by 100 km): update its expectation and say so in the commit message.

- [ ] **Step 5: Commit.**

```bash
git add who-knows/src/ship/computer/map_page.gd who-knows/test/unit/test_map_page.gd
git commit -m "feat: the map's centre slides from the ship to the star; marks shrink away by scale; limits everywhere"
```

---

### Task 4: Picking, and the table's calls for the mode

**Files:**
- Modify: `who-knows/src/ship/computer/map_page.gd`, `who-knows/src/ship/computer/ship_computer.gd`
- Create: `who-knows/test/unit/test_computer_picking.gd`

**Interfaces:**
- Consumes: `HoloVolume.marks_to_global`, `set_spin` (Task 2); `MapPage.zoom` (Task 1).
- Produces: `MapPage.placed_marks: Array[Dictionary]` (each `{"id": StringName, "position": Vector3}`); `ShipComputer.PICK_RADIUS := 24.0`, `PICK_TIE := 2.0`; `var spin: float` (a property: setting it spins the holo); `var hovered: StringName`; `mark_at(screen: Vector2, camera: Camera3D) -> StringName`; `pick(screen: Vector2, camera: Camera3D) -> StringName`; `hover(screen: Vector2, camera: Camera3D) -> StringName`; `select(id: StringName) -> void`; `act() -> void`; `zoom(notches: float) -> void`; `tab(index: int) -> void`; `next_tab() -> void`.

- [ ] **Step 1: Write the failing tests.** Create `test_computer_picking.gd`:

```gdscript
extends GutTest

## Picking with the mouse at a computer station (computer mode spec §4.5), and
## the calls the mode makes on the table: zoom, spin, tabs and the big
## button's action.

class FakeSource extends RefCounted:
	var list: Array[Contact] = []
	func contacts(focus: UniversePoint, range_m: float, _time: float) -> Array[Contact]:
		return list.filter(func(c: Contact) -> bool: return c.point.minus(focus).length() <= range_m)
	func contact(id: StringName, _focus: UniversePoint, _time: float) -> Contact:
		for c in list:
			if c.id == id:
				return c
		return null

var _universe: Universe
var _hull: Node3D
var _sensors: ShipSensors
var _source: FakeSource
var _computer: ShipComputer
var _cam: Camera3D

func before_each():
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	add_child_autofree(vp)
	_universe = Universe.new()
	vp.add_child(_universe)
	_hull = Node3D.new()
	vp.add_child(_hull)
	_universe.set_focus(_hull)
	_sensors = ShipSensors.new()
	vp.add_child(_sensors)
	_sensors.universe = _universe
	_source = FakeSource.new()
	_sensors.add_source(_source)
	_computer = ShipComputer.new()
	_computer.setup(Transform3D.IDENTITY)
	vp.add_child(_computer)
	var ctx := ComputerContext.new()
	ctx.sensors = _sensors
	ctx.hull = _hull
	_computer.bind(ctx)
	_cam = Camera3D.new()
	vp.add_child(_cam)
	_cam.current = true
	var centre := _computer.holo.global_position
	_cam.look_at_from_position(centre + Vector3(0, 0.5, -0.9), centre)

func _add(id: StringName, at: Vector3) -> void:
	var c := Contact.new()
	c.id = id
	c.kind = &"rock"
	c.label = "ROCK"
	c.point = _universe.to_universe(at)
	c.precision = Contact.EXACT
	c.radius = 300.0
	_source.list.append(c)

func _placed_on_screen(id: StringName) -> Vector2:
	var map := _computer.page() as MapPage
	for m in map.placed_marks:
		if m["id"] == id:
			return _cam.unproject_position(_computer.holo.marks_to_global(m["position"]))
	return Vector2(-1000, -1000)

func _ready_map() -> void:
	_add(&"rock:ahead", Vector3(0, 0, -5000))
	_add(&"rock:right", Vector3(5000, 0, 0))
	_sensors.refresh(MapPage.QUERY)
	(_computer.page() as MapPage).reselect(_computer.ctx)
	_computer.update(0.0)

func test_a_click_near_a_mark_selects_it():
	_ready_map()
	var at := _placed_on_screen(&"rock:right")
	assert_eq(_computer.pick(at + Vector2(10, 0), _cam), &"rock:right")
	assert_eq((_computer.page() as MapPage).selected, &"rock:right")

func test_a_click_far_from_every_mark_selects_nothing_and_keeps_the_selection():
	_ready_map()
	var before := (_computer.page() as MapPage).selected
	assert_eq(_computer.pick(Vector2(5, 5), _cam), &"")
	assert_eq((_computer.page() as MapPage).selected, before)

func test_hover_names_the_mark_under_the_cursor():
	_ready_map()
	assert_eq(_computer.hover(_placed_on_screen(&"rock:ahead"), _cam), &"rock:ahead")
	assert_eq(_computer.hovered, &"rock:ahead")
	_computer.hover(Vector2(5, 5), _cam)
	assert_eq(_computer.hovered, &"")

func test_spin_reaches_the_holo():
	_computer.spin = 0.5
	assert_almost_eq(_computer.holo.spin(), 0.5, 0.000001)

func test_zoom_moves_the_map_and_does_nothing_on_the_status_tab():
	_computer.zoom(1.0)
	assert_almost_eq((_computer.pages[0] as MapPage).scale_m, 13000.0, 0.01)
	_computer.tab(1)
	assert_eq(_computer.page_index, 1)
	_computer.zoom(1.0)
	assert_almost_eq((_computer.pages[0] as MapPage).scale_m, 13000.0, 0.01, "status ignores the wheel")

func test_act_is_the_big_button():
	_ready_map()
	_computer.act()
	assert_eq(_sensors.course, (_computer.page() as MapPage).selected)
```

- [ ] **Step 2: Run them and see them fail.**
Run: `./run_tests.ps1 "-gselect=test_computer_picking.gd"`
Expected: FAIL, "Invalid get index 'placed_marks'".

- [ ] **Step 3: Implement.** In `map_page.gd` add:

```gdscript
## What the last placing put in the holo that a click can take (computer mode
## spec §4.5): each target's {id, position}, in the frame the marks were
## placed in -- HoloVolume.marks_to_global finds it in the world.
var placed_marks: Array[Dictionary] = []
```

In `_place()`, add `placed_marks.clear()` after `volume.begin_marks()` and `var targets_shown := targets(ctx).size()` before the loop. After a contact's mark is added, add `if i < targets_shown: placed_marks.append({"id": c.id, "position": at})`. The appended course is drawn but is not a target unless it is in the list.

In `ship_computer.gd` add the constants, vars and functions:

```gdscript
## Picking with the mouse (computer mode spec §4.5): how far from a mark on
## screen a click still takes it, and the gap inside which the nearer to the
## camera wins.
const PICK_RADIUS := 24.0
const PICK_TIE := 2.0

## The contact under the cursor at a station, for the overlay's tag.
var hovered: StringName = &""
## The operator's spin of the holo at a station (spec §4.4).
var spin := 0.0:
	set(value):
		spin = value
		if holo != null:
			holo.set_spin(value)

## The id of the target nearest `screen`, as `camera` sees the holo, within
## PICK_RADIUS; "" when there is none or the page is not the map.
func mark_at(screen: Vector2, camera: Camera3D) -> StringName:
	var map := page() as MapPage
	if map == null or camera == null:
		return &""
	var best: StringName = &""
	var best_off := INF
	var best_depth := INF
	for m: Dictionary in map.placed_marks:
		var at := holo.marks_to_global(m["position"])
		if camera.is_position_behind(at):
			continue
		var off := camera.unproject_position(at).distance_to(screen)
		if off > PICK_RADIUS:
			continue
		var depth := camera.global_position.distance_to(at)
		if off < best_off - PICK_TIE or (absf(off - best_off) <= PICK_TIE and depth < best_depth):
			best = m["id"]
			best_off = off
			best_depth = depth
	return best

## Selects the mark under `screen`, if there is one; returns its id or "".
func pick(screen: Vector2, camera: Camera3D) -> StringName:
	var id := mark_at(screen, camera)
	if id != &"":
		select(id)
	return id

func hover(screen: Vector2, camera: Camera3D) -> StringName:
	hovered = mark_at(screen, camera)
	return hovered

## Selects contact `id` on the map: a click in the holo or on the overlay's list.
func select(id: StringName) -> void:
	var map := page() as MapPage
	if map == null:
		return
	map.selected = id
	if ctx.sensors != null:
		ctx.sensors.forget_arrival()
	_refresh()

## What the big button would do (spec §5.3).
func act() -> void:
	press(&"big")

func zoom(notches: float) -> void:
	var map := page() as MapPage
	if map != null:
		map.zoom(notches, ctx)
		_refresh()

## Opens page `index`: the overlay's tabs.
func tab(index: int) -> void:
	if index == page_index or index < 0 or index >= pages.size():
		return
	page_index = index
	page().opened(ctx)
	_play(&"page")
	_refresh()

func next_tab() -> void:
	press(&"page")
```

- [ ] **Step 4: Run.**
Run: `./run_tests.ps1 "-gselect=test_computer_picking.gd"`, then `./run_tests.ps1 "-gselect=test_ship_computer.gd"`, then `./run_tests.ps1 "-gselect=test_map_page.gd"`.
Expected: all PASS.

- [ ] **Step 5: Commit.**

```bash
git add who-knows/src/ship/computer/map_page.gd who-knows/src/ship/computer/ship_computer.gd who-knows/test/unit/test_computer_picking.gd
git commit -m "feat: pick a mark in the holo with the mouse; the table's calls for the computer mode"
```

---

### Task 5: The station at the table

**Files:**
- Create: `who-knows/src/ship/computer/computer_station.gd`
- Modify: `who-knows/src/ship/interior/interior_props.gd`, `who-knows/src/ship/computer/ship_computer.gd`, `who-knows/src/camera/camera_director.gd` (only the `GROUP` constant and `add_to_group` in `_ready`), `who-knows/test/unit/test_visual_style_rules.gd` (the list only)
- Test: `who-knows/test/unit/test_ship_computer.gd`, `who-knows/test/unit/test_interior_props.gd`, `who-knows/test/unit/test_bridge_computer_scene.gd`

**Interfaces:**
- Consumes: `ShipComputer.spin` (Task 4).
- Produces: `InteriorProps.HOLO_STATION_SIZE: Vector3`, `HOLO_STATION_DISTANCE := 1.03`, `HOLO_STATION_ELEVATION := 29.0`, `holo_station_shape_centre() -> Vector3`, `holo_station_eye(elevation_deg: float) -> Transform3D`; `ComputerStation` with `PROMPT`, `ELEVATION_MIN := 10.0`, `ELEVATION_MAX := 75.0`, `var computer: ShipComputer`, `var elevation: float`, `setup(owner_computer: ShipComputer, layer_bits: int)`, `prompt_text() -> String`, `interact(actor: Node)`, `director() -> CameraDirector`, `eye_transform() -> Transform3D`, `orbit(d_elevation: float)`, `recentre()`, `left()`; `ShipComputer.station: ComputerStation`; `CameraDirector.GROUP := &"camera_director"`.

- [ ] **Step 1: Write the failing tests.**

Append to `test_interior_props.gd`:

```gdscript
## Computer mode spec §3.1-§3.2: the station's box offers the computer over the
## table, under the holo; its eye stays under the ceiling however high it
## orbits.
func test_the_station_box_stays_under_the_holo():
	var top := InteriorProps.holo_station_shape_centre().y + InteriorProps.HOLO_STATION_SIZE.y * 0.5
	assert_lt(top, InteriorProps.HOLO_VOLUME_CENTRE - 0.3, "under the holo's floor")
	assert_gt(top, InteriorProps.HOLO_TABLE_TOP + 0.05, "above the table's collider")

func test_the_station_eye_looks_into_the_holo_from_the_operator_s_side():
	var eye := InteriorProps.holo_station_eye(InteriorProps.HOLO_STATION_ELEVATION)
	var centre := InteriorProps.holo_table_volume().origin
	assert_almost_eq(eye.origin.distance_to(centre), InteriorProps.HOLO_STATION_DISTANCE, 0.0001)
	assert_lt(eye.origin.z, 0.0, "on the operator's side, -z")
	assert_almost_eq(-eye.basis.z, (centre - eye.origin).normalized(), Vector3.ONE * 0.0001, "looking at the centre")
	assert_almost_eq(eye.origin.y, 1.85, 0.01)

func test_the_station_eye_orbits_under_the_ceiling():
	var high := InteriorProps.holo_station_eye(ComputerStation.ELEVATION_MAX)
	assert_lt(high.origin.y, InteriorProps.HEADROOM - 0.1)
```

Append to `test_ship_computer.gd`:

```gdscript
## Computer mode spec §3.1: each table builds its own station, in its frame.
func test_it_builds_a_station_in_the_table_s_frame():
	var f := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(2, 0, 3))
	var turned := ShipComputer.new()
	turned.setup(f)
	add_child_autofree(turned)
	assert_not_null(turned.station)
	assert_true(turned.station.transform.is_equal_approx(f))
	assert_true(turned.station.is_in_group("interactable"))
	assert_eq(turned.station.prompt_text(), "Use computer")
	assert_eq(turned.station.computer, turned)

func test_the_station_s_eye_orbits_and_recentres():
	var s := _computer.station
	var start := s.eye_transform()
	s.orbit(30.0)
	assert_almost_eq(s.elevation, InteriorProps.HOLO_STATION_ELEVATION + 30.0, 0.0001)
	assert_gt(s.eye_transform().origin.y, start.origin.y)
	s.orbit(1000.0)
	assert_eq(s.elevation, ComputerStation.ELEVATION_MAX)
	_computer.spin = 1.0
	s.recentre()
	assert_eq(s.elevation, InteriorProps.HOLO_STATION_ELEVATION)
	assert_eq(_computer.spin, 0.0)
	assert_true(s.eye_transform().is_equal_approx(start))
```

Append to `test_bridge_computer_scene.gd`:

```gdscript
## Computer mode spec §3.1: looking at the table top offers the computer, and
## (test_looking_at_a_button...) the buttons still win when looked at.
func test_looking_at_the_table_top_from_its_operator_s_spot_offers_the_computer():
	await wait_physics_frames(2)
	var c := _computer()
	var spot := DeckPaths.floor_point(Vector3i(-1, 0, -2))
	var eye := _ship.interior.global_transform * (spot + Vector3(0, 1.6, 0))
	var target := c.station.global_transform * Vector3(0, 0.95, 0)
	var query := PhysicsRayQueryParameters3D.create(eye, target, Interactor.MASK)
	query.collide_with_areas = true
	var hit := _ship.interior.get_world_3d().direct_space_state.intersect_ray(query)
	assert_eq(hit.get("collider"), c.station)

func test_the_station_finds_the_game_s_director():
	assert_eq(_computer().station.director(), _root.get_node("CameraDirector"))
```

- [ ] **Step 2: Run them and see them fail.**
Run: `./run_tests.ps1 "-gselect=test_interior_props.gd"`
Expected: FAIL, "Identifier 'HOLO_STATION_SIZE' not declared" (and similarly for the other two files).

- [ ] **Step 3: Implement.**

In `interior_props.gd`, after `holo_table_volume()`:

```gdscript
## The bridge computer's station (computer mode spec §3.1, §3.2): a box over
## the table's top and rim that offers "Use computer" -- above the table's
## collider, under the holo, short of the buttons -- and the eye you use the
## computer from: HOLO_STATION_DISTANCE from the holo's centre,
## HOLO_STATION_ELEVATION degrees above its level, on the operator's side.
const HOLO_STATION_SIZE := Vector3(1.1, 0.14, 1.1)
const HOLO_STATION_DISTANCE := 1.03
const HOLO_STATION_ELEVATION := 29.0

static func holo_station_shape_centre() -> Vector3:
	return Vector3(0, 0.93, 0)

## The eye at `elevation_deg` above the holo's level, looking at its centre, in
## the table's fixture frame.
static func holo_station_eye(elevation_deg: float) -> Transform3D:
	var e := deg_to_rad(elevation_deg)
	var centre := holo_table_volume().origin
	var eye := centre + Vector3(0, sin(e), -cos(e)) * HOLO_STATION_DISTANCE
	return Transform3D(Basis.IDENTITY, eye).looking_at(centre, Vector3.UP)
```

Create `computer_station.gd`:

```gdscript
class_name ComputerStation
extends Area3D

## Where you use a bridge computer from, and the view you get
## (docs/superpowers/specs/2026-09-30-computer-mode-design.md §3): an
## interactable over the table's top and rim -- "Use computer" -- and the eye
## the camera glides to, orbiting the holo's centre while you are there. The
## buttons stand proud of its box, so looking straight at one still offers
## that button.
##
## Knows nothing about ships. Its ShipComputer builds it at the table's
## fixture frame. Tables are rebuilt and ships come and go, so it finds the
## game's one CameraDirector by group, never by path.

const PROMPT := "Use computer"
## The orbit's bounds, degrees above the holo's level (spec §4.4).
const ELEVATION_MIN := 10.0
const ELEVATION_MAX := 75.0

var computer: ShipComputer
var elevation := InteriorProps.HOLO_STATION_ELEVATION

## Builds the box on physics layer bits `layer_bits`. Call once, before it
## enters the tree.
func setup(owner_computer: ShipComputer, layer_bits: int) -> void:
	computer = owner_computer
	name = "Station"
	collision_layer = layer_bits
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("interactable")
	var shape := BoxShape3D.new()
	shape.size = InteriorProps.HOLO_STATION_SIZE
	var hit := CollisionShape3D.new()
	hit.shape = shape
	hit.position = InteriorProps.holo_station_shape_centre()
	add_child(hit)

func prompt_text() -> String:
	return PROMPT

func can_interact(_actor: Node) -> bool:
	return director() != null

func interact(_actor: Node) -> void:
	var d := director()
	if d != null:
		d.use_station(self)

func director() -> CameraDirector:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(CameraDirector.GROUP) as CameraDirector

## Where the camera is while you use the computer, in the world.
func eye_transform() -> Transform3D:
	return global_transform * InteriorProps.holo_station_eye(elevation)

## Raises or lowers the eye round the holo (a vertical drag), within its bounds.
func orbit(d_elevation: float) -> void:
	elevation = clampf(elevation + d_elevation, ELEVATION_MIN, ELEVATION_MAX)

## R: the eye where it started, and the holo turned with the ship again.
func recentre() -> void:
	elevation = InteriorProps.HOLO_STATION_ELEVATION
	computer.spin = 0.0

## Called as you leave: walking past, the holo answers "which way?" again.
func left() -> void:
	recentre()
```

`CameraDirector.use_station` does not exist until Task 6. In this task `interact()` is reached only by the tests above, which don't call it. Add the method in Task 6.

In `ship_computer.gd`: add `var station: ComputerStation`, and at the end of `setup()`, before `_hum = ...`:

```gdscript
	station = ComputerStation.new()
	station.setup(self, InteriorKit.LAYER)
	station.transform = f
	add_child(station)
```

In `camera_director.gd`: add the constant and join the group in `_ready()`:

```gdscript
## The group the game's one director is in: a computer station finds it here
## (computer mode spec §3.1), since tables are rebuilt and ships come and go.
const GROUP := &"camera_director"
```

```gdscript
func _ready() -> void:
	add_to_group(GROUP)
	_apply_view()
```

Add a stub so `interact()` parses; Task 6 replaces it:

```gdscript
func use_station(_station: ComputerStation) -> void:
	pass
```

In `test_visual_style_rules.gd`, add `"res://src/ship/computer/computer_station.gd"` to `REUSABLE_FILES`.

- [ ] **Step 4: Run.**
Run: `./run_tests.ps1 "-gselect=test_interior_props.gd"`, `./run_tests.ps1 "-gselect=test_ship_computer.gd"`, `./run_tests.ps1 "-gselect=test_bridge_computer_scene.gd"` (all 17 must pass, including `test_looking_at_a_button_from_its_operator_s_spot_finds_the_button`), and `./run_tests.ps1 "-gselect=test_visual_style_rules.gd"`.
Expected: all PASS.

- [ ] **Step 5: Commit.**

```bash
git add who-knows/src/ship/computer/computer_station.gd who-knows/src/ship/interior/interior_props.gd who-knows/src/ship/computer/ship_computer.gd who-knows/src/camera/camera_director.gd who-knows/test/unit/test_interior_props.gd who-knows/test/unit/test_ship_computer.gd who-knows/test/unit/test_bridge_computer_scene.gd who-knows/test/unit/test_visual_style_rules.gd
git commit -m "feat: a station at every bridge computer -- Use computer, and an eye over the holo"
```

(Also stage the new `.gd.uid` file if Godot wrote one.)

---

### Task 6: The director's station mode

**Files:**
- Modify: `who-knows/src/camera/camera_director.gd`, `who-knows/src/avatar/avatar.gd`, `who-knows/src/avatar/interactor.gd`
- Create: `who-knows/test/unit/test_computer_station.gd`

**Interfaces:**
- Consumes: `ComputerStation.eye_transform()`, `left()` (Task 5).
- Produces: `CameraDirector.View.STATION` (appended last); `signal station_changed(station: ComputerStation)`; `var is_at_station: bool`; `use_station(station: ComputerStation)`; `leave_station()`; `station() -> ComputerStation`; `camera() -> Camera3D`. `Avatar.at_station: bool`, `Avatar.set_at_station(on: bool)`. `Interactor.suspended: bool`.

- [ ] **Step 1: Write the failing tests.** Create `test_computer_station.gd`:

```gdscript
extends GutTest

## The computer mode in the real flight scene (computer mode spec §3): F at
## the table glides you over the holo; F or Esc brings you back; nothing else
## takes your keys while you are there.

var _root: Node
var _ship: Ship
var _director: CameraDirector
var _avatar: Avatar

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_director = _root.get_node("CameraDirector")
	_avatar = _root.get_node("Ship/Interior/Avatar")

func _station() -> ComputerStation:
	return _ship.interior_builder.computers()[0].station

func _press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	_director._unhandled_input(ev)

func _enter() -> void:
	_station().interact(_avatar)
	await wait_seconds(CameraDirector.SIT_DURATION + 0.2)

func test_using_it_hands_the_view_to_the_station():
	watch_signals(_director)
	await _enter()
	assert_true(_director.is_at_station)
	assert_signal_emitted_with_parameters(_director, "station_changed", [_station()])
	assert_eq(_director.view, CameraDirector.View.STATION)
	assert_eq(_director.station(), _station())
	assert_almost_eq(_director.camera().global_position, _station().eye_transform().origin, Vector3.ONE * 0.01)
	assert_true(_avatar.at_station)
	assert_true(_avatar.interactor.suspended)
	assert_null(_avatar.interactor.current())

func test_f_leaves_and_nothing_else_takes_it():
	await _enter()
	_press(&"interact")
	await wait_seconds(CameraDirector.SIT_DURATION + 0.2)
	assert_false(_director.is_at_station)
	assert_eq(_director.view, CameraDirector.View.FOOT_FIRST)
	assert_eq(_director.camera().get_parent(), _avatar.head)
	assert_false(_avatar.at_station)
	assert_false(_avatar.interactor.suspended)
	assert_almost_eq(_station().computer.spin, 0.0, 0.0001, "the holo turned with the ship again")

func test_esc_leaves_too():
	await _enter()
	_press(&"ui_cancel")
	await wait_seconds(CameraDirector.SIT_DURATION + 0.2)
	assert_false(_director.is_at_station)

func test_not_while_seated():
	_director.sit(_ship.seat)
	await wait_seconds(CameraDirector.SIT_DURATION + 0.2)
	_station().interact(_avatar)
	assert_false(_director.is_at_station)

func test_the_camera_key_does_nothing_at_the_station():
	await _enter()
	_press(&"cycle_camera")
	assert_eq(_director.view, CameraDirector.View.STATION)
	await wait_frames(2)
	assert_almost_eq(_director.camera().global_position, _station().eye_transform().origin, Vector3.ONE * 0.01)

func test_the_eye_follows_the_orbit():
	await _enter()
	_station().orbit(30.0)
	await wait_frames(2)
	assert_almost_eq(_director.camera().global_position, _station().eye_transform().origin, Vector3.ONE * 0.01)

func test_a_rebuild_drops_you_out_with_your_controls_back():
	await _enter()
	_ship._rebuild_everything()
	await wait_frames(3)
	assert_false(_director.is_at_station)
	assert_eq(_director.camera().get_parent(), _avatar.head)
	assert_false(_avatar.at_station)
	assert_eq(_director.view, CameraDirector.View.FOOT_FIRST)

func test_saved_at_the_table_you_are_walking():
	await _enter()
	var you: Dictionary = _root.capture()["avatar"]
	assert_eq(you["mode"], "walking")

func test_the_avatar_ignores_esc_and_clicks_at_the_station():
	await _enter()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_avatar._unhandled_input(click)
	assert_true(_director.is_at_station, "the avatar's click-to-recapture stays out of it")
```

- [ ] **Step 2: Run them and see them fail.**
Run: `./run_tests.ps1 "-gselect=test_computer_station.gd"`
Expected: FAIL. `is_at_station` is not declared, and `View.STATION` does not exist.

- [ ] **Step 3: Implement.**

`camera_director.gd`:
- Add `STATION` to the end of the `View` enum.
- Remove the Task 5 stub `use_station`.
- Add near the other signals:

```gdscript
## Emitted when you step up to a computer station or leave it (computer mode
## spec §3): the station, or null.
signal station_changed(station: ComputerStation)
```

Add the vars and functions:

```gdscript
var is_at_station: bool = false
var _station: ComputerStation = null

## The station you are at, or null.
func station() -> ComputerStation:
	return _station if is_at_station else null

## The one interior camera, which is also the station's.
func camera() -> Camera3D:
	return _interior_cam

## Steps you up to a computer (computer mode spec §3.1): your body stays where
## it stood, the camera glides to the station's eye, the mouse is free.
func use_station(station: ComputerStation) -> void:
	if station == null or is_seated or is_at_station or _tween != null or _avatar.mode == Avatar.Mode.SUIT:
		return
	_station = station
	is_at_station = true
	_avatar.set_control_enabled(false)
	_avatar.set_at_station(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_move_camera_to(station.eye_transform())
	station_changed.emit(station)

## Back to your head (spec §3.4), the same move as standing up.
func leave_station() -> void:
	if not is_at_station or _tween != null:
		return
	_end_station()
	_move_camera_to(_avatar.head.global_transform)

func _end_station() -> void:
	is_at_station = false
	if is_instance_valid(_station):
		_station.left()
	_station = null
	_avatar.set_at_station(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	station_changed.emit(null)

## The table went while you were at it (a rebuild, or wrecked; spec §3.5): back
## to your head at once, with no move.
func _drop_station() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	_end_station()
	_interior_cam.reparent(_avatar.head, false)
	_interior_cam.transform = Transform3D.IDENTITY
	_avatar.set_control_enabled(true)
	view = View.FOOT_FIRST
	_apply_view()

## At a station the camera follows its eye, which orbits as you drag.
func _process(_delta: float) -> void:
	if not is_at_station:
		return
	if not is_instance_valid(_station) or not _station.is_inside_tree():
		_drop_station()
		return
	if _tween == null:
		_interior_cam.global_transform = _station.eye_transform()
```

- In `sit()` and `sit_now()`, add `or is_at_station` to the guard.
- In `cycle_view()`, change the guard to `if _tween != null or is_at_station:`.
- In `_on_transition_finished()`, add a branch between seated and standing:

```gdscript
	elif is_at_station:
		view = View.STATION
```

In `_apply_view()`, add:

```gdscript
		View.STATION:
			_interior_cam.current = true
			_chase_cam.current = false
```

At the top of `_unhandled_input()`:

```gdscript
	# At a station F and Esc leave it, and nothing else of the director's
	# applies: V would throw the camera off the station's eye.
	if is_at_station:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
			leave_station()
			get_viewport().set_input_as_handled()
		return
```

`avatar.gd`: add

```gdscript
## True while the camera is at a computer station (computer mode spec §3.3):
## Esc and a click are the station's, not for letting go of and taking back
## the mouse, and the Interactor rests.
var at_station := false

func set_at_station(on: bool) -> void:
	at_station = on
	if interactor != null:
		interactor.suspended = on
```

Then make the first lines of `_unhandled_input()`:

```gdscript
	if at_station:
		return
```

`interactor.gd`: add

```gdscript
## True while the avatar is using something that owns the view (a computer
## station): the ray reports nothing, and F is not the Interactor's.
var suspended := false
```

At the top of `_physics_process`:

```gdscript
	if suspended:
		if _current != null or _text != "":
			_current = null
			_text = ""
			prompt_changed.emit("")
		return
```

At the top of `_unhandled_input`: `if suspended: return`.

Headless runs cannot observe `Input.mouse_mode`. The probe (Task 9) and the playtest check it.

- [ ] **Step 4: Run.**
Run: `./run_tests.ps1 "-gselect=test_computer_station.gd"`, then `./run_tests.ps1 "-gselect=test_bridge_computer_scene.gd"`, then `./run_tests.ps1 "-gselect=test_camera_director.gd"` (if it exists: `ls who-knows/test/unit | grep -i director`), then `./run_tests.ps1 "-gselect=test_boarding_scene.gd"`.
Expected: all PASS.

- [ ] **Step 5: Commit.**

```bash
git add who-knows/src/camera/camera_director.gd who-knows/src/avatar/avatar.gd who-knows/src/avatar/interactor.gd who-knows/test/unit/test_computer_station.gd
git commit -m "feat: step up to the computer -- the director's station mode, Esc or F to leave"
```

---

### Task 7: The mouse and keys at the station

**Files:**
- Create: `who-knows/src/ship/computer/computer_mode_input.gd`
- Modify: `who-knows/scenes/flight_test.gd`
- Create: `who-knows/test/unit/test_computer_mode_input.gd`

**Interfaces:**
- Consumes: `CameraDirector.station()`, `camera()`, `is_moving()` (Task 6); `ComputerStation.orbit`, `recentre` (Task 5); `ShipComputer.pick`, `hover`, `zoom`, `next_tab`, `act`, `spin` (Task 4).
- Produces: `ComputerModeInput` with `var director: CameraDirector`, `DRAG_START := 4.0`, `SPIN_PER_PIXEL`, `ELEVATION_PER_PIXEL := 0.3`; `flight_test.gd`'s `var computer_input: ComputerModeInput` and `_wire_computer_mode()`.

- [ ] **Step 1: Write the failing tests.** Create `test_computer_mode_input.gd`:

```gdscript
extends GutTest

## The mouse and keys at a computer station (computer mode spec §3.3, §4.4).

var _root: Node
var _ship: Ship
var _director: CameraDirector
var _input: ComputerModeInput

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_director = _root.get_node("CameraDirector")
	_input = _root.computer_input
	_station().interact(_root.get_node("Ship/Interior/Avatar"))
	await wait_seconds(CameraDirector.SIT_DURATION + 0.3)

func _station() -> ComputerStation:
	return _ship.interior_builder.computers()[0].station

func _map() -> MapPage:
	return _station().computer.pages[0] as MapPage

func _button(index: MouseButton, pressed: bool, at := Vector2(400, 300)) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = index
	ev.pressed = pressed
	ev.position = at
	_input._unhandled_input(ev)

func _move(to: Vector2, by: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = to
	ev.relative = by
	_input._unhandled_input(ev)

func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = true
	_input._unhandled_input(ev)

func test_the_wheel_zooms():
	var before := _map().scale_m
	_button(MOUSE_BUTTON_WHEEL_UP, true)
	assert_almost_eq(_map().scale_m, before / 1.3, 0.01)
	_button(MOUSE_BUTTON_WHEEL_DOWN, true)
	assert_almost_eq(_map().scale_m, before, 0.01)

func test_a_drag_orbits_and_picks_nothing():
	var before := _map().selected
	_button(MOUSE_BUTTON_LEFT, true, Vector2(400, 300))
	_move(Vector2(460, 320), Vector2(60, 20))
	_button(MOUSE_BUTTON_LEFT, false, Vector2(460, 320))
	assert_almost_eq(_station().computer.spin, -60.0 * ComputerModeInput.SPIN_PER_PIXEL, 0.0001)
	assert_almost_eq(_station().elevation, InteriorProps.HOLO_STATION_ELEVATION + 20.0 * 0.3, 0.0001)
	assert_eq(_map().selected, before)

func test_a_click_on_a_mark_selects_it():
	await wait_frames(3)
	assert_gt(_map().placed_marks.size(), 0, "the start's rocks are on the map")
	var m: Dictionary = _map().placed_marks[_map().placed_marks.size() - 1]
	var at := _director.camera().unproject_position(_station().computer.holo.marks_to_global(m["position"]))
	_button(MOUSE_BUTTON_LEFT, true, at)
	_button(MOUSE_BUTTON_LEFT, false, at)
	assert_eq(_map().selected, m["id"])

func test_r_recentres_tab_turns_the_page_and_enter_acts():
	_station().computer.spin = 1.0
	_key(KEY_R)
	assert_eq(_station().computer.spin, 0.0)
	_key(KEY_ENTER)
	assert_eq(_ship.sensors.course, _map().selected, "Enter is the big button")
	_key(KEY_TAB)
	assert_eq(_station().computer.page_index, 1)

func test_nothing_happens_once_you_have_left():
	_director.leave_station()
	await wait_seconds(CameraDirector.SIT_DURATION + 0.2)
	var before := _map().scale_m
	_button(MOUSE_BUTTON_WHEEL_UP, true)
	assert_eq(_map().scale_m, before)
```

- [ ] **Step 2: Run them and see them fail.**
Run: `./run_tests.ps1 "-gselect=test_computer_mode_input.gd"`
Expected: FAIL, "Invalid get index 'computer_input'".

- [ ] **Step 3: Implement.** Create `computer_mode_input.gd`:

```gdscript
class_name ComputerModeInput
extends Node

## The mouse and keys while you are at a computer station
## (docs/superpowers/specs/2026-09-30-computer-mode-design.md §3.3): a click
## picks a mark in the holo, a drag orbits it, the wheel zooms, R recentres,
## Tab turns the page and Enter does what the big button would. A click on
## the overlay never reaches here, because its controls take it first.
## Leaving (F or Esc) is the director's, as standing up is.

## How far the mouse moves, pixels, before a press becomes a drag.
const DRAG_START := 4.0
## A horizontal drag spins the holo; a vertical one raises or lowers the eye.
const SPIN_PER_PIXEL := deg_to_rad(0.4)
const ELEVATION_PER_PIXEL := 0.3

var director: CameraDirector

var _pressed := false
var _press_at := Vector2.ZERO
var _dragging := false

func _unhandled_input(event: InputEvent) -> void:
	var station := director.station() if director != null else null
	if station == null or director.is_moving():
		_pressed = false
		_dragging = false
		return
	if event is InputEventMouseButton:
		_mouse_button(event, station)
	elif event is InputEventMouseMotion:
		_mouse_motion(event, station)
	elif event is InputEventKey and event.pressed and not event.echo:
		if not _key(event, station):
			return
	else:
		return
	if is_inside_tree():
		get_viewport().set_input_as_handled()

func _mouse_button(event: InputEventMouseButton, station: ComputerStation) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressed = true
				_press_at = event.position
				_dragging = false
			else:
				if _pressed and not _dragging:
					station.computer.pick(event.position, director.camera())
				_pressed = false
				_dragging = false
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				station.computer.zoom(-1.0)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				station.computer.zoom(1.0)

func _mouse_motion(event: InputEventMouseMotion, station: ComputerStation) -> void:
	if not _pressed:
		station.computer.hover(event.position, director.camera())
		return
	if not _dragging and event.position.distance_to(_press_at) > DRAG_START:
		_dragging = true
	if _dragging:
		station.computer.spin -= event.relative.x * SPIN_PER_PIXEL
		station.orbit(event.relative.y * ELEVATION_PER_PIXEL)

## True when the key was the mode's.
func _key(event: InputEventKey, station: ComputerStation) -> bool:
	match event.physical_keycode:
		KEY_R:
			station.recentre()
		KEY_TAB:
			station.computer.next_tab()
		KEY_ENTER, KEY_KP_ENTER:
			station.computer.act()
		_:
			return false
	return true
```

In `flight_test.gd`, add the var near the other HUD vars:

```gdscript
## The computer mode (computer mode spec §3.3, §5): its input and its overlay.
var computer_input: ComputerModeInput
```

Add the wiring function, and call `_wire_computer_mode()` in `_ready()` right after `_wire_prompt()`:

```gdscript
## The computer mode (docs/superpowers/specs/2026-09-30-computer-mode-design.md):
## the mouse and keys at a station, and the on-foot prompt cleared while you
## are there. Wired here so src/ship/computer never learns about the scene.
func _wire_computer_mode() -> void:
	computer_input = ComputerModeInput.new()
	computer_input.name = "ComputerModeInput"
	computer_input.director = _director
	add_child(computer_input)
	_director.station_changed.connect(_on_station_changed)

func _on_station_changed(_station: ComputerStation) -> void:
	_interact_prompt = ""
	_grasp_prompt = ""
	_show_prompt()
```

- [ ] **Step 4: Run.**
Run: `./run_tests.ps1 "-gselect=test_computer_mode_input.gd"`, then `./run_tests.ps1 "-gselect=test_computer_station.gd"`, then `./run_tests.ps1 "-gselect=test_hud_scene_wiring.gd"`.
Expected: all PASS. If `test_a_click_on_a_mark_selects_it` finds no marks, check that `test_the_start_s_big_rock_is_on_the_map` in `test_bridge_computer_scene.gd` still passes, and add a contact the way it does instead of relying on the start.

- [ ] **Step 5: Commit.**

```bash
git add who-knows/src/ship/computer/computer_mode_input.gd who-knows/scenes/flight_test.gd who-knows/test/unit/test_computer_mode_input.gd
git commit -m "feat: the mouse and keys at the computer -- click to pick, drag to orbit, wheel to zoom"
```

---

### Task 8: The overlay

**Files:**
- Create: `who-knows/src/ui/computer_overlay.gd`
- Modify: `who-knows/scenes/flight_test.gd`, `who-knows/src/ship/computer/map_page.gd` (one helper), `who-knows/test/unit/test_visual_style_rules.gd` (the list only)
- Create: `who-knows/test/unit/test_computer_overlay.gd`

**Interfaces:**
- Consumes: `ShipComputer.select`, `act`, `tab`, `hovered`, `page()`, `pages`, `page_index`, `ctx` (Task 4); `MapPage.targets`, `reach_colour`, `system_weight`, `colour_for`, `title`, `lines`, `lit`, `prompt` (Tasks 1, 3); `ComputerStation.computer` (Task 5); `CameraDirector.station_changed` (Task 6).
- Produces: `ComputerOverlay` (a `CanvasLayer`) with `show_for(station: ComputerStation)`, `refresh()`, `static list_rows(map: MapPage, ctx: ComputerContext) -> Array[Dictionary]` (each `{"id", "text", "colour", "indent", "selected"}`), and the nodes `tabs: Array[Button]`, `list_box: VBoxContainer`, `card_lines: Array[Label]`, `action: Button`, `tag: Label`, `scale_label: Label`; `MapPage.contact_by_id(ctx, id) -> Contact`; `flight_test.gd`'s `var computer_overlay: ComputerOverlay`.

The spec refines here: charting a warp is allowed from anywhere (warp spec §4.1), so a warp target's action is never disabled. Its reason (*NEED 512 QE*, *FLY · TOO CLOSE TO WARP*) stays on the card's third line, as the rim screen shows it. The action is disabled, reading *NO ACTION*, only when the big button is dark (a sign of life, say).

- [ ] **Step 1: Write the failing tests.** Create `test_computer_overlay.gd`:

```gdscript
extends GutTest

## The overlay round the holo at a computer station (computer mode spec §5).

class FakeSource extends RefCounted:
	var list: Array[Contact] = []
	func contacts(focus: UniversePoint, range_m: float, _time: float) -> Array[Contact]:
		return list.filter(func(c: Contact) -> bool: return c.point.minus(focus).length() <= range_m)
	func contact(id: StringName, _focus: UniversePoint, _time: float) -> Contact:
		for c in list:
			if c.id == id:
				return c
		return null

var _universe: Universe
var _hull: Node3D
var _sensors: ShipSensors
var _source: FakeSource
var _computer: ShipComputer
var _overlay: ComputerOverlay

func before_each():
	_universe = Universe.new()
	add_child_autofree(_universe)
	_hull = Node3D.new()
	add_child_autofree(_hull)
	_universe.set_focus(_hull)
	_sensors = ShipSensors.new()
	add_child_autofree(_sensors)
	_sensors.universe = _universe
	_source = FakeSource.new()
	_sensors.add_source(_source)
	_computer = ShipComputer.new()
	_computer.setup(Transform3D.IDENTITY)
	add_child_autofree(_computer)
	var ctx := ComputerContext.new()
	ctx.sensors = _sensors
	ctx.hull = _hull
	_computer.bind(ctx)
	_overlay = ComputerOverlay.new()
	add_child_autofree(_overlay)

func _add(id: StringName, kind: StringName, at: Vector3, precision := Contact.EXACT) -> void:
	var c := Contact.new()
	c.id = id
	c.kind = kind
	c.label = String(kind).to_upper()
	c.point = _universe.to_universe(at)
	c.precision = precision
	c.radius = 300.0
	c.km = 4
	_source.list.append(c)

func _map() -> MapPage:
	return _computer.pages[0] as MapPage

func _ready_map() -> void:
	_add(&"rock:a", &"rock", Vector3(0, 0, -3000))
	_add(&"life:b", &"life", Vector3(0, 0, -6000), Contact.PING)
	_sensors.refresh(MapPage.QUERY)
	_map().reselect(_computer.ctx)
	_overlay.show_for(_computer.station)

func test_it_shows_for_a_station_and_hides_for_none():
	_overlay.show_for(_computer.station)
	assert_true(_overlay.visible)
	_overlay.show_for(null)
	assert_false(_overlay.visible)

func test_near_in_the_list_is_what_is_on_the_map_with_its_distance():
	_ready_map()
	var rows := ComputerOverlay.list_rows(_map(), _computer.ctx)
	assert_eq(rows.map(func(r: Dictionary) -> StringName: return r["id"]), [&"rock:a", &"life:b"])
	assert_string_contains(rows[0]["text"], "KM")

func test_far_out_the_list_is_the_system_with_moons_under_their_planets():
	var s := SystemRecipe.from_seed(1337)
	_sensors.system = s
	_sensors.add_source(BodyContacts.new(s))
	_universe.origin = s.entry()
	_map().range_index = MapPage.SYSTEM_RANGE
	var rows := ComputerOverlay.list_rows(_map(), _computer.ctx)
	assert_eq(rows[0]["id"], BodyContacts.id_of(s.star))
	var last_planet := &""
	for r in rows:
		if r["indent"] == 0 and String(r["id"]).begins_with("body:"):
			last_planet = r["id"]
		if r["indent"] == 1:
			assert_ne(last_planet, &"", "a moon comes under a planet")

func test_a_row_click_selects_the_same_contact_as_a_holo_pick_would():
	_ready_map()
	_overlay.refresh()
	var row: Button = _overlay.list_box.get_child(2)   # 0 is the title, 1 the rock
	row.pressed.emit()
	assert_eq(_map().selected, &"life:b")

func test_the_action_is_the_big_button_s_and_dark_when_it_would_do_nothing():
	_ready_map()
	_computer.select(&"rock:a")
	_overlay.refresh()
	assert_eq(_overlay.action.text, "SET COURSE")
	assert_false(_overlay.action.disabled)
	_overlay.action.pressed.emit()
	assert_eq(_sensors.course, &"rock:a")
	_overlay.refresh()
	assert_eq(_overlay.action.text, "CLEAR COURSE")
	_computer.select(&"life:b")
	_overlay.refresh()
	assert_true(_overlay.action.disabled)
	assert_eq(_overlay.action.text, "NO ACTION")

func test_the_card_shows_the_page_s_lines():
	_ready_map()
	_computer.select(&"rock:a")
	_overlay.refresh()
	assert_eq(_overlay.card_lines[0].text, _map().lines(_computer.ctx)[0])

func test_the_status_tab_has_no_list_and_no_action():
	_ready_map()
	_overlay.tabs[1].pressed.emit()
	_overlay.refresh()
	assert_eq(_computer.page_index, 1)
	assert_false(_overlay.list_box.get_parent().get_parent().visible)
	assert_false(_overlay.action.visible)

func test_the_panels_take_the_mouse():
	_ready_map()
	assert_eq(_overlay.list_box.get_parent().get_parent().mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(_overlay.get_child(0).mouse_filter, Control.MOUSE_FILTER_IGNORE, "the middle lets clicks through to the holo")
```

Append to `test_computer_station.gd`:

```gdscript
func test_the_overlay_follows_the_station_and_the_prompt_clears():
	await _enter()
	assert_true(_root.computer_overlay.visible)
	assert_eq((_root.get_node("Prompt/Label") as Label).text, "")
	_press(&"interact")
	await wait_seconds(CameraDirector.SIT_DURATION + 0.2)
	assert_false(_root.computer_overlay.visible)
```

- [ ] **Step 2: Run them and see them fail.**
Run: `./run_tests.ps1 "-gselect=test_computer_overlay.gd"`
Expected: FAIL, "Identifier 'ComputerOverlay' not declared".

- [ ] **Step 3: Implement.**

In `map_page.gd` add:

```gdscript
## Contact `id` as the sensors know it, or null.
static func contact_by_id(ctx: ComputerContext, id: StringName) -> Contact:
	return ctx.sensors.contact(id) if ctx.sensors != null else null
```

Create `computer_overlay.gd`:

```gdscript
class_name ComputerOverlay
extends CanvasLayer

## What you read and click at a bridge computer
## (docs/superpowers/specs/2026-09-30-computer-mode-design.md §5): the tabs, the
## list, the selected target's card and its action, a tag for the mark under
## the cursor, and the hints, round the holo, which stays in the room in the
## middle. In the table's look, not the flight HUD's: LIGHT_WARM on screen
## black, accents by kind, from InteriorPalette alone. It keeps no state of
## its own: each frame it reads the station's computer and its page.

const FONT_SIZE := 18
const SMALL_SIZE := 14
const PANEL_ALPHA := 0.85
const LIST_WIDTH := 320.0
const CARD_WIDTH := 360.0
const MARGIN := 24.0
const CARD_LINES := 4
const TAG_OFFSET := Vector2(16, -24)
const HINTS := "DRAG ORBIT · SCROLL ZOOM · R RECENTRE · TAB PAGE · ENTER ACT"

var station: ComputerStation
var tabs: Array[Button] = []
var list_box: VBoxContainer
var list_title: Label
var card_lines: Array[Label] = []
var action: Button
var tag: Label
var scale_label: Label

var _list_panel: PanelContainer

func _ready() -> void:
	layer = 2
	_build()
	visible = false

## Shows the overlay for `s`, or hides it for null.
func show_for(s: ComputerStation) -> void:
	station = s
	visible = s != null
	if visible:
		refresh()

func _process(_delta: float) -> void:
	if visible and is_instance_valid(station):
		refresh()

func refresh() -> void:
	var computer := station.computer
	var ctx := computer.ctx
	var page := computer.page()
	for i in tabs.size():
		tabs[i].button_pressed = i == computer.page_index
	var map := page as MapPage
	_list_panel.visible = map != null
	if map != null:
		var system := ctx.sensors.system if ctx.sensors != null else null
		var far := MapPage.system_weight(map.scale_m) > 0.5 and system != null
		list_title.text = "SYSTEM · %s" % system.name.to_upper() if far else "NEARBY"
		_fill_list(list_rows(map, ctx))
		scale_label.text = map.title().trim_prefix("MAP · ")
	else:
		scale_label.text = ""
	var lines := page.lines(ctx)
	for i in CARD_LINES:
		card_lines[i].text = lines[i] if i < lines.size() else ""
	action.visible = map != null
	var lit := page.lit(ctx).has(&"big")
	action.disabled = not lit
	action.text = page.prompt(&"big", ctx).to_upper() if lit else "NO ACTION"
	_refresh_tag(computer)

## The list's rows (spec §5.2): far out, the system -- the star, each planet
## with its moons under it, each cluster; near in, what is on the map at full
## size, nearest first, with its distance.
static func list_rows(map: MapPage, ctx: ComputerContext) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var system := ctx.sensors.system if ctx.sensors != null else null
	if MapPage.system_weight(map.scale_m) > 0.5 and system != null:
		out.append(_row(map, ctx, BodyContacts.id_of(system.star), system.star.name, &"body", 0))
		for planet in system.bodies:
			if planet.kind != SystemBody.Kind.PLANET:
				continue
			out.append(_row(map, ctx, BodyContacts.id_of(planet), planet.name, &"body", 0))
			for moon in system.bodies:
				if moon.kind == SystemBody.Kind.MOON and moon.parent_id == planet.id:
					out.append(_row(map, ctx, BodyContacts.id_of(moon), moon.name, &"moon", 1))
		for t in system.clusters:
			out.append(_row(map, ctx, t.contact_id(), t.name, &"cluster", 0))
		return out
	for c in map.targets(ctx):
		out.append(_row(map, ctx, c.id, ContactText.line(c, ctx.relative(c.point).length()), c.kind, 0))
	return out

static func _row(map: MapPage, ctx: ComputerContext, id: StringName, text: String, kind: StringName,
		indent: int) -> Dictionary:
	var colour := MapPage.colour_for(kind)
	var c := MapPage.contact_by_id(ctx, id)
	if c != null:
		colour = map.reach_colour(ctx, c)
	if ctx.sensors != null and ctx.sensors.course == id:
		colour = InteriorPalette.AMBER
	return {"id": id, "text": text.to_upper(), "colour": colour, "indent": indent, "selected": map.selected == id}

## One button per row, reused from frame to frame.
func _fill_list(rows: Array[Dictionary]) -> void:
	while list_box.get_child_count() - 1 < rows.size():
		var b := _button("")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_on_row_pressed.bind(b))
		list_box.add_child(b)
	for i in range(1, list_box.get_child_count()):
		var b: Button = list_box.get_child(i)
		var shown := i - 1 < rows.size()
		b.visible = shown
		if not shown:
			continue
		var row: Dictionary = rows[i - 1]
		b.set_meta(&"id", row["id"])
		b.text = "%s%s %s" % ["    " if row["indent"] > 0 else "", "▸" if row["selected"] else " ", row["text"]]
		b.add_theme_color_override("font_color", row["colour"])
		b.add_theme_color_override("font_hover_color", row["colour"])

func _on_row_pressed(b: Button) -> void:
	if is_instance_valid(station):
		station.computer.select(b.get_meta(&"id"))

func _refresh_tag(computer: ShipComputer) -> void:
	var c := MapPage.contact_by_id(computer.ctx, computer.hovered) if computer.hovered != &"" else null
	tag.visible = c != null and computer.page() is MapPage
	if tag.visible:
		tag.text = ContactText.line(c, computer.ctx.relative(c.point).length()).to_upper()
		tag.position = get_viewport().get_mouse_position() + TAG_OFFSET

func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := HBoxContainer.new()
	top.position = Vector2(MARGIN, MARGIN)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	for i in 2:
		var t := _button("MAP" if i == 0 else "STATUS")
		t.toggle_mode = true
		t.pressed.connect(func() -> void:
			if is_instance_valid(station):
				station.computer.tab(i))
		top.add_child(t)
		tabs.append(t)
	var leave := _label("ESC  LEAVE", SMALL_SIZE)
	leave.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	leave.position = Vector2(-MARGIN - 120.0, MARGIN)
	root.add_child(leave)

	_list_panel = _panel()
	_list_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_list_panel.offset_left = MARGIN
	_list_panel.offset_top = MARGIN * 3.0
	_list_panel.offset_bottom = -MARGIN * 3.0
	_list_panel.custom_minimum_size.x = LIST_WIDTH
	root.add_child(_list_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_panel.add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_box)
	list_title = _label("", SMALL_SIZE)
	list_box.add_child(list_title)

	var card := _panel()
	card.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	card.offset_left = -CARD_WIDTH - MARGIN
	card.offset_right = -MARGIN
	card.custom_minimum_size.x = CARD_WIDTH
	root.add_child(card)
	var card_box := VBoxContainer.new()
	card.add_child(card_box)
	for i in CARD_LINES:
		var l := _label("", FONT_SIZE if i == 0 else SMALL_SIZE)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_box.add_child(l)
		card_lines.append(l)
	action = _button("")
	action.pressed.connect(func() -> void:
		if is_instance_valid(station):
			station.computer.act())
	card_box.add_child(action)

	var hints := _label(HINTS, SMALL_SIZE)
	hints.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hints.position = Vector2(MARGIN, -MARGIN - 20.0)
	root.add_child(hints)
	scale_label = _label("", FONT_SIZE)
	scale_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	scale_label.position = Vector2(-MARGIN - 160.0, -MARGIN - 24.0)
	root.add_child(scale_label)
	tag = _label("", SMALL_SIZE)
	tag.visible = false
	root.add_child(tag)

func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = _alpha(InteriorPalette.SCREEN_BACK, PANEL_ALPHA)
	box.border_color = _alpha(InteriorPalette.TRIM, 0.4)
	box.set_border_width_all(1)
	box.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", box)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p

func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", InteriorPalette.LIGHT_WARM)
	return l

func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", SMALL_SIZE)
	b.add_theme_color_override("font_color", InteriorPalette.LIGHT_WARM)
	b.add_theme_color_override("font_pressed_color", InteriorPalette.AMBER)
	b.add_theme_color_override("font_disabled_color", InteriorPalette.HOLO_DIM)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = _alpha(InteriorPalette.SCREEN_BACK, 0.0 if state == "normal" else 0.6)
		box.border_color = _alpha(InteriorPalette.TRIM, 0.5 if state == "pressed" else 0.0)
		box.set_border_width_all(1)
		box.set_content_margin_all(6)
		b.add_theme_stylebox_override(state, box)
	return b

## `c` at alpha `a`: the palette has no alpha of its own to give.
static func _alpha(c: Color, a: float) -> Color:
	c.a = a
	return c
```

In `test_visual_style_rules.gd`, add `"res://src/ui/computer_overlay.gd"` to `PAINTING_FILES`.

In `flight_test.gd`, add the var next to `computer_input`:

```gdscript
var computer_overlay: ComputerOverlay
```

In `_wire_computer_mode()`, before the `connect` line:

```gdscript
	computer_overlay = ComputerOverlay.new()
	computer_overlay.name = "ComputerOverlay"
	add_child(computer_overlay)
```

In `_on_station_changed()`, add `computer_overlay.show_for(_station)` (rename the parameter to `station` and use it).

- [ ] **Step 4: Run.**
Run: `./run_tests.ps1 "-gselect=test_computer_overlay.gd"`, `./run_tests.ps1 "-gselect=test_computer_station.gd"`, `./run_tests.ps1 "-gselect=test_visual_style_rules.gd"`, `./run_tests.ps1 "-gselect=test_hud_scene_wiring.gd"`.
Expected: all PASS.

- [ ] **Step 5: Commit.**

```bash
git add who-knows/src/ui/computer_overlay.gd who-knows/src/ship/computer/map_page.gd who-knows/scenes/flight_test.gd who-knows/test/unit/test_computer_overlay.gd who-knows/test/unit/test_computer_station.gd who-knows/test/unit/test_visual_style_rules.gd
git commit -m "feat: the computer's overlay -- the list, the target's card and its action, tabs and hints"
```

---

### Task 9: Renders, the zoom's cost, and the skills and docs

**Files:**
- Create: `who-knows/test/probes/computer_mode_render.gd`
- Modify: `.claude/skills/building-a-ship/SKILL.md`, `.claude/skills/building-a-ship/reference.md`, `.claude/skills/building-a-ship/ship_probe.gd`, `docs/superpowers/specs/2026-09-25-bridge-computer-design.md`, `docs/superpowers/specs/2026-09-28-warp-design.md`, `docs/superpowers/specs/2026-09-30-computer-mode-design.md`, `docs/design/visual-style.md`

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Write the probe.** Model it on `test/probes/computer_render.gd`, using its `_initialize`, `_frames`, `_shot` and NPC-hiding pattern:

```gdscript
extends SceneTree

# The computer mode in the real starter, for the owner
# (docs/superpowers/specs/2026-09-30-computer-mode-design.md §8.2). Run it
# WITHOUT --headless so it renders:
#
#   godot --path who-knows --resolution 1280x720 --script res://test/probes/computer_mode_render.gd -- <abs out dir>
#
# Writes mode_5km.png, mode_500km.png, mode_system.png, mode_status.png and
# mode_orbit.png (the eye raised and the holo spun), and prints the worst
# frame's holo update while zooming from 1 km to 9,000 km and back.

var _out := ""

func _initialize() -> void:
	_out = OS.get_cmdline_user_args()[0]
	var scene: Node = load("res://scenes/flight_test.tscn").instantiate()
	scene.save_enabled = false
	root.add_child(scene)
	_run.call_deferred(scene)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shot(name: String) -> void:
	await _frames(12)
	var file := "%s/mode_%s.png" % [_out, name]
	root.get_viewport().get_texture().get_image().save_png(file)
	print("render  %s" % file)

func _run(scene: Node) -> void:
	await _frames(5)
	var ship: Ship = scene.get_node("Ship")
	ship.npc_director.set_physics_process(false)
	for npc in ship.npc_director.live.values():
		(npc as Node3D).visible = false
	var computer: ShipComputer = ship.interior_builder.computers()[0]
	var avatar: Avatar = ship.get_node("Interior/Avatar")
	avatar.place(ship.interior.global_transform * Transform3D(Basis.IDENTITY, DeckPaths.floor_point(Vector3i(-1, 0, -2))))
	await _frames(5)
	computer.station.interact(avatar)
	await _frames(60)
	var map := computer.pages[0] as MapPage
	for pair in [[5000.0, "5km"], [500000.0, "500km"], [9000000.0, "system"]]:
		map.restore({"scale": pair[0], "selected": String(map.selected)})
		await _shot(pair[1])
	computer.station.orbit(30.0)
	computer.spin = 0.8
	await _shot("orbit")
	computer.station.recentre()
	computer.tab(1)
	await _shot("status")
	computer.tab(0)
	map.restore({"scale": 1000.0})
	var worst := 0.0
	for i in 80:
		computer.zoom(1.0 if i < 40 else -1.0)
		var t := Time.get_ticks_usec()
		computer.update(1.0 / 60.0)
		worst = maxf(worst, (Time.get_ticks_usec() - t) / 1000.0)
		await process_frame
	print("zoom    worst holo update %.2f ms over a 1 km - 9,000 km sweep" % worst)
	quit()
```

- [ ] **Step 2: Run the probe and look at every image.**
Run (PowerShell, from `who-knows/`): `& $env:GODOT_BIN --path . --resolution 1280x720 --script res://test/probes/computer_mode_render.gd -- "$env:TEMP\computer_mode"`. If `GODOT_BIN` is unset, use the path in `run_tests.ps1` without `_console`.
Expected: five PNGs and a `zoom worst holo update` line. Read each PNG.
- The holo fills the middle, and the list and the card sit clear of it.
- The text is warm cream, not the HUD's cyan.
- At 500 km your planet's limit ring shows.
- The system shot is the orrery.

Compare the worst update with style guide §2.6 (a fresh placing at 50 km was about 4 ms). If the sweep's worst is over 8 ms, cap placement while zooming at 15 Hz. In `MapPage.place_every()`, return `1.0 / 15.0` instead of `0.0` while `gliding()` and `_shown_m > STOPS[1]`, and add a test in `test_map_page.gd` that a glide at 50 km places at most every 1/15 s. Then rerun the probe and note both figures for the spec.

- [ ] **Step 3: Update the skill and the docs.**
- `building-a-ship/SKILL.md` checklist, under the `computer` bullet: add "its station's eye (1.85 m up, 0.9 m behind the holo's centre, up to 2.34 m while orbiting) must be clear of the ceiling and walls; the probe prints it". Under *Mistakes already made*, add any lesson the build taught. If none, add nothing.
- `building-a-ship/reference.md`: a *Computer mode* section with `InteriorProps.HOLO_STATION_SIZE`/`DISTANCE`/`ELEVATION`, `ComputerStation.ELEVATION_MIN`/`MAX`, `ShipComputer.PICK_RADIUS`/`PICK_TIE`, `MapPage.STOPS`, `SCALE_MIN`/`MAX`, `ZOOM_STEP`, `SHIP_CENTRED`/`STAR_CENTRED` and the three bands, and `CameraDirector.GROUP`.
- `building-a-ship/ship_probe.gd`: after the `table ...` print, add:

```gdscript
		var eye := computer.station.eye_transform().origin
		var floor_y := computer.station.global_position.y
		var high := (computer.station.global_transform * InteriorProps.holo_station_eye(ComputerStation.ELEVATION_MAX)).origin.y
		print("        eye %.2f m up, orbiting to %.2f m%s" % [eye.y - floor_y, high - floor_y,
			"" if high - floor_y < InteriorProps.HEADROOM - 0.1 else "  <-- EYE IN THE CEILING"])
```

- The bridge computer spec and the warp spec: add an "Amended <the build's date> (the computer mode spec)" note under their existing ones. Bridge computer: decisions 4 and 5 and §3.4, a station and one continuous scale. Warp §7.1: the SYSTEM range is now the far end of the continuous map, and limits are drawn at every scale.
- `docs/design/visual-style.md` §3.7: a paragraph on the mode. The camera glides over the holo. The overlay is the rim screen's look (`LIGHT_WARM` on `SCREEN_BACK` at 85%, `TRIM` rules, accents by kind), never the flight HUD's cyan. The chevron gives way to a pip once the map leaves the ship.
- The computer mode spec: set **Status** to built, with the date and branch, and add an *As built* section with the probe's figures and any difference from the plan.

- [ ] **Step 4: Run the files this branch touched, once more, and the ship probe.**
Run each: `test_map_page.gd`, `test_holo_volume.gd`, `test_ship_computer.gd`, `test_computer_picking.gd`, `test_computer_station.gd`, `test_computer_mode_input.gd`, `test_computer_overlay.gd`, `test_bridge_computer_scene.gd`, `test_interior_props.gd`, `test_interior_dressing.gd`, `test_visual_style_rules.gd`, `test_hud_scene_wiring.gd`, `test_boarding_scene.gd`. Then run the ship probe as `.claude/skills/building-a-ship/SKILL.md` says.
Expected: all PASS, with exit code 0. The probe prints an `eye` line under the starter's table with no `<--` warning.

- [ ] **Step 5: Commit, and send the renders.**

```bash
git add who-knows/test/probes/computer_mode_render.gd .claude/skills/building-a-ship docs
git commit -m "docs: the computer mode as built -- renders, the zoom's cost, the skill and the specs it amends"
```

Send the five PNGs to the owner with one line each saying what to look at, and ask before a full-suite run. Then hand over to `superpowers:finishing-a-development-branch`.
