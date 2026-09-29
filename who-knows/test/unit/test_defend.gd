extends GutTest

## A skitter bites back (docs/superpowers/specs/
## 2026-09-29-health-and-damage-design.md §5.4), scored from made-up contexts.

var _b: Behaviour

func before_each():
	_b = NpcBehaviours.make(&"defend")

func _ctx(player: Variant, fear := 0.0, hurt_ago := INF, time := 10.0) -> NpcContext:
	var ctx := NpcContext.new()
	ctx.needs = {&"fear": fear}
	ctx.player = player
	ctx.time = time
	ctx.extra[&"hurt_ago"] = hurt_ago
	return ctx

func test_it_is_a_reflex():
	assert_true(_b.reflex)

func test_calm_and_unhurt_it_leaves_you_alone():
	assert_eq(_b.score(_ctx(Vector3(1, 0, 0))), 0.0)
	assert_eq(_b.score(_ctx(null, 1.0, 0.0)), 0.0, "it has to see you")

func test_hurt_with_you_near_it_turns_on_you():
	assert_gte(_b.score(_ctx(Vector3(4, 0, 0), 0.5, 1.0)), _b.threshold)
	assert_eq(_b.score(_ctx(Vector3(8, 0, 0), 0.5, 1.0)), 0.0, "shot from afar, it only scatters")
	assert_eq(_b.score(_ctx(Vector3(4, 0, 0), 0.5, 5.0)), 0.0, "the hurt has faded")

func test_cornered_and_afraid_it_turns_on_you():
	assert_gte(_b.score(_ctx(Vector3(1.5, 0, 0), 0.8)), _b.threshold)
	assert_eq(_b.score(_ctx(Vector3(3, 0, 0), 0.8)), 0.0)

func test_it_lunges_then_bites_at_most_every_so_often():
	var far := _ctx(Vector3(3, 0, 0), 0.8, 0.5)
	_b.start(far)
	assert_eq(_b.think(far).action, &"lunge")
	var close := _ctx(Vector3(0.5, 0, 0), 0.8, 0.5, 10.0)
	assert_eq(_b.think(close).action, &"bite")
	assert_eq(_b.think(_ctx(Vector3(0.5, 0, 0), 0.8, 0.5, 10.5)).action, &"lunge", "cooling down")
	assert_eq(_b.think(_ctx(Vector3(0.5, 0, 0), 0.8, 0.5, 11.6)).action, &"bite")

func test_it_keeps_at_it_while_you_are_near_and_gives_up_when_you_go():
	var ctx := _ctx(Vector3(3, 0, 0), 0.6, 1.0)
	_b.start(ctx)
	assert_gte(_b.score(_ctx(Vector3(5, 0, 0), 0.6)), _b.threshold, "still fighting")
	assert_true(_b.done(_ctx(Vector3(7, 0, 0), 0.6)))
	assert_eq(_b.score(_ctx(Vector3(5, 0, 0), 0.6)), 0.0, "given up")
	_b.start(ctx)
	assert_true(_b.done(_ctx(Vector3(3, 0, 0), 0.1)), "calmed down")
