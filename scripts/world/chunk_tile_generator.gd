extends RefCounted
class_name ChunkTileGenerator


func generate(chunk_coord: Vector2i, world_meta) -> Dictionary:
	var config = world_meta.config
	var biome_index = _resolve_biome_index(chunk_coord, config)
	var biome = world_meta.biomes[biome_index]
	var size = config.chunk_size
	var ground = PackedColorArray()
	var roads = PackedByteArray()
	var objects = PackedByteArray()
	ground.resize(size * size)
	roads.resize(size * size)
	objects.resize(size * size)

	var noise = FastNoiseLite.new()
	noise.seed = config.seed + chunk_coord.x * 913 + chunk_coord.y * 337
	noise.frequency = biome.noise_scale

	for y in range(size):
		for x in range(size):
			var idx = y * size + x
			var world_tile = Vector2i(chunk_coord.x * size + x, chunk_coord.y * size + y)
			var sample = noise.get_noise_2d(world_tile.x, world_tile.y)
			var tint = biome.color.lerp(Color.WHITE, clampf((sample + 1.0) * 0.12, 0.0, 0.24))
			ground[idx] = tint
			if _is_road_tile(world_tile, world_meta, config.tile_size):
				roads[idx] = 1
			if _has_location(world_tile, world_meta):
				objects[idx] = 1

	return {
		"coord": chunk_coord,
		"ground": ground,
		"roads": roads,
		"objects": objects,
		"biome_color": biome.color
	}


func _resolve_biome_index(chunk_coord: Vector2i, config) -> int:
	var bx = clampi(chunk_coord.x, 0, config.biome_grid.x - 1)
	var by = clampi(chunk_coord.y, 0, config.biome_grid.y - 1)
	return by * config.biome_grid.x + bx


func _is_road_tile(world_tile: Vector2i, world_meta, tile_size: int) -> bool:
	var point = Vector2(world_tile * tile_size) + Vector2.ONE * tile_size * 0.5
	for road in world_meta.roads:
		for index in range(road.size() - 1):
			if Geometry2D.get_closest_point_to_segment(point, road[index], road[index + 1]).distance_to(point) <= tile_size * 0.33:
				return true
	return false


func _has_location(world_tile: Vector2i, world_meta) -> bool:
	for location in world_meta.locations:
		if location.world_tile == world_tile:
			return true
	return false
