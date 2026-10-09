class_name ProbeArgs
extends RefCounted

## The command line a probe or render script reads (ship designer spec §7.2):
## its own positional arguments, and `--ship <id or ship file>` anywhere among
## them, naming the ship to probe instead of the starter.

## The ship --ship names, or "" when there is none.
static func ship(args: PackedStringArray) -> String:
	var i := args.find("--ship")
	var named := args[i + 1] if i >= 0 and i + 1 < args.size() else ""
	return "" if named.begins_with("--") else named

## Why the command line cannot be probed, or "": a --ship naming nothing (last,
## empty, or followed by another flag) must stop the script, never fall back
## to the starter and pass its renders off as the ship asked for.
static func refused(args: PackedStringArray) -> String:
	if args.has("--ship") and ship(args) == "":
		return "--ship names no ship"
	return ""

## `args` without --ship and its value.
static func positional(args: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	var skip := false
	for a in args:
		if skip:
			skip = false
		elif a == "--ship":
			skip = true
		else:
			out.append(a)
	return out
