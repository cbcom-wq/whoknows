extends GutTest

## *+12 QE · ICE CHUNK*, rising and fading over 1.2 s (quantum energy spec §12).

var _toast: QuantumToast

func before_each():
	_toast = QuantumToast.new()
	add_child_autofree(_toast)

func test_it_starts_hidden():
	assert_false(_toast.visible)

func test_saying_shows_the_text():
	_toast.say("+12 QE · ICE CHUNK")
	assert_true(_toast.visible)
	assert_eq(_toast.text(), "+12 QE · ICE CHUNK")

func test_it_is_gone_after_1_2_seconds():
	_toast.say("+12 QE · ICE CHUNK")
	_toast.advance(QuantumToast.LIFE + 0.01)
	assert_false(_toast.visible)

func test_it_fades_as_it_goes():
	_toast.say("x")
	_toast.advance(QuantumToast.LIFE * 0.5)
	assert_almost_eq(_toast.modulate.a, 0.5, 0.01)

func test_a_new_toast_replaces_the_old():
	_toast.say("a")
	_toast.advance(0.8)
	_toast.say("b")
	assert_eq(_toast.text(), "b")
	assert_almost_eq(_toast.modulate.a, 1.0, 0.01)

func test_it_never_eats_a_click():
	assert_eq(_toast.mouse_filter, Control.MOUSE_FILTER_IGNORE)

## The middle of the view, not its corner: a zero-size control moved by
## set_anchors_preset alone sits at (0, 0) (reticle.gd's trap). The label's
## centre lies on the middle's x, and its top DROP below the middle's y.
func test_it_sits_under_the_middle_of_the_view():
	_toast.say("+12 QE · ICE CHUNK")
	var middle := get_viewport().get_visible_rect().size * 0.5
	assert_lt(_toast.global_position.distance_to(middle), 2.0, "the toast is at the middle")
	var label := _toast.get_child(0) as Label
	assert_lt(absf(label.global_position.x + label.size.x * 0.5 - middle.x), 2.0, "the label is centred")
	assert_lt(absf(label.global_position.y - (middle.y + QuantumToast.DROP)), 2.0, "and DROP under it")
