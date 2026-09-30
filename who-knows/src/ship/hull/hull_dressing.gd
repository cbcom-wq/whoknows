class_name HullDressing
extends RefCounted

## Turns a HullLayout into geometry (docs/superpowers/specs/
## 2026-09-28-ship-exterior-design.md §3.3): works out each record's frame and
## asks HullProps for the piece. The only place that decides which hull prop
## goes where.
##
## Each kit gets a child node of `root`, so their merged meshes keep their
## batch names: Skin/Hull/DressingHull is the plating, and so on.

## Builds everything under `root`. Returns the plating, trim and glazing meshes
## (for the miniature; every batch but the glows), each light group's lens glow,
## and the windows' glow material.
static func build(layout: HullLayout, root: Node3D) -> Dictionary:
	var skin := _kit(root, "Hull")
	skin.materials = {InteriorKit.Batch.HULL: HullMaterials.livery(), InteriorKit.Batch.SOLID: HullMaterials.trim()}
	for p in layout.plates:
		var lo: Vector2 = p["lo"]
		var hi: Vector2 = p["hi"]
		var mid := (lo + hi) * 0.5
		HullProps.plate(skin, HullLayout.face_frame(p["coord"], p["normal"]) * InteriorKit.at(Vector3(mid.x, mid.y, 0)),
			hi - lo)
	for e in layout.edges:
		var f := HullLayout.edge_frame(e)
		var span := HullLayout.edge_span(e)
		var ends: Array = e["ends"]
		HullProps.chamfer_strip(skin, f, span.x, span.y, ends[0] == &"cap", ends[1] == &"cap")
		if e["running"]:
			HullProps.running_strip(skin, f, span.x, span.y)
	for c in layout.corners:
		HullProps.corner_facet(skin, HullLayout.corner_frame(c))
	for fc in layout.facets:
		var face := HullLayout.facet_face(fc)
		HullProps.facet(skin, HullLayout.cell_frame(fc["coord"], fc["orientation"]), face["points"], face["normal"])
	for n in layout.nozzles:
		var f := HullLayout.face_frame(n["coord"], n["normal"])
		if n["kind"] == &"thruster":
			HullProps.thruster_bell(skin, f)
		else:
			HullProps.rcs_pod(skin, f)
	# Light fixtures (spec §6.1): housings on the skin, each group's lenses in
	# a kit of their own, so each group's glow material dims alone.
	var lens_kits := {}
	for m in layout.mounts:
		var group: StringName = m["group"]
		if not lens_kits.has(group):
			var lk := _kit(root, "Lens_%s" % group)
			lk.materials = {InteriorKit.Batch.GLOW: HullMaterials.glow_instance(0.0)}
			lens_kits[group] = lk
		var aim: Vector3 = m["aim"]
		var up := Vector3.FORWARD if absf(aim.dot(Vector3.UP)) > 0.9 else Vector3.UP
		var f := Transform3D(Basis.looking_at(-aim, up), m["position"])
		if group == HullLayout.FLOOD:
			HullProps.flood_fixture(skin, lens_kits[group], f)
		else:
			HullProps.forward_fixture(skin, lens_kits[group], f)
	var meshes: Array[Mesh] = []
	for mi in skin.commit():
		if mi.name == InteriorKit.BATCH_NAMES[InteriorKit.Batch.HULL] \
				or mi.name == InteriorKit.BATCH_NAMES[InteriorKit.Batch.SOLID]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			meshes.append(mi.mesh)
	var lenses := {}
	for group: StringName in lens_kits:
		var lens: MeshInstance3D = lens_kits[group].commit()[0]
		lens.name = "Lens"
		lenses[group] = lens
	# Windows and pods (spec §5): their own kit, so their glow has its own
	# material, which ShipLights dims with the ship.
	var window_glow := HullMaterials.glow_instance(HullMaterials.WINDOW_ENERGY)
	var glazing := _kit(root, "Windows")
	glazing.materials = {InteriorKit.Batch.HULL: HullMaterials.livery(), InteriorKit.Batch.SOLID: HullMaterials.trim(),
		InteriorKit.Batch.GLASS: HullMaterials.window_glass(), InteriorKit.Batch.GLOW: window_glow}
	for w in layout.windows:
		if w["round"]:
			HullProps.window_porthole(glazing, w["frame"], w["size"].x * 0.5)
		else:
			HullProps.window_rect(glazing, w["frame"], w["size"])
	for p in layout.pods:
		HullProps.pod_shell(glazing, p["frame"])
	for mi in glazing.commit():
		if mi.name != InteriorKit.BATCH_NAMES[InteriorKit.Batch.GLOW]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			# The miniature too: without the pod shell it has a notch at the cockpit.
			meshes.append(mi.mesh)
	return {"meshes": meshes, "lenses": lenses, "window_glow": window_glow}

## A kit on the hull's own layer, under a child of `root` named `kit_name`.
static func _kit(root: Node3D, kit_name: String) -> InteriorKit:
	var node := Node3D.new()
	node.name = kit_name
	root.add_child(node)
	var kit := InteriorKit.new(node)
	kit.layer = ExteriorBuilder.OWN_HULL_LAYER
	kit.light_mask = 1 | ExteriorBuilder.OWN_HULL_LAYER
	return kit
