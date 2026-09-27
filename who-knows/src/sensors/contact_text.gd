class_name ContactText
extends RefCounted

## How far a contact is, in the few capitalised words a screen or the HUD
## shows (docs/superpowers/specs/2026-09-25-bridge-computer-design.md §5.2,
## §6.1). `metres` is from the viewer to the contact's point. A big rock is as
## far as its surface; a ping says only its rounded kilometres, so it never
## gives away more than the sensors know; a region is as far as its edge.
## Pure.

static func distance(contact: Contact, metres: float) -> String:
	match contact.precision:
		Contact.PING:
			return "~%d KM" % contact.km
		Contact.REGION:
			var to_edge := metres - contact.radius
			return "HERE" if to_edge <= 0.0 else _metres(to_edge)
	return _metres(maxf(metres - contact.radius, 0.0))

static func line(contact: Contact, metres: float) -> String:
	return "%s · %s" % [contact.label, distance(contact, metres)]

static func _metres(m: float) -> String:
	if m < 1000.0:
		return "%d M" % (roundi(m / 10.0) * 10)
	return "%.1f KM" % (m / 1000.0)
