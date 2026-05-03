extends Node

const RosterUnitScript = preload("res://scripts/world/roster/roster_unit.gd")
const ItemDataScript = preload("res://scripts/items/data/item_data.gd")
const ItemInstanceScript = preload("res://scripts/items/item_instance.gd")
const WeaponDataScript = preload("res://scripts/items/data/weapon_data.gd")
const ShieldDataScript = preload("res://scripts/items/data/shield_data.gd")
const ArmorDataScript = preload("res://scripts/items/data/armor_data.gd")
const ConsumableDataScript = preload("res://scripts/items/data/consumable_data.gd")
const ToolDataScript = preload("res://scripts/items/data/tool_data.gd")
const PaintDataScript = preload("res://scripts/items/data/paint_data.gd")
const EmblemDataScript = preload("res://scripts/items/data/emblem_data.gd")
const WoundDataScript = preload("res://scripts/world/wounds/wound_data.gd")
const WoundInstanceScript = preload("res://scripts/world/wounds/wound_instance.gd")

signal roster_changed

const PARTY_CAPACITY := 3

var roster_units: Array = []
var selected_party_ids: Array[String] = []
var recruit_offers: Array[Dictionary] = []

var unit_catalog := {}
var item_catalog := {}
var wound_catalog := {}


func _ready() -> void:
	_rebuild_catalogs()
	ensure_initialized()


func ensure_initialized() -> void:
	if unit_catalog.is_empty() or item_catalog.is_empty():
		_rebuild_catalogs()
	if roster_units.is_empty():
		reset_defaults()
	else:
		_ensure_default_roster_composition()


func reset_defaults() -> void:
	_rebuild_catalogs()
	roster_units.clear()
	selected_party_ids.clear()
	recruit_offers = _build_default_recruit_offers()

	_add_default_roster_unit(_build_default_captain())
	_add_default_roster_unit(_build_default_footman())
	_add_default_roster_unit(_build_default_archer())

	var inventory: Node = _inventory()
	if inventory != null:
		inventory.reset_defaults()
		inventory.add(ItemInstanceScript.from_data(item_catalog["bandage"]))
		inventory.add(ItemInstanceScript.from_data(item_catalog["repair_kit"]))
		inventory.add(ItemInstanceScript.from_data(item_catalog["red_paint"]))
		inventory.add(ItemInstanceScript.from_data(item_catalog["wolf_emblem"]))

	roster_changed.emit()


func get_selected_party() -> Array:
	var result: Array = []
	for unit_id in selected_party_ids:
		var unit: RosterUnit = find_unit(unit_id)
		if unit != null and unit.is_available_for_battle():
			result.append(unit)
	return result


func find_unit(unit_id: String) -> RosterUnit:
	for unit in roster_units:
		if unit.id == unit_id:
			return unit
	return null


func add_unit(unit) -> void:
	if unit == null:
		return
	roster_units.append(unit)
	if selected_party_ids.size() < PARTY_CAPACITY and not selected_party_ids.has(unit.id):
		selected_party_ids.append(unit.id)
	roster_changed.emit()


func get_recruit_offers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for offer in recruit_offers:
		result.append(offer.duplicate(true))
	return result


func get_party_capacity() -> int:
	return PARTY_CAPACITY


func get_party_units() -> Array:
	var result: Array = []
	for unit_id in selected_party_ids:
		var unit: RosterUnit = find_unit(unit_id)
		if unit != null:
			result.append(unit)
	return result


func hire_recruit(recruit_id: String, replace_unit_id := "") -> bool:
	var offer_index := _find_recruit_offer_index(recruit_id)
	if offer_index == -1:
		return false
	var offer := recruit_offers[offer_index]
	if not _can_afford_offer(offer):
		return false
	var party_index := selected_party_ids.size()
	if replace_unit_id != "":
		party_index = selected_party_ids.find(replace_unit_id)
		if party_index == -1 or replace_unit_id == "captain_01":
			return false
		if not _remove_roster_unit(replace_unit_id):
			return false
	elif selected_party_ids.size() >= PARTY_CAPACITY:
		return false
	var unit := _create_unit_from_offer(offer)
	if unit == null:
		return false
	_charge_offer(offer)
	recruit_offers.remove_at(offer_index)
	roster_units.append(unit)
	selected_party_ids.insert(party_index, unit.id)
	_cleanup_selected_party()
	roster_changed.emit()
	return true


func dismiss_unit(unit_id: String) -> bool:
	if unit_id == "captain_01":
		return false
	if not _remove_roster_unit(unit_id):
		return false
	_cleanup_selected_party()
	roster_changed.emit()
	return true


func create_attacker_army_from_selected_party() -> ArmyData:
	var army := ArmyData.new()
	army.army_id = "roster_party"
	army.display_name = "Отряд"
	var slots: Array[ArmySlotData] = []
	var deploy_positions := [
		Vector2i(1, 3),
		Vector2i(1, 5),
		Vector2i(0, 4),
		Vector2i(0, 2),
		Vector2i(0, 6),
		Vector2i(2, 4)
	]
	var party := get_selected_party()
	for index in range(party.size()):
		var slot: ArmySlotData = party[index].to_army_slot()
		slot.deploy_hex = deploy_positions[index] if index < deploy_positions.size() else Vector2i(0, 3 + index)
		slot.facing = 0
		slots.append(slot)
	army.slots = slots
	return army


func apply_battle_result(result: Dictionary) -> void:
	var hp_per_unit: Dictionary = result.get("hp_per_unit", {})
	var killed_lookup := {}
	for unit_id in Array(result.get("killed", [])):
		killed_lookup[str(unit_id)] = true
	for unit in roster_units:
		if hp_per_unit.has(unit.id):
			unit.apply_battle_state(int(hp_per_unit[unit.id]), killed_lookup.has(unit.id))
		elif killed_lookup.has(unit.id):
			unit.apply_battle_state(0, true)

	var wounds_per_unit: Dictionary = result.get("persistent_wounds_per_unit", {})
	for unit_id in wounds_per_unit.keys():
		var unit: RosterUnit = find_unit(str(unit_id))
		if unit == null:
			continue
		for wound_payload in Array(wounds_per_unit[unit_id]):
			if wound_payload is Dictionary:
				var wound := WoundInstanceScript.from_dict(wound_payload, wound_catalog)
				if wound != null:
					unit.persistent_wounds.append(wound)

	var durability_delta: Dictionary = result.get("durability_delta", {})
	for instance_id in durability_delta.keys():
		var item: Variant = find_item_instance(str(instance_id))
		if item != null:
			item.durability = maxi(0, item.durability + int(durability_delta[instance_id]))

	var charges_delta: Dictionary = result.get("charges_delta", {})
	for instance_id in charges_delta.keys():
		var item: Variant = find_item_instance(str(instance_id))
		if item != null:
			item.charges = maxi(0, item.charges + int(charges_delta[instance_id]))

	_cleanup_selected_party()
	roster_changed.emit()


func find_item_instance(instance_id: String):
	var inventory: Node = _inventory()
	if inventory != null:
		var inventory_item: Variant = inventory.find_by_instance_id(instance_id)
		if inventory_item != null:
			return inventory_item
	for unit in roster_units:
		for item in unit.equipped.values():
			if item != null and item.instance_id == instance_id:
				return item
		for item in unit.quick_slots:
			if item != null and item.instance_id == instance_id:
				return item
		for item in unit.secondary_set.values():
			if item != null and item.instance_id == instance_id:
				return item
	return null


func to_dict() -> Dictionary:
	var units_payload: Array = []
	for unit in roster_units:
		units_payload.append(unit.to_dict())
	return {
		"roster_units": units_payload,
		"selected_party_ids": selected_party_ids.duplicate(),
		"recruit_offers": recruit_offers.duplicate(true)
	}


func load_from_dict(payload: Dictionary) -> void:
	_rebuild_catalogs()
	roster_units.clear()
	selected_party_ids.clear()
	recruit_offers = []
	for unit_payload in Array(payload.get("roster_units", [])):
		if unit_payload is Dictionary:
			var unit := RosterUnitScript.from_dict(unit_payload, unit_catalog, item_catalog, wound_catalog)
			if unit != null:
				roster_units.append(unit)
	for unit_id in Array(payload.get("selected_party_ids", [])):
		selected_party_ids.append(str(unit_id))
	for offer in Array(payload.get("recruit_offers", [])):
		if offer is Dictionary:
			recruit_offers.append(Dictionary(offer).duplicate(true))
	if roster_units.is_empty():
		reset_defaults()
		return
	_ensure_default_roster_composition()
	if recruit_offers.is_empty():
		recruit_offers = _build_default_recruit_offers()
	_cleanup_selected_party()
	roster_changed.emit()


func revive_unit(unit_id: String, restored_hp := 1) -> bool:
	var unit := find_unit(unit_id)
	if unit == null:
		return false
	unit.revive(restored_hp)
	if selected_party_ids.size() < PARTY_CAPACITY and not selected_party_ids.has(unit.id):
		selected_party_ids.append(unit.id)
	roster_changed.emit()
	return true


func _inventory():
	return get_node_or_null("/root/RosterInventory")


func _add_default_roster_unit(unit: RosterUnit) -> void:
	roster_units.append(unit)
	if selected_party_ids.size() < PARTY_CAPACITY:
		selected_party_ids.append(unit.id)


func _ensure_default_roster_composition() -> void:
	var defaults := [
		_build_default_captain(),
		_build_default_footman(),
		_build_default_archer()
	]
	for default_unit in defaults:
		if find_unit(default_unit.id) == null:
			roster_units.append(default_unit)
		if default_unit.is_available_for_battle() and not selected_party_ids.has(default_unit.id) and selected_party_ids.size() < PARTY_CAPACITY:
			selected_party_ids.append(default_unit.id)


func _build_default_captain() -> RosterUnit:
	var unit := RosterUnitScript.new().setup("captain_01", "Капитан", unit_catalog["footman"])
	unit.appearance.skin_tint = Color(0.94, 0.88, 0.76, 1.0)
	unit.appearance.cape_paint = Color("7a2f2f")
	unit.appearance.shield_paint = Color("f2f2f2")
	unit.appearance.shield_emblem_id = "wolf_emblem"
	unit.equip(ItemDataScript.Slot.MAIN_HAND, ItemInstanceScript.from_data(item_catalog["iron_sword"]))
	unit.equip(ItemDataScript.Slot.OFF_HAND, ItemInstanceScript.from_data(item_catalog["kite_shield"]))
	unit.equip(ItemDataScript.Slot.BODY, ItemInstanceScript.from_data(item_catalog["padded_armor"]))
	unit.equip(ItemDataScript.Slot.HEAD, ItemInstanceScript.from_data(item_catalog["hood"]))
	unit.assign_quick_slot(0, ItemInstanceScript.from_data(item_catalog["bandage"]))
	unit.assign_quick_slot(1, ItemInstanceScript.from_data(item_catalog["bandage"]))
	return unit


func _build_default_footman() -> RosterUnit:
	var unit := RosterUnitScript.new().setup("militia_02", "Ополченец Бран", unit_catalog["footman"])
	unit.appearance.skin_tint = Color(0.79, 0.68, 0.58, 1.0)
	unit.appearance.cape_paint = Color("385a7a")
	unit.equip(ItemDataScript.Slot.MAIN_HAND, ItemInstanceScript.from_data(item_catalog["spear"]))
	unit.equip(ItemDataScript.Slot.BODY, ItemInstanceScript.from_data(item_catalog["padded_armor"]))
	unit.assign_quick_slot(0, ItemInstanceScript.from_data(item_catalog["bandage"]))
	return unit


func _build_default_archer() -> RosterUnit:
	var unit := RosterUnitScript.new().setup("archer_03", "Стрелок Лис", unit_catalog["archer"])
	unit.appearance.skin_tint = Color(0.88, 0.80, 0.68, 1.0)
	unit.appearance.cape_paint = Color("4a6a3d")
	unit.equip(ItemDataScript.Slot.MAIN_HAND, ItemInstanceScript.from_data(item_catalog["spear"]))
	unit.equip(ItemDataScript.Slot.HEAD, ItemInstanceScript.from_data(item_catalog["hood"]))
	unit.assign_quick_slot(0, ItemInstanceScript.from_data(item_catalog["bandage"]))
	return unit


func _cleanup_selected_party() -> void:
	var filtered: Array[String] = []
	for unit_id in selected_party_ids:
		if filtered.size() >= PARTY_CAPACITY:
			break
		var unit := find_unit(unit_id)
		if unit == null or unit.is_dead():
			continue
		if not filtered.has(unit_id):
			filtered.append(unit_id)
	selected_party_ids = filtered


func _rebuild_catalogs() -> void:
	unit_catalog = _build_unit_catalog()
	item_catalog = _build_item_catalog()
	wound_catalog = _build_wound_catalog()


func _create_unit_from_offer(offer: Dictionary) -> RosterUnit:
	var base_unit_id := str(offer.get("base_unit_id", "footman"))
	if not unit_catalog.has(base_unit_id):
		return null
	var unit := RosterUnitScript.new().setup(
		str(offer.get("unit_id", "recruit_%s" % str(Time.get_unix_time_from_system()))),
		str(offer.get("display_name", "Ополченец")),
		unit_catalog[base_unit_id]
	)
	unit.perm_stat_bonuses = Dictionary(offer.get("perm_stat_bonuses", {})).duplicate(true)
	var appearance_payload := Dictionary(offer.get("appearance", {}))
	if appearance_payload.has("skin_tint"):
		unit.appearance.skin_tint = Color(appearance_payload.get("skin_tint", "ffffff"))
	if appearance_payload.has("cape_paint"):
		unit.appearance.cape_paint = Color(appearance_payload.get("cape_paint", "7a2f2f"))
	if appearance_payload.has("shield_paint"):
		unit.appearance.shield_paint = Color(appearance_payload.get("shield_paint", "f2f2f2"))
	unit.appearance.shield_emblem_id = str(appearance_payload.get("shield_emblem_id", ""))
	_apply_standard_loadout(unit)
	unit.current_hp = unit.get_max_hp()
	return unit


func _apply_standard_loadout(unit: RosterUnit) -> void:
	if unit == null:
		return
	unit.equipped.clear()
	unit.quick_slots.clear()
	match unit.base_unit_id:
		"archer":
			unit.equip(ItemDataScript.Slot.MAIN_HAND, ItemInstanceScript.from_data(item_catalog["spear"]))
			unit.equip(ItemDataScript.Slot.HEAD, ItemInstanceScript.from_data(item_catalog["hood"]))
			unit.assign_quick_slot(0, ItemInstanceScript.from_data(item_catalog["bandage"]))
		_:
			unit.equip(ItemDataScript.Slot.MAIN_HAND, ItemInstanceScript.from_data(item_catalog["spear"]))
			unit.equip(ItemDataScript.Slot.BODY, ItemInstanceScript.from_data(item_catalog["padded_armor"]))
			unit.assign_quick_slot(0, ItemInstanceScript.from_data(item_catalog["bandage"]))


func _build_default_recruit_offers() -> Array[Dictionary]:
	return [
		_make_offer("recruit_offer_01", "Дорин", "footman", 0, {"max_hp": 1}, {"skin_tint": "d4b198", "cape_paint": "7a3f2f"}),
		_make_offer("recruit_offer_02", "Ярвик", "footman", 0, {"attack": 1}, {"skin_tint": "9f7c66", "cape_paint": "3d5876"}),
		_make_offer("recruit_offer_03", "Хольм", "footman", 0, {"defense": 1}, {"skin_tint": "c7a27d", "cape_paint": "6a6f3d"}),
		_make_offer("recruit_offer_04", "Сивер", "footman", 0, {"movement": 1}, {"skin_tint": "7d5f4e", "cape_paint": "5b3f7a"}),
		_make_offer("recruit_offer_05", "Торен", "footman", 0, {"initiative": 1}, {"skin_tint": "b58e71", "cape_paint": "2f6a68"}),
		_make_offer("recruit_offer_06", "Маркел", "footman", 0, {"action_points": 1}, {"skin_tint": "8c6a55", "cape_paint": "7a2f45"}),
		_make_offer("recruit_offer_07", "Эдрик", "footman", 0, {"max_hp": 1, "defense": 1}, {"skin_tint": "e0bf9a", "cape_paint": "4e5a36"}),
		_make_offer("recruit_offer_08", "Ларк", "archer", 0, {"initiative": 1}, {"skin_tint": "d7b59b", "cape_paint": "365f42"}),
		_make_offer("recruit_offer_09", "Весса", "archer", 0, {"attack_range": 1}, {"skin_tint": "b5866e", "cape_paint": "5f4b36"}),
		_make_offer("recruit_offer_10", "Рин", "archer", 0, {"movement": 1, "attack": 1}, {"skin_tint": "f0d0b2", "cape_paint": "3a5275"})
	]


func _make_offer(recruit_id: String, display_name: String, base_unit_id: String, price: int, bonuses: Dictionary, appearance: Dictionary) -> Dictionary:
	return {
		"recruit_id": recruit_id,
		"unit_id": recruit_id.replace("offer", "unit"),
		"display_name": display_name,
		"base_unit_id": base_unit_id,
		"price": price,
		"perm_stat_bonuses": bonuses.duplicate(true),
		"appearance": appearance.duplicate(true)
	}


func _find_recruit_offer_index(recruit_id: String) -> int:
	for index in range(recruit_offers.size()):
		if str(recruit_offers[index].get("recruit_id", "")) == recruit_id:
			return index
	return -1


func _can_afford_offer(offer: Dictionary) -> bool:
	var inventory: Node = _inventory()
	if inventory == null:
		return int(offer.get("price", 0)) <= 0
	return inventory.currency >= int(offer.get("price", 0))


func _charge_offer(offer: Dictionary) -> void:
	var price := int(offer.get("price", 0))
	if price <= 0:
		return
	var inventory: Node = _inventory()
	if inventory == null:
		return
	inventory.currency = maxi(0, inventory.currency - price)
	inventory.inventory_changed.emit()


func _remove_roster_unit(unit_id: String) -> bool:
	for index in range(roster_units.size() - 1, -1, -1):
		if roster_units[index].id != unit_id:
			continue
		roster_units.remove_at(index)
		selected_party_ids.erase(unit_id)
		return true
	return false


func _build_unit_catalog() -> Dictionary:
	var result := {}
	var footman := UnitData.new()
	footman.unit_id = "footman"
	footman.display_name = "Ополченец"
	footman.max_hp = 13
	footman.attack = 5
	footman.defense = 2
	footman.initiative = 10
	footman.action_points = 7
	footman.movement = 2
	footman.attack_range = 1
	footman.color = Color("7ce7ff")
	footman.allowed_slots = [
		ItemDataScript.Slot.HEAD,
		ItemDataScript.Slot.BODY,
		ItemDataScript.Slot.MAIN_HAND,
		ItemDataScript.Slot.OFF_HAND,
		ItemDataScript.Slot.BELT_1,
		ItemDataScript.Slot.BELT_2
	]
	footman.quick_slot_count = 2
	footman.carry_capacity = 30
	result[footman.unit_id] = footman

	var archer := UnitData.new()
	archer.unit_id = "archer"
	archer.display_name = "Стрелок"
	archer.max_hp = 9
	archer.attack = 4
	archer.defense = 1
	archer.initiative = 12
	archer.action_points = 7
	archer.movement = 4
	archer.attack_range = 3
	archer.color = Color("9df3ff")
	archer.allowed_slots = footman.allowed_slots.duplicate()
	archer.quick_slot_count = 3
	archer.carry_capacity = 24
	result[archer.unit_id] = archer
	return result


func _build_item_catalog() -> Dictionary:
	var result := {}

	var sword := WeaponDataScript.new()
	sword.item_id = "iron_sword"
	sword.display_name = "Железный меч"
	sword.weight = 6
	sword.value = 24
	sword.max_durability = 42
	sword.damage = 5
	sword.reach = 1
	sword.weapon_class = "sword"
	sword.equip_slots = [ItemDataScript.Slot.MAIN_HAND]
	sword.tags = ["weapons"]
	result[sword.item_id] = sword

	var spear := WeaponDataScript.new()
	spear.item_id = "spear"
	spear.display_name = "Копьё"
	spear.weight = 5
	spear.value = 22
	spear.max_durability = 34
	spear.damage = 4
	spear.reach = 2
	spear.weapon_class = "spear"
	spear.equip_slots = [ItemDataScript.Slot.MAIN_HAND]
	spear.tags = ["weapons"]
	result[spear.item_id] = spear

	var shield := ShieldDataScript.new()
	shield.item_id = "kite_shield"
	shield.display_name = "Каплевидный щит"
	shield.weight = 5
	shield.value = 20
	shield.max_durability = 48
	shield.block_chance = 0.18
	shield.block_value = 2
	shield.equip_slots = [ItemDataScript.Slot.OFF_HAND]
	shield.tags = ["armor", "shields"]
	result[shield.item_id] = shield

	var body := ArmorDataScript.new()
	body.item_id = "padded_armor"
	body.display_name = "Стёганка"
	body.weight = 8
	body.value = 28
	body.max_durability = 50
	body.armor_slot = ItemDataScript.Slot.BODY
	body.armor_value = 3
	body.fatigue_penalty = 1
	body.equip_slots = [ItemDataScript.Slot.BODY]
	body.tags = ["armor"]
	result[body.item_id] = body

	var hood := ArmorDataScript.new()
	hood.item_id = "hood"
	hood.display_name = "Капюшон"
	hood.weight = 1
	hood.value = 6
	hood.max_durability = 16
	hood.armor_slot = ItemDataScript.Slot.HEAD
	hood.armor_value = 1
	hood.equip_slots = [ItemDataScript.Slot.HEAD]
	hood.tags = ["armor"]
	result[hood.item_id] = hood

	var bandage := ConsumableDataScript.new()
	bandage.item_id = "bandage"
	bandage.display_name = "Бинт"
	bandage.weight = 1
	bandage.value = 4
	bandage.charges = 1
	bandage.out_of_battle_use = true
	bandage.consumable_class = "bandage"
	bandage.equip_slots = [ItemDataScript.Slot.BELT_1, ItemDataScript.Slot.BELT_2, ItemDataScript.Slot.BELT_3, ItemDataScript.Slot.BELT_4]
	bandage.tags = ["consumables"]
	result[bandage.item_id] = bandage

	var repair_kit := ToolDataScript.new()
	repair_kit.item_id = "repair_kit"
	repair_kit.display_name = "Набор инструментов"
	repair_kit.weight = 2
	repair_kit.value = 10
	repair_kit.repair_efficiency = 1.4
	repair_kit.tags = ["tools"]
	result[repair_kit.item_id] = repair_kit

	var paint := PaintDataScript.new()
	paint.item_id = "red_paint"
	paint.display_name = "Красная краска"
	paint.weight = 1
	paint.value = 9
	paint.max_durability = -1
	paint.tint = Color("a93434")
	paint.allowed_targets = ["shield", "cape"]
	paint.tags = ["paints"]
	result[paint.item_id] = paint

	var emblem := EmblemDataScript.new()
	emblem.item_id = "wolf_emblem"
	emblem.display_name = "Эмблема волка"
	emblem.weight = 0
	emblem.value = 8
	emblem.emblem_id = "wolf"
	emblem.tags = ["emblems"]
	result[emblem.item_id] = emblem

	return result


func _build_wound_catalog() -> Dictionary:
	var result := {}

	var bleeding := WoundDataScript.new()
	bleeding.wound_id = "bleeding"
	bleeding.display_name = "Кровотечение"
	bleeding.severity = 1
	bleeding.requires_consumable_class = "bandage"
	result[bleeding.wound_id] = bleeding

	var broken_bone := WoundDataScript.new()
	broken_bone.wound_id = "broken_bone"
	broken_bone.display_name = "Перелом"
	broken_bone.severity = 2
	broken_bone.requires_consumable_class = "splint"
	result[broken_bone.wound_id] = broken_bone

	return result
