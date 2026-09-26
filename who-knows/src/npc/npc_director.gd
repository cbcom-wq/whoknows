class_name NpcDirector
extends Node

## Keeps the NPCs of one space alive where they matter and as records
## everywhere else (docs/superpowers/specs/2026-09-26-npc-foundation-design.md
## §4.3). One per space: the exterior, and each ship's interior. It never
## moves.
##
## Its sources say which records it may make live now: anything with
## records(director) -> Array of [NpcRecord, NpcSite]. Outside it makes them
## live by distance from the anchors; inside, every record of a live site.
## It pools demoted nodes, and schedules thinking so a frame thinks for a
## few NPCs, never all of them.

enum Rule { BY_DISTANCE, BY_SITE }

const THINK_HZ := 5.0
## Outside, a live NPC is demoted only this far past its live radius.
const DEMOTE_MARGIN := 100.0
const REVIEW_EVERY := 0.25

var rule := Rule.BY_DISTANCE
var max_live := 32
## Live NPCs go under this. It never moves.
var holder: Node3D
var catalog: NpcCatalog
## The space's stimulus bus, handed to every NPC it makes live.
var bus: Node
var sources: Array = []
## Bodies whose nearness makes NPCs live (outside).
var anchor_group: StringName = AsteroidStream.SPACE_ANCHOR
## The cameras that could see an NPC being demoted (outside).
var cameras: Array[Camera3D] = []
## Its own clock, seconds: rounds and memories read this.
var time := 0.0
## id -> Npc
var live := {}
## Warnings logged for going over max_live, for tests.
var over_budget := 0

var _pool := {}   # species id -> Array[Npc]
var _since_review := REVIEW_EVERY
var _tick := 0

func _physics_process(delta: float) -> void:
	time += delta
	_since_review += delta
	if _since_review >= REVIEW_EVERY:
		_since_review = 0.0
		review()
	think_step()

## One physics tick's thinking: the NPCs whose turn it is.
func think_step() -> void:
	var every := ticks_per_think()
	var turn := _tick % every
	_tick += 1
	var dt := float(every) / float(Engine.physics_ticks_per_second)
	for npc: Npc in live.values():
		if group_of(npc.record, every) == turn and is_instance_valid(npc):
			npc.think(time, dt)

## How many physics ticks between one NPC's thinks: 12 at 60 Hz.
static func ticks_per_think() -> int:
	return maxi(1, roundi(Engine.physics_ticks_per_second / THINK_HZ))

## Which tick of its round a record thinks on: spread evenly by id.
static func group_of(record: NpcRecord, every: int) -> int:
	return (hash(record.id) & 0x7FFFFFFF) % every

## Works out which NPCs should be live, and makes it so.
func review() -> void:
	var wanted := {}   # id -> [record, site]
	for source in sources:
		for entry: Array in source.records(self):
			var record: NpcRecord = amend(entry[0])
			if record != null:
				wanted[record.id] = [record, entry[1]]
	# A record no longer offered, or whose place has gone, is demoted at once:
	# its place is gone or far beyond sight.
	for id: StringName in live.keys():
		var npc: Npc = live[id]
		if not is_instance_valid(npc):
			live.erase(id)
		elif not wanted.has(id) or not npc.site.alive():
			demote(npc)
	if rule == Rule.BY_SITE:
		_review_by_site(wanted)
	else:
		_review_by_distance(wanted)

## A record on its way to being made live. The one place a ledger of changes
## (a death, a tamed creature) will plug in (spec §4.5); nothing is remembered
## yet, so it passes every record through unchanged.
func amend(record: NpcRecord) -> NpcRecord:
	return record

func _review_by_site(wanted: Dictionary) -> void:
	for id: StringName in wanted:
		if live.has(id):
			continue
		var site: NpcSite = wanted[id][1]
		if not site.alive():
			continue
		if live.size() >= max_live:
			_warn_over(wanted.size())
			return
		promote(wanted[id][0], site)

func _review_by_distance(wanted: Dictionary) -> void:
	var anchors := _anchors()
	# Live ones that have gone far enough, and could not be seen going. One
	# demoted now is not woken again in the same review.
	var gone := {}
	for id: StringName in live.keys():
		var npc: Npc = live[id]
		var d := _nearest(anchors, npc.global_position)
		if d > npc.species.live_radius + DEMOTE_MARGIN and not could_be_seen(npc):
			demote(npc)
			gone[id] = true
	# Records come alive within their live radius, nearest first.
	var candidates: Array = []
	for id: StringName in wanted:
		if live.has(id) or gone.has(id):
			continue
		var record: NpcRecord = wanted[id][0]
		var site: NpcSite = wanted[id][1]
		var species := catalog.get_def(record.species) if catalog != null else null
		if species == null or not site.alive():
			continue
		var at := site.frame() * site.start_pose(record, time).origin
		var d := _nearest(anchors, at)
		if d <= species.live_radius:
			candidates.append([d, record, site])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for c: Array in candidates:
		if live.size() >= max_live:
			_farthest_out(c[0])
			if live.size() >= max_live:
				_warn_over(live.size() + 1)
				return
		promote(c[1], c[2])

## Over budget: the farthest live NPC makes way for one nearer than it.
func _farthest_out(nearer_than: float) -> void:
	var anchors := _anchors()
	var worst: Npc = null
	var worst_d := nearer_than
	for npc: Npc in live.values():
		var d := _nearest(anchors, npc.global_position)
		if d > worst_d:
			worst = npc
			worst_d = d
	if worst != null:
		demote(worst)

func _warn_over(wanting: int) -> void:
	over_budget += 1
	push_warning("NpcDirector: %d NPCs want to be live, over %d" % [wanting, max_live])

## True while a camera could see it: within its fade and inside a camera's
## view. An NPC with no fade can be seen at any distance.
func could_be_seen(npc: Npc) -> bool:
	for cam in cameras:
		if not is_instance_valid(cam) or not cam.is_inside_tree():
			continue
		var far := npc.species.fade.y
		if far > 0.0 and cam.global_position.distance_to(npc.global_position) > far:
			continue
		if cam.is_position_in_frustum(npc.global_position):
			return true
	return false

## Makes `record` a live NPC at `site`.
func promote(record: NpcRecord, site: NpcSite) -> Npc:
	var species := catalog.get_def(record.species) if catalog != null else null
	if species == null:
		push_error("NpcDirector: no species called %s" % record.species)
		return null
	var npc: Npc = null
	var pool: Array = _pool.get(record.species, [])
	if not pool.is_empty():
		npc = pool.pop_back()
	else:
		npc = _make_npc()
	npc.director = self
	npc.bus = bus
	holder.add_child(npc)
	npc.setup(record, species, site, rule == Rule.BY_SITE, site.start_pose(record, time))
	live[record.id] = npc
	return npc

## A new body for the pool. Tests override it.
func _make_npc() -> Npc:
	return Npc.new()

## Back to being a record: out of the tree, into the pool.
func demote(npc: Npc) -> void:
	if npc == null:
		return
	if npc.record != null:
		live.erase(npc.record.id)
	if not is_instance_valid(npc):
		return
	if npc.get_parent() != null:
		npc.get_parent().remove_child(npc)
	_pool.get_or_add(npc.species.id, []).append(npc)

## Every live NPC, in no particular order.
func live_npcs() -> Array:
	return live.values()

## The bodies whose nearness makes NPCs live: the hull, you on a spacewalk.
func anchors() -> Array:
	return _anchors()

func _anchors() -> Array:
	var out: Array = []
	if not is_inside_tree():
		return out
	for node in get_tree().get_nodes_in_group(anchor_group):
		var n := node as Node3D
		if n != null and n.is_inside_tree():
			out.append(n)
	return out

static func _nearest(anchors: Array, at: Vector3) -> float:
	var best := INF
	for a: Node3D in anchors:
		best = minf(best, a.global_position.distance_to(at))
	return best

func _exit_tree() -> void:
	for pool: Array in _pool.values():
		for npc: Npc in pool:
			if is_instance_valid(npc) and npc.get_parent() == null:
				npc.free()
	_pool.clear()
