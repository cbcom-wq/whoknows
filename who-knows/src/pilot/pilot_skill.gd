class_name PilotSkill
extends RefCounted

## One pilot's skill, 0 novice to 1 ace, as the knobs it sets (hostile ships
## spec §5.4). Aim is not a knob: the turrets aim themselves for everyone.

var skill: float
## How long after bolts appear it starts a jink, s.
var reaction: float
## How hard it jinks, as a share of its lateral thrust.
var jink_share: float
## How often it jinks while in the target's range, s.
var jink_every: float
## How well it keeps the range it wants and the face that bears.
var position_gain: float
## How far its read of the fight may be off: the brawl score is scaled by 1 ± this.
var noise: float
## Past this share of its reach it holds fire, unless the store is full enough.
var hold_fire_past: float

func _init(p_skill: float = 0.5) -> void:
	skill = clampf(p_skill, 0.0, 1.0)
	reaction = lerpf(1.0, 0.2, skill)
	jink_share = lerpf(0.4, 1.0, skill)
	jink_every = lerpf(2.5, 0.8, skill)
	position_gain = lerpf(0.4, 1.0, skill)
	noise = lerpf(PilotValues.NOISE_AT_ZERO, 0.0, skill)
	hold_fire_past = lerpf(1.0, 0.75, skill)
