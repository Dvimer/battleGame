extends Node

var settlement_scene := preload("res://scenes/settlement.tscn")
var resource_scene := preload("res://scenes/resource_node.tscn")


func populate_chunk(chunk: Node2D, chunk_coord: Vector2i, world_meta) -> void:
	var settlements_root = chunk.get_node("Settlements")
	var locations_root = chunk.get_node("Locations")
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

	for location in world_meta.locations:
		var location_chunk = Vector2i(
			location.world_tile.x / world_meta.config.chunk_size,
			location.world_tile.y / world_meta.config.chunk_size
		)
		if location_chunk != chunk_coord:
			continue
		if str(location.location_type) != "resource":
			continue
		var resource_instance = resource_scene.instantiate()
		locations_root.add_child(resource_instance)
		resource_instance.call("setup", location, world_meta.config)
