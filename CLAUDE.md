# CLAUDE.md

Repo-wide conventions and gotchas for Claude Code / agents working in this project.

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
