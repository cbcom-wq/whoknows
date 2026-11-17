class_name WadooCast
extends RefCounted

## The people of Wadoo (docs/superpowers/specs/2026-11-16-wadoo-design.md §4, §5):
## twenty-five adults, each a record with a name, a body (one of the Wadee models),
## a role, a home and the jobs they go to. Pure: the same layout always makes the
## same records, with ids "wadee:wadoo:<n>".
##
## The names are written out here rather than made from syllables by seed (the
## spec's word): as fixed, and they read as names.
##
## `model`: a, b, c women and m, n men of the village; q the queen; s, t a woman
## and a man of the Sunguard. `jobs` are spot kinds (WadooSite.spots): garden,
## pump, glass, breach, dry (Halla's dead garden), wash (at the pool's bank).
## `grief`: lost someone to the beast, so mourns at the memorial. `shy`: keeps
## 3 m from you. A Sunguard's `post` is the place they keep.

const SITE := &"wadoo"
## Every Wadee is of one herd, the town, so its director lists them together.
const HERD := 0
const ID := "wadee:wadoo:%d"

const PEOPLE := [
	{"name": "Imsa", "title": "Queen Imsa", "model": "q", "role": &"queen", "home": "house_b", "grief": true},
	{"name": "Kesh", "model": "s", "role": &"sunguard", "home": "house_b", "post": "breach_walk"},
	{"name": "Oru", "model": "t", "role": &"sunguard", "home": "house_b", "post": "queen_door"},
	{"name": "Tarro", "model": "t", "role": &"sunguard", "home": "house_b", "post": "gate"},
	{"name": "Seli", "model": "s", "role": &"sunguard", "home": "house_b", "post": "breach"},
	{"name": "Nadi", "model": "s", "role": &"sunguard", "home": "house_b", "post": "pool"},
	{"name": "Halla", "model": "c", "role": &"villager", "home": "home_3", "jobs": ["dry", "garden"], "grief": true},
	{"name": "Daro", "model": "m", "role": &"villager", "home": "hut_b", "jobs": ["glass", "breach"]},
	{"name": "Lio", "model": "a", "role": &"villager", "home": "house_a", "jobs": ["garden", "pump"], "grief": true,
		"takes": ["armlet", "armlet", "the armlet"]},
	{"name": "Wenna", "model": "b", "role": &"villager", "home": "home_4", "jobs": ["wash", "garden"], "heals": true},
	{"name": "Asha", "model": "a", "role": &"villager", "home": "house_d", "jobs": ["garden", "pump"]},
	{"name": "Dessa", "model": "c", "role": &"villager", "home": "hut_b", "jobs": ["breach", "glass"], "grief": true},
	{"name": "Ema", "model": "b", "role": &"villager", "home": "home_3", "jobs": ["garden", "pump"]},
	{"name": "Ilsa", "model": "a", "role": &"villager", "home": "house_a", "jobs": ["glass", "garden"]},
	{"name": "Jori", "model": "c", "role": &"villager", "home": "home_4", "jobs": ["pump", "breach"]},
	{"name": "Kaya", "model": "b", "role": &"villager", "home": "house_d", "jobs": ["garden", "wash"], "grief": true},
	{"name": "Mira", "model": "a", "role": &"villager", "home": "home_3", "jobs": ["pump", "garden"]},
	{"name": "Nesh", "model": "c", "role": &"villager", "home": "hut_b", "jobs": ["breach", "pump"], "shy": true},
	{"name": "Pema", "model": "b", "role": &"villager", "home": "house_a", "jobs": ["garden", "glass"]},
	{"name": "Sabi", "model": "a", "role": &"villager", "home": "home_4", "jobs": ["wash", "pump"]},
	{"name": "Tova", "model": "c", "role": &"villager", "home": "house_d", "jobs": ["garden", "breach"], "grief": true},
	{"name": "Yara", "model": "b", "role": &"villager", "home": "home_3", "jobs": ["pump", "glass"], "shy": true},
	{"name": "Ebo", "model": "n", "role": &"villager", "home": "house_a", "jobs": ["breach", "glass"], "shy": true},
	{"name": "Hami", "model": "m", "role": &"villager", "home": "home_4", "jobs": ["breach", "pump"], "grief": true},
	{"name": "Rusk", "model": "n", "role": &"villager", "home": "house_d", "jobs": ["glass", "breach"]},
]

## The species a role is.
static func species_of(role: StringName) -> StringName:
	match role:
		&"queen":
			return &"wadee_queen"
		&"sunguard":
			return &"wadee_sunguard"
	return &"wadee_villager"

static func count() -> int:
	return PEOPLE.size()

## Person `n`'s record: home at their house's middle on the place's plane.
static func record(n: int, layout: Dictionary) -> NpcRecord:
	var p: Dictionary = PEOPLE[n]
	var home := Vector3.ZERO
	for s: Dictionary in layout.get("shells", []):
		if str(s["id"]) == str(p["home"]):
			home = Vector3(float(s["at"][0]), 0.0, -float(s["at"][1]))
	return NpcRecord.make(StringName(ID % n), species_of(p["role"]), SITE, home, seed_of(n), HERD)

static func records(layout: Dictionary) -> Array[NpcRecord]:
	var out: Array[NpcRecord] = []
	for n in PEOPLE.size():
		out.append(record(n, layout))
	return out

static func seed_of(n: int) -> int:
	return hash("wadoo:%s" % PEOPLE[n]["name"]) & 0x7FFFFFFF

## Which person a record is, or -1.
static func index_of(id: StringName) -> int:
	var s := String(id)
	if not s.begins_with("wadee:wadoo:"):
		return -1
	var n := s.get_slice(":", 2).to_int()
	return n if n >= 0 and n < PEOPLE.size() else -1

## Person `n` as their look and mind read them: their entry, with `seed`,
## `staff` and `title` filled in.
static func person(n: int) -> Dictionary:
	var p: Dictionary = PEOPLE[n].duplicate()
	p["seed"] = seed_of(n)
	p["staff"] = p["role"] == &"sunguard"
	p["title"] = p.get("title", p["name"])
	p["jobs"] = p.get("jobs", [])
	p["grief"] = p.get("grief", false)
	p["shy"] = p.get("shy", false)
	return p

## Where `person` stands when the Sunguard gather at the breach (gather.gd): 0 for
## the first of them in PEOPLE (Kesh, their captain), and on; -1 for the queen's
## door warden, who stays at her door, and for anyone not of the Sunguard.
static func gather_slot(person: Dictionary) -> int:
	if person.get("role", &"") != &"sunguard" or str(person.get("post", "")) == "queen_door":
		return -1
	var slot := 0
	for p: Dictionary in PEOPLE:
		if p["role"] != &"sunguard" or str(p.get("post", "")) == "queen_door":
			continue
		if p["name"] == person.get("name", ""):
			return slot
		slot += 1
	return -1
