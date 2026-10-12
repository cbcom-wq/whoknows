class_name SkyMap
extends RefCounted

## Which way a turret can fire without its own ship in the way (ship weapons
## spec §3.3): each direction of a SKY_YAW × SKY_PITCH grid over the half-sky
## above its mount face, marched from its muzzle through the ship's layout,
## every cell a cube, out to SKY_REACH. Pure, so ShipRules asks it too. A
## ship builds one per turret from its launch layout: a piece lost only opens
## the sky, and the ray each shot casts catches the rest.
##
## The mount frame: +y the face's normal, -z its forward (the hull's forward,
## or its up for a turret on a bow or a stern face). Yaw is 0 ahead and grows
## to the right; elevation is 0 along the face and PI/2 straight out.

var coord := Vector3i.ZERO
var normal := Vector3i.UP
## The mount frame in the hull's axes.
var basis := Basis.IDENTITY
## The muzzle, hull-local.
var origin := Vector3.ZERO
## 1 clear, 0 blocked, by yaw_i * SKY_PITCH + elevation_i.
var bits := PackedByteArray()

## The face a block of `orientation` stands on: its up, rounded.
static func normal_of(orientation: int) -> Vector3i:
	var up := BlockOrientation.basis_for(orientation) * Vector3.UP
	return Vector3i(roundi(up.x), roundi(up.y), roundi(up.z))

static func mount_basis(n: Vector3i) -> Basis:
	var up := Vector3(n)
	var forward := Vector3.FORWARD if absf(up.z) < 0.5 else Vector3.UP
	return Basis.looking_at(forward, up).orthonormalized()

## Where a turret on `coord`'s `n` face fires from, hull-local: the barrels'
## pivot, MUZZLE_UP off the face.
static func muzzle(p_coord: Vector3i, n: Vector3i) -> Vector3:
	return ShipGrid.cell_center(p_coord) + Vector3(n) * (WeaponValues.FACE_OUT + WeaponValues.MUZZLE_UP)

static func build(layout: ShipGrid, p_coord: Vector3i, n: Vector3i) -> SkyMap:
	var m := SkyMap.new()
	m.coord = p_coord
	m.normal = n
	m.basis = mount_basis(n)
	m.origin = muzzle(p_coord, n)
	m.bits.resize(WeaponValues.SKY_YAW * WeaponValues.SKY_PITCH)
	var steps := int(WeaponValues.SKY_REACH / WeaponValues.SKY_STEP)
	for yi in WeaponValues.SKY_YAW:
		for ei in WeaponValues.SKY_PITCH:
			var dir := m.basis * direction(yi, ei)
			m.bits[yi * WeaponValues.SKY_PITCH + ei] = 1 if _clear(layout, p_coord, m.origin, dir, steps) else 0
	return m

static func _clear(layout: ShipGrid, own: Vector3i, from: Vector3, dir: Vector3, steps: int) -> bool:
	for k in range(1, steps + 1):
		var p := from + dir * (k * WeaponValues.SKY_STEP)
		var cell := Vector3i((p / ShipGrid.CELL_SIZE).round())
		if cell != own and layout.has_block(cell):
			return false
	return true

## The centre of bin (yaw_i, elevation_i), a mount-frame unit vector.
static func direction(yi: int, ei: int) -> Vector3:
	var yaw := (yi + 0.5) / WeaponValues.SKY_YAW * TAU - PI
	var el := (ei + 0.5) / WeaponValues.SKY_PITCH * PI * 0.5
	return Vector3(sin(yaw) * cos(el), sin(el), -cos(yaw) * cos(el))

## A mount-frame direction's (yaw, elevation).
static func angles(d: Vector3) -> Vector2:
	var n := d.normalized()
	return Vector2(atan2(n.x, -n.z), asin(clampf(n.y, -1.0, 1.0)))

## A mount-frame direction's bin, or (-1, -1) below the face.
static func bin(d: Vector3) -> Vector2i:
	var a := angles(d)
	if a.y < -0.0001:
		return Vector2i(-1, -1)
	var yi := clampi(floori((a.x + PI) / TAU * WeaponValues.SKY_YAW), 0, WeaponValues.SKY_YAW - 1)
	var ei := clampi(floori(maxf(a.y, 0.0) / (PI * 0.5) * WeaponValues.SKY_PITCH), 0, WeaponValues.SKY_PITCH - 1)
	return Vector2i(yi, ei)

## Whether a shot along `dir_hull` (hull-local) is clear of the ship.
func can_bear(dir_hull: Vector3) -> bool:
	var b := bin(basis.inverse() * dir_hull)
	if b.x < 0:
		return false
	return bits[b.x * WeaponValues.SKY_PITCH + b.y] == 1

## The clear share of the half-sky, 0..1.
func coverage() -> float:
	var clear := 0
	for v in bits:
		clear += v
	return float(clear) / maxf(bits.size(), 1.0)
