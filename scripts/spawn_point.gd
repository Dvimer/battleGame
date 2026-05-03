extends Marker2D

@export var spawn_id := ""


func _ready() -> void:
	add_to_group("spawn_points")


func get_spawn_id() -> String:
	return spawn_id
