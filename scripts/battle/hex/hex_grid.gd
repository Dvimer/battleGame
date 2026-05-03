extends RefCounted
class_name HexGrid

var size := Vector2i.ZERO
var cells := {}


func setup(battlefield: BattlefieldData):
	size = battlefield.size
	cells.clear()
	for y in range(size.y):
		for x in range(size.x):
			var coord := Vector2i(x, y)
			cells[coord] = HexCell.new().setup(coord, battlefield.get_terrain(coord))
	return self


func in_bounds(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.y >= 0 and coord.x < size.x and coord.y < size.y


func get_cell(coord: Vector2i) -> HexCell:
	return cells.get(coord)


func get_terrain(coord: Vector2i) -> TerrainData:
	var cell := get_cell(coord)
	return cell.terrain if cell != null else null


func get_occupant(coord: Vector2i):
	var cell := get_cell(coord)
	return cell.occupant if cell != null else null


func is_walkable(coord: Vector2i, moving_unit = null) -> bool:
	if not in_bounds(coord):
		return false
	var occupant = get_occupant(coord)
	return occupant == null or occupant == moving_unit


func set_occupant(coord: Vector2i, unit) -> void:
	var cell := get_cell(coord)
	if cell != null:
		cell.occupant = unit


func move_unit(unit, target: Vector2i) -> bool:
	if unit == null or not is_walkable(target, unit):
		return false
	set_occupant(unit.coord, null)
	unit.coord = target
	set_occupant(target, unit)
	return true


func neighbor_cells(coord: Vector2i) -> Array[HexCell]:
	var result: Array[HexCell] = []
	for neighbor in HexCoord.neighbors(coord):
		var cell := get_cell(neighbor)
		if cell != null:
			result.append(cell)
	return result
