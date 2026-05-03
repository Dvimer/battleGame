extends Node

var settlement_scene := preload("res://scenes/settlement.tscn")


func populate_chunk(chunk: Node2D, chunk_coord: Vector2i, world_meta) -> void:
	var settlements_root = chunk.get_node("Settlements")
	for settlement in world_meta.settlements:
		var settlement_chunk = Vector2i(
			settlement.world_tile.x / world_meta.config.chunk_size,
			settlement.world_tile.y / world_meta.config.chunk_size
		)
		if settlement_chunk != chunk_coord:
			continue
		var instance = settlement_scene.instantiate()
		settlements_root.add_child(instance)
		instance.call("setup", settlement, world_meta.config)
