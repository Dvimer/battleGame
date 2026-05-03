extends RefCounted
class_name WorldAssembler

var biome_generator = preload("res://scripts/world/biome_generator.gd").new()
var settlement_generator = preload("res://scripts/world/settlement_generator.gd").new()
var road_generator = preload("res://scripts/world/road_generator.gd").new()
var object_generator = preload("res://scripts/world/object_generator.gd").new()


func generate(config, rng: RandomNumberGenerator):
	var world_meta = preload("res://scripts/world/world_meta.gd").new()
	world_meta.config = config
	world_meta.biomes = biome_generator.generate(config, rng)
	world_meta.settlements = settlement_generator.generate(config, rng, world_meta.biomes)
	_assign_capital(world_meta)
	world_meta.roads = road_generator.generate(config, rng, world_meta.settlements)
	world_meta.locations = object_generator.generate(config, rng, world_meta.biomes, world_meta.settlements)
	world_meta.world_tiles = config.get_world_tile_size()
	world_meta.world_pixels = config.get_world_pixel_size()
	return world_meta


func _assign_capital(world_meta) -> void:
	if world_meta.settlements.is_empty():
		return
	var candidate = world_meta.settlements[0]
	for settlement in world_meta.settlements:
		if settlement.settlement_type == "large":
			candidate = settlement
			break
	candidate.settlement_type = "capital"
	candidate.settlement_name = "Столица"
	candidate.scene_path = "res://scenes/main.tscn"
	candidate.spawn_id = "hub_default"
	candidate.discovered = true
	world_meta.capital = candidate
	world_meta.spawn_pos = candidate.map_position + Vector2(0.0, world_meta.config.tile_size * 1.5)
