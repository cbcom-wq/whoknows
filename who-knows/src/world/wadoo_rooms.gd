class_name WadooRooms
extends RefCounted

## The Wadees' rooms inside their brick shells (docs/superpowers/specs/
## 2026-11-16-wadoo-design.md §8, §10): a room model made in Blender
## (tools/blender/wadoo_rooms.py, assets/wadoo/<room>.glb) set in a shell's frame
## (its floor's middle, y up, the door toward -z), painted from WadeePalette.ROOM
## by its materials' names, lit by its sunglass lamps, solid where its empties
## say. The hall's door (WadooDoor) hangs in the shell's doorway.
##
## The model's empties: lamp_<n> a lamp's light; col_<name> a solid box (its
## scale the half size) walked round; floor_<name> one you step up on (the dais
## and its step: solid to you, walked by the Wadees, RAISED for their feet); seat,
## sit and stand: the throne's seat, where the queen stands to sit on it, and
## where she stands to receive you.

const SCENES := {&"hall": "res://assets/wadoo/hall.glb"}
const ROOT_NAME := "Room_%s"
## A lamp's light: warm, near, no shadow (the shell's walls hold the daylight).
## Four of them lit the hall's pale walls as bright as the street at 1.6; the
## inside is meant warm and dim (docs/design/visual-style.md).
const LAMP_ENERGY := 0.8
const LAMP_RANGE := 5.5
const LAMP_ATTENUATION := 1.4
## Roughness by material; bronze is metal; sunglass glows.
const ROUGH := {"bronze": 0.35, "water": 0.12, "sunglass": 0.3, "turquoise": 0.4, "stone": 0.8, "wood": 0.75}
const ROUGH_CLOTH := 0.95
const METAL_BRONZE := 0.8
## The floor raised in a room, in its frame: [x half width, z from, z to, height]
## (the hall's dais and its step; wadoo_rooms.py DAIS and STEP).
const RAISED := {&"hall": [[2.2, 1.25, 2.55, 0.3], [1.2, 1.0, 1.25, 0.15]]}

static var _materials := {}
static var _marks := {}

## Builds `room` under `parent` at the shell frame `f` (parent-local): the model,
## its lamps and its solid boxes (BodyProxy.LAYER). The room's root node.
static func build(room: StringName, parent: Node3D, f: Transform3D) -> Node3D:
	var scene := load(SCENES[room]) as PackedScene
	var node := scene.instantiate() as Node3D
	node.name = ROOT_NAME % room
	parent.add_child(node)
	node.transform = f
	var body := StaticBody3D.new()
	body.name = "Solid"
	body.collision_layer = BodyProxy.LAYER
	body.collision_mask = 0
	node.add_child(body)
	for child: Node in node.find_children("*", "Node3D", true, false):
		var n := child as Node3D
		if n.name.begins_with("col_") or n.name.begins_with("floor_"):
			var c := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = n.transform.basis.get_scale() * 2.0
			c.shape = box
			c.transform = Transform3D(Basis.IDENTITY, n.transform.origin)
			body.add_child(c)
		elif n.name.begins_with("lamp_"):
			var light := OmniLight3D.new()
			light.name = "Light_%s" % n.name
			light.light_color = WadeePalette.LAMP
			light.light_energy = LAMP_ENERGY
			light.omni_range = LAMP_RANGE
			light.omni_attenuation = LAMP_ATTENUATION
			light.shadow_enabled = false
			light.transform = Transform3D(Basis.IDENTITY, n.transform.origin)
			node.add_child(light)
	paint(node)
	return node

## Gives every surface of `node`'s meshes its WadeePalette.ROOM colour by name.
static func paint(node: Node) -> void:
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		mi.layers = OasisLooks.WORLD_LAYER
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			var key := m.resource_name if m != null else ""
			mi.set_surface_override_material(s, material(key))

## The material called `key` (a WadeePalette.ROOM name), made once.
static func material(key: String) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.albedo_color = WadeePalette.ROOM.get(key, WadeePalette.ROOM["stone"])
	m.roughness = float(ROUGH.get(key, ROUGH_CLOTH))
	if key == "bronze":
		m.metallic = METAL_BRONZE
	if key == "sunglass":
		m.emission_enabled = true
		m.emission = WadeePalette.ROOM["sunglass"]
		m.emission_energy_multiplier = InteriorMaterials.GLOW_ENERGY
	_materials[key] = m
	return m

## Where the room's empty `mark` (seat, stand) is, in its frame; null if none.
static func mark(room: StringName, name: String) -> Variant:
	if not _marks.has(room):
		var found := {}
		var node := (load(SCENES[room]) as PackedScene).instantiate() as Node3D
		for child: Node in node.find_children("*", "Node3D", true, false):
			found[String(child.name)] = (child as Node3D).transform
		node.free()
		_marks[room] = found
	var t: Variant = _marks[room].get(name)
	return Transform3D(Basis.IDENTITY, (t as Transform3D).origin) if t != null else null

## How far the floor of `room` is raised at `local` (x, z in its frame): the
## dais, its step, or 0.
static func raised(room: StringName, local: Vector2) -> float:
	var h := 0.0
	for r: Array in RAISED.get(room, []):
		if absf(local.x) <= float(r[0]) and local.y >= float(r[1]) and local.y <= float(r[2]):
			h = maxf(h, float(r[3]))
	return h

## The solid boxes of `room`, for those who walk it: [middle (x, z), half size
## (x, z)] in its frame.
static func solids(room: StringName) -> Array:
	var out := []
	mark(room, "")
	for key: String in _marks[room]:
		if key.begins_with("col_"):
			var t: Transform3D = _marks[room][key]
			var half := t.basis.get_scale()
			out.append([Vector2(t.origin.x, t.origin.z), Vector2(half.x, half.z)])
	return out
