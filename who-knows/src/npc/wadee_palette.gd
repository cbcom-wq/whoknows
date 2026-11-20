class_name WadeePalette
extends RefCounted

## The Wadees' colours (docs/superpowers/specs/2026-11-16-wadoo-design.md §11), the
## one place a Wadee's colour is chosen. A Wadee is one mesh whose UVs point at
## the texels of a SLOTS x 1 palette (tools/blender/wadee_rig.py SLOTS); the game
## builds that palette for each person from their seed and role, so five bodies
## dress as twenty-five people. Colours are sRGB, as an albedo texture reads them.

const SLOTS := 16
## The slots, in wadee_rig.py's order.
const SKIN := 0
const LIPS := 1
const HAIR := 2
const BROW := 3
const SCLERA_SLOT := 4
const IRIS_SLOT := 5
const PUPIL_SLOT := 6
const LASH_SLOT := 7
const CLOTH_1 := 8
const CLOTH_2 := 9
const CLOTH_3 := 10
const LEATHER_SLOT := 11
const BRONZE_SLOT := 12
const TURQUOISE_SLOT := 13
const SUNGLASS_SLOT := 14
const CAPE := 15

## Skin: warm browns, from deep to light.
const SKINS: Array[Color] = [Color("5e3a26"), Color("6b432c"), Color("714630"), Color("7a4c32"), Color("83553a"),
	Color("8d5b3c"), Color("925e3e"), Color("9a6644"), Color("a8714c"), Color("b07a52")]
## Hair: near-black to dark brown.
const HAIRS: Array[Color] = [Color("0f0a08"), Color("17100c"), Color("1e140e"), Color("2a1a12"), Color("3a2416"),
	Color("4e2e1a")]
## Lips take this much of LIP_TINT over the skin.
const LIP_TINT := Color("8a3b33")
const LIP_SHARE := 0.4
## Eyes.
const SCLERA := Color("ece6dc")
const IRISES: Array[Color] = [Color("3a2414"), Color("4a2c18"), Color("5a3820")]
const PUPIL := Color("100a07")
const LASH := Color("140d09")
## Cloth, the outfit set: cream, rust and teal (the concept), and their kin.
const CLOTHS: Array[Color] = [Color("e4d3b6"), Color("8e4a2b"), Color("3d8787"), Color("c08a3a"), Color("3b4a78"),
	Color("c9b08a"), Color("a5553a"), Color("6b6b3a"), Color("2f6b6e"), Color("d0a24a")]
## The Sunguard wear the same: rust, cream and teal.
const SUNGUARD_CLOTH: Array[Color] = [Color("7e3a22"), Color("e4d3b6"), Color("2f6b6e")]
## The queen: cream, deep teal and saffron, and a royal cape.
const QUEEN_CLOTH: Array[Color] = [Color("efe2c8"), Color("2f6b6e"), Color("d0a24a")]
const ROYAL := Color("5a2a4a")
const LEATHER := Color("5e3f2b")
const BRONZE := Color("b5803e")
## Water stone: they wear it for the oasis.
const TURQUOISE := Color("3fb3a6")
## Sunglass: sand made glass and filled with sun.
const SUNGLASS := Color("ffc94a")

## The Wadees' rooms (WadooRooms, tools/blender/wadoo_rooms.py), by the room
## model's material names: pale stone, dark wood, their cloths and metals, the
## basin's water, and the woven map's sand, dunes and red thread; the
## Glassworks' clear glass (rods, bottles), pale sea-green, and the kiln's ember.
const ROOM := {
	"stone": Color("c9b79a"), "stone_dark": Color("9e8d73"), "wood": Color("5a3a24"), "bronze": BRONZE,
	"sunglass": SUNGLASS, "royal": ROYAL, "teal": Color("2f6b6e"), "rust": Color("8e4a2b"), "cream": Color("e4d3b6"),
	"saffron": Color("d0a24a"), "turquoise": TURQUOISE, "water": Color("3f7664"), "map_sand": Color("d8b98a"),
	"map_dune": Color("a8805a"), "map_red": Color("a52a22"), "clay": Color("a8653f"), "glass": Color("9fd1c7"),
	"ember": Color("ff8a3a"),
}
## A room's sunglass lamps: their light, as a lamp's glow (InteriorPalette's rule:
## warm practical lights).
const LAMP := Color("ffc06a")
## The Glassworks' kiln: the light from its mouth, hotter and redder than a lamp.
const KILN := Color("ff9a52")

## A sun-lily's petals (ItemLooks.sun_lily): pale gold, as the sun at its edge.
const LILY := Color("f0dca0")

## Roughness and metal per slot (surface()).
const ROUGH_SKIN := 0.55
const ROUGH_CLOTH := 0.9
const ROUGH_EYE := 0.25
const ROUGH_BRONZE := 0.35
const METAL_BRONZE := 0.8
const ROUGH_STONE := 0.3

## The SLOTS colours of the person with `seed` and `role` (&"villager",
## &"sunguard", &"queen"), by slot.
static func colours(seed: int, role: StringName) -> PackedColorArray:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed) & 0x7FFFFFFF
	var out := PackedColorArray()
	out.resize(SLOTS)
	var skin: Color = SKINS[rng.randi_range(0, SKINS.size() - 1)]
	var hair: Color = HAIRS[rng.randi_range(0, HAIRS.size() - 1)]
	out[SKIN] = skin
	out[LIPS] = skin.lerp(LIP_TINT, LIP_SHARE)
	out[HAIR] = hair
	out[BROW] = hair
	out[SCLERA_SLOT] = SCLERA
	out[IRIS_SLOT] = IRISES[rng.randi_range(0, IRISES.size() - 1)]
	out[PUPIL_SLOT] = PUPIL
	out[LASH_SLOT] = LASH
	var cloth := _cloths(rng, role)
	out[CLOTH_1] = cloth[0]
	out[CLOTH_2] = cloth[1]
	out[CLOTH_3] = cloth[2]
	out[LEATHER_SLOT] = LEATHER
	out[BRONZE_SLOT] = BRONZE
	out[TURQUOISE_SLOT] = TURQUOISE
	out[SUNGLASS_SLOT] = SUNGLASS
	out[CAPE] = ROYAL
	return out

## Three different cloths for a villager; the Sunguard's and the queen's are set.
static func _cloths(rng: RandomNumberGenerator, role: StringName) -> Array[Color]:
	if role == &"sunguard":
		return SUNGUARD_CLOTH
	if role == &"queen":
		return QUEEN_CLOTH
	var picks: Array[Color] = []
	var left := CLOTHS.duplicate()
	for k in 3:
		picks.append(left.pop_at(rng.randi_range(0, left.size() - 1)))
	return picks

## The palette texture of a person: SLOTS x 1, RGBA8.
static func image(seed: int, role: StringName) -> Image:
	var img := Image.create(SLOTS, 1, false, Image.FORMAT_RGBA8)
	var c := colours(seed, role)
	for k in SLOTS:
		img.set_pixel(k, 0, c[k])
	return img

## How each slot meets light, the same for everyone: SLOTS x 1, its green the
## roughness and its blue the metal (StandardMaterial3D's channels).
static func surface() -> Image:
	var img := Image.create(SLOTS, 1, false, Image.FORMAT_RGBA8)
	for k in SLOTS:
		var rough := ROUGH_CLOTH
		var metal := 0.0
		match k:
			SKIN, LIPS:
				rough = ROUGH_SKIN
			SCLERA_SLOT, IRIS_SLOT, PUPIL_SLOT:
				rough = ROUGH_EYE
			BRONZE_SLOT:
				rough = ROUGH_BRONZE
				metal = METAL_BRONZE
			TURQUOISE_SLOT, SUNGLASS_SLOT:
				rough = ROUGH_STONE
		img.set_pixel(k, 0, Color(0.0, rough, metal, 1.0))
	return img
