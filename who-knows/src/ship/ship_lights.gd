class_name ShipLights
extends Node3D

## The ship's work lights (docs/superpowers/specs/2026-09-28-ship-exterior-design.md
## §6, §7): floods under and around the hull, and a forward pair, at the
## mounts HullLayout picks. The helm (L, K) and the bridge's lights panel both
## switch this one state. It lives under the hull body, so the floating
## origin carries it (CLAUDE.md), and it outlives rebuilds: bind() remakes the
## lights from the new mounts and keeps what was on.

signal changed

const FLOOD := &"flood"
const FORWARD := &"forward"
const GROUPS: Array[StringName] = [FLOOD, FORWARD]
## The world and the ship's own hull; never the interior (layer 2).
const LIGHT_MASK := 1 | ExteriorBuilder.OWN_HULL_LAYER
## Beams are on the world's layer, so the canopy shows your forward beams.
const BEAM_LAYER := 1
## Each group: its cone (full angle, degrees), reach (m), energy at full
## power, and whether it casts shadows. Energies are tuned at the renders.
const SETTINGS := {
	FLOOD: {"cone": 55.0, "reach": 40.0, "energy": 4.0, "shadows": false},
	FORWARD: {"cone": 22.0, "reach": 220.0, "energy": 16.0, "shadows": true},
}
## How much of its reach a beam is drawn along before it has faded out.
const BEAM_FRACTION := 0.6
## Both levels in low power (quantum energy spec §8): the lights still work.
const LOW_POWER_LEVEL := 0.5

var floods := false
var forward := false
## The windows' brightness and the lights', 1 at full power.
var interior_level := 1.0
var exterior_level := 1.0
## The ship's quantum plant, for low power. Null means full power.
var quantum: QuantumPlant

var _rig: Node3D
var _spots: Dictionary = {}    # StringName -> Array[SpotLight3D]
var _beams: Dictionary = {}    # StringName -> MeshInstance3D
var _lenses: Dictionary = {}   # StringName -> MeshInstance3D
var _window_glow: ShaderMaterial

## Remakes the spot lights and beams at `mounts` (HullLayout.mounts), with
## each group's lens glow and the windows' glow from the new skin, and shows
## them as the state says.
func bind(mounts: Array, lenses: Dictionary, window_glow: ShaderMaterial) -> void:
	if is_instance_valid(_rig):
		remove_child(_rig)
		_rig.free()
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	_spots.clear()
	_beams.clear()
	_lenses = lenses
	_window_glow = window_glow
	for group in GROUPS:
		var s: Dictionary = SETTINGS[group]
		var kit := InteriorKit.new(_rig)
		kit.layer = BEAM_LAYER
		kit.materials = {InteriorKit.Batch.GLOW: HullMaterials.beam(HullPalette.WORK_LIGHT)}
		var spots: Array[SpotLight3D] = []
		for mount: Dictionary in mounts:
			if mount["group"] != group:
				continue
			var at: Vector3 = mount["position"]
			var aim: Vector3 = mount["aim"]
			var spot := SpotLight3D.new()
			spot.name = "%s_%d" % [group, spots.size()]
			spot.transform = Transform3D(Basis.looking_at(aim, _up(aim)), at)
			spot.light_color = HullPalette.WORK_LIGHT
			spot.spot_angle = s["cone"] * 0.5
			spot.spot_range = s["reach"]
			spot.shadow_enabled = s["shadows"]
			spot.light_cull_mask = LIGHT_MASK
			spot.set_meta(&"group", group)
			_rig.add_child(spot)
			spots.append(spot)
			var length: float = s["reach"] * BEAM_FRACTION
			HullProps.beam_cone(kit, Transform3D(Basis.looking_at(-aim, _up(aim)), at), length,
				tan(deg_to_rad(s["cone"] * 0.5)) * length)
		_spots[group] = spots
		if not spots.is_empty():
			var beam_mesh: MeshInstance3D = kit.commit()[0]
			beam_mesh.name = "Beam_%s" % group
			_beams[group] = beam_mesh
	_apply()

static func _up(aim: Vector3) -> Vector3:
	return Vector3.FORWARD if absf(aim.normalized().dot(Vector3.UP)) > 0.9 else Vector3.UP

func is_on(group: StringName) -> bool:
	return floods if group == FLOOD else forward

func set_group(group: StringName, on: bool) -> void:
	if is_on(group) == on:
		return
	if group == FLOOD:
		floods = on
	else:
		forward = on
	_apply()
	changed.emit()

func toggle(group: StringName) -> void:
	set_group(group, not is_on(group))

func spots(group: StringName) -> Array[SpotLight3D]:
	var none: Array[SpotLight3D] = []
	return _spots.get(group, none)

func beam(group: StringName) -> MeshInstance3D:
	return _beams.get(group)

## Low power halves the windows and the lights (spec §7.1).
func apply_power(low_power: bool) -> void:
	var level := LOW_POWER_LEVEL if low_power else 1.0
	if is_equal_approx(level, exterior_level) and is_equal_approx(level, interior_level):
		return
	interior_level = level
	exterior_level = level
	_apply()

func _process(_delta: float) -> void:
	apply_power(quantum != null and quantum.store != null and quantum.store.is_low_power())

func _apply() -> void:
	for group in GROUPS:
		var on := is_on(group)
		var s: Dictionary = SETTINGS[group]
		for spot in spots(group):
			spot.visible = on
			spot.light_energy = s["energy"] * exterior_level
		if _beams.has(group):
			_beams[group].visible = on
		var lens: MeshInstance3D = _lenses.get(group)
		if is_instance_valid(lens) and lens.material_override is ShaderMaterial:
			(lens.material_override as ShaderMaterial).set_shader_parameter(&"energy",
				InteriorMaterials.GLOW_ENERGY * exterior_level if on else 0.0)
	if _window_glow != null:
		_window_glow.set_shader_parameter(&"energy", HullMaterials.WINDOW_ENERGY * interior_level)

## The ship's save part (spec §7.1). A save without one loads with both off.
func to_dict() -> Dictionary:
	return {"floods": floods, "forward": forward}

func from_dict(d: Dictionary) -> void:
	floods = bool(d.get("floods", false))
	forward = bool(d.get("forward", false))
	_apply()
	changed.emit()
