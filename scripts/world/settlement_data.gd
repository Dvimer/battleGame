extends Resource
class_name SettlementData

@export_enum("small", "large", "capital") var settlement_type := "small"
@export var settlement_name := ""
@export var biome_id := ""
@export var biome_index := Vector2i.ZERO
@export var world_tile := Vector2i.ZERO
@export var map_position := Vector2.ZERO
@export var scene_path := "res://scenes/main.tscn"
@export var spawn_id := "hub_default"
@export var discovered := false
