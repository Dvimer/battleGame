extends Node

var config
var world_meta
var rng = RandomNumberGenerator.new()
var assembler = preload("res://scripts/world/world_assembler.gd").new()


func _ready() -> void:
	if config == null:
		config = preload("res://scripts/world/world_gen_config.gd").new()
	start_new_session_world()


func start_new_session_world() -> void:
	var session_rng = RandomNumberGenerator.new()
	session_rng.randomize()
	config.seed = int(session_rng.randi())
	rng.seed = config.seed
	world_meta = null
	regenerate(config.seed)


func ensure_world():
	if world_meta == null:
		rng.seed = config.seed
		world_meta = assembler.generate(config, rng)
	return world_meta


func regenerate(seed_override := -1):
	if seed_override >= 0:
		config.seed = seed_override
	rng.seed = config.seed
	world_meta = assembler.generate(config, rng)
	var chunk_cache = get_node_or_null("/root/ChunkCache")
	if chunk_cache != null and chunk_cache.has_method("clear_cache"):
		chunk_cache.call("clear_cache")
	var fog = get_node_or_null("/root/FogOfWar")
	if fog != null and fog.has_method("reset_for_world"):
		fog.call("reset_for_world", world_meta)
	return world_meta


func get_world_meta():
	return ensure_world()


func get_config():
	if config == null:
		config = preload("res://scripts/world/world_gen_config.gd").new()
	return config
