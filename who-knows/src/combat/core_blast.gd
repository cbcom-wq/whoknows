class_name CoreBlast
extends Node3D

## A destroyed ship's core going up (docs/superpowers/specs/
## 2026-10-24-hostile-ships-design.md §8.2): a big warm flash and light at the
## core, the brightest thing in the scene for a moment, a deep boom, and a
## blast that hurts what is near -- hulls at their nearest cell, NPCs, loose
## items, and you on a spacewalk -- falling off to nothing at RADIUS × its
## scale. Never its own ship.
##
## The floating origin (CLAUDE.md): it is in Universe.EXTERIOR_SPACE, its flash
## and its light under it, so a shift carries them. Gone after LIFE.

## The blast: PEAK hp at the centre, falling linearly to 0 at RADIUS × scale
## (spec §8.2, call H). A ship's scale is its mass against MASS_T, within
## SCALE: the starter's is about 1.
const RADIUS := 120.0
const PEAK := 400.0
const MASS_T := 105.0
const SCALE := Vector2(0.5, 2.0)
## The flash: grows to FLASH_SIZE × scale m across in the first FLASH_GROW of
## its FLASH_LIFE, fading all the while, and gone at the end of it. Its light
## reaches LIGHT_RANGE × scale.
const FLASH_SIZE := 20.0
const FLASH_LIFE := 1.2
const FLASH_GROW := 0.1
## How far past white its colours burn, so the outside's glow halos it and it
## reads from far off; and the white-hot middle, against the flash.
const FLASH_HOT := 3.0
const CORE_HOT := 5.0
const CORE_SHARE := 0.55
const LIGHT_RANGE := 300.0
const LIGHT_ENERGY := 16.0
## The boom: heard outside to BOOM_REACH m through the suit's bus, and as a
## thump through the hull of a ship you are aboard within THUMP_REACH m,
## quieter to THUMP_QUIETEST dB at the edge.
const BOOM_REACH := 2000.0
const BOOM_UNIT := 80.0
const THUMP_REACH := 500.0
const THUMP_QUIETEST := -18.0
## Long enough for the boom to finish.
const LIFE := 3.0
## N·s of shove per hp the blast deals, outward.
const PUSH := 0.5
## What the blast looks for: other hulls (and bases), loose items, NPCs. You
## are found by distance, out in your suit.
const MASK := 1 | Item.LAYER | Npc.LAYER
const MOST := 1024

static var _sphere: Mesh

var blast_scale := 1.0
var flash: Node3D
var light: OmniLight3D
var _shells: Array[StandardMaterial3D] = []
var _age := 0.0

## PEAK at the centre, falling linearly to 0 at RADIUS × `scale`. Pure.
static func damage_at(distance: float, scale: float) -> float:
	return PEAK * maxf(1.0 - distance / (RADIUS * scale), 0.0)

## A ship of `mass_t` tonnes' blast scale.
static func scale_for(mass_t: float) -> float:
	return clampf(mass_t / MASS_T, SCALE.x, SCALE.y)

static func scale_of(ship: Ship) -> float:
	return scale_for(ship.stats.total_mass_kg / 1000.0 if ship.stats != null else MASS_T)

## Where `ship`'s core is, world: the middle of its quantum core's blocks, or
## the hull's own place if it has none.
static func core_of(ship: Ship) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for coord: Vector3i in ship.grid.coords():
		if ship.grid.get_block(coord).block_id == &"quantum_core":
			sum += ShipGrid.cell_center(coord)
			n += 1
	return ship.exterior.to_global(sum / n) if n > 0 else ship.exterior.global_position

## The core goes up at `at` under `outside`: the flash, the boom, then the
## blast, which spares `source` (the exploding ship, or whatever set it off).
static func go(outside: Node3D, at: Vector3, scale: float, source: Node) -> void:
	var blast := CoreBlast.new()
	blast.name = "CoreBlast"
	blast.blast_scale = scale
	outside.add_child(blast, true)
	blast.global_position = at
	blast._boom()
	blast._reach(source)

func _ready() -> void:
	add_to_group(Universe.EXTERIOR_SPACE)
	flash = Node3D.new()
	flash.name = "Flash"
	flash.scale = Vector3.ONE * 0.01
	add_child(flash)
	_shell(SpacePalette.PHASER, FLASH_HOT, 1.0)
	_shell(SpacePalette.WARP, CORE_HOT, CORE_SHARE)
	light = OmniLight3D.new()
	light.name = "Light"
	light.light_color = SpacePalette.PHASER
	light.light_energy = LIGHT_ENERGY
	light.omni_range = LIGHT_RANGE * blast_scale
	light.light_cull_mask = PlasmaBolt.light_mask(true)
	light.shadow_enabled = false
	add_child(light)

## A glowing sphere of `colour` burning `hot` times past it, `share` of the
## flash across: unshaded, added to what is behind it, its own material so it
## fades alone.
func _shell(colour: Color, hot: float, share: float) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var burn := colour * hot
	burn.a = 1.0
	m.albedo_color = burn
	_shells.append(m)
	var mi := MeshInstance3D.new()
	mi.name = "Shell"
	mi.mesh = _sphere_mesh()
	mi.material_override = m
	mi.layers = PlasmaBolt.render_layer(true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * share
	flash.add_child(mi)

func _process(delta: float) -> void:
	tick(delta)

## `delta` seconds on: the flash grows and fades, the light dims; gone at LIFE.
func tick(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	var t := _age / FLASH_LIFE
	if t >= 1.0:
		flash.visible = false
		light.visible = false
		return
	var grow := minf(t / FLASH_GROW, 1.0)
	var size := FLASH_SIZE * 0.5 * blast_scale * (1.0 - (1.0 - grow) * (1.0 - grow))
	flash.scale = Vector3.ONE * maxf(size, 0.01)
	var left := 1.0 - t
	for m in _shells:
		m.albedo_color.a = pow(left, 1.5)
	light.light_energy = LIGHT_ENERGY * left * left

## The boom, outside through the suit's bus; and a thump through the hull of
## the ship you are aboard, if it is near enough to feel it.
func _boom() -> void:
	var s := Synth.sound(&"core_boom")
	if s == null:
		return
	var out := AudioStreamPlayer3D.new()
	out.name = "Boom"
	out.bus = AudioBuses.SUIT
	out.max_distance = BOOM_REACH
	out.unit_size = BOOM_UNIT
	out.stream = s
	add_child(out)
	out.play()
	for node in get_tree().get_nodes_in_group(Ship.GROUP):
		var ship := node as Ship
		if ship == null or not ship.listener_aboard():
			continue
		var d := ship.exterior.global_position.distance_to(global_position)
		if d < THUMP_REACH:
			var thump := AudioStreamPlayer.new()
			thump.name = "Thump"
			thump.bus = AudioBuses.SHIP
			thump.volume_db = lerpf(0.0, THUMP_QUIETEST, d / THUMP_REACH)
			thump.stream = s
			add_child(thump)
			thump.play()
		break

## One sphere query: each hull is hit once at its nearest cell, each NPC and
## each loose item outside once, by damage_at their distance; then you, out in
## your suit.
func _reach(source: Node) -> void:
	var reach := RADIUS * blast_scale
	var at := global_position
	var shape := SphereShape3D.new()
	shape.radius = reach
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, at)
	q.collision_mask = MASK
	q.exclude = _spared(source)
	# collider -> [distance, shape, nearest point, on a hull section]
	var nearest := {}
	for r: Dictionary in get_world_3d().direct_space_state.intersect_shape(q, MOST):
		var collider := r["collider"] as CollisionObject3D
		if collider == null or not _outside(collider):
			continue
		var e := _place(collider, r["shape"], at)
		if not nearest.has(collider) or _nearer(e, nearest[collider]):
			nearest[collider] = e
	for collider: CollisionObject3D in nearest:
		if is_instance_valid(collider) and collider.is_inside_tree():
			var e: Array = nearest[collider]
			Hit.deliver(collider, _hit(e[2], e[0], e[1], source))
	for node in get_tree().get_nodes_in_group(Avatar.GROUP):
		var you := node as Avatar
		if you != null and you.mode == Avatar.Mode.SUIT and you.global_position.distance_to(at) < reach:
			you.receive_hit(_hit(you.global_position, you.global_position.distance_to(at), -1, source))

## Where the blast meets `collider`'s shape `shape_index`, from `at`:
## [distance, shape, point, whether it is a ship's hull section]. A hull's is
## its cell, less half a cell to the face; anything else is where it is.
static func _place(collider: CollisionObject3D, shape_index: int, at: Vector3) -> Array:
	var point := collider.global_position
	if not collider.has_meta(&"receive_hit"):
		return [point.distance_to(at), shape_index, point, false]
	var owner_id := collider.shape_find_owner(shape_index)
	var node := collider.shape_owner_get_owner(owner_id) as Node3D if owner_id >= 0 else null
	var section := false
	if node != null:
		point = node.global_position
		var ship := collider.get_meta(&"ship", null) as Ship
		section = ship != null and ship.damage != null and node.has_meta(&"cell") 			and ship.damage.sections_of.has(node.get_meta(&"cell"))
	return [maxf(point.distance_to(at) - ShipGrid.CELL_SIZE * 0.5, 0.0), shape_index, point, section]

## A ship's plating before its parts (an engine, a turret): what the blast
## breaks is the hull, HULL % (spec §8.1); then the nearer.
static func _nearer(a: Array, b: Array) -> bool:
	if a[3] != b[3]:
		return a[3]
	return a[0] < b[0]

## A blast hit on whatever is at `point`, `d` m off.
func _hit(point: Vector3, d: float, shape_index: int, source: Node) -> Hit:
	var dir := point - global_position
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.UP
	var damage := damage_at(d, blast_scale)
	var hit := Hit.make(point - dir * minf(d, ShipGrid.CELL_SIZE * 0.5), -dir, dir, dir * damage * PUSH, source)
	hit.damage = damage
	hit.kind = &"blast"
	hit.shape = shape_index
	return hit

## The exploding ship's own hull, which the blast never reaches.
static func _spared(source: Node) -> Array[RID]:
	var out: Array[RID] = []
	if source is Ship:
		out.append((source as Ship).exterior.get_rid())
	elif source is CollisionObject3D:
		out.append((source as CollisionObject3D).get_rid())
	return out

## Only what is outside: an NPC or an item aboard is the interior's.
static func _outside(collider: CollisionObject3D) -> bool:
	if collider is Npc:
		return not (collider as Npc).inside
	if collider is Item:
		return (collider as Item).in_space
	return true

## The flash's chunky sphere, of radius 1 m.
static func _sphere_mesh() -> Mesh:
	if _sphere == null:
		var m := SphereMesh.new()
		m.radius = 1.0
		m.height = 2.0
		m.radial_segments = 12
		m.rings = 6
		_sphere = m
	return _sphere
