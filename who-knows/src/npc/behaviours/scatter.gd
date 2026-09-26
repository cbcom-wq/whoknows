extends Behaviour

## Bolts when the rock shakes, something hits it, or it sees a herd mate bolt
## (docs/superpowers/specs/2026-09-26-npc-foundation-design.md §13.2, §7.3):
## runs from the source along the surface, each at its own angle so the herd
## fans out, and some leap off toward a moon or rubble if there is one to land
## on. They meet again at shelter.

const SPEED := 1.0
const FRESH := 0.5
const FAN := deg_to_rad(60.0)
const RUN := 12.0
const LEAP := 25.0
const LASTS := 3.0

var _to: Variant = null
var _leap: Variant = null

func _init() -> void:
	reflex = true
	threshold = 0.45
	min_time = LASTS

func score(ctx: NpcContext) -> float:
	var s := 0.0
	for kind in [Stimulus.VIBRATION, Stimulus.TOUCH, Perception.MATE_BOLTED]:
		var p := ctx.recent(kind, FRESH)
		if p != null:
			s = maxf(s, p.sure)
	return s

func start(ctx: NpcContext) -> void:
	super(ctx)
	var source := ctx.position - ctx.forward
	var strongest := 0.0
	for kind in [Stimulus.VIBRATION, Stimulus.TOUCH, Perception.MATE_BOLTED]:
		var p := ctx.recent(kind, FRESH)
		if p != null and p.sure > strongest:
			strongest = p.sure
			source = p.where
	var away := ctx.position - source
	away -= ctx.up * away.dot(ctx.up)
	if away.length() < 0.01:
		away = ctx.forward
	var seed := ctx.record.seed if ctx.record != null else 0
	var turn := (float(seed % 1000) / 999.0 * 2.0 - 1.0) * FAN
	away = away.normalized().rotated(ctx.up, turn)
	_to = ctx.position + away * RUN
	_leap = null
	if seed % 3 == 0:
		_leap = ctx.position + (away + ctx.up).normalized() * LEAP
	ctx.raise(&"fear", 0.4)

func think(_ctx: NpcContext) -> Intent:
	var i := Intent.go(_to, SPEED, &"bolt")
	if _leap != null:
		i.action = &"leap"
		i.leap_to = _leap
		_leap = null
	return i

func done(ctx: NpcContext) -> bool:
	return running(ctx) >= LASTS
