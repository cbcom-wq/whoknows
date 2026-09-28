class_name StarSystem
extends Node3D

## The star system as you see it (the system skeleton spec §3, §7): the only
## node that knows the system. It builds a BodyProxy per star, planet and
## moon, a BeltLook per belt, the space dust and Whereabouts, places every one
## each physics tick for where the focus is, and aims the sun from the star.
##
## The floating origin (CLAUDE.md): this node and its `Bodies` holder sit at
## the identity and never move; each proxy is a member of
## Universe.EXTERIOR_SPACE of its own, placed afresh every tick anyway.

var recipe: SystemRecipe
var universe: Universe
## The scene's sun, re-aimed every tick; null to leave it alone.
var sun: DirectionalLight3D
var proxies: Array[BodyProxy] = []
var belts: Array[BeltLook] = []
var dust: SpaceDust
var whereabouts: Whereabouts

var _bodies: Node3D
var _by_id := {}

func setup(p_recipe: SystemRecipe, p_universe: Universe, p_sun: DirectionalLight3D = null) -> void:
	recipe = p_recipe
	universe = p_universe
	sun = p_sun
	_bodies = Node3D.new()
	_bodies.name = "Bodies"
	add_child(_bodies)
	for b in recipe.bodies:
		var p := BodyProxy.new()
		p.setup(b)
		_bodies.add_child(p)
		proxies.append(p)
		_by_id[b.id] = p
	for k in recipe.belts.size():
		var look := BeltLook.new()
		look.name = "Belt%d" % k
		look.setup(recipe.belts[k], WorldSeed.sub(recipe.seed, StringName("belt_look_%d" % k)))
		add_child(look)
		belts.append(look)
	dust = SpaceDust.new()
	add_child(dust)
	whereabouts = Whereabouts.new()
	add_child(whereabouts)
	whereabouts.setup(recipe, universe)
	if sun != null:
		var palette: Dictionary = SpacePalette.STARS[recipe.star.star_palette]
		sun.light_color = palette[&"light"]
		sun.light_energy = palette[&"energy"]
	place_all()

func proxy(id: StringName) -> BodyProxy:
	return _by_id.get(id)

func _physics_process(_delta: float) -> void:
	place_all()

## Places every body, and the sun, for where the focus is now.
func place_all() -> void:
	if universe == null or not is_instance_valid(universe.focus) or not universe.focus.is_inside_tree():
		return
	var focus := universe.to_universe(universe.focus.global_position)
	for p in proxies:
		p.place(universe, focus)
	for b in belts:
		b.place(universe, focus)
	dust.density = whereabouts.dust()
	dust.place(universe, focus)
	if sun != null:
		aim_sun(sun, recipe.star.point, focus)

## Points `light` from the star at `star` towards `focus` (§7.6).
static func aim_sun(light: DirectionalLight3D, star: UniversePoint, focus: UniversePoint) -> void:
	var dir := focus.minus(star)
	if dir.is_zero_approx():
		return
	dir = dir.normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	light.global_basis = Basis.looking_at(dir, up)
