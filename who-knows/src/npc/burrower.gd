class_name Burrower
extends Locomotor

## Goes under a rock and comes up elsewhere (docs/superpowers/specs/
## 2026-10-10-rock-creatures-design.md §5.2, §8.1). The mind only asks
## Intent.go(point, speed, &"burrow"); the crawler hands over on it. The body
## sinks (the look drops by its height over SINK, then the collider and the
## look go and it leaves the fire-control targets), travels hidden along the
## rock's surface directions at UNDER_SPEED with no physics and no ray, then
## stands up at the target on the solid ground (RockSite.pose_at, the one ray)
## and joins the targets again as it rises over RISE. Only a RockSite has a
## surface to go under; elsewhere it hands straight back to the crawler.

const SINK := 1.5
const UNDER_SPEED := 2.0
const RISE := 1.5
## A step in the way along the route (0 to 1) to measure how long a metre of
## it is, so the pace is even where the rock is stretched.
const PROBE := 0.01

enum Phase { SINKING, UNDER, RISING, DONE }

var phase := Phase.DONE
## Site-local: where it comes up.
var _target := Vector3.ZERO
## The route: from this direction about this axis through this angle.
var _from := Vector3.UP
var _axis := Vector3.RIGHT
var _angle := 0.0
## Seconds into the phase, and how far along the route (0 to 1).
var _t := 0.0
var _u := 0.0

func enter(npc: Npc) -> void:
	phase = Phase.DONE
	_t = 0.0
	_u = 0.0
	npc.velocity = Vector3.ZERO
	var rock := npc.site as RockSite
	if rock == null or npc.intent.move_to == null:
		return
	_target = npc.intent.move_to
	_from = rock.data.dir_of(npc.local_position())
	var to := rock.data.dir_of(_target)
	_angle = _from.angle_to(to)
	_axis = _from.cross(to)
	if _axis.length() < 0.0001:
		# On the same line, or exactly opposite: any way round will do.
		_axis = _from.cross(Vector3.RIGHT if absf(_from.x) < 0.9 else Vector3.UP)
	_axis = _axis.normalized()
	phase = Phase.SINKING

func step(npc: Npc, _intent: Intent, delta: float) -> void:
	match phase:
		Phase.SINKING:
			_t += delta
			npc.sink_look(npc.species.height * _smooth(_t / SINK))
			if _t >= SINK:
				_go_under(npc)
		Phase.UNDER:
			_travel(npc, delta)
		Phase.RISING:
			_t += delta
			npc.sink_look(npc.species.height * (1.0 - _smooth(_t / RISE)))
			if _t >= RISE:
				npc.sink_look(0.0)
				npc.set_solid(true)
				phase = Phase.DONE
				npc.surfaced()

## Nothing is left to do: back to the crawler, and the burrow intent that sent
## it is spent (it would send it straight down again until the next think).
func handover(npc: Npc) -> StringName:
	if phase != Phase.DONE:
		return &""
	if npc.intent.action == &"burrow":
		npc.intent = Intent.idle()
	return &"surface_crawler"

## Put back the way it was if it leaves mid-burrow (a pooled node demoted
## under the rock, or one brought down while sinking): solid, drawn, up.
func exit(npc: Npc) -> void:
	if phase != Phase.DONE:
		npc.sink_look(0.0)
		npc.set_solid(true)
		if npc.look != null:
			npc.look.visible = true
	phase = Phase.DONE

func _go_under(npc: Npc) -> void:
	npc.set_solid(false)
	if npc.look != null:
		npc.look.visible = false
	Weapons.leave(npc)
	phase = Phase.UNDER
	_t = 0.0
	_u = 0.0

## Along the route at UNDER_SPEED, the body on the surface point of each
## direction: hidden, so the exact ground does not matter until it is up.
func _travel(npc: Npc, delta: float) -> void:
	var rock := npc.site as RockSite
	var here := rock.data.surface_point(_dir_at(_u))
	var per_unit := here.distance_to(rock.data.surface_point(_dir_at(_u + PROBE))) / PROBE
	_u = minf(_u + UNDER_SPEED * delta / maxf(per_unit, 0.01), 1.0)
	npc.global_position = rock.frame() * rock.data.surface_point(_dir_at(_u))
	if _u >= 1.0:
		_emerge(npc, rock)

## Up at the target, on the solid ground there, and a target again.
func _emerge(npc: Npc, rock: RockSite) -> void:
	npc.global_transform = rock.frame() * rock.pose_at(rock.data.dir_of(_target))
	var director := npc.director as NpcDirector
	if director != null and director.targets:
		Weapons.join(npc, Weapons.npc_id(npc.record.id))
	npc.sink_look(npc.species.height)
	if npc.look != null:
		npc.look.visible = true
	phase = Phase.RISING
	_t = 0.0

## The direction `u` of the way along the route.
func _dir_at(u: float) -> Vector3:
	return Quaternion(_axis, _angle * u) * _from

static func _smooth(k: float) -> float:
	var x := clampf(k, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
