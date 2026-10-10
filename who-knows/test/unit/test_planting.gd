extends GutTest

## The fit test (habitat modules spec §5.2), against built surfaces.

## Flat ground at y = `height`, tilted by `tilt` about x; a step of `step` m
## where x > `step_at`. Its up is its normal. A body box is blocked when its
## lowest corner is under the ground.
class Ground extends PlantSurface:
	var height := 0.0
	var tilt := 0.0
	var step := 0.0
	var step_at := INF
	var normal := Vector3.UP
	func _init(p_height := 0.0, p_tilt := 0.0) -> void:
		height = p_height
		tilt = p_tilt
		normal = Basis(Vector3.RIGHT, tilt) * Vector3.UP
	func at(x: float, z: float) -> float:
		return height + z * -tan(tilt) + (step if x > step_at else 0.0)
	func up_at(_point: Vector3) -> Vector3:
		return normal
	func cast(from: Vector3, dir: Vector3, reach: float) -> Dictionary:
		var to := from + dir * reach
		var g := at(to.x, to.z)
		if from.y >= g and to.y <= g:
			return {"position": Vector3(to.x, g, to.z), "normal": normal}
		return {}
	func blocked(box: Transform3D, size: Vector3) -> bool:
		for sx in [-0.5, 0.5]:
			for sz in [-0.5, 0.5]:
				var p := box * (Vector3(sx, -0.5, sz) * size)
				if p.y < at(p.x, p.z) - 0.01:
					return true
		return false
	func fixed() -> bool:
		return true
	func site_id() -> StringName:
		return &"rock:test"

var _hub: ModuleDefinition
var _drill: ModuleDefinition

func before_all():
	_hub = ModuleCatalog.get_def(ModuleCatalog.HUB)
	_drill = ModuleCatalog.get_def(ModuleCatalog.DRILL)

func _hub_site(r: Planting.Result) -> BaseSite:
	var s := BaseSite.new()
	s.add(ModuleCatalog.HUB, r.cell, r.turns, r.legs)
	return s

func test_a_hub_fits_on_flat_ground_on_short_legs():
	var r := Planting.fit(Ground.new(), _hub, Vector3(10, 0, 5), Vector3.FORWARD, 0)
	assert_eq(r.fit, Planting.Fit.OK)
	assert_eq(r.legs.size(), 4)
	for leg in r.legs:
		assert_almost_eq(leg, HabitatValues.LEG_MIN + HabitatValues.LEG_SPARE, 0.01)
	assert_almost_eq(r.frame.basis.y, Vector3.UP, Vector3.ONE * 0.001, "a new hub's up is the surface's")
	assert_eq(r.cell, Vector3i.ZERO, "the hub is the base's first module")
	assert_almost_eq(Vector2(r.body.origin.x, r.body.origin.z), Vector2(10, 5), Vector2.ONE * 0.01, "centred on the aim")
	assert_eq(Planting.prompt(r, _hub), "Plant Hub")

func test_a_hub_faces_you():
	var r := Planting.fit(Ground.new(), _hub, Vector3.ZERO, Vector3.RIGHT, 0)
	assert_almost_eq(-r.frame.basis.z, Vector3.RIGHT, Vector3.ONE * 0.001)

func test_legs_that_cannot_reach():
	var g := Ground.new()
	g.step = -3.0
	g.step_at = 0.0
	var r := Planting.fit(g, _hub, Vector3(0, 0, 0), Vector3.FORWARD, 0)
	assert_eq(r.fit, Planting.Fit.LEGS_CANT_REACH)
	assert_eq(Planting.prompt(r, _hub), "Legs can't reach")

func test_no_ground_no_ghost():
	var r := Planting.fit(Ground.new(-50.0), _hub, Vector3(0, 0, 0), Vector3.FORWARD, 0)
	assert_eq(r.fit, Planting.Fit.NO_GROUND)
	assert_eq(Planting.prompt(r, _hub), "")

func test_anything_but_a_hub_needs_a_base():
	var r := Planting.fit(Ground.new(), _drill, Vector3.ZERO, Vector3.FORWARD, 0)
	assert_eq(r.fit, Planting.Fit.HUB_FIRST)
	assert_eq(Planting.prompt(r, _drill), "Plant a hub first")

func test_a_drill_snaps_to_the_base_s_grid():
	var hub := Planting.fit(Ground.new(), _hub, Vector3.ZERO, Vector3.FORWARD, 0)
	var site := _hub_site(hub)
	var aim := hub.frame * Vector3(10.3, -2.0, 0.4)
	var r := Planting.fit(Ground.new(), _drill, aim, Vector3.FORWARD, 1, site, hub.frame)
	assert_eq(r.fit, Planting.Fit.OK)
	assert_eq(r.turns, 1)
	assert_eq(r.cell.y, 0, "the same storey on flat ground")
	var local := hub.frame.affine_inverse() * r.body.origin
	var expect := ShipGrid.cell_center(r.cell) \
		+ Vector3(_drill.turned_size(1) - Vector3i.ONE) * ShipGrid.CELL_SIZE * 0.5
	assert_almost_eq(local, expect, Vector3.ONE * 0.01, "its body sits on the base's grid")
	assert_eq(Planting.prompt(r, _drill), "Plant Drill")

func test_touching_a_module_is_blocked():
	var hub := Planting.fit(Ground.new(), _hub, Vector3.ZERO, Vector3.FORWARD, 0)
	var site := _hub_site(hub)
	# The hub's cells run x 0..2: a drill at x 3 touches it.
	var aim := hub.frame * Vector3(6.0, -2.0, 1.0)
	var r := Planting.fit(Ground.new(), _drill, aim, Vector3.FORWARD, 0, site, hub.frame)
	assert_eq(r.fit, Planting.Fit.BLOCKED)
	assert_eq(Planting.prompt(r, _drill), "Blocked")

func test_too_far_from_the_base():
	var hub := Planting.fit(Ground.new(), _hub, Vector3.ZERO, Vector3.FORWARD, 0)
	var r := Planting.fit(Ground.new(), _drill, hub.frame * Vector3(40, -2, 0), Vector3.FORWARD, 0,
		_hub_site(hub), hub.frame)
	assert_eq(r.fit, Planting.Fit.TOO_FAR)
	assert_eq(Planting.prompt(r, _drill), "Too far from the base")

func test_too_steep_for_the_base_s_up():
	var hub := Planting.fit(Ground.new(), _hub, Vector3.ZERO, Vector3.FORWARD, 0)
	var slope := Ground.new(0.0, deg_to_rad(40.0))
	var r := Planting.fit(slope, _drill, hub.frame * Vector3(10, -2, 0), Vector3.FORWARD, 0,
		_hub_site(hub), hub.frame)
	assert_eq(r.fit, Planting.Fit.TOO_STEEP)
	assert_eq(Planting.prompt(r, _drill), "Too steep")

func test_too_close_to_a_ship():
	var r := Planting.fit(Ground.new(), _hub, Vector3.ZERO, Vector3.FORWARD, 0, null, Transform3D.IDENTITY, 12.0)
	assert_eq(r.fit, Planting.Fit.NEAR_SHIP)
	assert_eq(Planting.prompt(r, _hub), "Too close to a ship")

func test_no_room_for_a_new_base():
	var r := Planting.fit(Ground.new(), _hub, Vector3.ZERO, Vector3.FORWARD, 0, null, Transform3D.IDENTITY,
		INF, false)
	assert_eq(r.fit, Planting.Fit.NO_ROOM)
	assert_eq(Planting.prompt(r, _hub), "No room")

## One module unfolds at a time (the final review): while the base unfolds,
## the fit waits, whatever else would be said, with no ghost (as for a hub
## first).
func test_wait_while_the_base_unfolds():
	var hub := Planting.fit(Ground.new(), _hub, Vector3.ZERO, Vector3.FORWARD, 0)
	var aim := hub.frame * Vector3(10.3, -2.0, 0.4)
	var r := Planting.fit(Ground.new(), _drill, aim, Vector3.FORWARD, 0, _hub_site(hub), hub.frame, INF, true, true)
	assert_eq(r.fit, Planting.Fit.UNFOLDING)
	assert_eq(Planting.prompt(r, _drill), "Wait: unfolding")
