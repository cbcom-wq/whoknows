class_name Universe
extends Node

## Where the engine's origin is in the universe, and the floating origin that
## keeps it near you (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §4).
##
## Engine positions are 32-bit floats: precise near the origin, shimmering tens
## of kilometres out. So when the focus -- the hull, or you on a spacewalk --
## strays SHIFT_AT from the origin, everything in exterior space moves back by
## the same whole kilometres, first thing in a physics tick. Nothing moves
## relative to anything else, so there is nothing to see. The interior is its
## own space and never moves.

## After a shift, for anything that remembers an engine position instead of
## being moved: subtract `delta` from it.
signal shifted(delta: Vector3)

## What the shift moves. Each member is moved itself, never through a parent:
## a member's parent never moves, so the member's own coordinates stay small.
const EXTERIOR_SPACE := &"exterior_space"
## World-space particles outside, which cannot be moved once emitted. While
## one is alive the shift waits, up to FORCE_AT.
const HOLDS_SHIFT := &"holds_origin_shift"

const SHIFT_AT := 2000.0
const FORCE_AT := 4000.0
## The origin moves in whole steps of this, so it is always exact.
const STEP := 1000.0

var origin := UniversePoint.new()
## Where "you" are: the hull aboard, the avatar on a spacewalk.
var focus: Node3D
## How many times the origin has moved: for the debug readout and live checks.
var shifts := 0

var _held_until_ms := 0

func _ready() -> void:
	process_physics_priority = -1000

func _physics_process(_delta: float) -> void:
	check()

func set_focus(body: Node3D) -> void:
	focus = body

## Moves the origin if the focus has strayed. True if it did.
func check() -> bool:
	if not is_instance_valid(focus) or not focus.is_inside_tree():
		return false
	var p := focus.global_position
	var far := maxf(absf(p.x), maxf(absf(p.y), absf(p.z)))
	if far <= SHIFT_AT:
		return false
	if far <= FORCE_AT and is_held():
		return false
	shift(Vector3(snappedf(p.x, STEP), snappedf(p.y, STEP), snappedf(p.z, STEP)))
	return true

## Moves the origin by `delta`, whole STEPs, and everything outside with it.
func shift(delta: Vector3) -> void:
	for node in get_tree().get_nodes_in_group(EXTERIOR_SPACE):
		var n := node as Node3D
		if n != null and n.is_inside_tree():
			n.global_position -= delta
	origin = origin.plus(delta)
	shifts += 1
	shifted.emit(delta)

## True while a world-space effect outside is alive: its emitting flag, and
## its particles' lifetime after.
func is_held() -> bool:
	var now := Time.get_ticks_msec()
	for node in get_tree().get_nodes_in_group(HOLDS_SHIFT):
		var p := node as GPUParticles3D
		if p != null and p.emitting:
			_held_until_ms = maxi(_held_until_ms, now + int(ceil(p.lifetime * 1000.0)))
	return now < _held_until_ms

func to_universe(p: Vector3) -> UniversePoint:
	return origin.plus(p)

func to_engine(u: UniversePoint) -> Vector3:
	return u.minus(origin)
