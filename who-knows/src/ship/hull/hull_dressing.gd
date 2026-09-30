class_name HullDressing
extends RefCounted

## Turns a HullLayout into geometry (docs/superpowers/specs/
## 2026-09-28-ship-exterior-design.md §3.3): works out each record's frame and
## asks HullProps for the piece. The only place that decides which hull prop
## goes where.
##
## Each kit gets a child node of `root`, so their merged meshes keep their
## batch names: Skin/Hull/DressingHull is the plating, and so on.
##
## Every piece belongs to one cell, and the dressing notes which vertices of
## which mesh each cell's pieces are, so ExteriorBuilder can tint one cell for
## its damage without dressing anything again (health and damage spec §9).

## The batches a cell's damage tints: the plating, the trim and the glass.
## Glows are lights, not paint, and stay as they are: the running strips, a
## bell's ring, the windows' bands and the lamps' lenses.
const TINTED: Array[InteriorKit.Batch] = [InteriorKit.Batch.HULL, InteriorKit.Batch.SOLID,
	InteriorKit.Batch.GLASS]

## Builds everything under `root`. Returns the plating, trim and glazing meshes
## (for the miniature; every batch but the glows), each light group's lens glow,
## the windows' glow material, each cell's `spans` in the TINTED batches
## (Vector3i -> [[ArrayMesh, first vertex, end vertex], ...]), and those
## meshes' `surfaces` (ArrayMesh -> its surface arrays), to recolour them.
static func build(layout: HullLayout, root: Node3D) -> Dictionary:
	var skin := _kit(root, "Hull")
	skin.materials = {InteriorKit.Batch.HULL: HullMaterials.livery(), InteriorKit.Batch.SOLID: HullMaterials.trim()}
	skin.keep_arrays = true
	var marks := {}   # Vector3i -> [[kit, batch, from, to], ...]
	for p in layout.plates:
		var lo: Vector2 = p["lo"]
		var hi: Vector2 = p["hi"]
		var mid := (lo + hi) * 0.5
		var at := _counts(skin)
		HullProps.plate(skin, HullLayout.face_frame(p["coord"], p["normal"]) * InteriorKit.at(Vector3(mid.x, mid.y, 0)),
			hi - lo)
		_mark(marks, skin, p["coord"], at)
	for e in layout.edges:
		var f := HullLayout.edge_frame(e)
		var span := HullLayout.edge_span(e)
		var ends: Array = e["ends"]
		var at := _counts(skin)
		HullProps.chamfer_strip(skin, f, span.x, span.y, ends[0] == &"cap", ends[1] == &"cap")
		if e["running"]:
			HullProps.running_strip(skin, f, span.x, span.y)
		_mark(marks, skin, e["coord"], at)
	for c in layout.corners:
		var at := _counts(skin)
		HullProps.corner_facet(skin, HullLayout.corner_frame(c))
		_mark(marks, skin, c["coord"], at)
	for fc in layout.facets:
		var face := HullLayout.facet_face(fc)
		var at := _counts(skin)
		HullProps.facet(skin, HullLayout.cell_frame(fc["coord"], fc["orientation"]), face["points"], face["normal"])
		_mark(marks, skin, fc["coord"], at)
	for n in layout.nozzles:
		var f := HullLayout.face_frame(n["coord"], n["normal"])
		var at := _counts(skin)
		if n["kind"] == &"thruster":
			HullProps.thruster_bell(skin, f)
		else:
			HullProps.rcs_pod(skin, f)
		_mark(marks, skin, n["coord"], at)
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
		var at := _counts(skin)
		if group == HullLayout.FLOOD:
			HullProps.flood_fixture(skin, lens_kits[group], f)
		else:
			HullProps.forward_fixture(skin, lens_kits[group], f)
		_mark(marks, skin, m["coord"], at)
	var meshes: Array[Mesh] = []
	var committed := {}   # kit -> {Batch: MeshInstance3D}
	committed[skin] = _by_batch(skin.commit())
	for mi: MeshInstance3D in committed[skin].values():
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
	glazing.keep_arrays = true
	glazing.materials = {InteriorKit.Batch.HULL: HullMaterials.livery(), InteriorKit.Batch.SOLID: HullMaterials.trim(),
		InteriorKit.Batch.GLASS: HullMaterials.window_glass(), InteriorKit.Batch.GLOW: window_glow}
	for w in layout.windows:
		var at := _counts(glazing)
		if w["round"]:
			HullProps.window_porthole(glazing, w["frame"], w["size"].x * 0.5)
		else:
			HullProps.window_rect(glazing, w["frame"], w["size"])
		_mark(marks, glazing, w["coord"], at)
	for p in layout.pods:
		var at := _counts(glazing)
		HullProps.pod_shell(glazing, p["frame"])
		_mark(marks, glazing, p["cell"], at)
	committed[glazing] = _by_batch(glazing.commit())
	for mi: MeshInstance3D in committed[glazing].values():
		if mi.name != InteriorKit.BATCH_NAMES[InteriorKit.Batch.GLOW]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			# The miniature too: without the pod shell it has a notch at the cockpit.
			meshes.append(mi.mesh)
	var spans := {}
	for coord: Vector3i in marks:
		var runs := []
		for run: Array in marks[coord]:
			runs.append([committed[run[0]][run[1]].mesh, run[2], run[3]])
		spans[coord] = runs
	var surfaces := {}
	for kit: InteriorKit in [skin, glazing]:
		for batch in TINTED:
			if committed[kit].has(batch):
				surfaces[committed[kit][batch].mesh] = kit.arrays[batch]
	return {"meshes": meshes, "lenses": lenses, "window_glow": window_glow, "spans": spans,
		"surfaces": surfaces}

## How many vertices each TINTED batch of `kit` holds now.
static func _counts(kit: InteriorKit) -> PackedInt32Array:
	var out := PackedInt32Array()
	for batch in TINTED:
		out.append(kit.vertex_count(batch))
	return out

## Notes that what `kit` gained in the TINTED batches since `at` (its
## _counts) is `coord`'s, as runs [kit, batch, from, to]. A run that carries on
## from one the cell already has joins it.
static func _mark(marks: Dictionary, kit: InteriorKit, coord: Vector3i, at: PackedInt32Array) -> void:
	if not marks.has(coord):
		marks[coord] = []
	var runs: Array = marks[coord]
	for i in TINTED.size():
		var batch := TINTED[i]
		var to := kit.vertex_count(batch)
		if to == at[i]:
			continue
		var joined := false
		for run: Array in runs:
			if run[0] == kit and run[1] == batch and run[3] == at[i]:
				run[3] = to
				joined = true
				break
		if not joined:
			runs.append([kit, batch, at[i], to])

## A kit's committed meshes by batch.
static func _by_batch(committed: Array[MeshInstance3D]) -> Dictionary:
	var out := {}
	for mi in committed:
		out[InteriorKit.BATCH_NAMES.find(String(mi.name))] = mi
	return out

## A kit on the hull's own layer, under a child of `root` named `kit_name`.
static func _kit(root: Node3D, kit_name: String) -> InteriorKit:
	var node := Node3D.new()
	node.name = kit_name
	root.add_child(node)
	var kit := InteriorKit.new(node)
	kit.layer = ExteriorBuilder.OWN_HULL_LAYER
	kit.light_mask = 1 | ExteriorBuilder.OWN_HULL_LAYER
	return kit
