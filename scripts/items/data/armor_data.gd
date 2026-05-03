extends ItemData
class_name ArmorData

@export var armor_slot := ItemData.Slot.BODY
@export var armor_value := 0
@export var fatigue_penalty := 0
@export var wear_per_block := 1


func _init() -> void:
	item_class = "armor"
