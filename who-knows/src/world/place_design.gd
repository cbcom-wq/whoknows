class_name PlaceDesign
extends RefCounted

## One named place a system design pins on a world (SystemDesign): where it is,
## which way it faces, and its layout of pieces, read from
## data/places/<id>.json. Latitude and longitude are in the universe's axes
## (SystemDesign.dir_of); the place's frame has x east, y up and z south.

## Where a place's layout file is.
const LAYOUT_DIR := "res://data/places"

## Layouts read so far, by place id; an empty Dictionary where there was none.
static var _layouts := {}

var id: StringName
var name := ""
var body_id: StringName
var lat := 0.0
var lon := 0.0
## Degrees: turns the layout clockwise, seen from above.
var heading := 0.0
## Whether the place shows a beacon inside its world's well.
var beacon := false

## A unit direction from the world's centre.
func dir() -> Vector3:
	return SystemDesign.dir_of(lat, lon)

func frame() -> Basis:
	return SystemDesign.frame_at(dir(), heading)

## The direction of the layout point `east`, `north` metres from the place, on
## a world of `world_radius`: along the great circle the frame's offset points
## down, so it stays exact however far off it is.
func local_dir(east: float, north: float, world_radius: float) -> Vector3:
	var d := dir()
	var offset := frame() * Vector3(east, 0.0, -north)
	var metres := offset.length()
	if is_zero_approx(metres):
		return d
	var angle := metres / world_radius
	return (d * cos(angle) + offset / metres * sin(angle)).normalized()

## data/places/<id>.json as a Dictionary; empty when there is none, or it is
## not one. Read once.
func layout() -> Dictionary:
	if _layouts.has(id):
		return _layouts[id]
	var out := {}
	var path := "%s/%s.json" % [LAYOUT_DIR, id]
	if FileAccess.file_exists(path):
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) == OK and json.data is Dictionary:
			out = json.data
		else:
			push_error("%s is not a JSON object" % path)
	_layouts[id] = out
	return out
