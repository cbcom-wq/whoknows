class_name WeaponAim
extends RefCounted

## Where to fire a bolt so it meets a target (ship weapons spec §5.2). A bolt
## carries its shooter's velocity, so the solve is in the shooter's frame: the
## target moves at its velocity less the shooter's. The target is taken to
## hold its velocity; changing it is how you dodge.

## {dir, time}: the world direction to fire at `speed` and the seconds until
## the bolt meets the target; {} when it never can (it outruns the bolt, or is
## at the muzzle).
static func intercept(shooter: Vector3, shooter_v: Vector3, speed: float, target: Vector3,
		target_v: Vector3) -> Dictionary:
	var p := target - shooter
	var v := target_v - shooter_v
	var a := v.dot(v) - speed * speed
	var b := 2.0 * p.dot(v)
	var c := p.dot(p)
	if c < 1e-6:
		return {}
	var t := -1.0
	if absf(a) < 1e-6:
		if absf(b) > 1e-9:
			t = -c / b
	else:
		var disc := b * b - 4.0 * a * c
		if disc >= 0.0:
			var root := sqrt(disc)
			var t1 := (-b - root) / (2.0 * a)
			var t2 := (-b + root) / (2.0 * a)
			var lo := minf(t1, t2)
			var hi := maxf(t1, t2)
			t = lo if lo > 0.0 else hi
	if t <= 0.0:
		return {}
	var aim := p + v * t
	if aim.length_squared() < 1e-9:
		return {}
	return {"dir": aim.normalized(), "time": t}
