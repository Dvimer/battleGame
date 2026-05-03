extends Resource
class_name WorldGenConfig

@export var tile_size := 64
@export var chunk_size := 32
@export var biome_grid := Vector2i(6, 6)
@export var seed := 424242
@export var road_curviness := 140.0
@export var visibility_radius_tiles := 5
@export var settlements_per_biome_min := 1
@export var settlements_per_biome_max := 2


func get_chunk_pixel_size() -> int:
	return tile_size * chunk_size


func get_world_tile_size() -> Vector2i:
	return Vector2i(biome_grid.x * chunk_size, biome_grid.y * chunk_size)


func get_world_pixel_size() -> Vector2:
	var tile_count := get_world_tile_size()
	return Vector2(tile_count.x * tile_size, tile_count.y * tile_size)
