extends RefCounted
class_name ObjectGenerator

const CAPITAL_RESOURCE_NODE_COUNT := 4
const BIOME_RESOURCE_NODE_COUNT := 2
const MAX_ACCUMULATION_MINUTES := 480

const RESOURCE_LIBRARY := {
	"forest": {
		"display_name": "Лесной участок",
		"resource_type": "wood",
		"storage_cap": 64.0,
		"full_storage_days": 1.0,
		"description": "Старый лесной участок с удобным подъездом. Даёт дерево для мастерской и будущих построек."
	},
	"mine": {
		"display_name": "Железная шахта",
		"resource_type": "ore",
		"storage_cap": 48.0,
		"full_storage_days": 1.25,
		"description": "Небольшая шахта с рудной жилой. Железо пригодится для оружия, щитов и инструментов."
	},
	"herb_field": {
		"display_name": "Травничий луг",
		"resource_type": "herbs",
		"storage_cap": 52.0,
		"full_storage_days": 0.75,
		"description": "Поле полезных трав. Поддерживает медицину, повязки и будущую алхимию."
	},
	"quarry": {
		"display_name": "Каменоломня",
		"resource_type": "stone",
		"storage_cap": 60.0,
		"full_storage_days": 1.5,
		"description": "Камень для укреплений, мастерских и тяжёлых заготовок."
	},
	"hunting_grounds": {
		"display_name": "Охотничьи угодья",
		"resource_type": "hides",
		"storage_cap": 40.0,
		"full_storage_days": 1.0,
		"description": "Дичь и выделанные шкуры. Подойдут для снаряжения, ремней и лёгкой брони."
	},
	"clay_pit": {
		"display_name": "Глиняный карьер",
		"resource_type": "clay",
		"storage_cap": 50.0,
		"full_storage_days": 1.25,
		"description": "Мягкая глина для ремесла, печей и городского производства."
	},
	"coal_vein": {
		"display_name": "Угольная жила",
		"resource_type": "coal",
		"storage_cap": 44.0,
		"full_storage_days": 1.75,
		"description": "Источник угля для печей и кузнечных работ."
	},
	"ruins": {
		"display_name": "Старые руины",
		"resource_type": "scrap",
		"storage_cap": 36.0,
		"full_storage_days": 2.0,
		"description": "Заброшенные руины, где можно вытаскивать лом, старые детали и редкие находки."
	}
}

const BIOME_WEIGHTS := {
	"plains": {"forest": 1.0, "herb_field": 1.1, "quarry": 0.5, "hunting_grounds": 1.2, "clay_pit": 1.1, "ruins": 0.8},
	"forest": {"forest": 1.5, "herb_field": 1.0, "hunting_grounds": 1.3, "clay_pit": 0.6, "ruins": 0.7},
	"highland": {"mine": 1.5, "quarry": 1.3, "coal_vein": 1.2, "ruins": 0.9, "forest": 0.5},
	"marsh": {"herb_field": 1.5, "clay_pit": 1.2, "hunting_grounds": 0.8, "ruins": 0.9, "forest": 0.6}
}


func generate(config, rng: RandomNumberGenerator, biomes: Array, settlements: Array) -> Array:
	var occupied := {}
	for settlement in settlements:
		occupied[settlement.world_tile] = true

	var locations: Array = []
	var capital = _find_capital(settlements)
	if capital != null:
		_add_capital_ring_resources(capital, biomes, config, rng, occupied, locations)

	for biome_index in range(biomes.size()):
		var biome = biomes[biome_index]
		var grid_x = biome_index % config.biome_grid.x
		var grid_y = biome_index / config.biome_grid.x
		var biome_origin = Vector2i(grid_x * config.chunk_size, grid_y * config.chunk_size)
		for _resource_index in range(BIOME_RESOURCE_NODE_COUNT):
			_try_add_resource_location(biome, biome_origin, config, rng, occupied, locations)
	return locations


func _find_capital(settlements: Array):
	for settlement in settlements:
		if settlement.settlement_type == "capital":
			return settlement
	return settlements[0] if not settlements.is_empty() else null


func _add_capital_ring_resources(capital, biomes: Array, config, rng: RandomNumberGenerator, occupied: Dictionary, locations: Array) -> void:
	if capital == null:
		return
	var biome = _find_biome_for_tile(capital.world_tile, biomes, config)
	if biome == null:
		return
	var chosen_types := _pick_weighted_types(_biome_weights_for(biome.biome_id), CAPITAL_RESOURCE_NODE_COUNT, rng)
	for source_type in chosen_types:
		var tile := _find_free_tile_near(capital.world_tile, config, rng, occupied, 4, 10)
		if tile == Vector2i(-1, -1):
			continue
		occupied[tile] = true
		locations.append(_build_resource_location(source_type, biome, tile, config))


func _try_add_resource_location(biome, biome_origin: Vector2i, config, rng: RandomNumberGenerator, occupied: Dictionary, locations: Array) -> void:
	var source_type := _pick_weighted_type(_biome_weights_for(biome.biome_id), rng)
	var tile := _find_free_tile_in_biome(biome_origin, config, rng, occupied)
	if tile == Vector2i(-1, -1):
		return
	occupied[tile] = true
	locations.append(_build_resource_location(source_type, biome, tile, config))


func _build_resource_location(source_type: String, biome, tile: Vector2i, config) -> LocationData:
	var location := preload("res://scripts/world/location_data.gd").new()
	var source_def: Dictionary = RESOURCE_LIBRARY[source_type]
	location.location_type = "resource"
	location.display_name = str(source_def["display_name"])
	location.biome_id = biome.biome_id
	location.world_tile = tile
	location.map_position = Vector2(tile * config.tile_size) + Vector2.ONE * config.tile_size * 0.5
	location.metadata = {
		"node_id": "%s_%d_%d" % [source_type, tile.x, tile.y],
		"source_type": source_type,
		"resource_type": str(source_def["resource_type"]),
		"storage_cap": float(source_def["storage_cap"]),
		"full_storage_days": float(source_def.get("full_storage_days", 1.0)),
		"max_accumulation_minutes": int(round(float(source_def.get("full_storage_days", 1.0)) * 24.0 * 60.0)),
		"description": str(source_def["description"]),
		"color": _resource_color_for(source_type)
	}
	return location


func _biome_weights_for(biome_id: String) -> Dictionary:
	var biome_type := biome_id.split("_")[0]
	return Dictionary(BIOME_WEIGHTS.get(biome_type, {"forest": 1.0, "mine": 1.0, "herb_field": 1.0, "quarry": 1.0}))


func _pick_weighted_types(weights: Dictionary, count: int, rng: RandomNumberGenerator) -> Array[String]:
	var available := weights.duplicate(true)
	var result: Array[String] = []
	while result.size() < count and not available.is_empty():
		var chosen := _pick_weighted_type(available, rng)
		result.append(chosen)
		available.erase(chosen)
	return result


func _pick_weighted_type(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total_weight := 0.0
	for source_type in weights.keys():
		total_weight += float(weights[source_type])
	var pick := rng.randf() * total_weight
	var cursor := 0.0
	for source_type in weights.keys():
		cursor += float(weights[source_type])
		if pick <= cursor:
			return str(source_type)
	return str(weights.keys()[0])


func _find_biome_for_tile(tile: Vector2i, biomes: Array, config):
	var grid_x := clampi(tile.x / config.chunk_size, 0, config.biome_grid.x - 1)
	var grid_y := clampi(tile.y / config.chunk_size, 0, config.biome_grid.y - 1)
	var index: int = grid_y * config.biome_grid.x + grid_x
	return biomes[index] if index >= 0 and index < biomes.size() else null


func _find_free_tile_near(center_tile: Vector2i, config, rng: RandomNumberGenerator, occupied: Dictionary, min_distance: int, max_distance: int) -> Vector2i:
	for _attempt in range(48):
		var offset := Vector2i(
			rng.randi_range(-max_distance, max_distance),
			rng.randi_range(-max_distance, max_distance)
		)
		var tile := center_tile + offset
		if tile.x < 2 or tile.y < 2 or tile.x >= config.get_world_tile_size().x - 2 or tile.y >= config.get_world_tile_size().y - 2:
			continue
		if absi(offset.x) + absi(offset.y) < min_distance:
			continue
		if occupied.has(tile):
			continue
		return tile
	return Vector2i(-1, -1)


func _find_free_tile_in_biome(biome_origin: Vector2i, config, rng: RandomNumberGenerator, occupied: Dictionary) -> Vector2i:
	for _attempt in range(40):
		var tile := Vector2i(
			biome_origin.x + rng.randi_range(2, config.chunk_size - 3),
			biome_origin.y + rng.randi_range(2, config.chunk_size - 3)
		)
		if occupied.has(tile):
			continue
		return tile
	return Vector2i(-1, -1)


func _resource_color_for(source_type: String) -> String:
	match source_type:
		"forest":
			return "72c06b"
		"mine":
			return "c4c9cf"
		"herb_field":
			return "6bd48a"
		"quarry":
			return "b6aa96"
		"hunting_grounds":
			return "b27c52"
		"clay_pit":
			return "c77758"
		"coal_vein":
			return "5e5f66"
		"ruins":
			return "d5b173"
		_:
			return "ffffff"
