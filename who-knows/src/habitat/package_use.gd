class_name PackageUse
extends ItemUse

## A module package in hand (habitat modules spec §5.2, §5.3). Aboard it is
## only a heavy case. On a spacewalk, aimed at a big rock within PLANT_REACH,
## it shows a ghost of the module and says whether it fits, re-testing ten
## times a second; R turns it a quarter turn; `use` re-tests once more and, if
## it fits, plants it -- the package is used up and the base unfolds.

const SURFACE_LAYER := AsteroidBody.LAYER

## Quarter turns the ghost is turned by.
var turns := 0

var _ghost: PackageGhost
var _last: Planting.Result
var _surface: PlantSurface
var _since := INF
## The physics tick aim_text last ran on: the ghost is only for a package being aimed.
var _aimed_at := -1000

## Physics ticks the ghost may go without aim_text being called before it is hidden.
const STALE_AFTER := 3

func _exit_tree() -> void:
	if is_instance_valid(_ghost):
		_ghost.queue_free()

## The ghost belongs to a package being aimed: hide it when the item leaves the
## hand (dropped, thrown, stowed) or aim_text has not run for a few ticks
## (aimed at a stow point, or off the rock).
func _physics_process(_delta: float) -> void:
	if _ghost == null or not is_instance_valid(_ghost) or not _ghost.visible:
		return
	var item := get_parent() as Item
	if item == null or item.state != Item.State.HELD \
			or Engine.get_physics_frames() - _aimed_at > STALE_AFTER:
		_ghost.hide_fit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"turn_module") and _ghost != null and _ghost.visible:
		turn()

func turn() -> void:
	turns = posmod(turns + 1, 4)
	_since = INF

func aim_text(item: Item, aim: Transform3D, holder: CollisionObject3D) -> String:
	if not _outside(holder):
		if _ghost != null:
			_ghost.hide_fit()
		return ""
	_aimed_at = Engine.get_physics_frames()
	_since += get_physics_process_delta_time()
	if _since >= HabitatValues.FIT_EVERY:
		_since = 0.0
		refit(item, aim, holder.get_parent() as Node3D)
	return Planting.prompt(_last, _module(item)) if _last != null else ""

func use(item: Item, aim: Transform3D, world: Node3D, holder: CollisionObject3D) -> bool:
	if holder != null and not _outside(holder):
		return false
	var r := refit(item, aim, world)
	if r == null or r.fit != Planting.Fit.OK:
		return false
	var bases := _bases()
	if bases == null or bases.plant(_module(item).kind, r, _surface) == null:
		return false
	if _ghost != null:
		_ghost.hide_fit()
	Item.consume(item)
	return true

## The fit where `aim` looks now, with the ghost shown in `space` (the space
## you float in, which never moves). Null with nothing to plant on in reach.
func refit(item: Item, aim: Transform3D, space: Node3D) -> Planting.Result:
	_last = null
	_surface = null
	var bases := _bases()
	if bases == null or not is_inside_tree():
		if _ghost != null and is_instance_valid(_ghost):
			_ghost.hide_fit()
		return null
	var from := aim.origin
	var to := from - aim.basis.z * HabitatValues.PLANT_REACH
	var hit := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, to, SURFACE_LAYER))
	if hit.is_empty() or not (hit["collider"] is AsteroidDetail):
		if _ghost != null:
			_ghost.hide_fit()
		return null
	_surface = RockSurface.new(hit["collider"])
	var site := bases.on(_surface.site_id())
	var frame := bases.frame_of(site) if site != null else Transform3D.IDENTITY
	_last = Planting.fit(_surface, _module(item), hit["position"], -aim.basis.z, turns, site, frame,
		_ship_gap(hit["position"]), bases.slots.free_count() > 0)
	_show(space)
	return _last

func _show(space: Node3D) -> void:
	if _ghost == null or not is_instance_valid(_ghost):
		if space == null:
			return
		_ghost = PackageGhost.new()
		_ghost.name = "PackageGhost"
		space.add_child(_ghost)
	_ghost.show_fit(_last)

func _module(item: Item) -> ModuleDefinition:
	return ModuleCatalog.get_def(item.definition.module)

func _bases() -> Bases:
	return get_tree().get_first_node_in_group(Bases.GROUP) as Bases if is_inside_tree() else null

## How far `p` is from the nearest ship's hull.
func _ship_gap(p: Vector3) -> float:
	var best := INF
	for node in get_tree().get_nodes_in_group(Ship.GROUP):
		var ship := node as Ship
		if ship != null and ship.visible:
			best = minf(best, SuitTie.gap(ship, p))
	return best

static func _outside(holder: Node) -> bool:
	var avatar := holder as Avatar
	return avatar == null or avatar.mode == Avatar.Mode.SUIT
