class_name MemorialLilies
extends Area3D

## The lilies at the memorial (docs/superpowers/specs/2026-11-16-wadoo-design.md
## §7): a sun-lily grows at the edge of garden_1, and anyone may lay one before
## the stones of those the beast killed. Holding a sun-lily and looking at a
## stone or the cairn, [F] Lay the lily: it lies on the ground before the
## next bare stone, its head toward it, between the stone and where a mourner
## kneels (WadooSite MEMORIAL_OUT), on the side away from its lamp, until each
## stone has one.
##
## An Area3D on the exterior props' layer (5, value 16), a box a little larger
## than each stone and a cylinder over the cairn, so the Interactor's ray finds
## it whichever you look at; it stops nothing. Built by PlaceField under the
## place's node at the memorial's middle. It knows nothing of the village: the
## flight scene answers `laid` (takes the lily from your hands, counts the task)
## and draws the count from WadooState (set_count).

signal laid(actor: Node)

const NAME := "MemorialLilies"
const LILY := &"sun_lily"
## A lily lies this far outside the stones' ring, m, ASIDE along the stone's
## face (its lamp is on the other side, OasisLooks.LAMP_ASIDE), and this high (its
## stem's radius, so it rests on the ground); the area is MARGIN larger than a
## stone all round.
const OUT := 0.4
const ASIDE := -0.15
const LIE := 0.05
const MARGIN := 0.12
## The lily's size as ItemLooks.sun_lily draws it.
const LILY_SIZE := Vector3(0.14, 0.32, 0.14)

var stones := 0
var count := 0
var lilies: Array[Node3D] = []

## The lilies of a memorial at `f` (its middle on the ground, place frame) of
## `stones` on a ring of `radius`; `feet` (place frame) is the ground before
## each stone, where its lily lies.
static func make(f: Transform3D, radius: float, p_stones: int, feet: PackedVector3Array) -> MemorialLilies:
	var m := MemorialLilies.new()
	m.name = NAME
	m.transform = f
	m.stones = p_stones
	m.collision_layer = 16
	m.collision_mask = 0
	m.monitoring = false
	m.add_to_group(&"interactable")
	var inv := f.affine_inverse()
	for k in p_stones:
		var d := OasisLooks.memorial_dir(k, p_stones)
		var stone := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = OasisLooks.MEMORIAL_STONE + Vector3.ONE * MARGIN * 2.0
		stone.shape = box
		stone.transform = Transform3D(Basis.looking_at(-d, Vector3.UP),
			d * radius + Vector3(0.0, OasisLooks.MEMORIAL_STONE.y * 0.5 - OasisLooks.MEMORIAL_SINK, 0.0))
		m.add_child(stone)
		var lily := Node3D.new()
		lily.name = "Lily_%d" % k
		var foot := inv * feet[k] if k < feet.size() else _off(d, radius)
		var head := Basis(Vector3.UP, 0.25 * sin(k * 2.3)) * -d
		lily.transform = Transform3D(Basis(head.cross(Vector3.UP), head, Vector3.UP), foot + Vector3(0.0, LIE, 0.0))
		var kit := OasisLooks.kit_under(lily)
		ItemLooks.sun_lily(kit, LILY_SIZE)
		kit.commit()
		m.add_child(lily)
		m.lilies.append(lily)
	var cairn := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.75
	cyl.height = 1.0
	cairn.shape = cyl
	cairn.position = Vector3(0.0, 0.5, 0.0)
	m.add_child(cairn)
	m.set_count(0)
	return m

## The ground before stone `k` of `stones` on a ring of `radius` round `middle`
## ([east, north] m): where its lily lies, as [east, north].
static func foot_of(middle: Vector2, radius: float, k: int, p_stones: int) -> Vector2:
	var off := _off(OasisLooks.memorial_dir(k, p_stones), radius)
	return middle + Vector2(off.x, -off.z)

## Lily's place off the middle, its stone the way `d`.
static func _off(d: Vector3, radius: float) -> Vector3:
	return d * (radius + OUT) + Vector3.UP.cross(d) * ASIDE

## Shows `n` lilies (no more than the stones), one before each of the first n.
func set_count(n: int) -> void:
	count = clampi(n, 0, stones)
	for k in lilies.size():
		lilies[k].visible = k < count

func prompt_text() -> String:
	return "Lay the lily"

## You hold a sun-lily and a stone is bare.
func can_interact(actor: Node) -> bool:
	return count < stones and Grasp.kind_in(actor) == LILY

func interact(actor: Node) -> void:
	if can_interact(actor):
		laid.emit(actor)
