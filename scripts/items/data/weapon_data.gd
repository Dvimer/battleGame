extends ItemData
class_name WeaponData

@export var damage := 1
@export var reach := 1
@export var attack_abilities: Array[String] = []
@export var two_handed := false
@export var weapon_class := ""
@export var wear_per_hit := 1


func _init() -> void:
	item_class = "weapon"
