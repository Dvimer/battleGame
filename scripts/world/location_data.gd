extends Resource
class_name LocationData

@export_enum("poi", "dungeon", "road") var location_type := "poi"
@export var display_name := ""
@export var biome_id := ""
@export var world_tile := Vector2i.ZERO
@export var map_position := Vector2.ZERO
@export var discovered := false
@export var metadata := {}
