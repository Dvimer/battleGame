extends ItemData
class_name PaintData

@export var tint := Color.WHITE
@export var allowed_targets: Array[String] = []


func _init() -> void:
	item_class = "paint"
