extends RefCounted
class_name ObjectGenerator


func generate(config, rng: RandomNumberGenerator, biomes: Array, settlements: Array) -> Array:
	var occupied := {}
	for settlement in settlements:
		occupied[settlement.world_tile] = true

	var locations: Array = []
	for biome_index in range(biomes.size()):
		var biome = biomes[biome_index]
		var grid_x = biome_index % config.biome_grid.x
		var grid_y = biome_index / config.biome_grid.x
		var biome_origin = Vector2i(grid_x * config.chunk_size, grid_y * config.chunk_size)
		_try_add_location("poi", "Сторожевой пост", biome, biome_origin, config, rng, occupied, biome.poi_probability, locations)
		_try_add_location("dungeon", "Руины", biome, biome_origin, config, rng, occupied, biome.dungeon_probability, locations)
		_try_add_location("poi", "Ресурсный узел", biome, biome_origin, config, rng, occupied, biome.resource_probability, locations)
	return locations


func _try_add_location(location_type: String, label: String, biome, biome_origin: Vector2i, config, rng: RandomNumberGenerator, occupied: Dictionary, probability: float, locations: Array) -> void:
	if rng.randf() > probability:
		return
	var tile = Vector2i(
		biome_origin.x + rng.randi_range(2, config.chunk_size - 3),
		biome_origin.y + rng.randi_range(2, config.chunk_size - 3)
	)
	if occupied.has(tile):
		return
	occupied[tile] = true
	var location = preload("res://scripts/world/location_data.gd").new()
	location.location_type = location_type
	location.display_name = label
	location.biome_id = biome.biome_id
	location.world_tile = tile
	location.map_position = Vector2(tile * config.tile_size) + Vector2.ONE * config.tile_size * 0.5
	location.metadata = {"color": biome.color.to_html()}
	locations.append(location)
