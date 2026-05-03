extends Node

signal inventory_changed

var items: Array = []
var capacity := 80
var currency := 0
var tools := 0
var medicine := 0
var supplies := 0


func reset_defaults() -> void:
	items.clear()
	capacity = 80
	currency = 0
	tools = 8
	medicine = 4
	supplies = 12
	inventory_changed.emit()


func add(item) -> bool:
	if item == null:
		return false
	items.append(item)
	if is_overloaded():
		items.pop_back()
		return false
	inventory_changed.emit()
	return true


func remove(item) -> void:
	var index := items.find(item)
	if index == -1:
		return
	items.remove_at(index)
	inventory_changed.emit()


func filter_by_tag(tag: String) -> Array:
	var result: Array = []
	for item in items:
		if item != null and item.data != null and item.data.has_tag(tag):
			result.append(item)
	return result


func current_weight() -> int:
	var total := 0
	for item in items:
		if item != null and item.data != null:
			total += int(item.data.weight)
	return total


func is_overloaded() -> bool:
	return current_weight() > capacity


func find_by_instance_id(instance_id: String):
	for item in items:
		if item != null and item.instance_id == instance_id:
			return item
	return null


func to_dict() -> Dictionary:
	var serialized_items: Array = []
	for item in items:
		serialized_items.append(item.to_dict())
	return {
		"items": serialized_items,
		"capacity": capacity,
		"currency": currency,
		"tools": tools,
		"medicine": medicine,
		"supplies": supplies
	}


func load_from_dict(payload: Dictionary, item_catalog: Dictionary) -> void:
	items.clear()
	for item_payload in Array(payload.get("items", [])):
		if item_payload is Dictionary:
			var item := ItemInstance.from_dict(item_payload, item_catalog)
			if item != null:
				items.append(item)
	capacity = int(payload.get("capacity", 80))
	currency = int(payload.get("currency", 0))
	tools = int(payload.get("tools", 0))
	medicine = int(payload.get("medicine", 0))
	supplies = int(payload.get("supplies", 0))
	inventory_changed.emit()
