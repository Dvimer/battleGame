extends Node

signal location_entered(location_id: String, payload: Dictionary)
signal quest_triggered(chain_id: String, payload: Dictionary)
signal player_moved(world_position: Vector2)
signal chunk_loaded(chunk_coord: Vector2i)
