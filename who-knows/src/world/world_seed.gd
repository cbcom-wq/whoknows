class_name WorldSeed
extends RefCounted

## Sub-seeds (docs/superpowers/specs/2026-09-23-planetfall-design.md §5.1):
## each concern of a seeded thing -- a world's terrain, its palette, a
## system's slots, one slot's moons -- draws from its own seed, so adding a
## knob later or reordering the draws within one concern never reshuffles any
## other. A world someone remembers stays that world.
##
## Hand-written, like AsteroidRecipe's cell hash: the engine's hash() is not
## promised to stay the same between engine versions.

## FNV-1a's 64-bit offset basis and prime, as signed 64-bit ints.
const _FNV_OFFSET := -3750763034362895579
const _FNV_PRIME := 1099511628211
## splitmix64's increment.
const _GOLDEN := -7046029254386353131

## The seed for `concern` of the thing seeded with `seed`: splitmix64 over
## `seed` XOR FNV-1a(`concern`).
static func sub(seed: int, concern: StringName) -> int:
	return AsteroidRecipe.mix((seed ^ fnv1a(String(concern))) + _GOLDEN)

## 64-bit FNV-1a over `text`'s UTF-8 bytes, with wrapping multiplies.
static func fnv1a(text: String) -> int:
	var h := _FNV_OFFSET
	for b in text.to_utf8_buffer():
		h ^= b
		h *= _FNV_PRIME
	return h

## A generator for `concern`.
static func rng(seed: int, concern: StringName) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = sub(seed, concern)
	return r

## FastNoiseLite takes a 32-bit seed: the sub-seed's low 31 bits.
static func noise_seed(sub_seed: int) -> int:
	return sub_seed & 0x7FFFFFFF
