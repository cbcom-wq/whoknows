# Wadoo: the Wadees at home

**Status:** designed 2026-11-16. The owner settled the decisions marked *Owner* and then said
"Use your best judgement and build. Be creative. Make it interesting. Make things to do if
possible. Consider ranged weapons over spears; the Wadees aren't primitive, they are just
tribal." Everything marked *My call* is mine, made under that word.

**Builds on:**
- the desert world (`2026-11-03-desert-world-design.md`): WADIS (`p3` of system 1337), its oasis
  and the walled village of Parts A and B;
- the NPC foundation (`2026-09-26-npc-foundation-design.md`) and the `building-an-npc` and
  `designing-an-npc` skills;
- the Wadee spikes on branch `wadee-spike`: five models built in Blender from CC0 base meshes,
  skeletons and CC0 motions (`tools/blender/`, `assets/wadee/`).

## 1. Intent

WADIS's village is not empty: it is **Wadoo**, home of the Wadees, the game's first people. You
land, walk in through the gate, and find a town living through a loss. A beast came out of the
dunes at night, crushed two huts, broke the wall and killed six of them. The Wadees go on with their
day: gardens, water, glass, watch. They notice you, talk to you, and let you help. If you earn
it, their queen receives you in her hall and asks you to hunt the beast with her five warriors,
on foot, because it hears ships and hides under the sand. If you hurt them, they remember it for
good.

This design ends with the warriors gathered at the breach, ready. **The hunt and the beast are
the next design.**

## 2. Goals, non-goals, anti-goals

**Goals**
- A town that feels lived in: 25 people at work, at rest, talking and grieving, at real places.
- Talking to anyone. Each has a name and a line, and the lines change with what you have done.
- Things to do: small tasks that matter to someone and change the village where you can see it.
- The queen's audience in her hall, and the invitation.
- Harm with consequences: the town flees, the warriors fight back with ranged weapons, and the
  village never forgets.
- The Wadees' smooth style inside their buildings too: the queen's hall, a home, the glassworks.
- At least 80 fps on the GTX 960 at 1280 × 720, on foot among them.

**Non-goals** (later, each its own design)
- The hunt, following the tracks, and the beast.
- Night, children, trade with money, branching conversations beyond one choice.
- Wadees anywhere but Wadoo.

**Anti-goals** (failure even if it works)
- Mannequins on rails: people sliding, walking through walls or each other, or freezing in place.
- A theme park: everyone staring at you, or lines that never change.
- Wadees as primitive savages. They are tribal, and their tools are clever.
- A town that halves the frame rate.

## 3. Decisions

| Decision | Choice | Whose |
|---|---|---|
| Who they are | Slender, beautiful, in touch with their oasis; women far outnumber men and lead; peaceful, fierce in defence | Owner |
| Their loss | A beast came at night, caught them by surprise, killed several | Owner |
| What you find | The Wadees going about their normal lives | Owner |
| The queen | You must find and talk to her to be invited | Owner |
| The hunt | On foot with 5 warriors; the beast hears ships | Owner (built in the next design) |
| Talking | A panel styled like the computer's pages, ending in one choice; the others one short line each | Owner (option 1) |
| Harm | They can be wounded and killed and remember it; others flee, warriors attack, the queen never speaks to you again; saved; only real wounds count | Owner (option 1) |
| Their look | Smooth, lifelike, made in Blender from CC0 meshes and motions; becomes a style-guide rule | Owner |
| Inside their buildings | The Wadees' style, not the chunky interiors | Owner |
| Weapons | Ranged, not spears: tribal, not primitive | Owner |
| Frame floor | 80 fps | Owner |
| Numbers, jobs, memorial, queen's house and door warden, always day | 25 adults, no children; jobs at village places; a memorial; the queen in the biggest house with a warrior at its door; no night | My proposals, owner agreed |
| Scope | Ends with the warriors at the breach | My call |
| Everything in §4 to §12 not listed above | | My call |

## 4. Who the Wadees are (the fiction)

The Wadees make things from what the desert gives: sand, sun and water.
- **Sunglass.** They melt sand into glass and fill it with sunlight. A sunglass cell glows gold and
  holds a day's sun. It runs their pump, lights their lamps, and arms their warriors.
- **The sunstaff** is a warrior's weapon: a bronze staff with a sunglass head that throws a bolt
  of stored sun. It is their craft at its finest.
- **Turquoise** is *water stone*: they wear it for the oasis. Bronze is for standing: the queen
  wears the most.
- **The buildings are theirs.** The workshop is the **Glassworks**, where sunglass and staffs are
  made. The comms hut is the **Listening House**, where a horn of glass and wire listens to the
  dunes. It heard the beast too late.

**The cast**, 25 in all, each a record with a name:
- **Queen Imsa.** In her hall (`house_b`, the tallest house, at the head of the north court).
- **The Sunguard**, five warriors:
  - **Kesh**, their captain, a woman. She walks the breach.
  - **Oru**, a man. He keeps the queen's door.
  - Three more, who keep watch at the gate, the breach and the pool.
- **Nineteen villagers**, fifteen women and four men, among them:
  - **Halla**, an old woman at the dry garden;
  - **Daro**, the glassworker;
  - **Lio**, a young woman who lost her mother's armlet;
  - **Wenna**, the healer at the pool.
  - The rest have names from a syllable list, fixed by their seeds.

**The marks of the attack** (all on the existing layout):
- the crushed huts `hut_8` and `hut_9`;
- the breach in the east wall;
- `garden_dry`, dead because the beast smashed the pump's sunglass cell;
- the tracks;
- **the memorial**, new: six standing stones with sunglass lamps, between the crushed huts and
  the pool, where mourners kneel.

## 5. A day in Wadoo

It is always day (the game has no night). Each Wadee has a **home** and two or three **jobs**,
fixed by their seed and role. Jobs are places from the layout, each with a motion:

| Job | Where | Motion (library clip) |
|---|---|---|
| Tend a garden | `garden_0`, `garden_1` | `Farm_Watering`, `Farm_Harvest`, `Farm_PlantSeed` |
| Fetch water | the pump, then home | `Interact` at the pump, `Walk_Carry` home |
| Work glass | before the Glassworks | `Fixing_Kneeling`, `Interact` |
| Patch the breach | the breach's rubble | `PickUp_Table`, `Fixing_Kneeling` |
| Mourn | the memorial | `Fixing_Kneeling` (kneel), `Idle` |
| Rest in the shade | under the three sails | `Sitting_*` |
| Talk | in pairs, anywhere on the paths | `Idle_Talking` |
| Drink | the pool's bank | `Consume` |
| Keep watch (Sunguard) | gate, breach, pool, the queen's door | `Idle_FoldArms`, staff held |
| Go home | their home's door; inside for a while, out of sight | walk, then hidden |

The brain chooses by needs: *work* rises and is eased by jobs, *rest* by shade, *company* by
talk, *thirst* by the pool. Grief is a need that rises fastest in those who lost someone. So the
town is never in step, and the same Wadee is found at different places on different visits.

**Meeting you.** A Wadee who sees you near (8 m) for the first time turns and looks for a moment,
then goes back to what they were doing. A few are shy and keep 3 m away. They give way on the
paths. They never crowd you or stare for long.

## 6. Talking

Look at a Wadee within 2.5 m: **[F] Talk to Halla**. A panel opens, in the computer's look
(warm light on black, `InteriorPalette`): their name, a line or a few pages, and at most one
choice. While it is open you stand still and they face you and play `Idle_Talking`.

- **Lines** are data (`data/wadoo/lines.json`): each has a speaker (a name, a role or anyone), and
  conditions on the village's state. The most specific line whose conditions hold is spoken, and
  a speaker who has several cycles through them.
- **The village's state** (`WadooState`, saved): *regard* (0–3), each task's progress, whether
  you have met the queen, accepted the hunt, or hurt anyone, and who is dead.

## 7. Things to do

Three small tasks, each given by someone in the town and each raising **regard** by one. **Any
one opens the queen's door.** All three earn the queen's gift (§8).

1. **The pump (Halla, Daro).** Halla, at the dead garden: the beast smashed the pump's sunglass
   cell. Daro at the Glassworks has a new one cooling.
   - Talk to Daro: he sets a **sun cell** (a new item, gold glass in a bronze cage) on his bench.
   - Take it, carry it to the pump, and **[F] Fit the sun cell**.
   - The pump wakes: it thumps, water runs in the channel, and over a minute `garden_dry` turns
     green. Halla's lines change.
2. **The armlet (Lio).** Lio lost her mother's bronze armlet when they ran from the beast. It lies
   outside the breach among the rubble and the tracks, glinting in the sun (the Glinter's glint,
   on a beat). Take it and **[F] Give the armlet** to Lio. She wears it from then on.
3. **The memorial (the mourners).** The mourners have no flowers left. A **sun-lily** grows at
   the edge of `garden_1`, one at a time (a new item). Pick it and **[F] Lay the lily** at the
   memorial. A lily lies there from then on, one for each you bring, up to six.

**Wenna the healer** is not a task. If you are hurt, **[F] Ask Wenna to heal you**, and she
restores your health while she talks.

## 8. The queen

**Oru keeps her door.**
- Until regard is at least 1: "The queen does not receive strangers. Help our people, and they
  will speak for you." He stands in the doorway.
- From regard 1: "They speak well of you. Go in." He steps aside, and the door is open.

**The hall**, in the Wadees' style:
- a long room with a raised dais at the back, the queen's seat, and woven hangings;
- sunglass lamps on bronze stands, and a basin of water in the middle;
- the Sunguard's staff rack;
- a **woven map of the dunes** on the wall, with the beast's path stitched in red.

**The audience** is a few pages, set by what you have done:
1. She greets you. She names the tasks you did, if any.
2. She tells you what happened: the night, the six lost, the beast under the sand, the Listening
   House that heard it too late, and why a ship cannot hunt it.
3. She asks: **"Will you hunt it with my Sunguard, on foot?"** — *I'll hunt with you* / *Not yet*.

- **Not yet:** she waits. Talk to her again for the last page alone.
- **I'll hunt with you:**
  - **The gift:** she gives you a **sun-rod**, a short sunstaff of your own. It is a new hand
    weapon: a bolt of sun, slower to fire than the pistol and stronger, which recharges in
    daylight. If you did all three tasks, she adds a water-stone charm to it, and its bolts are
    brighter.
  - **The Sunguard gather at the breach** and wait: Kesh says "When you are ready, we go." This is
    where this design ends.

## 9. Harm and defence

- **A wound counts.** A hit that takes health from a Wadee counts; a miss or a stray that does no
  damage does not. One counted wound and **the village is hostile, for good** (saved).
- **Villagers** who see or hear it run home and stay inside. A Wadee caught in the open with no
  way home crouches and hides.
- **The Sunguard fight** with sunstaffs:
  - they keep 10–25 m off, move between cover (walls, huts, sails), and fire bolts of sun (`Spell_Simple_Shoot`);
  - a bolt does 12 damage, and one fires every 1.5–2.5 s, each with its own rhythm;
  - they dodge (`Roll`) when you aim at them, and stagger when hit (`Hit_Chest`, `Hit_Knockback`).
- **Wadees die** at 0 health (`Death01`): 60 hp for villagers and 90 for the Sunguard. The dead
  stay dead (the ledger).
  - If the queen or Kesh dies, the hunt can never be offered.
  - Oru is dead or hostile, so the hall door is barred to you. The queen, if you reach her,
    says only "Leave my hall."
- **If you black out** among them, the Sunguard stop firing. You wake aboard your ship, as after
  any blackout outside (health and damage spec §7.2; this line first said "where you fell", which
  is not the game's rule), with what you held dropped where you fell. They come for you again only
  once you are back on your feet and inside the walls.
- **Leaving the walls** ends the fight. The Sunguard return to their posts, still hostile.

## 10. Their places inside

Three buildings open, each dressed in the Wadees' style. Each is a Blender-made room model fitted
to its shell's inside, with collision from simple boxes and warm sunglass lamps (`OmniLight3D`)
that light the brick shell's inner faces:
- **the Queen's Hall** (`house_b`, §8), entered once Oru steps aside;
- **a home** (`home_4`): bedrolls, low table, pots, a loom, a family's water jar; open, and its
  people come and go;
- **the Glassworks** (`workshop`): a kiln glowing, glass rods cooling, half-made staffs, sand bins.

The Listening House (`comms`) and the other homes stay shut. Their doors are what Wadees vanish
through when they go home.

## 11. The look

- **People** are the spike's five models, refined. The pending model session is folded in here
  (`tools/blender/README.md`):
  - the women's faces made more feminine, like the concept;
  - straps that meet the body;
  - better hair.
- **Variants:**
  - the **queen**: a crown of bronze and turquoise, more jewellery, a long cape;
  - the **Sunguard**: a leather harness and arm guards, and a sunstaff in the hand (a prop on the
    `RightHand` bone);
  - **Lio's armlet** shows once given.
- **Crowd-ready** (`wadee_render.gd` `_breakdown` found the cost):
  - each Wadee is **one mesh, one material**. Its colours are slots in a small palette texture,
    and the UVs point at the slots;
  - a Wadee's own colours (skin, hair, three cloths) are a palette built from `WadeePalette` by
    seed, so 25 people with 5 models look like 25;
  - shadows only within 25 m;
  - motions update every frame within 30 m and at 15 Hz beyond.
- **Style rule:** `docs/design/visual-style.md` gains *The Wadees' style*:
  - people and their interiors are smooth and lifelike, made in Blender from CC0 meshes and motions
    (`tools/blender/`), never paid for;
  - colours come from `WadeePalette`;
  - the room kit and `InteriorPalette` stay for ships and bases.

  `test_visual_style_rules.gd` learns the new palette.

## 12. How it is built

| Piece | What | Where |
|---|---|---|
| Models | the five, refined, plus queen and Sunguard variants; single-mesh palette atlas; the clips of §5 and §9 from both UAL packs | `tools/blender/wadee_base.py`, `wadee_rig.py`, `assets/wadee/` |
| `WadeePalette` | skin, hair, cloth, metal, stone, glass, and the palette texture for a seed | `src/npc/wadee_palette.gd` |
| `WadeeLook` | the model, its palette, its motions picked from speed and the intent's action, the staff prop, LOD | `src/npc/wadee_look.gd` |
| `WadooPaths` | a walking graph from the layout: doors, gate, breach, pump, gardens, bank, sails, memorial, posts, joined where the way is clear of walls and shells | `src/npc/populations/wadoo_paths.gd` |
| `GroundWalker` | walks the graph on a world's ground, feet on it, gravity from the site, giving way to others | `src/npc/ground_walker.gd` |
| `WadooSite`, `WadooSource` | the town as a site (its frame is the place's node; alive while loaded; fills jobs, paths, posts, state) and the exterior director's source of its 25 records | `src/npc/populations/` |
| Species | `wadee_villager`, `wadee_sunguard`, `wadee_queen` | `data/npcs/` |
| Behaviours | `job`, `go_home`, `talk_pair`, `rest_shade`, `mourn`, `keep_post`, `greet`, `give_way` (reused), `flee_home`, `hide`, `fight_ranged`, `converse` | `src/npc/behaviours/` |
| `WadooState` | regard, tasks, queen, hunt, hostility; a save part `"wadoo"` | `src/world/wadoo_state.gd` |
| Talking | the `talk` interaction, `DialogPanel`, `data/wadoo/lines.json` | `src/npc/`, `src/ui/` |
| Things | sun cell, sun-lily, armlet (items); the pump, memorial and lily spot (place pieces); the sun-rod (an item use) | `src/items/`, `src/world/` |
| Interiors | three room models, collision boxes, lamps; the three shells' doors open | `tools/blender/wadoo_rooms.py`, `assets/wadoo/`, `PlaceField` |
| Sunstaff bolts | a `Bolt` that hits the avatar, gold | `src/combat/sun_bolt.gd` |

- **The floating origin:** the town's NPCs are exterior NPCs (members of
  `Universe.EXTERIOR_SPACE`). Their homes and paths are in the place's frame, so they never hold
  an engine position.
- **Loading:** the records are offered only while the place's node exists and you are within
  400 m of it. They wake where their job puts them, never in view if they can help it.
- **Saving:** the town's state is saved with the game: the ledger for the dead and wounded, and
  `WadooState` for the rest.

## 13. Stages

Each stage is committed on branch `wadoo`, rendered at eye height and shown to the owner.

1. **A living town:**
   - the models refined and crowd-ready, with the new clips;
   - the palette, the look, the walker, the paths, the site, the source and the species;
   - jobs, rest, talk, mourn, home, greet, give way;
   - the memorial;
   - 25 Wadees at at least 80 fps.
2. **Talking and the queen:**
   - talking, the panel, the lines, `WadooState` and saving;
   - Oru's door;
   - the hall's room and the queen's audience;
   - the invitation, and the Sunguard gathering at the breach.
3. **Things to do:** the pump and sun cell, the armlet, the lilies, Wenna's healing, and regard.
4. **Harm and the Sunguard:** hostility, fleeing and hiding, sunstaff bolts, fighting, death; the
   sun-rod gift.
5. **Their homes:** the home and the Glassworks rooms; then the skills, the style guide and the
   specs updated.

## 14. How it is proved

- **Unit tests per piece**, as the NPC skill's checklist:
  - species read-backs and the catalogue;
  - paths (every node reachable, no edge through a wall or shell);
  - the walker on test ground;
  - each behaviour from a made-up context;
  - the site and source (records stable, homes in the place's frame);
  - `WadooState` round-trips;
  - lines chosen by state;
  - each task's steps;
  - hostility turning.
- **The floating-origin scene test** covers them.
- **A probe** (`test/probes/wadoo_play.gd`) lands, walks in through the gate, and:
  - takes eye-height views;
  - reads the frame rate with the town in view (at least 80);
  - talks, does each task, and has the audience;
  - in a separate run, wounds a villager and records the town's reaction.

  It saves runs of frames for GIFs.
- **The owner sees** the GIFs and stills after each stage.

## 15. As built

### Stage 1: a living town (2026-11-17, branch `wadoo`)

- **The people:** eight models (`a`, `b`, `c`, `m`, `n`, the queen `q`, the Sunguard `s` and `t`), one
  mesh and one material each, coloured per person by `WadeePalette` from a 16 x 1 palette texture;
  29 clips from both motion packs (`tools/blender/README.md`). The Sunguard carry the sunstaff across
  the back; finger bones are still to come, so nothing is held in the hand yet.
- **The cast** is a fixed list (`WadooCast.PEOPLE`), not a seeded herd: every name, role, home, job
  and trait is written down, and only the colours come from the seed. Homes are `house_b` (the queen
  and the Sunguard), `home_3`, `home_4`, `house_a`, `house_d` and `hut_b`.
- **Behaviour names** differ from §12: `job` is `work`; `drink` (the bank), `hold_court` (the queen)
  and `keep_post` were added; `flee_home`, `hide`, `fight_ranged` and `converse` belong to stages 2
  and 4. `work` rotates each person's jobs; fetching water is the pump, then a walk home carrying.
- **Rest needed benches:** six (two under each sail, `data/places/oasis.json` `benches`,
  `BrickShell.bench`), with seats the walker reaches past the path grid's margin.
- **The memorial** stands at [16.5, -16.5]: six stones on a 2.4 m ring, a cairn, and a sunglass lamp
  before each stone (`OasisLooks.memorial`). Mourners kneel before a stone.
- **Waking:** `WadooSource` offers the 25 records from 1.5 km (`NEAR_ENOUGH`), and the director wakes
  them within the species' 400 m. The exterior director's `max_live` went from 32 to 40 so the whole
  town is awake at once. Indoors is hidden, not a room, until stage 5.
- **Proved:** `wadoo_play.gd` landed, stepped out and lived a minute in the town: all 25 awake;
  **132 fps** on foot at 1280 x 720 on the GTX 960 (floor 80); feet 0.003 m from the drawn ground on
  average, 0.014 at worst. Stopping their minds, bodies and motions gave 165 fps and hiding them 173:
  the town costs about 1.3 ms of physics plus its motions. The census after a minute: 5 on post, 11 at
  work, 3 resting, 2 mourning, 3 talking, the queen at court.

### Stage 2: talking and the queen (2026-11-17, branch `wadoo`)

- **Talking** is an interaction, `NpcTalk` (`talk`), in all three species: look at a Wadee within
  2.5 m, **[F] Talk to Halla** (the queen's prompt is "Talk to Queen Imsa"). The flight scene holds
  you still while the panel is open, and the Wadee turns to you (`converse`, `Idle_Talking`, or
  `Sitting_Talking` on a bench). `DialogPanel` turns pages with F, Space or Enter, answers with 1
  or 2, and Esc leaves.
- **The lines** are 54 entries in `data/wadoo/lines.json`. A line is picked by who it is for and
  what is true: a name outranks a trait (`#grief`, `#shy`), a trait a role, a role anyone, and
  among equals the one with more conditions wins; ties take turns. `{deeds}` names the tasks you
  have done. A person's own lines go under their name: the queen grieves, and while her lines were
  under her role she greeted you as a mourner.
- **`WadooState`** is saved as the part `"wadoo"`: regard 0 to 3, the three tasks (the lilies up
  to six), whether you met the queen, the hunt (`later` or `accepted`, which sticks) and hostility.
  The door opens at regard 1 unless the town is hostile. Until stage 3, a task is done only by a
  test or the probe.
- **Oru** stands 1 m before the queen's door while it is shut to you, and 1.3 m to its side once
  it opens. A Sunguard at their post holds it: `give_way` stepped Oru back from you through the
  doorway, which is open on the walking grid whether the door is shut or not. No one steps aside
  into a building they are not in.
- **The hall** is `house_b`, opened (`"open": true, "room": "hall"` in `oasis.json`). Its room is
  a Blender model (`tools/blender/wadoo_rooms.py`, `assets/wadoo/hall.glb`) fitted inside the brick
  shell, painted from `WadeePalette.ROOM`:
  - a dais 0.3 m high across the back, with a 0.15 m step;
  - the throne, teal and bronze, under a teal cloth;
  - a basin of water in the middle and a rug before it;
  - four sunglass lamps on bronze stands (`OmniLight3D`, no shadows), banners on the side walls;
  - the Sunguard's staff rack, jars and cushions;
  - the woven map of the dunes, with the village, its breach and the beast's path in red.

  Its lamps are at half the strength first tried (`LAMP_ENERGY` 0.8): at 1.6 the four of them lit
  the pale walls as bright as the street. A `ReflectionProbe` meant to keep the sky's light out
  barely changed the walls, since the lamps lit them, so it went. The desert's blowing sand passed
  through the walls, so no sand blows while you are in a room (`BlowingSand.sheltered`,
  `flight_test._indoors`).

  Collision is simple boxes: `col_` empties for the furniture, `floor_` empties for the dais and
  its step. The walking grid opens inside the room and through its doorway, and the furniture is
  solid again; the walkers' feet follow the floor, the dais and a 1.2 m ramp at the door.
- **The door** (`WadooDoor`) is a plank leaf with bronze studs. It swings into the hall over 1.4 s
  when the town comes to think well of you, and it is already open when you land with regard.
- **The queen** sits on her throne. She rises as you come within 4.5 m and faces you, and sits
  again once you are 7 m off. Her audience is four pages (her greeting, the night of the beast, the
  six lost, why a ship cannot hunt it), then "Will you hunt it with my Sunguard, on foot?" *Not
  yet* leaves the question for next time. *I'll hunt with you* sends Kesh, Tarro, Seli and Nadi to
  the breach (`gather`). Oru keeps her door. The sun-rod is given in stage 4, with the weapon.
- **Found on the way:** `BrickShell._pieces` cut a wall at every hole's sides and stacked pieces
  under each hole, so a window over a door built a piece of brick down across the doorway. This
  bricked up the doorway of every two-storey house with a window over its door. It showed first in
  the open hall, as the one doorway anyone walks through. A wall is now cut into upright strips,
  and each strip leaves every hole over it open.
- **Proved:** `wadoo_play.gd -- <out> hall` lands and walks to the hall:
  - Oru waits 0.01 m from his place before the shut door and holds it as you walk up;
  - the Interactor finds him from 1.8 m, F opens his panel, and Esc shuts it;
  - with regard 1 the door swings to 96 degrees and Oru steps aside;
  - the queen sits on her throne, and rises as you come in;
  - her audience runs through the Interactor and the keys, and the hunt is accepted;
  - 4 of 4 Sunguard reach the breach in 61 s;
  - the feet of 24 Wadees are 0.001 m from the ground on average, 0.006 at worst.

### Stage 3: things to do (2026-11-17, branch `wadoo`)

- **Three new items** (`data/items/`): the sun cell (2.5 kg, carried in both hands: gold glass in a
  bronze cage, with a loop to lift it), Lio's bronze armlet with its water stone, and the sun-lily.
  Only the Wadees make them: each is `never_made`, worth its value if converted but never in the
  machine's list (`QuantumValues.makeable`). The armlet glints like salvage, so you find it by the
  flash.
- **The pump.** Halla's dry garden now has its own pump beside it, a piece of its own (`SunPump`,
  the layout's `sun_pump`): a round stone well head, a bronze frame with an empty cage, a rod over the
  well, and a short stone channel to the bed. The old pump by the pool is the town's and stays as it
  was.
  - Talk to Daro and he sets a sun cell by the Glassworks door (the layout's `makes`). If it is lost
    before the pump has it, he sets out another (`_restock`): you cannot get stuck.
  - Holding it, **[F] Fit the sun cell**: the cell glows in the cage, the rod nods, water shows in the
    channel, and over a minute the green rises over the dry crops. The green is drawn over the dry
    rows, a little wider, rather than the bed being rebuilt.
  - Once fitted, Halla's dry garden is a garden again: she and the others tend it (its spots turn
    from `dry` to `garden`), and Halla's lines change. The pump does not thump: the town has no
    sounds yet.
- **The armlet** lies 10 m out past the breach, beyond the rubble, toward the beast's tracks (first
  put among the rubble, where a block hid it and its glint). Holding it, **[F] Give the
  armlet to Lio** (the cast's `takes`): she takes it, thanks you, and wears it on her left forearm
  from then on, as she wakes too (`WadeeLook.wear`).
- **The lilies.** A sun-lily grows at the edge of `garden_1` (the north garden), one at a time: 30 s
  after none is about, another opens. Holding one, look at a stone or the cairn: **[F] Lay the lily**
  (`MemorialLilies`). It lies before the next bare stone, between the stone and where a mourner
  kneels, its head to the stone, up to six. The mourners' lines change.
- **Wenna** heals. Hurt, **[F] Ask Wenna to heal you**: she says two pages and your health is full.
- **Talking knows what you hold** and whether you are hurt (`WadooSite.you`): Halla sees Daro's cell in
  your hands, Daro does not make a second while you carry one. The prompt says what F will do.
- **The tasks** each raise regard by one; the first opens the queen's door. With all three done,
  regard is 3.
- **Talking to someone walking by** needs you to walk up to them: as you come, they give way and turn
  to you (`give_way`), or stop to greet you (`greet`). The probe first stood you beside Lio at once;
  nothing stopped her, she was 3 m off before you spoke, and the armlet stayed in your hands, so the
  lily and the memorial (full hands) failed after it. It now walks up at 1.7 m/s.
- **Proved:** `wadoo_play.gd -- <out> things` lands and plays stage 3 through the Interactor, as a
  player (all checks passed in each of two runs, the numbers from both):
  - Daro, walked up to (1.89 to 1.90 m), sets the cell by the Glassworks door; F picks it up; F at
    the pump fits it, and the cell glows, the rod nods and the water runs;
  - the armlet is found past the breach by its glint, picked up, and given to Lio (walked up to,
    1.84 to 2.01 m), who wears it;
  - a sun-lily is picked by the north garden and laid before the first stone;
  - at half health, Wenna heals you to full;
  - a minute after the fitting the dry garden is green, regard is 3 and the queen's door is open;
  - the feet of 25 Wadees are 0.002 to 0.003 m from the ground on average, 0.019 at worst.
- **Small:** the armlet is 11 cm across, bronze on sand. At 2 m it reads as a ring
  (`oasis_wadoo_armlet_close`). At 6 m it is a few pixels and its turquoise stone. Look straight
  at it and the crosshair hides it. Its glint (the salvage glint, 0.15 s every 2 to 4 s) was not
  caught in either still, so whether it shows on bright sand is not proved yet.

### Stage 4: harm and the Sunguard (2026-11-17, branch `wadoo`)

- **One wound turns the town.** A hit that takes health from a Wadee is told to the town
  (`NpcSite.wounded`); one from anything but a Wadee (you, your bolt, your ship's turret) makes the
  village hostile for good (`WadooState.hostile`, saved). A miss does nothing. Hostile, the Sunguard
  will not talk.
- **The villagers** run for their doors (`flee_home`, at 4.2 m/s) and go in: hidden, not drawn, not
  solid. They come out 20 s after you have left the walls. One you stand between and their door,
  within 7 m, crouches where they are, facing you (`cower`, `Crouch_Idle`), until you are 12 m off;
  then they run for it.
- **The Sunguard fight** while you are on your feet within the walls (`fight_ranged`):
  - each picks a place 12 to 24 m from you on open ground inside the walls with a clear line to
    your chest, the nearest to them, a place by a wall or house counting 6 m nearer (cover); they run
    there with the staff in the right hand, and pick again every 5 to 9 s or when you have moved out
    of their 10 to 25 m band;
  - from there they throw a bolt of sun (`Spell_Simple_Shoot`, the left hand casting; the bolt
    leaves the staff's glass head 0.25 s into the throw): 12 damage at 30 m/s, aimed half a lead
    ahead of you, a little off. Each throws every 1.5 to 2.5 s, in their own rhythm. One that hits
    you bursts at a quarter size: a full burst 0.3 m from your eye hid a sixth of the view;
  - aimed at (you armed and looking within 1.2 m of them), at most once in 4 s and half the time,
    they roll 2.5 m aside (`Roll`);
  - hurt, they stagger (`Hit_Chest`). The spec's `Hit_Knockback` for a big wound was dropped: it lays
    them flat by 0.3 s and there is no clip to rise, so they would pop up;
  - no line to you from anywhere: they close in to 15 m.
- **The staff in the hand.** The models have no finger bones, so the staff is held upright beside
  the right shoulder in an open hand, leaning out and forward, its head where the one they aim at
  sees it. Reasoned from the hand bone's axes it first leaned 40 degrees across the back with its
  head hidden behind her own; the turn is now measured from the two clips
  (`test/probes/wadee_poses.gd`).
- **Death.** At 0 health (60 for a villager, 90 for a Sunguard) they fall (`Death01`) with what they
  hold and lie where they fell, no longer solid, until the town sleeps; the ledger keeps them dead.
  A person's look poses itself: the body never flips or shrinks it as it does a creature's. The
  director demotes the ledger's dead at its next review (every 0.25 s), so a fallen Sunguard first
  vanished at once; a person now stays while the town still offers them (`Npc.lies_where_fell`).
  A creature lies its `CORPSE_FOR` 20 s too, with the same keep (`Npc.lies_where_fell` holds any
  dead one whose time is not yet run out while its source offers it; the `corpses` branch).
- **You down.** Blacked out you are not someone to fight, and you wake aboard your ship (the game's
  rule outside, health and damage §7.2; §9 is corrected). The rod lies where you fell. Back on your
  feet within the walls, after 8 s of grace, the fight goes on. Leaving the walls ends it: the
  Sunguard go back to their posts, still hostile.
- **The sun-rod** (the queen's gift, §8). As you take up the hunt she says "Then take this. A
  sun-rod: a sunstaff of your own, short enough for one hand. It drinks the sun as you walk." and it
  is laid before you and put in your hands (`flight_test._give_rod`, once: `WadooState.rod_given`).
  - It is a new hand weapon (`SunRod`, items `sun_rod` and `sun_rod_charmed`): a bolt of sun of 25
    damage (the pistol's is 10) every 0.9 s (the pistol's 0.25), from 6 charges that come back one
    every 5 s out of doors. It never breaks and is never made; worth 300 QE.
  - With all three tasks done, she adds "I have bound a water stone to it, for all you did for us:
    its sun will burn brighter.": a turquoise stone under the head, bolts 1.8 times as bright, 360 QE.
- **The dead and the hall** need nothing of their own: a death comes only after a wound, which has
  already turned the town. Hostile, the hall's door stays shut (`WadooState.door_open`), the queen
  says only "Leave my hall." and anyone else "They will not look at you.", so the hunt is never
  offered again.
- **Proved:** `wadoo_play.gd -- <out> harm` lands, steps out on foot and plays it as a player
  would, the rod fired through the hands and F to pick it up (run on the GTX 960 at 1280 x 720; all
  checks passed, the numbers from the third of four runs, the first two having found the blackout
  rule and the vanishing dead):
  - the queen's rod in your hands, and a bolt of it over the town (5 of 6 left);
  - you shoot Ema (35 of 60 hp left) and the town turns at once;
  - Halla, cornered 3.5 m off between you and her door, cowers; 6 s after the wound 5 villagers are
    in, 11 running home, 3 cowering, and all 5 Sunguard fighting;
  - the first bolt comes within 6 s; Oru fires from 24 m; 160 fps in the fight with 25 awake;
  - aimed at, Seli rolls aside (16 m off); 7 bolts of the rod bring her down (4 hit: she was moving
    and rolling), and she lies where she fell to the end;
  - you black out: no bolt while you are down; you wake aboard your ship; out of the airlock,
    103 m from the middle and outside the walls, nobody fires; the rod lies where you fell, and F
    takes it up; back in the walls the fight goes on;
  - 70 m out, beyond the walls: no bolt in 5 s and no Sunguard fighting; the 16 hidden come out
    again;
  - standing in the open, 51 of their 56 bolts hit you, 612 hp over the run (the probe mended you
    12 times): about 10 s of standing still in their fire puts you down. The lead only tells when
    you move, so cover and moving are meant to matter; whether it is too hard is the owner's call.
- **The poses** up close (`test/probes/wadee_poses.gd`): the staff across the back, upright in the
  hand aiming and shooting, the roll, the stagger, the fall and the dead, and a villager cowering.
