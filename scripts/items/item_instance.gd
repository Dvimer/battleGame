extends RefCounted
class_name ItemInstance

var instance_id := ""
var data
var durability := -1
var max_durability := -1
var charges := -1
var paint
var emblem
var enchants: Array[String] = []
var custom_name := ""


static func from_data(p_data) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = _make_instance_id(p_data.item_id)
	item.data = p_data
	item.max_durability = p_data.max_durability
	item.durability = p_data.max_durability
	if str(p_data.item_class) == "consumable":
		item.charges = int(p_data.charges)
	return item


static func from_dict(payload: Dictionary, catalog: Dictionary) -> ItemInstance:
	var item_id := str(payload.get("item_id", ""))
	if not catalog.has(item_id):
		return null
	var item := ItemInstance.from_data(catalog[item_id])
	item.instance_id = str(payload.get("instance_id", item.instance_id))
	item.durability = int(payload.get("durability", item.durability))
	item.max_durability = int(payload.get("max_durability", item.max_durability))
	item.charges = int(payload.get("charges", item.charges))
	item.custom_name = str(payload.get("custom_name", ""))
	item.enchants.clear()
	for enchant_id in Array(payload.get("enchants", [])):
		item.enchants.append(str(enchant_id))
	var paint_id := str(payload.get("paint_id", ""))
	if paint_id != "" and catalog.has(paint_id) and str(catalog[paint_id].item_class) == "paint":
		item.paint = catalog[paint_id]
	var emblem_id := str(payload.get("emblem_id", ""))
	if emblem_id != "" and catalog.has(emblem_id) and str(catalog[emblem_id].item_class) == "emblem":
		item.emblem = catalog[emblem_id]
	return item


func duplicate_instance() -> ItemInstance:
	var item := ItemInstance.from_data(data)
	item.instance_id = instance_id
	item.durability = durability
	item.max_durability = max_durability
	item.charges = charges
	item.paint = paint
	item.emblem = emblem
	item.enchants = enchants.duplicate()
	item.custom_name = custom_name
	return item


func is_broken() -> bool:
	return max_durability >= 0 and durability == 0


func tick_wear(amount: int) -> void:
	if max_durability < 0 or amount <= 0:
		return
	durability = maxi(0, durability - amount)


func consume_charge() -> bool:
	if charges < 0:
		return true
	if charges <= 0:
		return false
	charges -= 1
	return true


func get_display_name() -> String:
	if custom_name != "":
		return custom_name
	return data.display_name if data != null else "Item"


func to_dict() -> Dictionary:
	return {
		"instance_id": instance_id,
		"item_id": data.item_id if data != null else "",
		"durability": durability,
		"max_durability": max_durability,
		"charges": charges,
		"paint_id": paint.item_id if paint != null else "",
		"emblem_id": emblem.item_id if emblem != null else "",
		"enchants": enchants.duplicate(),
		"custom_name": custom_name
	}


static func _make_instance_id(item_id: String) -> String:
	return "%s_%d_%d" % [item_id, Time.get_ticks_usec(), randi()]
