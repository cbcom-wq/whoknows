class_name HudElement
extends Control

## Base for everything the HUD draws -- the console band's readouts and the
## canopy's velocity marker alike.
##
## HudRoot pushes one snapshot per frame. A null snapshot means no vehicle is
## being piloted; elements that hold a last-good reading may simply ignore it,
## because HudRoot fades the whole layer out. Elements that draw world-derived
## geometry must stop drawing, since a stale reticle would point at a lie.

func render(_telemetry: VehicleTelemetry) -> void:
	pass
