# Blender tools

## The Wadees (`wadee_base.py`, `wadee_rig.py`, `wkit.py`)

`wadee_base.py` builds the eight Wadee models, the people of WADIS's oasis town Wadoo, and
writes them as `.blend` files into a static folder for `wadee_rig.py`. It does the whole
job in code, so it can be re-run after any change. `a`, `b` and `c` are women and `m` and `n`
are men. Each has its own skin, hair, height and outfit colours (`VARIANTS` at the bottom of
the script).

**Source bodies.** The bodies are the realistic female and male meshes from Blender's
*Human Base Meshes* bundle, v1.4.1, which is CC0 (public domain, no credit needed). It is
downloaded from blender.org's demo files and is not kept in this repo. Unzip it into a folder
of its own. The script reads `human_base_meshes_bundle.blend` from that folder.

**What the script does to them:**
- bakes the sculpt at multires level 2;
- scales every body to 1.745 m, then by the variant's scale;
- lowers the A-pose arms about a pivot above the armpit;
- slims the body by 3% and fills out the women's bust a little;
- decimates the body to about 40k triangles;
- colours the base mesh's own eyeballs (sclera, iris, pupil) and the lips;
- builds lashes, brows, hair, clothes and jewellery around the body, and pushes them clear of it.

Colours are the Wadee outfit set: cream, rust, teal, leather, bronze and turquoise.
`wkit.py` holds the shared mesh helpers (tubes, ellipsoids, raycast projection, baking).

**Skeleton and motions (`wadee_rig.py`).** The second step reads the eight models
`wadee_base.py` wrote:
- **Skeleton:** each model gets 23 bones, named as Godot's humanoid profile (`Hips`, `Spine`,
  `Chest`, `UpperChest`, `Neck`, `Head`, then `Left`/`Right` `Shoulder`, `UpperArm`, `LowerArm`,
  `Hand`, `UpperLeg`, `LowerLeg`, `Foot`, `Toes`). There are no fingers yet. The joints are found
  on the body itself: slices give the trunk and legs, the deltoid gives the shoulder, and the
  narrowest point above the hand gives the wrist.
- **Weights:** the skin uses Blender's heat weights. Everything else copies the skin under it,
  with a rule per kind of part:
  - eyes, lashes and brows follow the head;
  - hair follows only the head, neck and chest;
  - clothes copy the body without its arms, give 40% of any leg pull to the hips, and are
    smoothed along the cloth so a skirt stretches rather than tears;
  - a ring round an arm follows the arm, while a coin, bead, belt or sandal follows the trunk.
- **Motions:** they come from Quaternius's *Universal Animation Library* (Standard, CC0,
  downloaded from OpenGameArt and not kept in this repo). Each bone turns in the world as the
  library's bone does. The turn is measured from a pose of the library's body that matches ours,
  with its T-pose arms brought down to where ours hang. The hips' movement is scaled by hip
  height.
- **Clips**, from two libraries. Library 1 (bones `DEF-*`): `Idle`, `Idle_Talking`, `Walk`,
  `Walk_Formal`, `Jog_Fwd`, `Sprint`, `Sitting_Enter`, `Sitting_Idle`, `Sitting_Exit`,
  `Sitting_Talking`, `Fixing_Kneeling`, `Interact`, `PickUp_Table`, `Hit_Chest`, `Hit_Head`,
  `Death01`, `Roll`, `Spell_Simple_Shoot`, `Spell_Simple_Idle`, `Crouch_Idle`, `Crouch_Fwd`.
  Library 2 (*Universal Animation Library 2*, CC0; its bones are named as Unreal's mannequin, so
  it has its own map, `NAMES2`): `Farm_Watering`, `Farm_Harvest`, `Farm_PlantSeed`,
  `Walk_Carry`, `Consume`, `Idle_FoldArms`, `Yes`, `Hit_Knockback`. Godot drops the library's
  `_Loop` from a name and loops that clip; `WadeeLook` loops the others it holds (`HELD`).
- **One mesh, one material:** after weighting, every part's faces get UVs at the texel of their
  material's slot in a 16 x 1 palette (`SLOTS`: skin, lips, hair, brow, eye white, iris, pupil,
  lash, cloth 1-3, leather, bronze, turquoise, sunglass, cape), and the parts are joined. The
  game colours each person from `WadeePalette` (`src/npc/wadee_palette.gd`), so a Wadee is one
  draw call and five bodies dress as many people.
- **Variants** (`VARIANTS` in `wadee_base.py`): `a`, `b`, `c` women and `m`, `n` men, the
  villagers; `q` the queen (a diadem of bronze and turquoise, a collar, more rings and a long
  cape); `s` and `t`, a woman and a man of the Sunguard (a leather harness crossing chest and
  back, and leather arm guards). Clothes take materials by role (`cloth1` top, `cloth2` skirt,
  `cloth3` trim), and the men's chest sash runs over the shoulder.
- **The sunstaff** (`sunstaff.glb`): a 1.5 m bronze staff with a sunglass orb in a bronze cage,
  its grip at the origin, along +y. The Sunguard carry it across the back (`WadeeLook`).

**Rebuild**, from this folder. Use `--disable-autoexec`, since the bundle and the library are
downloaded files:

```
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --disable-autoexec --python wadee_base.py -- <path to human_base_meshes_bundle.blend> <static dir> render
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --disable-autoexec --python wadee_rig.py -- <path to AnimationLibrary_Godot_Standard.glb> <path to UAL2_Standard.glb> <static dir> <rig dir> [render]
```

`wadee_rig.py` writes the rigged models and the staff into `<rig dir>`; copy the `.glb` files into `../../who-knows/assets/wadee` (the test sheets stay out of the game). With `render` it also writes test
sheets of each clip, one row per moment, as `blender_<clip>.png`. Name a few tags (`a m`) to
rig only those. Then import them (`godot --headless --path . --import` from `who-knows`) and
look at them in the game. Run this windowed, not headless:

```
godot --path . --resolution 1280x720 --script res://test/probes/wadee_render.gd -- <abs out dir>
```

That probe lands at the oasis and walks out of the airlock:
- three Wadees walk a loop on the north bank while two stand talking inside it;
- the three then run a wider loop, and 20 more join for a frame-rate reading.

It writes eye-height shots and runs of frames (`oasis_seq_walk_NN.png`, `oasis_seq_run_NN.png`).
The first run of the static models, on 2026-11-15, gave 183 fps with all five in view, against
the floor of the time, 120 (it is 80 since 2026-11-16).

**Where they stand (2026-11-16).** The owner wants to keep these models. They still need:
- **Women's faces:** more feminine, closer to the concept art of the Wadee woman in her wraps.
- **Clothes that connect:** done for the men's sash (2026-11-16); the harness's shoulder
  pieces read as flat plates.
- **Hair:** the scalp is a smooth shell and the long hair is made of tubes. Hair cards or a
  sculpted hair mesh would read better.
- **Lips:** the corners are slightly ragged up close, because the lips are coloured per face.
- **Weight:** each model is 60-70k triangles in one mesh; Godot makes its LODs on import.

**Movement still to do:**
- **In the game** since Wadoo stage 1: `GroundWalker` walks them over the ground and
  `WadeeLook` picks and paces the clips by speed and action.
- **Fingers:** there are no finger bones, and nothing grips a spear.
- **Long skirts:** they stretch between the legs when running. That needs skirt bones or cloth.
- **Small faults:** a man's anklet hangs low, and the women's tops gap a little at the armpit
  when running.

## Their rooms (`wadoo_rooms.py`)

`wadoo_rooms.py` builds the furnishings inside three of Wadoo's brick shells, one GLB per room:
- `hall`: the queen's hall, in `house_b`;
- `home`: a family's home, in `home_4`;
- `glassworks`: the Glassworks, in `workshop`.

Everything is plain shapes made in the script, with no downloads. Materials are named by what they
are, and the game paints each from `WadeePalette.ROOM`. Empties mark where lamps (`lamp_`) and the
kiln (`kiln_`) shine, which boxes are solid (`col_`) or stood on (`floor_`), the queen's marks, and
the spots where a Wadee works, sits or hides (`spot_<kind>_<n>_<action>` and `look_<kind>_<n>`). The
script's docstring has the details.

```
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --disable-autoexec --python wadoo_rooms.py -- <out dir> hall home glassworks [render]
```

Copy the GLBs into `../../who-knows/assets/wadoo` and `--import`, after every change: the game
reads the empties from the GLB, not the script, and `test_wadoo_hall.gd` and `test_wadoo_homes.gd`
check them there.
`render` writes preview shots of each room (`VIEWS`).
