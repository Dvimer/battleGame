extends ItemData
class_name ShieldData

@export var block_chance := 0.0
@export var block_value := 0
@export var off_hand_abilities: Array[String] = []
@export var wear_per_block := 1


func _init() -> void:
	item_class = "shield"
