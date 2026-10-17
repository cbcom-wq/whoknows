class_name ModuleDamage
extends RefCounted

## A base's damage (ship weapons spec §6.5): each module is a section of its
## own, its hp the sum of its blocks', its damage a number in its site entry
## ("damage"), so it sleeps and saves with the base. Pure. A wrecked module
## stops working until it is mended above wrecked; nothing breaks off.

static func part(index: int) -> StringName:
	return StringName("module:%d" % index)

static func index_of(p: StringName) -> int:
	var s := String(p)
	return s.substr(7).to_int() if s.begins_with("module:") else -1

static func hp(site: BaseSite, index: int, catalog: BlockCatalog) -> float:
	var total := 0.0
	var m: Dictionary = site.modules[index]
	for b: Array in ModuleCatalog.get_def(m["kind"]).turned(m["turns"]):
		var def := catalog.get_def(b[1])
		total += float(def.hp) if def != null else 0.0
	return total

static func taken(site: BaseSite, index: int) -> float:
	return float(site.modules[index].get("damage", 0.0))

static func stage(site: BaseSite, index: int, catalog: BlockCatalog) -> int:
	return BlockDamage.stage_at(taken(site, index), hp(site, index, catalog))

## Deals `amount`; true if the module's stage changed.
static func hit(site: BaseSite, index: int, amount: float, catalog: BlockCatalog) -> bool:
	if amount <= 0.0 or index < 0 or index >= site.modules.size():
		return false
	var before := stage(site, index, catalog)
	site.modules[index]["damage"] = minf(taken(site, index) + amount, hp(site, index, catalog))
	return stage(site, index, catalog) != before

## Mends `share` (0..1) of its hp; returns the share used.
static func repair(site: BaseSite, index: int, share: float, catalog: BlockCatalog) -> float:
	var total := hp(site, index, catalog)
	if total <= 0.0 or share <= 0.0:
		return 0.0
	var used := minf(share * total, taken(site, index))
	site.modules[index]["damage"] = taken(site, index) - used
	return used / total

## "DRILL 2": its kind and its number among its kind.
static func label(site: BaseSite, index: int) -> String:
	var kind: StringName = site.modules[index]["kind"]
	var n := 0
	for i in index + 1:
		if site.modules[i]["kind"] == kind:
			n += 1
	return "%s %d" % [ModuleCatalog.get_def(kind).display_name.to_upper(), n]

## The wrecked modules of `kind`.
static func wrecked(site: BaseSite, kind: StringName, catalog: BlockCatalog) -> Array[int]:
	var out: Array[int] = []
	for i in site.modules.size():
		if site.modules[i]["kind"] == kind and stage(site, i, catalog) == BlockDamage.Stage.WRECKED:
			out.append(i)
	return out
