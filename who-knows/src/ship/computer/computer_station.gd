class_name ComputerStation
extends Area3D

## Where you use a bridge computer from, and the view you get
## (docs/superpowers/specs/2026-09-30-computer-mode-design.md §3): an
## interactable over the table's top and rim -- "Use computer" -- and the eye
## the camera glides to, orbiting the holo's centre while you are there. The
## buttons stand proud of its box, so looking straight at one still offers
## that button.
##
## Knows nothing about ships. Its ShipComputer builds it at the table's
## fixture frame. Tables are rebuilt and ships come and go, so it finds the
## game's one CameraDirector by group, never by path.

const PROMPT := "Use computer"
## The orbit's bounds, degrees above the holo's level (spec §4.4).
const ELEVATION_MIN := 10.0
const ELEVATION_MAX := 75.0

var computer: ShipComputer
var elevation := InteriorProps.HOLO_STATION_ELEVATION

## Builds the box on physics layer bits `layer_bits`. Call once, before it
## enters the tree.
func setup(owner_computer: ShipComputer, layer_bits: int) -> void:
	computer = owner_computer
	name = "Station"
	collision_layer = layer_bits
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("interactable")
	var shape := BoxShape3D.new()
	shape.size = InteriorProps.HOLO_STATION_SIZE
	var hit := CollisionShape3D.new()
	hit.shape = shape
	hit.position = InteriorProps.holo_station_shape_centre()
	add_child(hit)

func prompt_text() -> String:
	return PROMPT

func can_interact(_actor: Node) -> bool:
	return director() != null

func interact(_actor: Node) -> void:
	var d := director()
	if d != null:
		d.use_station(self)

func director() -> CameraDirector:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(CameraDirector.GROUP) as CameraDirector

## Where the camera is while you use the computer, in the world.
func eye_transform() -> Transform3D:
	return global_transform * InteriorProps.holo_station_eye(elevation)

## Raises or lowers the eye round the holo (a vertical drag), within its bounds.
func orbit(d_elevation: float) -> void:
	elevation = clampf(elevation + d_elevation, ELEVATION_MIN, ELEVATION_MAX)

## R: the eye where it started, and the holo turned with the ship again.
func recentre() -> void:
	elevation = InteriorProps.HOLO_STATION_ELEVATION
	computer.spin = 0.0

## Called as you leave: walking past, the holo answers "which way?" again.
func left() -> void:
	recentre()
