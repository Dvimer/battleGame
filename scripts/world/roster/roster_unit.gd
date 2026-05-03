extends RefCounted
class_name RosterUnit

const AppearanceStateScript = preload("res://scripts/world/appearance/appearance_state.gd")
const WoundInstanceScript = preload("res://scripts/world/wounds/wound_instance.gd")
const ItemDataScript = preload("res://scripts/items/data/item_data.gd")

var id := ""
var display_name := ""
var base_unit_id := ""
var base_unit_data: UnitData
var level := 1
var equipped := {}
var quick_slots: Array = []
var secondary_set := {}
var appearance
var persistent_wounds: Array = []
var total_battles := 0
var perm_stat_bonuses := {}


func setup(unit_id: String, unit_name: String, unit_data: UnitData) -> RosterUnit:
	id = unit_id
	display_name = unit_name
	base_unit_id = unit_data.unit_id if unit_data != null else ""
	base_unit_data = unit_data
	appearance = AppearanceStateScript.new()
	return self


func equip(slot: int, item):
	if item == null:
		return null
	if base_unit_data != null and not base_unit_data.allowed_slots.is_empty() and not base_unit_data.allowed_slots.has(slot):
		return item
	if item.data != null and not item.data.equip_slots.is_empty() and not item.data.equip_slots.has(slot):
		return item
	var previous = equipped.get(slot)
	equipped[slot] = item
	return previous


func unequip(slot: int):
	var previous = equipped.get(slot)
	equipped.erase(slot)
	return previous


func assign_quick_slot(index: int, item):
	while quick_slots.size() < get_quick_slot_count():
		quick_slots.append(null)
	var previous = quick_slots[index] if index >= 0 and index < quick_slots.size() else null
	if index >= 0 and index < quick_slots.size():
		quick_slots[index] = item
	return previous


func get_quick_slot_count() -> int:
	return base_unit_data.quick_slot_count if base_unit_data != null else 0


func swap_secondary_set() -> void:
	var main_hand := ItemDataScript.Slot.MAIN_HAND
	var off_hand := ItemDataScript.Slot.OFF_HAND
	var current_main = equipped.get(main_hand)
	var current_off = equipped.get(off_hand)
	equipped[main_hand] = secondary_set.get(main_hand)
	equipped[off_hand] = secondary_set.get(off_hand)
	secondary_set[main_hand] = current_main
	secondary_set[off_hand] = current_off


func compute_total_weight() -> int:
	var total := 0
	for item in equipped.values():
		if item != null and item.data != null:
			total += int(item.data.weight)
	for item in quick_slots:
		if item != null and item.data != null:
			total += int(item.data.weight)
	return total


func to_army_slot() -> ArmySlotData:
	var slot := ArmySlotData.new()
	slot.unit_data = base_unit_data
	slot.deploy_hex = Vector2i.ZERO
	slot.facing = 0
	slot.equipped = _duplicate_item_map(equipped)
	slot.quick_slots = _duplicate_item_array(quick_slots)
	slot.secondary_set = _duplicate_item_map(secondary_set)
	slot.appearance = appearance.duplicate_state() if appearance != null else null
	slot.persistent_wounds = _duplicate_wounds(persistent_wounds)
	slot.roster_unit_id = id
	return slot


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"base_unit_id": base_unit_id,
		"level": level,
		"equipped": _serialize_item_map(equipped),
		"quick_slots": _serialize_item_array(quick_slots),
		"secondary_set": _serialize_item_map(secondary_set),
		"appearance": appearance.to_dict() if appearance != null else {},
		"persistent_wounds": _serialize_wounds(persistent_wounds),
		"total_battles": total_battles,
		"perm_stat_bonuses": perm_stat_bonuses.duplicate(true)
	}


static func from_dict(payload: Dictionary, unit_catalog: Dictionary, item_catalog: Dictionary, wound_catalog: Dictionary) -> RosterUnit:
	var unit_id := str(payload.get("base_unit_id", ""))
	if not unit_catalog.has(unit_id):
		return null
	var unit := RosterUnit.new().setup(
		str(payload.get("id", unit_id)),
		str(payload.get("display_name", unit_catalog[unit_id].display_name)),
		unit_catalog[unit_id]
	)
	unit.base_unit_id = unit_id
	unit.level = int(payload.get("level", 1))
	unit.equipped = _deserialize_item_map(Dictionary(payload.get("equipped", {})), item_catalog)
	unit.quick_slots = _deserialize_item_array(Array(payload.get("quick_slots", [])), item_catalog)
	unit.secondary_set = _deserialize_item_map(Dictionary(payload.get("secondary_set", {})), item_catalog)
	unit.appearance = AppearanceStateScript.from_dict(Dictionary(payload.get("appearance", {})))
	unit.persistent_wounds = _deserialize_wounds(Array(payload.get("persistent_wounds", [])), wound_catalog)
	unit.total_battles = int(payload.get("total_battles", 0))
	unit.perm_stat_bonuses = Dictionary(payload.get("perm_stat_bonuses", {})).duplicate(true)
	return unit


func _duplicate_item_map(source: Dictionary) -> Dictionary:
	var result := {}
	for slot_key in source.keys():
		var item = source[slot_key]
		result[int(slot_key)] = item.duplicate_instance() if item != null else null
	return result


func _duplicate_item_array(source: Array) -> Array:
	var result: Array = []
	for item in source:
		result.append(item.duplicate_instance() if item != null else null)
	return result


func _duplicate_wounds(source: Array) -> Array:
	var result: Array = []
	for wound in source:
		if wound != null:
			result.append(wound.duplicate_instance())
	return result


static func _serialize_item_map(source: Dictionary) -> Dictionary:
	var result := {}
	for slot_key in source.keys():
		var item = source[slot_key]
		result[str(int(slot_key))] = item.to_dict() if item != null else {}
	return result


static func _serialize_item_array(source: Array) -> Array:
	var result: Array = []
	for item in source:
		result.append(item.to_dict() if item != null else {})
	return result


static func _serialize_wounds(source: Array) -> Array:
	var result: Array = []
	for wound in source:
		result.append(wound.to_dict())
	return result


static func _deserialize_item_map(payload: Dictionary, item_catalog: Dictionary) -> Dictionary:
	var result := {}
	for slot_key in payload.keys():
		var item_payload: Dictionary = payload[slot_key]
		var item := ItemInstance.from_dict(item_payload, item_catalog)
		if item != null:
			result[int(slot_key)] = item
	return result


static func _deserialize_item_array(payload: Array, item_catalog: Dictionary) -> Array:
	var result: Array = []
	for item_payload in payload:
		if item_payload is Dictionary:
			result.append(ItemInstance.from_dict(item_payload, item_catalog))
		else:
			result.append(null)
	return result


static func _deserialize_wounds(payload: Array, wound_catalog: Dictionary) -> Array:
	var result: Array = []
	for wound_payload in payload:
		if wound_payload is Dictionary:
			var wound := WoundInstanceScript.from_dict(wound_payload, wound_catalog)
			if wound != null:
				result.append(wound)
	return result
