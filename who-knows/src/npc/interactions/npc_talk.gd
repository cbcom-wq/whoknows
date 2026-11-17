class_name NpcTalk
extends RefCounted

## The &"talk" interaction (docs/superpowers/specs/2026-11-16-wadoo-design.md §6):
## look at someone who talks, within the Interactor's reach, and [F] Talk to them.
## The body only routes it: what is said, and how it is shown, are the site's
## (NpcSite.can_talk, talk_name, talk).

const ID := &"talk"

static func can(npc: Npc, _actor: Node) -> bool:
	return not npc.down and npc.site.can_talk(npc)

static func prompt(npc: Npc) -> String:
	return "Talk to %s" % npc.site.talk_name(npc)

static func run(npc: Npc, actor: Node) -> void:
	npc.site.talk(npc, actor)
