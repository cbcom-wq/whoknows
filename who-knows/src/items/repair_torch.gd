class_name RepairTorch
extends ItemUse

## The repair torch (docs/superpowers/specs/
## 2026-09-29-health-and-damage-design.md §8, and for ships
## 2026-10-03-ship-damage-sections-design.md §6): hold `use` to weld what you
## are aimed at within REACH. A hull section only from outside, SECTION_RATE of
## it a second for SECTION_SCRAP a whole section, its pieces coming back as it
## rises; a component where it is, at RATE, one feed per hp; and it brings a
## knocked-out droid round. It is fed scrap plates: aim at one and
## hold, and in PLATE_TIME the plate is gone and the hopper has PLATE more.
## The player sees the hopper's `feed` as SCRAP (owner, 2026-10-02: "FEED"
## said nothing).
## It works on a spacewalk (ItemDefinition.works_outside), where the hull is.
##
## It finds the ship from what it hits (meta &"ship" on the hull and the
## interior) or, aimed through a hole, from Ship.GROUP.

const REACH := 2.5
const RATE := 25.0
const HOPPER := 300.0
const PLATE := 100.0
const PLATE_TIME := 1.5
## The share of a hull section mended a second, and what a whole section
## costs: 25 s and one plate from nothing to whole.
const SECTION_RATE := 0.04
const SECTION_SCRAP := 100.0
const PLATE_ID := &"scrap_plate"
## The hull, the interior, items and NPCs.
const MASK := 1 | 2 | Item.LAYER | Npc.LAYER
## Welding this recently: saving waits, and the light is on.
const BUSY_FOR := 0.2
const LIGHT_RANGE := 1.5
const LIGHT_ENERGY := 1.2
const SPARKS := 16

var feed := HOPPER

var _target_key := ""
var _charge := 0.0
var _since_weld := INF
var _light: OmniLight3D
var _sparks: GPUParticles3D

func _ready() -> void:
	_light = OmniLight3D.new()
	_light.name = "WeldLight"
	_light.light_color = InteriorPalette.WELD
	_light.light_energy = LIGHT_ENERGY
	_light.omni_range = LIGHT_RANGE
	_light.shadow_enabled = false
	_light.visible = false
	add_child(_light)
	_sparks = GPUParticles3D.new()
	_sparks.name = "WeldSparks"
	_sparks.amount = SPARKS
	_sparks.lifetime = 0.4
	_sparks.local_coords = false
	_sparks.emitting = false
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.BACK
	m.spread = 70.0
	m.initial_velocity_min = 1.0
	m.initial_velocity_max = 2.5
	m.gravity = Vector3.ZERO
	_sparks.process_material = m
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.015, 0.015, 0.05)
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.albedo_color = InteriorPalette.WELD
	mesh.material = look
	_sparks.draw_pass_1 = mesh
	_sparks.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	# World-space sparks can't be moved once out: they hold the shift (CLAUDE.md).
	_sparks.add_to_group(Universe.HOLDS_SHIFT)
	add_child(_sparks)

func _process(delta: float) -> void:
	_since_weld += delta
	var welding := _since_weld < BUSY_FOR
	if _light != null:
		_light.visible = welding
		_sparks.emitting = welding

## The press does nothing of its own: holding does the work.
func use(_item: Item, _aim: Transform3D, _world: Node3D, _holder: CollisionObject3D) -> bool:
	return false

func hold(item: Item, aim: Transform3D, _world: Node3D, holder: CollisionObject3D, delta: float) -> bool:
	var t := target(item, aim, holder)
	var key: String = t.get("key", "")
	if key != _target_key:
		_target_key = key
		_charge = 0.0
	var did := false
	match t.get("kind", &""):
		&"plate":
			if HOPPER - feed >= PLATE:
				did = true
				_charge += delta
				if _charge >= PLATE_TIME:
					Item.consume(t["item"])
					feed += PLATE
					_charge = 0.0
					_target_key = ""
		&"part":
			did = _mend_part(t, delta)
		&"npc":
			did = _mend_npc(t["npc"], delta)
	if did:
		_since_weld = 0.0
		_show_at(t["point"], t["normal"], holder)
	return did

## Mends the section or component `t` is on: a section only from outside.
func _mend_part(t: Dictionary, delta: float) -> bool:
	var ship: Ship = t["ship"]
	var part: StringName = t["part"]
	if ship.damage.is_section(part):
		if not t["outside"]:
			return false
		var used := ship.repair_section(part, minf(SECTION_RATE * delta, feed / SECTION_SCRAP))
		feed -= used * SECTION_SCRAP
		return used > 0.0
	var hp := ship.repair_component(part, minf(RATE * delta, feed))
	feed -= hp
	return hp > 0.0

## Brings a knocked-out NPC round for the health it gets up with, or heals a
## hurt one at RATE; one feed per hp either way.
func _mend_npc(npc: Npc, delta: float) -> bool:
	if npc.down:
		var cost := npc.health.max * npc.species.wake_health
		if feed < cost:
			return false
		npc.revive()
		feed -= cost
		return true
	var hp := minf(minf(RATE * delta, feed), npc.health.max - npc.health.current)
	if hp <= 0.0:
		return false
	npc.health.heal(hp)
	feed -= hp
	return true

## What the torch is aimed at: {kind, key, point, normal} and, by kind, the
## plate `item`; for a `part`, the `ship`, the `part` (a section or a
## component), its `cell` and whether it is `outside` (a hole is a piece of
## its section, from outside); or the `npc`. Empty when it is aimed at nothing
## it can work on.
func target(item: Item, aim: Transform3D, holder: CollisionObject3D) -> Dictionary:
	if not item.is_inside_tree():
		return {}
	var from := aim.origin
	var dir := -aim.basis.z.normalized()
	var exclude: Array[RID] = [item.get_rid()]
	if holder != null:
		exclude.append(holder.get_rid())
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * REACH, MASK, exclude)
	var hit := item.get_world_3d().direct_space_state.intersect_ray(query)
	var reach := REACH
	if not hit.is_empty():
		var collider: Object = hit["collider"]
		var point: Vector3 = hit["position"]
		var normal: Vector3 = hit["normal"]
		reach = from.distance_to(point)
		var plate := collider as Item
		if plate != null and plate.definition.id == PLATE_ID:
			return {"kind": &"plate", "key": "plate:%d" % plate.get_instance_id(), "item": plate,
				"point": point, "normal": normal}
		var npc := collider as Npc
		if npc != null and npc.species != null and npc.species.knocked_out_for > 0.0:
			return {"kind": &"npc", "key": "npc:%s" % npc.record.id, "npc": npc, "point": point, "normal": normal}
		if collider != null and collider.has_meta(&"ship"):
			var ship := collider.get_meta(&"ship") as Ship
			var on := ship.part_hit(collider, int(hit.get("shape", -1)), point, normal)
			if not on.is_empty():
				return {"kind": &"part", "key": "part:%s:%s" % [on["part"], on["outside"]], "ship": ship,
					"part": on["part"], "cell": on["cell"], "outside": on["outside"],
					"point": point, "normal": normal}
	# Nothing hit on the way, or not yet: a hole along the ray?
	for node in item.get_tree().get_nodes_in_group(Ship.GROUP):
		var ship := node as Ship
		var cell := ship.missing_cell_along(from, dir, reach)
		if cell != ShipCells.NONE:
			var part := ship.damage.part_of(cell)
			return {"kind": &"part", "key": "part:%s:true" % part, "ship": ship, "part": part,
				"cell": cell, "outside": true, "point": from + dir * reach, "normal": -dir}
	return {}

func aim_text(item: Item, aim: Transform3D, holder: CollisionObject3D) -> String:
	var t := target(item, aim, holder)
	var scrap := status().to_upper()
	match t.get("kind", &""):
		&"plate":
			return "LOAD PLATE +%d · %s" % [roundi(PLATE), scrap] if HOPPER - feed >= PLATE else "TORCH FULL · %s" % scrap
		&"part":
			var ship: Ship = t["ship"]
			if ship.damage.is_section(t["part"]) and not t["outside"]:
				return "HULL %d%% · WELD FROM OUTSIDE" % roundi(ship.hull_whole() * 100.0)
			return "%s · %s" % [ship.part_label(t["part"]), scrap]
		&"npc":
			var npc: Npc = t["npc"]
			return "%s · %s · %s" % [npc.species.display_name.to_upper(), "DOWN" if npc.down else "%d%% H" % roundi(npc.health.fraction() * 100.0), scrap]
	return scrap

## What the hopper holds, shown as SCRAP: welding uses it up (one an hp of a
## component, SECTION_SCRAP a whole section), and each plate loaded adds PLATE.
func status() -> String:
	return "scrap %d/%d" % [floori(feed), roundi(HOPPER)]

func busy() -> String:
	return "welding" if _since_weld < BUSY_FOR else ""

func save() -> Dictionary:
	return {"feed": feed}

func restore(state: Dictionary) -> void:
	feed = clampf(float(state.get("feed", feed)), 0.0, HOPPER)

## The light and sparks where the nozzle meets the surface, on the layers for
## where you are: aboard the interior's, outside the world's.
func _show_at(point: Vector3, normal: Vector3, holder: CollisionObject3D) -> void:
	if _light == null:
		return
	var outside := holder is Avatar and (holder as Avatar).mode == Avatar.Mode.SUIT
	var layer := 1 if outside else InteriorKit.LAYER
	_light.light_cull_mask = (1 | ExteriorBuilder.OWN_HULL_LAYER) if outside else InteriorKit.LAYER
	_sparks.layers = layer
	_light.global_position = point + normal * 0.15
	_sparks.global_position = point + normal * 0.02
	if normal.length() > 0.5:
		var up := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		_sparks.global_basis = Basis.looking_at(-normal, up)
