class_name HudRoot
extends CanvasLayer

## The piloting HUD's one global node.
##
## Holds whichever vehicle is currently being piloted, pulls a single
## telemetry snapshot per frame, and hands it to every element. It knows
## nothing about ships, seats or cameras: the scene's bootstrap decides when
## a vehicle becomes active and tells it. That ignorance is deliberate -- it
## is what lets a future vehicle of any kind light this same HUD.

## Expected to match the seat transition's duration, so the band arrives
## exactly as the camera settles into the seat rather than popping in ahead
## of it or lagging behind. This layer deliberately knows nothing about
## seats or who moves the view, so it cannot read that duration itself --
## whoever wires the HUD to a vehicle owns both halves and is expected to
## inject it here.
var fade_in: float = 0.75
## Leaving is quicker than arriving: the instruments go with the chair.
const FADE_OUT := 0.2

## The full-rect Control wrapping everything. CanvasLayer has no modulate of
## its own, so this is the fade target.
@export var screen_path: NodePath

var _source: Node = null
var _descendants: Array[HudElement] = []
var _registered: Array[HudElement] = []
var _tween: Tween = null

@onready var _screen: Control = get_node(screen_path)

func _ready() -> void:
	_screen.modulate.a = 0.0

## Walks the whole subtree fresh each call. Elements may be nested inside
## layout containers, so a direct-children scan would miss them. Re-walking
## on every refresh rather than caching once in _ready() is deliberate: the
## production tree is static, so caching would work here, but caching fails
## silently the moment it stops working -- an element that never renders and
## never errors. Walking a handful of nodes at 60fps is free at this scale,
## and buys the removal of that whole failure class.
func _collect(node: Node) -> void:
	for child in node.get_children():
		if child is HudElement:
			_descendants.append(child)
		_collect(child)

## Hands control of the HUD to `source`, or clears it when given null.
##
## The contract is duck-typed rather than a base class so that no vehicle has
## to inherit from anything to be pilotable. A source that cannot answer it is
## refused here, once, rather than erroring every frame downstream.
func set_active_vehicle(source: Node) -> void:
	if source != null and not source.has_method("build_telemetry"):
		push_warning(
			"HudRoot: %s has no build_telemetry(); HUD staying dark" % source
		)
		source = null
	_source = source
	_fade_to(1.0 if _source != null else 0.0)

func is_armed() -> bool:
	return _source != null

## Registers an element that cannot be a descendant. The canopy marker lives
## inside the ship's SubViewport, which is nowhere near this node.
func register_element(element: HudElement) -> void:
	if not _registered.has(element):
		_registered.append(element)

func unregister_element(element: HudElement) -> void:
	_registered.erase(element)

func _process(_delta: float) -> void:
	refresh()

## Builds one snapshot and gives every element the same instance. Elements
## must never pull their own -- two snapshots in one frame can disagree.
func refresh() -> void:
	_descendants.clear()
	_collect(self)

	var telemetry: VehicleTelemetry = null
	if is_instance_valid(_source):
		telemetry = _source.build_telemetry()

	for element in _descendants:
		if is_instance_valid(element):
			element.render(telemetry)
	# Purge freed registrants as we go, rather than re-testing a dead slot
	# forever: is_instance_valid() alone would skip it every frame but never
	# remove it.
	for i in range(_registered.size() - 1, -1, -1):
		var element: HudElement = _registered[i]
		if is_instance_valid(element):
			element.render(telemetry)
		else:
			_registered.remove_at(i)

func _fade_to(alpha: float) -> void:
	if _tween != null:
		_tween.kill()
	var duration := fade_in if alpha > 0.0 else FADE_OUT
	_tween = create_tween()
	_tween.tween_property(_screen, "modulate:a", alpha, duration)
