extends Node

const ACTIVE_RADIUS := 1

var world_root: Node
var active_chunks := {}
var last_center_chunk := Vector2i(999999, 999999)


func _event_bus() -> Node:
	return get_node_or_null("/root/EventBus")


func _world_generator() -> Node:
	return get_node_or_null("/root/WorldGenerator")


func _chunk_cache() -> Node:
	return get_node_or_null("/root/ChunkCache")


func register_world(root: Node) -> void:
	world_root = root
	last_center_chunk = Vector2i(999999, 999999)


func unregister_world(root: Node) -> void:
	if world_root != root:
		return
	for coord in active_chunks.keys():
		var chunk_node = active_chunks[coord]
		if is_instance_valid(chunk_node):
			chunk_node.queue_free()
	active_chunks.clear()
	world_root = null


func update_for_player(world_position: Vector2) -> void:
	if world_root == null:
		return
	var world_generator = _world_generator()
	if world_generator == null:
		return
	var config = world_generator.get_config()
	var center_chunk = Vector2i(
		int(floor(world_position.x / float(config.get_chunk_pixel_size()))),
		int(floor(world_position.y / float(config.get_chunk_pixel_size())))
	)
	if center_chunk == last_center_chunk:
		return
	last_center_chunk = center_chunk
	_sync_chunks(center_chunk, world_generator.get_world_meta())


func _sync_chunks(center_chunk: Vector2i, world_meta) -> void:
	var required = {}
	for y in range(center_chunk.y - ACTIVE_RADIUS, center_chunk.y + ACTIVE_RADIUS + 1):
		for x in range(center_chunk.x - ACTIVE_RADIUS, center_chunk.x + ACTIVE_RADIUS + 1):
			var coord = Vector2i(x, y)
			if x < 0 or y < 0 or x >= world_meta.config.biome_grid.x or y >= world_meta.config.biome_grid.y:
				continue
			required[coord] = true
			if not active_chunks.has(coord):
				_load_chunk(coord, world_meta)

	for coord in active_chunks.keys():
		if required.has(coord):
			continue
		var chunk_node = active_chunks[coord]
		if is_instance_valid(chunk_node):
			chunk_node.queue_free()
		active_chunks.erase(coord)


func _load_chunk(coord: Vector2i, world_meta) -> void:
	var chunk_scene = load("res://scenes/chunk.tscn")
	var chunk = chunk_scene.instantiate()
	world_root.get_node("Chunks").add_child(chunk)
	var chunk_data = _chunk_cache().get_or_create_chunk(coord, world_meta)
	chunk.call("setup", coord, chunk_data, world_meta.config)
	world_root.get_node("LocationSpawner").call("populate_chunk", chunk, coord, world_meta)
	active_chunks[coord] = chunk
	var event_bus = _event_bus()
	if event_bus != null:
		event_bus.emit_signal("chunk_loaded", coord)
