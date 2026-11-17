class_name WadooLines
extends RefCounted

## What a Wadee says to you (docs/superpowers/specs/2026-11-16-wadoo-design.md §6),
## from data/wadoo/lines.json. Each line names who may say it (a name, @role,
## #trait or * for anyone) and when (facts of WadooState.facts(): equal to a
## value, or min:/max: bounds). The most specific line that holds is spoken: a
## name over a trait over a role over anyone, then the one with more conditions;
## among equals a speaker goes through them in turn. A line with no "hostile"
## condition holds only while the village is not hostile.

const PATH := "res://data/wadoo/lines.json"
## How much who a line names counts toward how specific it is.
const RANK_NAME := 100
const RANK_TRAIT := 20
const RANK_ROLE := 10
const RANK_ANYONE := 0
## How a done task is named in the queen's greeting ({deeds}).
const DEEDS := {&"pump": "you woke Halla's pump", &"armlet": "you found Lio's armlet",
	&"lilies": "you laid a lily for our dead"}

static var _loaded: WadooLines

var lines: Array = []

## The lines in `path`, read once.
static func shared() -> WadooLines:
	if _loaded == null:
		_loaded = from_file(PATH)
	return _loaded

static func from_file(path: String) -> WadooLines:
	var out := WadooLines.new()
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		push_error("WadooLines: %s will not parse" % path)
		return out
	out.lines = (json.data as Dictionary).get("lines", [])
	return out

## What `person` (WadooCast.person) says now: {pages: Array[String], choice: {} or
## {ask, answers: [{say, then, reply}]}, then: String}, with {name} and {deeds}
## filled in; counts it as heard. {} if they have nothing to say.
func pick(person: Dictionary, state: WadooState, speaker: StringName, you := {}) -> Dictionary:
	var facts := state.facts()
	facts.merge(you, true)
	var best: Array = []
	var best_rank := -1
	for line: Dictionary in lines:
		var r := rank(line, person)
		if r < 0 or not holds(line.get("when", {}), facts):
			continue
		r += (line.get("when", {}) as Dictionary).size()
		if r > best_rank:
			best = [line]
			best_rank = r
		elif r == best_rank:
			best.append(line)
	if best.is_empty():
		return {}
	var line: Dictionary = best[state.heard_from(speaker) % best.size()]
	var pages: Array[String] = []
	for p: String in line.get("pages", []):
		pages.append(fill(p, person, facts))
	var choice: Dictionary = (line.get("choice", {}) as Dictionary).duplicate(true)
	if not choice.is_empty():
		choice["ask"] = fill(str(choice.get("ask", "")), person, facts)
	return {"pages": pages, "choice": choice, "then": str(line.get("then", ""))}

## How specific a line is for `person` by who it names, or -1 if not theirs.
static func rank(line: Dictionary, person: Dictionary) -> int:
	var who := str(line.get("who", "*"))
	if who == "*":
		return RANK_ANYONE
	if who.begins_with("@"):
		return RANK_ROLE if String(person.get("role", "")) == who.substr(1) else -1
	if who.begins_with("#"):
		return RANK_TRAIT if bool(person.get(who.substr(1), false)) else -1
	return RANK_NAME if str(person.get("name", "")) == who else -1

## Whether every condition in `when` holds of `facts`.
static func holds(when: Dictionary, facts: Dictionary) -> bool:
	if not when.has("hostile") and bool(facts.get("hostile", false)):
		return false
	for key: String in when:
		var want: Variant = when[key]
		if key.begins_with("min:"):
			if float(facts.get(key.substr(4), 0)) < float(want):
				return false
		elif key.begins_with("max:"):
			if float(facts.get(key.substr(4), 0)) > float(want):
				return false
		elif not _same(facts.get(key), want):
			return false
	return true

static func _same(have: Variant, want: Variant) -> bool:
	if want is bool:
		# a fact no one gave (you, not hurt) is false
		return (have is bool and have) == want
	if want is float or want is int:
		return float(have) == float(want)
	return str(have) == str(want)

static func fill(text: String, person: Dictionary, facts: Dictionary) -> String:
	return text.replace("{name}", str(person.get("name", ""))).replace("{deeds}", deeds(facts)) \
		.replace("{charm}", charm(facts))

## What the queen adds to her gift (§8) if you did all three things: the water
## stone, said as the end of a sentence; "" if not.
static func charm(facts: Dictionary) -> String:
	if int(facts.get("tasks_done", 0)) < WadooState.TASKS.size():
		return ""
	return " I have bound a water stone to it, for all you did for us: its sun will burn brighter."

## What you did for Wadoo, as the queen says it: "You woke Halla's pump, and you
## laid a lily for our dead". "You came to us" if nothing.
static func deeds(facts: Dictionary) -> String:
	var done: Array[String] = []
	for t: StringName in WadooState.TASKS:
		if bool(facts.get("task:%s" % t, false)):
			done.append(DEEDS[t])
	if done.is_empty():
		return "You came to us"
	var text := done[0]
	if done.size() > 1:
		text = ", ".join(done.slice(0, done.size() - 1)) + " and " + done[done.size() - 1]
	return text[0].to_upper() + text.substr(1)
