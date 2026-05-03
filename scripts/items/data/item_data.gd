extends Resource
class_name ItemData

enum Slot {
	HEAD,
	BODY,
	MAIN_HAND,
	OFF_HAND,
	BACK,
	NECK,
	BELT_1,
	BELT_2,
	BELT_3,
	BELT_4
}

@export var item_id := ""
@export var display_name := ""
@export var weight := 0
@export var value := 0
@export var stack_size := 1
@export var rarity := "common"
@export var max_durability := -1
@export var item_class := "generic"
@export var tags: Array[String] = []
@export var equip_slots: Array[int] = []


func has_tag(tag: String) -> bool:
	return tags.has(tag)
