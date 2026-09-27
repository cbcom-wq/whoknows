class_name StatusPage
extends ComputerPage

## The ship itself (docs/superpowers/specs/2026-09-25-bridge-computer-design.md
## §7): your ship in miniature over the table, and its store, power and suit
## on the rim. It uses no button but PAGE.

func title() -> String:
	return "STATUS"

func lines(ctx: ComputerContext) -> PackedStringArray:
	return PackedStringArray([qe_line(ctx), power_line(ctx), suit_line(ctx)])

static func qe_line(ctx: ComputerContext) -> String:
	if ctx.store == null:
		return "QE --"
	if ctx.store.is_low_power():
		return "QE %d · LOW POWER" % ctx.store.amount
	return "QE %d / %d" % [ctx.store.amount, ctx.store.capacity]

## Generated against drawn: the core gives half in low power (quantum energy
## spec §3.1).
static func power_line(ctx: ComputerContext) -> String:
	if ctx.stats == null:
		return "POWER --"
	var gen := ctx.stats.power_gen
	if ctx.store != null and ctx.store.is_low_power():
		gen *= QuantumValues.LOW_POWER_AUTHORITY
	return "POWER %.1f / %.1f MW" % [gen, ctx.stats.power_draw]

## The suit of whoever pressed the table's buttons last.
static func suit_line(ctx: ComputerContext) -> String:
	var cell: SuitCell = null
	if ctx.operator != null and is_instance_valid(ctx.operator):
		cell = ctx.operator.get("suit_cell") as SuitCell
	if cell == null:
		return "SUIT --"
	return "SUIT %d%%" % roundi(cell.charge / SuitCell.CAPACITY * 100.0)

func holo(volume: HoloVolume, ctx: ComputerContext, _delta: float) -> void:
	volume.show_map_frame(false)
	volume.show_marks([])
	volume.show_bracket(Vector3.ZERO, 0.0, false)
	if not volume.miniature_shown() and ctx.exterior_builder != null:
		volume.show_miniature(ctx.exterior_builder.multimeshes(), ctx.exterior_builder.bounds())
