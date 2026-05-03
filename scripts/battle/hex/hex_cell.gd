extends RefCounted
class_name HexCell

var coord := Vector2i.ZERO
var terrain: TerrainData
var occupant = null


func setup(p_coord: Vector2i, p_terrain: TerrainData):
	coord = p_coord
	terrain = p_terrain
	return self
