extends GutTest

## A minimal telemetry source. HudRoot never learns what a Ship is -- it only
## requires that a source can answer build_telemetry().
class StubSource:
	extends Node
	var calls: int = 0
	func build_telemetry() -> VehicleTelemetry:
		calls += 1
		return VehicleTelemetry.from_state(
			Basis.IDENTITY, Vector3.ZERO,
			Vector3(0.0, 0.0, -42.0), Vector3.ZERO,
			true, false, 120.0
		)

## A source that does not honour the contract at all.
class BrokenSource:
	extends Node

class RecordingElement:
	extends HudElement
	var last_telemetry: VehicleTelemetry = null
	var render_count: int = 0
	func render(telemetry: VehicleTelemetry) -> void:
		last_telemetry = telemetry
		render_count += 1

var _hud: HudRoot
var _screen: Control
var _child: RecordingElement

func before_each():
	_hud = HudRoot.new()
	_screen = Control.new()
	_screen.name = "Screen"
	_hud.add_child(_screen)
	_hud.screen_path = NodePath("Screen")
	_child = RecordingElement.new()
	_screen.add_child(_child)
	add_child_autofree(_hud)
	# Drive distribution only from explicit refresh() calls. Left enabled,
	# _process would fire on any frame boundary between tests and make the
	# call-counting assertions below flaky.
	_hud.set_process(false)

func _source() -> StubSource:
	var s := StubSource.new()
	add_child_autofree(s)
	return s

func test_descendant_elements_are_discovered_automatically():
	_hud.set_active_vehicle(_source())
	_hud.refresh()
	assert_not_null(_child.last_telemetry, "a nested element still receives frames")
	assert_almost_eq(_child.last_telemetry.speed, 42.0, 0.001)

func test_starts_disarmed():
	assert_false(_hud.is_armed(), "nothing is being piloted at startup")

func test_arms_when_given_a_valid_source():
	_hud.set_active_vehicle(_source())
	assert_true(_hud.is_armed())

func test_a_source_without_the_contract_leaves_the_hud_dark():
	var broken := BrokenSource.new()
	add_child_autofree(broken)
	_hud.set_active_vehicle(broken)
	# HudRoot warns once via push_warning() when refused; acknowledge it so
	# GUT's default engine-error-as-failure policy doesn't flag the expected
	# warning as an unexpected error.
	assert_engine_error(1, "has no build_telemetry")
	assert_false(_hud.is_armed(), "no build_telemetry means no HUD, not a crash")
	_hud.refresh()
	assert_null(_child.last_telemetry, "and nothing is pushed")

func test_clearing_the_vehicle_pushes_null_to_elements():
	_hud.set_active_vehicle(_source())
	_hud.refresh()
	_hud.set_active_vehicle(null)
	_hud.refresh()
	assert_null(_child.last_telemetry, "elements are told the vehicle is gone")

func test_registered_external_elements_receive_frames():
	# CockpitMarker cannot be a descendant: it must live inside the ship's
	# SubViewport, which is elsewhere in the tree entirely.
	var external := RecordingElement.new()
	add_child_autofree(external)
	_hud.register_element(external)
	_hud.set_active_vehicle(_source())
	_hud.refresh()
	assert_not_null(external.last_telemetry, "external element got the frame")

func test_registering_twice_does_not_double_render():
	var external := RecordingElement.new()
	add_child_autofree(external)
	_hud.register_element(external)
	_hud.register_element(external)
	_hud.set_active_vehicle(_source())
	_hud.refresh()
	assert_eq(external.render_count, 1, "registered once, rendered once")

func test_unregistered_elements_stop_receiving_frames():
	var external := RecordingElement.new()
	add_child_autofree(external)
	_hud.register_element(external)
	_hud.unregister_element(external)
	_hud.set_active_vehicle(_source())
	_hud.refresh()
	assert_eq(external.render_count, 0, "no frames after unregistering")

func test_one_snapshot_is_built_per_frame_and_shared():
	# Two elements, one build_telemetry() call. Panels must never each pull
	# their own snapshot -- they would disagree within a single frame.
	var second := RecordingElement.new()
	_screen.add_child(second)
	var source := _source()
	_hud.set_active_vehicle(source)
	_hud.refresh()
	assert_eq(source.calls, 1, "exactly one snapshot built")
	assert_eq(_child.last_telemetry, second.last_telemetry, "and both saw the same one")

func test_elements_added_after_ready_are_still_discovered():
	# _collect() re-walks on every refresh rather than caching in _ready().
	# Caching would work for the static scene tree, but would fail silently
	# for anything added later -- an element that never renders and never errors.
	var late := RecordingElement.new()
	_screen.add_child(late)
	_hud.set_active_vehicle(_source())
	_hud.refresh()
	assert_not_null(late.last_telemetry, "an element added after _ready() still receives frames")

func test_a_freed_external_element_does_not_break_distribution():
	var external := RecordingElement.new()
	add_child(external)
	_hud.register_element(external)
	external.free()
	_hud.set_active_vehicle(_source())
	_hud.refresh()
	assert_true(_hud.is_armed(), "distribution survived a freed registrant")
