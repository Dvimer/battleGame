extends ItemData
class_name ToolData

@export var repair_efficiency := 1.0
@export var craft_efficiency := 1.0


func _init() -> void:
	item_class = "tool"
