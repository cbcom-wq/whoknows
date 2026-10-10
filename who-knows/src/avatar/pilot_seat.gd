class_name PilotSeat
extends Seat

## The flight station. Sitting here hands ship control to the pilot and
## moves the camera into the cockpit without a cut. The ship's one seat that
## flies (ship bridge spec §3.4), at a pilot seat's pod or a bridge's helm.

func _init() -> void:
	flies = true

func prompt_text() -> String:
	return "Take the controls"
