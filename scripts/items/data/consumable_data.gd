extends ItemData
class_name ConsumableData

@export var charges := 1
@export var use_ability_id := ""
@export var out_of_battle_use := false
@export var consumable_class := ""


func _init() -> void:
	item_class = "consumable"
