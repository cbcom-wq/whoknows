class_name WorldNames
extends RefCounted

## Names for seeded places (docs/superpowers/specs/2026-09-23-planetfall-design.md
## §5.2): two or three syllables from a fixed table, and for a world a
## designation number, as in KORVA-7. A star's name is its syllables alone,
## and the system is named after it.

const SYLLABLES: Array[String] = [
	"KOR", "VA", "TES", "RIN", "AL", "DO", "MER", "SU", "NAX", "EL", "BRA", "TO",
	"VEL", "KA", "RU", "SEN", "OR", "LI", "MA", "ZE", "TAR", "O", "QUI", "HES",
	"DRA", "NU", "KES", "TREL", "VOSS", "IM", "PA", "LOR",
]
## A moon is its planet's name and one of these (KORVA-7 b).
const MOON_LETTERS := "bcdefg"

## Two or three syllables.
static func syllables(rng: RandomNumberGenerator) -> String:
	var count := 2 + rng.randi_range(0, 1)
	var out := ""
	for i in count:
		out += SYLLABLES[rng.randi_range(0, SYLLABLES.size() - 1)]
	return out

## A world's name: syllables and a designation number, 1 to 99.
static func world(rng: RandomNumberGenerator) -> String:
	return "%s-%d" % [syllables(rng), rng.randi_range(1, 99)]

## A star's name, and its system's.
static func star(rng: RandomNumberGenerator) -> String:
	return syllables(rng)

## The `k`th moon of `planet`, from 0.
static func moon(planet: String, k: int) -> String:
	return "%s %s" % [planet, MOON_LETTERS[k]]
