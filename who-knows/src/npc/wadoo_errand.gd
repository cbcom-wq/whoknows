class_name WadooErrand
extends Behaviour

## A Wadee's errand (docs/superpowers/specs/2026-11-16-wadoo-design.md §5): it lets
## go of any spot it held, takes one (`choose`), walks there, turns to face what it
## works at, does the spot's action for its time (`span`, by seed and clock), easing
## `need` at `rate`, and lets the spot go. A Wadoo behaviour that goes somewhere to
## do something extends this and overrides `choose`, and maybe `action`.
##
## Its town is the WadooSite in ctx.extra[&"town"]; who it is, its record's id.

## A fraction of top speed: a walk (1.2 m/s at 1.6).
const WALK := 0.75
const ARRIVED := 0.35
## Turned within this of what it works at, it begins, rad.
const FACING := 0.4
## Walking longer than this, it gives up (the way is blocked).
const GIVE_UP := 90.0

var span := Vector2(20.0, 40.0)
var need: StringName = &""
var rate := 0.0
var spot: Dictionary = {}
var town: WadooSite
var _since := -1.0
var _for := 0.0
var _finished := false

func start(ctx: NpcContext) -> void:
	super(ctx)
	_since = -1.0
	_finished = false
	town = ctx.extra.get(&"town") as WadooSite
	spot = {}
	if town != null:
		town.release(who(ctx))
		town.mark(who(ctx), &"")
		spot = choose(ctx)
	_finished = spot.is_empty()
	_for = lerpf(span.x, span.y, roll(ctx, 1))

## The spot to go to, claimed; {} for none. Errands override it.
func choose(_ctx: NpcContext) -> Dictionary:
	return {}

func think(ctx: NpcContext) -> Intent:
	if spot.is_empty():
		return Intent.idle()
	var at: Vector3 = spot["at"]
	if _since < 0.0:
		if flat_distance(ctx.position, at) > ARRIVED:
			if running(ctx) > GIVE_UP:
				finish(ctx)
				return Intent.idle()
			return Intent.go(at, WALK, walk_action(ctx))
		if not facing(ctx, spot["face"]):
			return Intent.idle().facing(spot["face"])
		_since = ctx.time
	if need != &"":
		ctx.ease(need, rate)
	if ctx.time - _since >= _for:
		finish(ctx)
	return Intent.idle(action(ctx)).facing(spot["face"])

## What it does at the spot, this think.
func action(_ctx: NpcContext) -> StringName:
	return spot["action"]

## What it does as it walks there (&"carry": a load in its arms).
func walk_action(_ctx: NpcContext) -> StringName:
	return &""

## At the spot and at it.
func acting() -> bool:
	return _since >= 0.0

func finish(ctx: NpcContext) -> void:
	_finished = true
	if town != null:
		town.release(who(ctx))

func done(_ctx: NpcContext) -> bool:
	return _finished

static func who(ctx: NpcContext) -> StringName:
	return ctx.record.id if ctx.record != null else &""

## A number in [0, 1) from its seed and the clock: the same think gives the same.
static func roll(ctx: NpcContext, salt: int) -> float:
	var s := ctx.record.seed if ctx.record != null else 0
	return fposmod(float(s % 10007) * 0.618034 + ctx.time * 0.37 + salt * 0.291, 1.0)

## Turned toward `at` within FACING.
static func facing(ctx: NpcContext, at: Vector3) -> bool:
	var to := Vector2(at.x - ctx.position.x, at.z - ctx.position.z)
	if to.length() < 0.05:
		return true
	return absf(Vector2(ctx.forward.x, ctx.forward.z).angle_to(to)) < FACING

## The person it is ({name, role, jobs, grief, shy, ...}), from the site.
static func person(ctx: NpcContext) -> Dictionary:
	return ctx.extra.get(&"person", {})
