# Blender tools

## The Wadees (`wadee_base.py`, `wadee_rig.py`, `wkit.py`)

`wadee_base.py` builds the five Wadee models, the people of WADIS's oasis town Wadoo, and
writes them as glTF to `who-knows/assets/wadee/wadee_<a|b|c|m|n>.glb`. It does the whole
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

**Skeleton and motions (`wadee_rig.py`).** The second step reads the five models
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
- **Clips:** `Idle`, `Idle_Talking`, `Walk`, `Walk_Formal`, `Jog_Fwd` (a fast run) and `Sprint`.
  Godot drops the library's `_Loop` from each name and loops the clip.
- **Pace:** to keep the feet from sliding, move a Wadee at the library's pace times its hip
  height over 0.917 m. The library's pace is 1.05 m/s walking and about 5.9 m/s on `Jog_Fwd`.

**Rebuild**, from this folder. Use `--disable-autoexec`, since the bundle and the library are
downloaded files:

```
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --disable-autoexec --python wadee_base.py -- <path to human_base_meshes_bundle.blend> <static dir> render
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --disable-autoexec --python wadee_rig.py -- <path to AnimationLibrary_Godot_Standard.glb> <static dir> ../../who-knows/assets/wadee [render]
```

`wadee_rig.py` writes the rigged models into the game. With `render` it also writes test
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
- **Clothes that connect:** the men's chest sash should run all the way over the shoulder,
  and every strap, sash and band should meet the body or the garment it hangs from.
- **Hair:** the scalp is a smooth shell and the long hair is made of tubes. Hair cards or a
  sculpted hair mesh would read better.
- **Lips:** the corners are slightly ragged up close, because the lips are coloured per face.
- **Weight:** each model is 55–65k triangles. That is fine for a few, but a town of 20–25
  needs lighter versions for distance.

**Movement still to do:**
- **Not in the game yet:** no locomotor walks them over the world's ground (the NPC
  foundation's `GroundWalker`), and nothing blends between clips by speed. The probe steers
  its walkers round circles.
- **Fingers:** there are no finger bones, and nothing grips a spear.
- **Long skirts:** they stretch between the legs when running. That needs skirt bones or cloth.
- **Small faults:** a man's anklet hangs low, and the women's tops gap a little at the armpit
  when running.
