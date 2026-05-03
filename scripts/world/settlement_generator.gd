extends RefCounted
class_name SettlementGenerator

const TOWN_PREFIXES := ["Аур", "Бел", "Кедр", "Мор", "Сер", "Тер", "Вал", "Рив"]
const TOWN_SUFFIXES := ["град", "бор", "поле", "холм", "брод", "берег", "скат", "дол"]


func generate(config, rng: RandomNumberGenerator, biomes: Array) -> Array:
	var settlements: Array = []
	for biome_index in range(biomes.size()):
		var biome = biomes[biome_index]
		var grid_x = biome_index % config.biome_grid.x
		var grid_y = biome_index / config.biome_grid.x
		var count = rng.randi_range(config.settlements_per_biome_min, config.settlements_per_biome_max)
		if biome.settlement_weight > 1.05:
			count += 1
		for local_index in range(count):
			var settlement = preload("res://scripts/world/settlement_data.gd").new()
			settlement.biome_id = biome.biome_id
			settlement.biome_index = Vector2i(grid_x, grid_y)
			settlement.settlement_type = "large" if local_index == 0 and biome.settlement_weight >= 1.0 else "small"
			settlement.settlement_name = _build_name(rng)
			var biome_origin = Vector2i(grid_x * config.chunk_size, grid_y * config.chunk_size)
			var padding = maxi(3, config.chunk_size / 6)
			var tile = Vector2i(
				biome_origin.x + rng.randi_range(padding, config.chunk_size - padding - 1),
				biome_origin.y + rng.randi_range(padding, config.chunk_size - padding - 1)
			)
			settlement.world_tile = tile
			settlement.map_position = Vector2(tile * config.tile_size) + Vector2.ONE * config.tile_size * 0.5
			settlement.scene_path = "res://scenes/main.tscn"
			settlement.spawn_id = "hub_default"
			settlements.append(settlement)
	return settlements


func _build_name(rng: RandomNumberGenerator) -> String:
	return "%s%s" % [
		TOWN_PREFIXES[rng.randi_range(0, TOWN_PREFIXES.size() - 1)],
		TOWN_SUFFIXES[rng.randi_range(0, TOWN_SUFFIXES.size() - 1)]
	]
