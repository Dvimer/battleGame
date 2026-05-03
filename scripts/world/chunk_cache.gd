extends Node

var chunks := {}
var tile_generator = preload("res://scripts/world/chunk_tile_generator.gd").new()


func get_or_create_chunk(chunk_coord: Vector2i, world_meta) -> Dictionary:
	if not chunks.has(chunk_coord):
		chunks[chunk_coord] = tile_generator.generate(chunk_coord, world_meta)
	return chunks[chunk_coord]


func clear_cache() -> void:
	chunks.clear()
