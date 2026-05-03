extends Resource
class_name BattlefieldData

@export var battlefield_id := ""
@export var display_name := ""
@export var size := Vector2i(11, 9)
@export var default_terrain: TerrainData
@export var terrain_overrides := {}
@export var environment := {}


func in_bounds(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.y >= 0 and coord.x < size.x and coord.y < size.y


func get_terrain(coord: Vector2i) -> TerrainData:
	return terrain_overrides.get(coord, default_terrain)
