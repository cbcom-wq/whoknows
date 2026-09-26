class_name QuantumPlant
extends Node

## Owns the ship's quantum store and drives its core(s) and machine(s) from it
## (quantum energy spec §3.2, §7, §8): the one place live QE state lives, at
## Ship/Quantum. A rebuild frees every QuantumCore and QuantumMachine (Task
## 3's dressing) and builds new ones, so the plant outlives them all -- bind()
## again with whatever the rebuild produced and the store carries on
## unbothered.
##
## `flight_computer` is polled each physics tick for whether boost is
## actually applying right now, exactly the way RcsShow polls
## FlightComputer's commanded_force_local rather than being told about it
## (spec §8's "the core's state follows the store and boost"). Ship wires
## it once, in _ready(), alongside creating this node -- with `items`, where
## the machines' made items go, and `item_catalog`, what they can make.
##
## Each machine runs a MachineCycle, kept here by the machine's cell so a
## rebuild never drops an item mid-conversion (spec §7.4). The plant applies
## its cues: the credit as the bead arrives, the debit as a make starts, the
## made item into the bay, the show and the sounds. While the machine works,
## the item it is converting or making is in its grip -- HELD, so nothing
## takes it -- and the bay takes nothing else.
##
## Each machine's charge plate charges a suit from the store (spec §7.3, §9):
## pressed, it moves CHARGE_RATE QE a second into the presser's `suit_cell`,
## one for one, down to 0 and in low power too, while they stay within the
## plate's reach -- the screen counting up, the plate glowing and a tone
## rising. A charge is kept by the machine's cell, so a rebuild never stops it.

signal low_power_changed(low: bool)
## A credit landed: how much, and from where (spec §3.2's sources):
## &"pilot", &"convert"; later the hose.
signal credited(amount: int, source: StringName)

## The big button's colours (MachineCycle.button_colour) as ReadoutPanel's
## lit states; anything else is dark.
const PANEL_STATES := {&"SIGNAL_GO": &"go", &"AMBER": &"cycling", &"CORAL": &"vacuum"}
## The core's hum (spec §13): positional at the core, on the Ship bus, and
## capped below the ship's own hum (-16 dB) however close you stand, so the
## bridge stays calm.
const HUM_DB := -24.0
const HUM_MAX_DB := -20.0
## The hum's pitch while boosting, and how fast it slides there and back.
const HUM_BOOST_PITCH := 1.25
const HUM_SLIDE := 0.5
## The machine's positional players, as the airlock's.
const PLAYER_UNIT_SIZE := 3.0
const PLAYER_MAX_DISTANCE := 30.0
## The charge plate (spec §7.3): QE a second into the suit.
const CHARGE_RATE := 50.0
## The charge tone's pitch from an empty suit to a full one: it rises as the
## suit fills.
const CHARGE_PITCH_FROM := 0.8
const CHARGE_PITCH_TO := 1.6
## A fraction owed this close to a whole QE is that whole QE: the owed sum
## gathers float error tick by tick.
const OWED_SNAP := 1e-6

var store: QuantumStore
var cores: Array[QuantumCore] = []
var machines: Array[QuantumMachine] = []
var flight_computer: FlightComputer
## Where made items go: the ship's items (Ship.items).
var items: Node3D
## What the machines can make from (Ship.item_catalog).
var item_catalog: ItemCatalog
## One MachineCycle per machine, by the machine's cell, across rebuilds.
var cycles: Dictionary = {}   # Vector3i -> MachineCycle

var _last_state: StringName = &""
var _makeable: Array = []
var _makeable_from: ItemCatalog = null
## Per machine cell: the item in the machine's grip while it converts or
## makes (it lives in `items`, so a rebuild leaves it be), the show, the
## positional players, and the screen as last written.
var _held: Dictionary = {}   # Vector3i -> Item
var _shows: Dictionary = {}   # Vector3i -> QuantumShow
var _players: Dictionary = {}   # Vector3i -> {StringName: AudioStreamPlayer3D}
var _written: Dictionary = {}   # Vector3i -> Array
## Per core: its hum.
var _hums: Dictionary = {}   # QuantumCore -> AudioStreamPlayer3D
## Per machine cell: whoever its plate is charging.
var _charges: Dictionary = {}   # Vector3i -> Node3D
## QE a suit has taken that the store has not yet paid for: always under one.
## The store pays in whole QE (spec §3.2), so a fraction waits for the next.
var _charge_owed := 0.0

## Sets the capacity from the ship's blocks, drives every core from the
## result, and -- on the very first bind only -- starts the store at half
## capacity (spec §3.2). Later binds (a rebuild, or a capacity change) keep
## the same store and its amount, merely clamped to the new capacity. Each
## machine keeps its cycle, and gets a fresh show, players and wiring.
func bind(new_cores: Array[QuantumCore], new_machines: Array[QuantumMachine], stats: ShipStats) -> void:
	cores = new_cores
	machines = new_machines
	if store == null:
		store = QuantumStore.new(stats.quantum_capacity, stats.quantum_capacity / 2)
		store.changed.connect(_on_store_changed)
		store.low_power_changed.connect(func(low: bool) -> void: low_power_changed.emit(low))
	else:
		store.set_capacity(stats.quantum_capacity)
	_bind_machines()
	_bind_hums()
	_drive_cores()

func _physics_process(delta: float) -> void:
	tick(delta)

## Advances everything by `delta`: the pilot light, each machine's cycle, the
## cores and their hum. Called every physics tick; tests call it directly.
func tick(delta: float) -> void:
	if store == null:
		return
	var before := store.amount
	store.tick(delta)
	if store.amount != before:
		credited.emit(store.amount - before, &"pilot")
	for machine in machines:
		if is_instance_valid(machine):
			_tick_machine(machine, delta)
	_drive_cores()
	_update_hums(delta)

## The positional player `key` (&"bay" or &"panel") of the machine at `cell`.
func player(cell: Vector3i, key: StringName) -> AudioStreamPlayer3D:
	return _players.get(cell, {}).get(key)

## The hum playing at `core`.
func hum(core: QuantumCore) -> AudioStreamPlayer3D:
	return _hums.get(core)

## The show of the machine at `cell`.
func machine_show(cell: Vector3i) -> QuantumShow:
	return _shows.get(cell)

func _on_store_changed(_amount: int, _capacity: int) -> void:
	_drive_cores()

## The gauge follows the store every tick; the state (full/boost/low_power)
## only when it actually changes, so an unchanging state never re-triggers
## QuantumCore.set_state()'s per-call bookkeeping (spec §8; until Task 11
## this is the whole of it -- no dimming, no restore show).
func _drive_cores() -> void:
	if store == null or store.capacity <= 0:
		return
	var fraction := float(store.amount) / float(store.capacity)
	var line_fraction := float(store.line()) / float(store.capacity)
	for core in cores:
		core.set_fill(fraction, line_fraction)
	var state: StringName = &"boost" if _boosting() else (&"low_power" if store.is_low_power() else &"full")
	if state != _last_state:
		_last_state = state
		for core in cores:
			core.set_state(state)

func _boosting() -> bool:
	return flight_computer != null and flight_computer.boosting

# --- the machines (spec §7) ---------------------------------------------------

## Hands each rebuilt machine its cycle (a new one for a new cell), a show,
## players and its buttons' wiring. A machine whose cell is gone drops its
## cycle, and lets go whatever it had in its grip, whole.
func _bind_machines() -> void:
	_shows.clear()
	_players.clear()
	_written.clear()
	var seen := {}
	for machine in machines:
		var cell := machine.cell
		seen[cell] = true
		var cycle: MachineCycle = cycles.get(cell)
		if cycle == null:
			cycle = MachineCycle.new()
			cycles[cell] = cycle
		var show := machine.get_node_or_null(^"QuantumShow") as QuantumShow
		if show == null:
			show = QuantumShow.new()
			show.setup(machine.bay.transform, machine.conduit_path, InteriorKit.LAYER)
			machine.add_child(show)
		_shows[cell] = show
		_players[cell] = {
			&"bay": _player(machine, "Sound_bay", machine.bay.position),
			&"panel": _player(machine, "Sound_panel", machine.panel.position),
			&"plate": _player(machine, "Sound_plate", machine.plate.position),
		}
		for button: ReadoutPanel in [machine.panel, machine.prev_button, machine.next_button]:
			button.prompt_source = cycle.prompt.bind(button.role)
			var on_pressed := _on_pressed.bind(cell, button)
			if not button.pressed.is_connected(on_pressed):
				button.pressed.connect(on_pressed)
		machine.plate.prompt_source = _plate_prompt
		var on_plate := _on_plate_pressed.bind(cell)
		if not machine.plate.pressed.is_connected(on_plate):
			machine.plate.pressed.connect(on_plate)
		machine.bay.busy = cycle.stage != MachineCycle.Stage.IDLE
	for cell in cycles.keys():
		if not seen.has(cell):
			cycles.erase(cell)
			_charges.erase(cell)
			var item: Item = _held.get(cell)
			_held.erase(cell)
			if is_instance_valid(item):
				QuantumShow.swell(item, 1.0)
				item.set_loose()

func _makeable_list() -> Array:
	if item_catalog != _makeable_from:
		_makeable_from = item_catalog
		_makeable = QuantumValues.makeable(item_catalog) if item_catalog != null else []
	return _makeable

func _tick_machine(machine: QuantumMachine, delta: float) -> void:
	var cell := machine.cell
	var cycle: MachineCycle = cycles[cell]
	var bay := machine.bay
	var stowed: Item = null if bay.is_free() else bay.item
	var cues := cycle.step(delta, stowed.definition.id if stowed != null else &"",
		stowed.definition.quantum_value if stowed != null else 0, store, _makeable_list())
	for cue in cues:
		_apply(machine, cycle, cue)
	bay.busy = cycle.stage != MachineCycle.Stage.IDLE
	bay.hold_turn(delta)
	_show(machine, cycle)
	_charge(machine, delta)
	_write(machine, cycle)

## Does what a cue means (spec §7.1-§7.2, §7.5).
func _apply(machine: QuantumMachine, cycle: MachineCycle, cue: StringName) -> void:
	var cell := machine.cell
	var bay := machine.bay
	var show: QuantumShow = _shows[cell]
	match cue:
		&"convert_start":
			# Into the machine's grip: no Take prompt, and nothing else goes in.
			var item := bay.item
			bay.item = null
			item.set_held()
			_held[cell] = item
			_play(cell, &"bay", &"convert")
		&"bead":
			show.run_bead(MachineCycle.BEAD_TIME)
			show.flash()
		&"credited":
			var item: Item = _held.get(cell)
			_held.erase(cell)
			if store.credit(cycle.value, &"convert"):
				credited.emit(cycle.value, &"convert")
				var core := _core_at_end_of(machine)
				if core != null:
					core.flash()
				if is_instance_valid(item):
					Item.consume(item)
			elif is_instance_valid(item):
				# The store filled while the bead ran (another machine, say): the
				# item comes back whole rather than being wasted.
				QuantumShow.swell(item, 1.0)
				bay.secure(item)
				_play(cell, &"panel", &"warning_chime")
		&"make_start":
			var def := cycle.making
			if not store.spend(cycle.value, &"make"):
				push_error("QuantumPlant: a make the cycle allowed could not be paid for")
				return
			var item := Item.new()
			var at := bay.global_position
			item.setup(def, fposmod(at.x * 0.37 + at.z * 0.61, 1.0))
			item.set_held()
			QuantumShow.swell(item, 0.0)
			(items if items != null else machine).add_child(item, true)
			item.global_transform = bay.item_transform(item)
			_held[cell] = item
			_play(cell, &"bay", &"materialize")
		&"materialized":
			var item: Item = _held.get(cell)
			_held.erase(cell)
			if is_instance_valid(item):
				QuantumShow.swell(item, 1.0)
				bay.busy = false
				bay.secure(item)
			show.flash()
		&"refused":
			_play(cell, &"panel", &"warning_chime")

## The show follows the cycle each tick, so a rebuilt show picks up where
## the old one was: sparkles while it works, and the item in its grip turning
## at the bay's centre as it shrinks away or swells in.
func _show(machine: QuantumMachine, cycle: MachineCycle) -> void:
	var cell := machine.cell
	var show: QuantumShow = _shows[cell]
	show.sparkle(cycle.stage != MachineCycle.Stage.IDLE)
	var item: Item = _held.get(cell)
	if not is_instance_valid(item):
		return
	item.global_transform = machine.bay.item_transform(item)
	if cycle.stage == MachineCycle.Stage.CONVERTING:
		QuantumShow.shrink(item, cycle.elapsed / (MachineCycle.CONVERT_TIME - MachineCycle.BEAD_TIME))
	elif cycle.stage == MachineCycle.Stage.MAKING:
		QuantumShow.swell(item, cycle.elapsed / MachineCycle.MAKE_TIME)

## The screen over the bay, the big button's colour and the arrows, written
## only when they change. While the plate charges a suit, the screen counts
## the charge up instead (spec §7.3).
func _write(machine: QuantumMachine, cycle: MachineCycle) -> void:
	var suit := _suit_of(_charges.get(machine.cell))
	var lines := charge_screen(_percent(suit), store.amount) if suit != null else cycle.screen()
	var state: StringName = PANEL_STATES.get(cycle.button_colour(), &"")
	var prev := &"go" if cycle.prompt(&"prev") != "" else &""
	var next := &"go" if cycle.prompt(&"next") != "" else &""
	var shown := [lines, state, prev, next]
	if _written.get(machine.cell) == shown:
		return
	_written[machine.cell] = shown
	machine.panel.set_readout(lines, state)
	machine.prev_button.set_readout(PackedStringArray(), prev)
	machine.next_button.set_readout(PackedStringArray(), next)

## A button pressed: the cycle acts on it at its next step, and the button
## beeps where it is.
func _on_pressed(role: StringName, cell: Vector3i, button: ReadoutPanel) -> void:
	var cycle: MachineCycle = cycles.get(cell)
	if cycle == null:
		return
	cycle.press(role)
	var beep := player(cell, &"panel")
	if beep != null:
		beep.position = button.position
	_play(cell, &"panel", &"panel_beep")

## The core whose crown the machine's conduit runs into, or null.
func _core_at_end_of(machine: QuantumMachine) -> QuantumCore:
	if machine.conduit_path.is_empty():
		return null
	var end := machine.conduit_path[machine.conduit_path.size() - 1]
	for core in cores:
		if is_instance_valid(core) and core.crown().distance_to(end) < 0.01:
			return core
	return null

## A positional player on the Ship bus under `parent`, at `at` -- the one
## already there, if `parent` has one of that name.
func _player(parent: Node3D, player_name: String, at: Vector3) -> AudioStreamPlayer3D:
	var p := parent.get_node_or_null(player_name) as AudioStreamPlayer3D
	if p != null:
		return p
	p = AudioStreamPlayer3D.new()
	p.name = player_name
	p.bus = AudioBuses.SHIP
	p.unit_size = PLAYER_UNIT_SIZE
	p.max_distance = PLAYER_MAX_DISTANCE
	p.position = at
	parent.add_child(p)
	return p

func _play(cell: Vector3i, key: StringName, sound_name: StringName) -> void:
	var p := player(cell, key)
	var s := Synth.sound(sound_name)
	if p == null or s == null or not p.is_inside_tree():
		return
	p.stream = s
	p.play()

# --- the charge plate (spec §7.3, §9) ---------------------------------------------

## What pressing a plate would do for `actor`: *Charge suit (+n QE)*, n being
## what the suit will take or, if less, all the store can give; *Suit
## charged* when it is full; *Store empty* when the store has nothing to
## give. "" for anyone without a suit.
func plate_prompt(actor: Variant) -> String:
	var suit := _suit_of(actor)
	if suit == null or store == null:
		return ""
	if suit.room() <= 0.0:
		return "Suit charged"
	if not _can_charge(suit):
		return "Store empty"
	return "Charge suit (+%d QE)" % maxi(roundi(minf(suit.room(), _can_give())), 1)

## The machine's screen while its plate charges a suit `percent` full, over a
## store of `stored` QE.
static func charge_screen(percent: int, stored: int) -> PackedStringArray:
	return PackedStringArray(["CHARGE · SUIT", "SUIT %d%%" % percent, "STORE %d QE" % stored])

## The plates prompt for whoever would press them.
func _plate_prompt() -> String:
	return plate_prompt(_presser())

## Whoever would press a plate: the avatar.
func _presser() -> Node:
	return get_tree().get_first_node_in_group(Avatar.GROUP) if is_inside_tree() else null

## True while pressing a plate would charge `suit`: it has room, and the store
## has something to give.
func _can_charge(suit: SuitCell) -> bool:
	return suit != null and store != null and suit.room() > 0.0 and _can_give() > 0.0

## A plate pressed by `actor`: its charge starts, at the next tick. A full
## suit is told so with the small chime, and an empty store with the warning.
## One suit charges at one plate at a time.
func _on_plate_pressed(actor: Node, cell: Vector3i) -> void:
	var suit := _suit_of(actor)
	if suit == null or store == null:
		return
	if suit.room() <= 0.0:
		_play(cell, &"plate", &"panel_beep")
		return
	if not _can_charge(suit):
		_play(cell, &"plate", &"warning_chime")
		return
	for other: Vector3i in _charges.keys():
		if _charges[other] == actor:
			_end_charge(other, &"")
	_charges[cell] = actor

## Moves QE from the store into the suit charging at `machine`'s plate:
## CHARGE_RATE a second, one for one, down to 0 and in low power too (spec
## §3.2), while its wearer stays within the plate's reach. The store pays in
## whole QE, and any fraction is owed (_charge_owed). The charge ends when the
## suit is full (the small chime), when the store has nothing left to give
## (the warning), or as soon as you step away; stepping back does not restart
## it. Then the plate shows what it is doing.
func _charge(machine: QuantumMachine, delta: float) -> void:
	var cell := machine.cell
	var actor = _charges.get(cell)   # untyped: it may have been freed since
	var suit := _suit_of(actor)
	if _charges.has(cell) and (suit == null or not machine.plate.within_reach(actor)):
		_end_charge(cell, &"")
		suit = null
	if suit != null:
		var give := _can_give()
		var want := minf(CHARGE_RATE * delta, suit.room())
		if want >= give:
			# All the store has left: settle exactly, to the last QE.
			suit.add(maxf(give, 0.0))
			_charge_owed = float(store.amount)
		else:
			_charge_owed += suit.add(want)
		var whole := mini(floori(_charge_owed + OWED_SNAP), store.amount)
		store.spend(whole, &"suit")
		_charge_owed = maxf(_charge_owed - whole, 0.0)
		if suit.room() <= 0.0:
			_end_charge(cell, &"panel_beep")
		elif _can_give() <= 0.0:
			_end_charge(cell, &"warning_chime")
	_show_plate(machine)

## Lit and glowing while it charges, the tone rising with the suit; lit while
## a press would charge; dark otherwise.
func _show_plate(machine: QuantumMachine) -> void:
	var cell := machine.cell
	var suit := _suit_of(_charges.get(cell))
	if suit == null:
		machine.plate.set_readout(-1)
		machine.plate.set_lit(_can_charge(_suit_of(_presser())))
		return
	machine.plate.set_readout(_percent(suit))
	machine.plate.set_lit(true)
	var tone := player(cell, &"plate")
	if tone == null:
		return
	tone.pitch_scale = lerpf(CHARGE_PITCH_FROM, CHARGE_PITCH_TO, suit.charge / SuitCell.CAPACITY)
	var s := Synth.sound(&"charge")
	if s != null and (tone.stream != s or not tone.playing) and tone.is_inside_tree():
		tone.stream = s
		tone.play()

## Ends the charge at `cell`: the tone stops, and `chime` (if any) sounds.
func _end_charge(cell: Vector3i, chime: StringName) -> void:
	_charges.erase(cell)
	var tone := player(cell, &"plate")
	if tone != null:
		tone.stop()
		tone.pitch_scale = 1.0
	if chime != &"":
		_play(cell, &"plate", chime)

## How much the store can still give a suit: what it holds, less what is owed.
func _can_give() -> float:
	return float(store.amount) - _charge_owed

## How full `suit` is, in whole percent, never rounded up.
static func _percent(suit: SuitCell) -> int:
	return floori(suit.charge * 100.0 / SuitCell.CAPACITY)

## The suit `actor` wears, or null -- for no actor, one freed since it
## pressed, or one without a suit.
static func _suit_of(actor: Variant) -> SuitCell:
	if not is_instance_valid(actor):
		return null
	return actor.get(&"suit_cell") as SuitCell

# --- the core's hum (spec §13) ------------------------------------------------

func _bind_hums() -> void:
	_hums.clear()
	for core in cores:
		var p := _player(core, "Hum", InteriorProps.QUANTUM_HEART)
		p.volume_db = HUM_DB
		p.max_db = HUM_MAX_DB
		_hums[core] = p

## Starts each hum once its sound is built, and slides its pitch up while
## boosting and back after.
func _update_hums(delta: float) -> void:
	var pitch := HUM_BOOST_PITCH if _boosting() else 1.0
	for core: QuantumCore in _hums:
		var p: AudioStreamPlayer3D = _hums[core]
		if not is_instance_valid(p):
			continue
		p.pitch_scale = move_toward(p.pitch_scale, pitch, HUM_SLIDE * delta)
		if not p.playing and p.is_inside_tree():
			var s := Synth.sound(&"core_hum")
			if s != null:
				p.stream = s
				p.play()
