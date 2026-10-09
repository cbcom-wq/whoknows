class_name BaseExterior
extends Node3D

## A base's outside beyond its hull (habitat modules spec §8.1, §5.3): each
## module's four chunky legs down to the rock, and, while a module unfolds, its
## case flying in, its legs punching down and its body growing out of the
## case, all by transform. In the base's frame, under its Exterior. Built from
## the site's leg lengths, never from the rock, so a waking base needs no
## ground to stand. Colours from HullPalette; no shader.

const LEG_RADIUS := 0.09
const PAD_RADIUS := 0.28
const CASE_SIZE := Vector3(0.5, 0.35, 0.5)
const LAYER := 1

var _legs: Array[MeshInstance3D] = []
var _show: Node3D
var _leg_count := 0

## Every module's legs, from the site.
func build(site: BaseSite) -> void:
	for leg in _legs:
		leg.queue_free()
	_legs.clear()
	var kit := InteriorKit.new(self)
	kit.layer = LAYER
	var count := 0
	for i in site.modules.size():
		count += _add_legs(kit, site, i, 1.0)
	if count > 0:
		_legs.assign(kit.commit())
	_leg_count = count

func leg_count() -> int:
	return _leg_count

## Module `index` at `t` of its unfolding (0..1): the case flies in and
## settles, the legs punch down, the body grows from the case. At 1 the show
## is gone and the hull the rebuild made stands in its place.
func unfold(index: int, t: float, site: BaseSite) -> void:
	if _show != null:
		_show.queue_free()
		_show = null
	if t >= 1.0:
		return
	_show = Node3D.new()
	_show.name = "Unfolding"
	add_child(_show)
	var u := HabitatValues
	var at := t * u.UNFOLD
	var centre := site.centre_of(index)
	var full := Vector3(ModuleCatalog.get_def(site.modules[index]["kind"]).turned_size(site.modules[index]["turns"])) \
		* ShipGrid.CELL_SIZE
	var kit := InteriorKit.new(_show)
	kit.layer = LAYER
	var fly := clampf(at / (u.FLY + u.SETTLE), 0.0, 1.0)
	var grow := clampf((at - u.FLY - u.SETTLE - u.LEGS) / u.WALLS, 0.0, 1.0)
	var size := CASE_SIZE.lerp(full, grow * grow * (3.0 - 2.0 * grow))
	var drop := Vector3.UP * (1.0 - fly) * 6.0
	kit.bevel_box(InteriorKit.Batch.SOLID, InteriorKit.at(centre + drop - Vector3.UP * (full.y - size.y) * 0.5),
		size, minf(0.1, size.x * 0.1), InteriorKit.solid(HullPalette.TRIM))
	var legs := clampf((at - u.FLY - u.SETTLE) / u.LEGS, 0.0, 1.0)
	if legs > 0.0:
		_add_legs(kit, site, index, legs)
	kit.commit()

## The four legs of module `index`, `reach` of the way down. Returns how many.
func _add_legs(kit: InteriorKit, site: BaseSite, index: int, reach: float) -> int:
	var m: Dictionary = site.modules[index]
	var legs: PackedFloat32Array = m["legs"]
	var size := ModuleCatalog.get_def(m["kind"]).turned_size(m["turns"])
	var at := ShipGrid.cell_center(m["cell"])
	var tops := Planting.corners(size)
	var made := 0
	for k in mini(legs.size(), tops.size()):
		var top: Vector3 = at + tops[k]
		var foot := top - Vector3.UP * legs[k] * reach
		kit.tube_between(InteriorKit.Batch.SOLID, top, foot, LEG_RADIUS, InteriorKit.solid(HullPalette.TRIM))
		kit.disc(InteriorKit.Batch.SOLID, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), foot + Vector3.UP * 0.02),
			PAD_RADIUS, InteriorKit.solid(HullPalette.PANEL_LINE))
		made += 1
	return made
