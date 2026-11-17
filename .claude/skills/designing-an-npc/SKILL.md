---
name: designing-an-npc
description: Use when designing a new NPC for the who-knows Godot project from a description, a story or concept art - a creature, a droid, crew, or a people like the Wadees - before it is built; or when choosing or reworking how an NPC looks or moves. Also when the owner shares concept art, asks for a person, a town's people, a face, clothes, a walk or a fight, or calls a look too plain, too chunky, robotic or "pasted on".
---

# Designing an NPC

## Overview

This is the judgment half of making an NPC. A description becomes three things:
- **decisions the owner has made** about what it is;
- **a look and motion the owner has seen and kept**;
- **a design doc** a builder can plan from.

`building-an-npc` (beside this skill) is how to build it into the game: the five layers, the
checklist and its *Mistakes already made*. Read both; this skill never repeats that one.
**The owner decides what it is. You decide how it is made**, and you say each call in a line.

## The order

1. **What it is.** Settle it with the owner one question at a time, each with your
   recommendation (§ *Questions*). Write the answers down as they come: first in memory, later in
   the spec.
2. **Its look, as a spike.** A throwaway build the owner said yes to, rendered and shown, then
   reworked on their words until they say keep it (§ *Looks*).
3. **Its motion, as a spike**, once the look is kept (§ *Motion*).
4. **Commit a spike only at the owner's word**, on its own branch in a sibling worktree
   (`git worktree add ../whoknows-<branch> -b <branch> main`). Never merge or push without their
   word.
5. **The design doc:** `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`. It holds the
   decisions, what the spikes taught, the approaches and the builder check, and the owner approves
   it.
6. **Build it:** the plan, then `building-an-npc`, with the spikes' scripts and models as the
   starting point.

The look comes before behaviour: the owner settles who they are before deciding what they do.

## Questions (the owner's to answer)

| Ask | What it decides | The Wadees' answer |
|---|---|---|
| What are they doing when the player first finds them? | behaviours, jobs, places | living their normal lives in their town |
| How does the player meet them, and what do they want of the player? | the first meeting, a quest, interactions | find and talk to the queen to be invited on the hunt |
| How do they speak? | a dialog panel, single lines | a panel styled like the computer's pages, ending in one choice; the others one short line each |
| What can the player do to them, and what follows? | health, the ledger, reactions, saving | they can be wounded and killed; others flee, warriors attack, the queen never speaks to you again; saved |
| How many, where, and who leads? | population, site, director | 25 adults, no children: Queen Imsa, five Sunguard warriors and nineteen villagers, mostly women |
| What do they look like? Is there concept art? | the look | slender and beautiful; the owner's drawing: long hair, cream, rust and teal wraps, bronze and turquoise jewellery |

Then answer `building-an-npc`'s *Decide before you build* for the engine side: the space, the
locomotor, the senses, the needs, how it is found, what can be done to it.

## Looks

| It is | Made as | Where |
|---|---|---|
| A droid or crew inside a ship | interior kit pieces in `InteriorPalette` (the binding style) | `NpcLooks`, `building-an-npc` |
| A creature in space or on a rock | flat facets in `SpacePalette` | `NpcLooks`, `building-an-npc` |
| A person, or anything with a face seen close up | a model made in Blender from CC0 base meshes, changed in a script that can be re-run | `tools/blender/` (`wadee_base.py`, `README.md`) |

- **Style:** `docs/design/visual-style.md` is binding. The owner has said WhoKnows means "you
  don't really know what you're going to get", so a world's people may have a style of their own.
  The Wadees are smooth and lifelike, not chunky. A look outside the guide needs the owner's
  approval, and then the guide, the code and the tests change together (`CLAUDE.md`). Until then it
  is a spike. Ask whether a new people keeps the guide's style, and offer a spike of each.
- **People:** start from a sculpted base mesh, never from code shapes. Shape it, then add hair,
  clothes and jewellery, in a script.
- **Concept art:** put the renders beside it and name every difference before showing them.
- **Every strap meets something:** a sash runs over the shoulder, and a band touches the body or
  the garment it hangs from. Check from the front, the back and the side.
- **Show the look:** first Blender test renders (the group, faces close, three-quarter views) for
  quick turns. Then the real scene at eye height (1.6 m) with a probe. If the owner may be away,
  send the images with `SendUserFile`.

## Motion

- **Source:** a CC0 motion library copied onto the model's skeleton (`tools/blender/wadee_rig.py`,
  from Quaternius's *Universal Animation Library*). It is real motion that holds up close.
  - Motion made in code looks mechanical, for the same reason code-built faces failed.
  - Mixamo needs the owner's sign-in and is not CC0.
- **List the clips the answers call for:** standing, walking and talking; running, fighting,
  being hit and dying; sitting, kneeling and working. Check the library has them before promising
  anything: its free packs have no spear set, and no finger bones are rigged yet.
- **Downloads:**
  - ask first, giving the file's name, source and size;
  - CC0 only, and never pay (the owner: "absolutely do not pay any");
  - keep each in its own folder outside the repo, and open it in Blender with
    `--disable-autoexec`.
- **Show motion as motion:** a run of frames from the game made into a GIF, and a Blender sheet of
  each clip (one row per moment). A still cannot show a walk.
- **Measure a crowd:** take the frame rate with as many in view as the design wants, then take
  one thing away at a time to see where the time goes (`wadee_render.gd` `_breakdown`). 25
  Wadees in view ran at 74–80 fps on the GTX 960, against the floor of 80. The scene alone was 157 (6.4 ms),
  leaving them about 6 ms, which 25 just fit. The cost was draw calls (13 meshes and 18 materials each, drawn again
  into every shadow map), motions on the CPU and the probe's steering, not triangles. So a
  people meant for crowds is designed as one mesh with few materials, shadows only near, and
  motions updated less often when far.
  - **That design held** (Wadoo stage 1, 2026-11-17): one mesh and one material each, coloured
    from a palette texture per person, shadows within 25 m and far motions at 15 Hz. All 25 awake
    and walking in the game ran at 132 fps on the GTX 960, against 74–80 for the spike.
- **Map each action to a clip before building** (`WadeeLook.CLIPS`): a job the design names
  (water a garden, fetch water, mourn) needs a clip that reads as it from 10 m. The farming,
  carrying, drinking, arms-folded and nodding clips came from the library's second pack; ask for
  a second pack before inventing a motion.

## Mistakes already made (don't repeat)

| Mistake | What happened | Do instead |
|---|---|---|
| A person's look built from code shapes | Rejected: the chin too weak and rounded, "eyes look pasted on, little contour" | Start from a sculpted CC0 base mesh (Blender's *Human Base Meshes*) |
| Showing faces without the concept art beside them | The owner kept the models but wants the women's faces "more feminine like in the concept image" | Compare with the concept side by side, and say what differs, before asking |
| Straps that end in the air | The men's chest sash did not go over the shoulder | Check every strap from the front, the back and the side |
| A scripted "name your own price" download | itch.io's free route needs a key its page script makes, and after a few scripted tries it answered HTTP 429 | Look for the author's own upload of the same free pack on OpenGameArt, which has direct links |
