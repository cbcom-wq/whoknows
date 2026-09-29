extends GutTest

## What a hit carries, and how it is delivered (docs/superpowers/specs/
## 2026-09-29-health-and-damage-design.md §3).

class Receiver extends Node:
	var got: Hit = null
	func receive_hit(hit: Hit) -> void:
		got = hit

func test_make_still_takes_five_arguments_and_does_no_damage():
	var hit := Hit.make(Vector3.ONE, Vector3.UP, Vector3.FORWARD, Vector3.BACK, null)
	assert_eq(hit.position, Vector3.ONE)
	assert_eq(hit.damage, 0.0)
	assert_eq(hit.kind, &"")
	assert_eq(hit.shape, -1)

func test_deliver_calls_receive_hit():
	var node: Receiver = autofree(Receiver.new())
	var hit := Hit.make(Vector3.ZERO, Vector3.UP, Vector3.FORWARD, Vector3.ZERO, null)
	Hit.deliver(node, hit)
	assert_same(node.got, hit)

func test_deliver_calls_the_meta_callable_on_a_scriptless_body():
	var body: StaticBody3D = autofree(StaticBody3D.new())
	var got := []
	body.set_meta(&"receive_hit", func(h: Hit) -> void: got.append(h))
	var hit := Hit.make(Vector3.ZERO, Vector3.UP, Vector3.FORWARD, Vector3.ZERO, null)
	Hit.deliver(body, hit)
	assert_eq(got.size(), 1)
	assert_same(got[0], hit)

func test_deliver_ignores_a_body_that_cannot_be_hit():
	var body: StaticBody3D = autofree(StaticBody3D.new())
	Hit.deliver(body, Hit.make(Vector3.ZERO, Vector3.UP, Vector3.FORWARD, Vector3.ZERO, null))
	Hit.deliver(null, Hit.make(Vector3.ZERO, Vector3.UP, Vector3.FORWARD, Vector3.ZERO, null))
	assert_true(true, "no error")
