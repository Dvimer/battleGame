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

	# Предварительно строим set дорожных тайлов для этого чанка —
	# O(roads × segments) один раз вместо O(tiles² × roads × segments)
	var road_set := _build_road_set(chunk_coord, size, config.tile_size, world_meta.roads)

	# Предварительно строим set тайлов с объектами — O(locations) один раз
	var location_set := {}
	for location in world_meta.locations:
		location_set[location.world_tile] = true

	var chunk_origin: Vector2i = chunk_coord * size
	for y in range(size):
		for x in range(size):
			var idx: int = y * size + x
			var world_tile := Vector2i(chunk_origin.x + x, chunk_origin.y + y)
			var sample := noise.get_noise_2d(world_tile.x, world_tile.y)
			ground[idx] = biome.color.lerp(Color.WHITE, clampf((sample + 1.0) * 0.12, 0.0, 0.24))
			if road_set.has(world_tile):
				roads[idx] = 1
			if location_set.has(world_tile):
				objects[idx] = 1

	return {
		"coord": chunk_coord,
		"ground": ground,
		"roads": roads,
		"objects": objects,
		"biome_color": biome.color
	}


func _resolve_biome_index(chunk_coord: Vector2i, config) -> int:
	var bx := clampi(chunk_coord.x, 0, config.biome_grid.x - 1)
	var by := clampi(chunk_coord.y, 0, config.biome_grid.y - 1)
	return by * config.biome_grid.x + bx


## Растеризует все сегменты дорог в set тайлов для данного чанка.
## Сложность: O(roads × segments × segment_tiles) — выполняется один раз на чанк.
func _build_road_set(chunk_coord: Vector2i, chunk_size: int, tile_size: int, roads: Array) -> Dictionary:
	var result := {}
	var half := float(tile_size) * 0.5
	var threshold := float(tile_size) * 0.33
	var threshold_sq := threshold * threshold
	var chunk_origin: Vector2i = chunk_coord * chunk_size

	for road in roads:
		for seg_index in range(road.size() - 1):
			var a: Vector2 = road[seg_index]
			var b: Vector2 = road[seg_index + 1]
			# AABB сегмента в тайловых координатах с запасом
			var margin := int(ceil(threshold / float(tile_size))) + 1
			var min_tx := int(floor(minf(a.x, b.x) / float(tile_size))) - margin
			var max_tx := int(ceil(maxf(a.x, b.x)  / float(tile_size))) + margin
			var min_ty := int(floor(minf(a.y, b.y) / float(tile_size))) - margin
			var max_ty := int(ceil(maxf(a.y, b.y)  / float(tile_size))) + margin
			# Ограничиваем до тайлов этого чанка
			min_tx = maxi(min_tx, chunk_origin.x)
			max_tx = mini(max_tx, chunk_origin.x + chunk_size - 1)
			min_ty = maxi(min_ty, chunk_origin.y)
			max_ty = mini(max_ty, chunk_origin.y + chunk_size - 1)
			for ty in range(min_ty, max_ty + 1):
				for tx in range(min_tx, max_tx + 1):
					var point := Vector2(tx * tile_size + half, ty * tile_size + half)
					var closest := Geometry2D.get_closest_point_to_segment(point, a, b)
					var dx := point.x - closest.x
					var dy := point.y - closest.y
					if dx * dx + dy * dy <= threshold_sq:
						result[Vector2i(tx, ty)] = true
	return result
