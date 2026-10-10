class_name GridHome
extends Node3D

## What a ship and a base share (docs/superpowers/specs/
## 2026-09-26-habitat-modules-design.md §9.1, §5.5): a ShipGrid built into an
## exterior body and a walkable interior in a slot of its own, the items in
## it, its airlocks and quantum plant, and being the place you are in. Ship
## adds flight; Base stands still. Both have the same four nodes: Exterior (a
## RigidBody3D) with ExteriorBuilder under it, and Interior with
## InteriorBuilder under it.

## Someone crossed one of its airlocks' outer hatches (airlock spec §7):
## `outward` true out onto a spacewalk, false in (many ships spec §4.3).
signal airlock_crossed(avatar: Avatar, outward: bool)

const INTERIOR_WORLD_BASE := Vector3(0.0, -5000.0, 0.0)
const SLOT_SPACING := 2000.0
## How close a rebuilt stow point must be to where a stowed item's point was
## for the item to stay stowed through the rebuild.
const RESEAT_TOLERANCE := 0.05
## Where you wake after blacking out, if it has one.
const WAKE_ROOM := &"bunk_room"
## The livery every builder paints the hull with: one shared instance. Each
## home swaps it for its own copy, `livery` (_apply_livery).
const HULL_LIVERY_MATERIAL: ShaderMaterial = preload("res://data/materials/hull_livery.tres")
## The window glass's shader; each home makes its own material from it.
const CANOPY_SHADER: Shader = preload("res://data/materials/interior/canopy_window.gdshader")
## Marks a hull piece made for the own layer alone, so set_own can move it
## back.
const OWN_ONLY := &"own_only"

@export var interior_slot: int = 0
## Where a spacewalker goes (airlock spec §7.4): the scene's root for things in
## the real world.
@export var outside_path: NodePath

var grid: ShipGrid
var outside: Node3D
var catalog: BlockCatalog
var item_catalog: ItemCatalog
## Every item in it that is not in someone's hand (hands-and-items spec §4.4).
## A sibling of the builders, so an interior rebuild never touches it.
var items: Node3D
## Every airlock that can cycle, by cell (airlock spec §4.5). Each outlives the
## rebuilds that replace the room it drives.
var airlocks: Dictionary = {}   # Vector3i -> Airlock
## The quantum store and the cores and machines it drives (quantum energy
## spec §3.2).
var quantum: QuantumPlant
## True for the place you are in (many ships spec §4.2): its hull's own pieces
## are drawn on ExteriorBuilder.OWN_HULL_LAYER, which your windows leave out,
## and its interior shows. Anything else hides its interior.
var own := true
## This home's own copy of the hull livery (_apply_livery).
var livery: ShaderMaterial = HULL_LIVERY_MATERIAL.duplicate()

var _stocked := false
var _airlocks_root: Node

@onready var exterior: RigidBody3D = $Exterior
@onready var interior: Node3D = $Interior
@onready var exterior_builder: ExteriorBuilder = $Exterior/ExteriorBuilder
@onready var interior_builder: InteriorBuilder = $Interior/InteriorBuilder

func _process(_delta: float) -> void:
	# hull_livery.gdshader paints its stripe from ship-local height, but the
	# skin's merged plating meshes (HullDressing: the Hull and Windows kits'
	# HULL batches, built in hull space) are drawn with a MODEL_MATRIX that is
	# model-to-*world* -- it carries the hull RigidBody3D's own rotation.
	# Pushing the hull's inverse transform every frame lets the shader cancel
	# that rotation (`hull_inverse * MODEL_MATRIX`) before testing height, so
	# the stripe stays fixed on the hull under roll and pitch instead of
	# swimming across it. See hull_livery.gdshader's header comment for the
	# full derivation. Each home pushes its own hull's into its own copy: one
	# shared material would hold only the last one's (many ships, §12).
	livery.set_shader_parameter(&"hull_inverse", exterior.global_transform.affine_inverse())

## Puts the interior in its slot, finds outside, loads the catalogues and makes
## the Items and Airlocks holders. Call first in _ready.
func _setup_home() -> void:
	_make_canopy_material()
	interior.global_position = interior_slot_origin()
	outside = get_node_or_null(outside_path) as Node3D if not outside_path.is_empty() else null
	if outside == null:
		outside = get_parent() as Node3D
	if catalog == null:
		catalog = BlockCatalog.load_from_dir("res://data/blocks")
	if item_catalog == null:
		item_catalog = ItemCatalog.load_from_dir("res://data/items")
	items = Node3D.new()
	items.name = "Items"
	interior.add_child(items)
	_airlocks_root = Node.new()
	_airlocks_root.name = "Airlocks"
	add_child(_airlocks_root)

## True while it is spooling or travelling at warp: no airlock works then.
## Only a ship can.
func is_warping() -> bool:
	return false

## Why a save must wait on it (saving spec §5), or "": an airlock cycling, the
## quantum machine busy, or a bolt in flight.
func home_busy() -> String:
	for airlock: Airlock in airlocks.values():
		var why := airlock.busy()
		if why != "":
			return why
	var why := quantum.busy() if quantum != null else ""
	if why != "":
		return why
	if items != null:
		for node in items.get_children():
			if node is PlasmaBolt:
				return "bolt in flight"
	return ""

## Every item in it that is not in someone's hand, as saved data in the
## interior's frame (saving spec §6.4).
func items_to_dict() -> Array:
	var out := []
	var frame := interior.global_transform
	for node in items.get_children():
		var item := node as Item
		if item != null and item.state != Item.State.HELD and not item.is_queued_for_deletion():
			out.append(item.to_dict(frame))
	return out

## Every window's glass shows this ship's own canopy view (cockpit pod spec
## §3): one material per ship, fed by its own SubViewport, so each instance of
## ship.tscn draws its own (many ships spec §3.1). Made here rather than in the
## .tscn: a ViewportTexture's path inside an instanced scene is fragile.
func _make_canopy_material() -> void:
	var canopy := get_node_or_null("Canopy") as SubViewport
	if canopy == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = CANOPY_SHADER
	mat.set_shader_parameter(&"canopy_view", canopy.get_texture())
	interior_builder.canopy_material = mat

## Every hull piece painted with the shared livery gets this ship's own copy:
## the stripe is measured through `hull_inverse`, which is this hull's alone.
## After every rebuild, as the builders always paint with the shared one.
func _apply_livery() -> void:
	for node in exterior.find_children("*", "GeometryInstance3D", true, false):
		var g := node as GeometryInstance3D
		if g.material_override == HULL_LIVERY_MATERIAL:
			g.material_override = livery

func interior_slot_origin() -> Vector3:
	# Interior space sits well clear of the combat arena so the walkable
	# interior can never intersect a flying hull. Collision layers enforce
	# the same separation independently.
	return INTERIOR_WORLD_BASE + Vector3(interior_slot * SLOT_SPACING, 0.0, 0.0)

func set_own(on: bool) -> void:
	own = on
	_apply_own()

## Every piece the builders made for the own layer alone goes on the layer
## `own` says; pieces on both layers stay on both. After every rebuild too: the
## builders always make the own layer.
func _apply_own() -> void:
	interior.visible = own
	for node in exterior.find_children("*", "GeometryInstance3D", true, false):
		var g := node as GeometryInstance3D
		if g.layers == ExteriorBuilder.OWN_HULL_LAYER:
			g.set_meta(OWN_ONLY, true)
		if g.has_meta(OWN_ONLY):
			g.layers = ExteriorBuilder.OWN_HULL_LAYER if own else 1

## Where you wake after blacking out (health and damage spec §7.2), best
## first, in the world: the bunk room's cells, then the rest by how near they
## are to it (or to the core, with no bunk room); never the airlock. The
## caller takes the first you fit: a bunk room is mostly bunks, so that is
## often the cell at its door.
func wake_spots() -> Array[Transform3D]:
	var layout := interior_builder.layout()
	var core := Vector3.ZERO
	for coord: Vector3i in grid.coords():
		if grid.get_block(coord).block_id == BlockDamage.CORE:
			core = Vector3(coord)
	var bunks: Array[Vector3i] = []
	var rest: Array[Vector3i] = []
	for cell: Vector3i in interior_builder.walkable_coords():
		var zone := layout.zone_at(cell) if layout != null else &""
		if zone == InteriorLayout.AIRLOCK_ZONE:
			continue
		if zone == WAKE_ROOM:
			bunks.append(cell)
		else:
			rest.append(cell)
	var near := Vector3(bunks[0]) if not bunks.is_empty() else core
	rest.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return Vector3(a).distance_to(near) < Vector3(b).distance_to(near))
	var out: Array[Transform3D] = []
	for cell in bunks + rest:
		out.append(interior.global_transform * Transform3D(Basis.IDENTITY, DeckPaths.floor_point(cell)))
	return out

## Hands each rebuilt airlock room to its Airlock, making one for a new
## airlock and dropping those whose cell is gone. An Airlock keeps its cycle,
## so a rebuild never resets a pressure or moves a hatch.
func _bind_airlocks() -> void:
	if _airlocks_root == null:
		return
	var seen := {}
	for room in interior_builder.airlock_rooms():
		seen[room.coord] = true
		var airlock: Airlock = airlocks.get(room.coord)
		if airlock == null:
			airlock = Airlock.new()
			airlock.setup(self, room.coord)
			_airlocks_root.add_child(airlock)
			airlock.crossed.connect(airlock_crossed.emit)
			airlocks[room.coord] = airlock
		airlock.bind(room, exterior_builder.alcoves().get(room.coord))
	for at in airlocks.keys():
		if not seen.has(at):
			var gone: Airlock = airlocks[at]
			airlocks.erase(at)
			_airlocks_root.remove_child(gone)
			gone.free()

## Every stowed item and where its stow point was, before a rebuild frees the
## points.
func _stowed_items() -> Array:
	var out := []
	if items == null:
		return out
	for node in items.get_children():
		var item := node as Item
		if item != null and item.state == Item.State.STOWED and is_instance_valid(item.stow_point):
			out.append([item, item.stow_point.global_position])
	return out

## Puts each stowed item back in the rebuilt point at the same place, or lets
## it loose where it is if that point is gone.
func _reseat(stowed: Array) -> void:
	var points := interior_builder.stow_points()
	for entry in stowed:
		var item: Item = entry[0]
		var was: Vector3 = entry[1]
		var home: StowPoint = null
		for point in points:
			if point.fits(item) and point.global_position.distance_to(was) < RESEAT_TOLERANCE:
				home = point
				break
		if home != null:
			home.secure(item)
		else:
			item.set_loose()

## Fills every stocked stow point, once, when the home first loads
## (hands-and-items spec §5.3).
func _stock() -> void:
	if items == null:
		return
	for point in interior_builder.stow_points():
		if point.stock == &"" or not point.is_free():
			continue
		var def := item_catalog.get_def(point.stock)
		if def == null:
			push_warning("GridHome: no item called %s to stock" % point.stock)
			continue
		var item := Item.new()
		var at := point.global_position
		item.setup(def, fposmod(at.x * 0.37 + at.z * 0.61, 1.0))
		items.add_child(item, true)
		point.secure(item)

## One saved item back aboard: in the stow point it was in (the rebuild's
## own RESEAT_TOLERANCE rule), or loose where it was -- on the floor under
## its point if that point has gone (§6.4). Null if its kind has gone.
func restore_item(d: Dictionary) -> Item:
	var item := Item.from_dict(d, item_catalog)
	if item == null:
		return null
	items.add_child(item, true)
	var frame := interior.global_transform
	var place := frame * SaveCodec.to_transform(d.get("place"))
	if String(d.get("state", "")) == "stowed":
		var was := frame * SaveCodec.to_vec3(d.get("point"), place.origin)
		for point in interior_builder.stow_points():
			if point.fits(item) and point.global_position.distance_to(was) < RESEAT_TOLERANCE:
				point.secure(item)
				return item
		place = Transform3D(place.basis, Vector3(was.x, was.y + item.definition.size.y * 0.5, was.z))
	item.set_loose()
	item.global_transform = place
	item.linear_velocity = frame.basis * SaveCodec.to_vec3(d.get("v"))
	item.angular_velocity = frame.basis * SaveCodec.to_vec3(d.get("w"))
	return item
