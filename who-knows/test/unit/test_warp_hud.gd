extends GutTest

## The warp on the HUD (the warp spec §7.3): the plan's line while charted,
## the stage while it runs, toasts at the limits, and which marker marks what.

func _drive_with(status: WarpPlan.Status) -> WarpDrive:
	var d := WarpDrive.new()
	autofree(d)
	d.charted = &"p1"
	d.plan = WarpPlan.new()
	d.plan.status = status
	d.plan.cost = 376
	return d

func test_the_panel_reads_the_plan_while_charted():
	var d := _drive_with(WarpPlan.Status.READY)
	assert_eq(WarpPanel.line_text(d), "WARP READY · J")
	assert_eq(WarpPanel.colour_for(d), HudPalette.GO)
	d.plan.into_low_power = true
	assert_eq(WarpPanel.colour_for(d), HudPalette.WARNING)
	d.plan.status = WarpPlan.Status.NO_QE
	assert_eq(WarpPanel.line_text(d), "WARP · NEED 376 QE")
	assert_eq(WarpPanel.colour_for(d), HudPalette.WARNING)
	d.charted = &""
	assert_eq(WarpPanel.line_text(d), "", "nothing charted, nothing said")

func test_the_panel_counts_down_the_spool():
	var d := _drive_with(WarpPlan.Status.READY)
	d.stage = WarpDrive.Stage.SPOOLING
	d.spool_left = 6.2
	assert_eq(WarpPanel.line_text(d), "WARP · SPOOLING 7")

func test_a_toast_shows_then_fades():
	var p := WarpPanel.new()
	add_child_autofree(p)
	p.drive = _drive_with(WarpPlan.Status.NONE)
	p.drive.charted = &""
	var t := VehicleTelemetry.new()
	p.toast("LEAVING KORVA-7 · WARP CLEAR")
	p.render(t)
	assert_true(p.visible)
	assert_eq(p.toast_label.text, "LEAVING KORVA-7 · WARP CLEAR")
	p._process(WarpPanel.TOAST_TIME + 0.1)
	p.render(t)
	assert_false(p.visible)

func test_the_panel_hides_on_a_spacewalk():
	var p := WarpPanel.new()
	add_child_autofree(p)
	p.drive = _drive_with(WarpPlan.Status.READY)
	var t := VehicleTelemetry.new()
	t.has_beacon = true
	p.render(t)
	assert_false(p.visible)

func test_distances_read_in_km():
	assert_eq(BodyMarker.distance_text(82400.0), "82 KM")
	assert_eq(BodyMarker.distance_text(6200.0), "6.2 KM")

func test_the_contact_marker_leaves_worlds_and_clusters_to_the_body_marker():
	assert_false(ContactMarker.marks_kind(BodyContacts.KIND))
	assert_false(ContactMarker.marks_kind(BodyContacts.CLUSTER))
	assert_false(ContactMarker.marks_kind(BodyContacts.MOON), "moons are warp targets: the body marker's")
	assert_true(ContactMarker.marks_kind(&"life"))

func test_labels_that_would_overlap_keep_only_the_nearer():
	var marks: Array[Dictionary] = [
		{"id": &"body:far", "position": Vector2(410, 300), "text": "FAR WORLD · 130 KM", "metres": 130000.0},
		{"id": &"body:near", "position": Vector2(400, 300), "text": "NEAR WORLD · 20 KM", "metres": 20000.0},
		{"id": &"body:apart", "position": Vector2(400, 500), "text": "APART · 40 KM", "metres": 40000.0},
	]
	var kept := BodyMarker.declutter(marks)
	assert_eq(kept.size(), 3, "every bracket stays")
	assert_eq(kept[0]["id"], &"body:near", "nearest first")
	assert_eq(kept[0]["text"], "NEAR WORLD · 20 KM")
	assert_eq(kept[1]["text"], "APART · 40 KM", "far enough apart to keep its label")
	assert_eq(kept[2]["text"], "", "its label would lie on the nearer one's")
