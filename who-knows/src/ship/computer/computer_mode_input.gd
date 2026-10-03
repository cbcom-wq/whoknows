class_name ComputerModeInput
extends Node

## The mouse and keys while you are at a computer station
## (docs/superpowers/specs/2026-09-30-computer-mode-design.md §3.3): a click
## picks a mark in the holo, a drag orbits it, the wheel zooms, R recentres,
## Tab turns the page and Enter does what the big button would. A click on
## the overlay never reaches here, because its controls take it first.
## Leaving (F or Esc) is the director's, as standing up is.

## How far the mouse moves, pixels, before a press becomes a drag.
const DRAG_START := 4.0
## A horizontal drag spins the holo; a vertical one raises or lowers the eye.
const SPIN_PER_PIXEL := deg_to_rad(0.4)
const ELEVATION_PER_PIXEL := 0.3

var director: CameraDirector

var _pressed := false
var _press_at := Vector2.ZERO
var _dragging := false

func _unhandled_input(event: InputEvent) -> void:
	var station := director.station() if director != null else null
	if station == null or director.is_moving():
		_pressed = false
		_dragging = false
		return
	if event is InputEventMouseButton:
		_mouse_button(event, station)
	elif event is InputEventMouseMotion:
		_mouse_motion(event, station)
	elif event is InputEventKey and event.pressed and not event.echo:
		if not _key(event, station):
			return
	else:
		return
	if is_inside_tree():
		get_viewport().set_input_as_handled()

func _mouse_button(event: InputEventMouseButton, station: ComputerStation) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressed = true
				_press_at = event.position
				_dragging = false
			else:
				if _pressed and not _dragging:
					station.computer.pick(event.position, director.camera())
				_pressed = false
				_dragging = false
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				station.computer.zoom(-1.0)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				station.computer.zoom(1.0)

func _mouse_motion(event: InputEventMouseMotion, station: ComputerStation) -> void:
	# A release the overlay swallowed, or a window that lost focus, leaves
	# _pressed set; motion with the button up means it was let go.
	if _pressed and not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_pressed = false
		_dragging = false
	if not _pressed:
		station.computer.hover(event.position, director.camera())
		return
	if not _dragging and event.position.distance_to(_press_at) > DRAG_START:
		_dragging = true
	if _dragging:
		station.computer.spin -= event.relative.x * SPIN_PER_PIXEL
		station.orbit(event.relative.y * ELEVATION_PER_PIXEL)

## True when the key was the mode's.
func _key(event: InputEventKey, station: ComputerStation) -> bool:
	match event.physical_keycode:
		KEY_R:
			station.recentre()
		KEY_TAB:
			station.computer.next_tab()
		KEY_ENTER, KEY_KP_ENTER:
			station.computer.act()
		_:
			return false
	return true
