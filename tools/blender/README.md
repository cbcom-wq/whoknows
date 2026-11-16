# Blender tools

## The Wadees (`wadee_base.py`, `wkit.py`)

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

**Rebuild**, from this folder. Use `--disable-autoexec`, since the bundle is a downloaded file:

```
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --disable-autoexec --python wadee_base.py -- <path to human_base_meshes_bundle.blend> <out dir> render
```

Then copy `<out dir>/wadee_*.glb` to `who-knows/assets/wadee/`, import them
(`godot --headless --path . --import` from `who-knows`), and look at them in the game. Run
this windowed, not headless:

```
godot --path . --resolution 1280x720 --script res://test/probes/wadee_render.gd -- <abs out dir>
```

That probe lands at the oasis, walks out of the airlock and stands the five by the pool. It
writes eye-height shots (`oasis_wadee_*.png`) and checks the frame rate on foot. The first run,
on 2026-11-15, gave 183 fps with all five in view, against a floor of 120.

**Where they stand (2026-11-16).** The owner wants to keep these models. They still need:
- **Women's faces:** more feminine, closer to the concept art of the Wadee woman in her wraps.
- **Clothes that connect:** the men's chest sash should run all the way over the shoulder,
  and every strap, sash and band should meet the body or the garment it hangs from.
- **Hair:** the scalp is a smooth shell and the long hair is made of tubes. Hair cards or a
  sculpted hair mesh would read better.
- **Lips:** the corners are slightly ragged up close, because the lips are coloured per face.
- **Weight:** each model is 55–65k triangles. That is fine for a few, but a town of 20–25
  needs lighter versions for distance.

They have no skeleton or animation yet. The Wadee design (still to be written) covers that.
