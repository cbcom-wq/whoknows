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
