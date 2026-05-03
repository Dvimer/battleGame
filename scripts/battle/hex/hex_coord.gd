extends RefCounted
class_name HexCoord

const SQRT_3 := 1.7320508075688772


static func directions() -> Array[Vector2i]:
	return [
		Vector2i(1, 0),
		Vector2i(1, -1),
		Vector2i(0, -1),
		Vector2i(-1, -1),
		Vector2i(-1, 0),
		Vector2i(0, 1)
	]


static func axial_to_pixel(coord: Vector2i, hex_size: float) -> Vector2:
	return Vector2(
		hex_size * 1.5 * float(coord.x),
		hex_size * SQRT_3 * (float(coord.y) + 0.5 * float(posmod(coord.x, 2)))
	)


static func pixel_to_axial(pixel: Vector2, hex_size: float) -> Vector2i:
	var q := (2.0 / 3.0 * pixel.x) / hex_size
	var r := (-1.0 / 3.0 * pixel.x + SQRT_3 / 3.0 * pixel.y) / hex_size
	return _cube_round_to_offset(q, -q - r, r)


static func distance(a: Vector2i, b: Vector2i) -> int:
	var ac := _offset_to_cube(a)
	var bc := _offset_to_cube(b)
	return int((absi(ac.x - bc.x) + absi(ac.y - bc.y) + absi(ac.z - bc.z)) / 2)


static func neighbor(coord: Vector2i, direction: int) -> Vector2i:
	var even_directions := [
		Vector2i(1, 0),
		Vector2i(1, -1),
		Vector2i(0, -1),
		Vector2i(-1, -1),
		Vector2i(-1, 0),
		Vector2i(0, 1)
	]
	var odd_directions := [
		Vector2i(1, 1),
		Vector2i(1, 0),
		Vector2i(0, -1),
		Vector2i(-1, 0),
		Vector2i(-1, 1),
		Vector2i(0, 1)
	]
	var dirs: Array = even_directions if posmod(coord.x, 2) == 0 else odd_directions
	return coord + dirs[wrapi(direction, 0, 6)]


static func neighbors(coord: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for index in range(6):
		result.append(neighbor(coord, index))
	return result


static func direction_index(from: Vector2i, to: Vector2i) -> int:
	var delta := to - from
	for index in range(6):
		if neighbor(from, index) - from == delta:
			return index
	var best_index := 0
	var best_distance := 999999
	for index in range(6):
		var candidate_distance := distance(neighbor(from, index), to)
		if candidate_distance < best_distance:
			best_distance = candidate_distance
			best_index = index
	return best_index


static func direction_to_pixel(direction: int, length: float) -> Vector2:
	var angles := [0.0, -60.0, -120.0, 180.0, 120.0, 60.0]
	var angle := deg_to_rad(angles[wrapi(direction, 0, 6)])
	return Vector2(cos(angle), sin(angle)) * length


static func corners(center: Vector2, hex_size: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(6):
		var angle := deg_to_rad(60.0 * index)
		points.append(center + Vector2(cos(angle), sin(angle)) * hex_size)
	return points


static func _cube_round_to_offset(q: float, s: float, r: float) -> Vector2i:
	var rq := roundi(q)
	var rs := roundi(s)
	var rr := roundi(r)
	var q_diff := absf(float(rq) - q)
	var s_diff := absf(float(rs) - s)
	var r_diff := absf(float(rr) - r)

	if q_diff > s_diff and q_diff > r_diff:
		rq = -rs - rr
	elif s_diff > r_diff:
		rs = -rq - rr
	else:
		rr = -rq - rs
	return _axial_to_offset(Vector2i(rq, rr))


static func _offset_to_cube(coord: Vector2i) -> Vector3i:
	var q := coord.x
	var r := coord.y - int((coord.x - posmod(coord.x, 2)) / 2)
	return Vector3i(q, -q - r, r)


static func _axial_to_offset(axial: Vector2i) -> Vector2i:
	var col := axial.x
	var row := axial.y + int((axial.x - posmod(axial.x, 2)) / 2)
	return Vector2i(col, row)
