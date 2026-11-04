# Hostile ships · the tasks, one session each

Each task's plan is a file here, run in a session of its own, in its own worktree `D:\git\whoknows-hostiles-tNN` on branch `hostiles-tNN` cut from `hostiles`. A wave starts once the waves before it are merged into `hostiles`; the tasks in one wave share no files, so they run side by side.

| Wave | Task | Depends on |
|---|---|---|
| 1 | [Task 1: sides](task-01-sides.md) | - |
| 1 | [Task 2: velocity-hold](task-02-velocity-hold.md) | - |
| 1 | [Task 3: fight-assessment](task-03-fight-assessment.md) | - |
| 1 | [Task 4: steering](task-04-steering.md) | - |
| 1 | [Task 10: spill-over](task-10-spill-over.md) | - |
| 2 | [Task 5: objective](task-05-objective.md) | 1, 3 |
| 2 | [Task 8: hit-feel](task-08-hit-feel.md) | 1 |
| 3 | [Task 6: ship-pilot](task-06-ship-pilot.md) | 1, 2, 3, 4, 5 |
| 4 | [Task 7: hostile-spawn](task-07-hostile-spawn.md) | 6 |
| 4 | [Task 9: burst-and-chip](task-09-burst-and-chip.md) | 8, 10 |
| 5 | [Task 11: sparks-and-gas](task-11-sparks-and-gas.md) | 9 |
| 5 | [Task 15: your-pilot](task-15-your-pilot.md) | 6, 7 |
| 6 | [Task 12: destroyed](task-12-destroyed.md) | 10, 11 |
| 7 | [Task 13: core-blast](task-13-core-blast.md) | 12 |
| 8 | [Task 14: ship-lost](task-14-ship-lost.md) | 6, 12, 13 |
| 9 | [Task 16: duel-probe](task-16-duel-probe.md) | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 |
| 10 | [Task 17: upkeep](task-17-upkeep.md) | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 |
