extends RefCounted
class_name BiomeGenerator

const BIOME_LIBRARY := [
	{
		"id": "plains",
		"name_ru": "Луга",
		"name_en": "Plains",
		"color": "84b96b",
		"settlement_weight": 1.2,
		"poi_probability": 0.18,
		"dungeon_probability": 0.06,
		"resource_probability": 0.38
	},
	{
		"id": "forest",
		"name_ru": "Лес",
		"name_en": "Forest",
		"color": "4f8c5a",
		"settlement_weight": 0.9,
		"poi_probability": 0.34,
		"dungeon_probability": 0.14,
		"resource_probability": 0.42
	},
	{
		"id": "highland",
		"name_ru": "Высоты",
		"name_en": "Highland",
		"color": "9f9a6b",
		"settlement_weight": 0.75,
		"poi_probability": 0.22,
		"dungeon_probability": 0.2,
		"resource_probability": 0.28
	},
	{
		"id": "marsh",
		"name_ru": "Болота",
		"name_en": "Marsh",
		"color": "5f8264",
		"settlement_weight": 0.55,
		"poi_probability": 0.42,
		"dungeon_probability": 0.18,
		"resource_probability": 0.32
	}
]


func generate(config, rng: RandomNumberGenerator) -> Array:
	var biomes: Array = []
	for y in range(config.biome_grid.y):
		for x in range(config.biome_grid.x):
			var preset: Dictionary = BIOME_LIBRARY[rng.randi_range(0, BIOME_LIBRARY.size() - 1)]
			var biome = preload("res://scripts/world/biome_data.gd").new()
			biome.biome_id = "%s_%d_%d" % [preset["id"], x, y]
			biome.display_name = str(preset["name_ru"])
			biome.color = Color(str(preset["color"]))
			biome.noise_scale = rng.randf_range(0.04, 0.08)
			biome.settlement_weight = float(preset["settlement_weight"])
			biome.poi_probability = float(preset["poi_probability"])
			biome.dungeon_probability = float(preset["dungeon_probability"])
			biome.resource_probability = float(preset["resource_probability"])
			biomes.append(biome)
	return biomes
