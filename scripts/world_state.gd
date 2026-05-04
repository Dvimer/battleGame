extends Node

const FORGE_COST := 12
const GARDEN_COST := 10

const FARM_FIELD_COUNT := 12
const FARM_START_UNLOCKED_FIELDS := 2
const FARM_CELLS_PER_FIELD := 9

const FARM_CROP_DEFS := {
	"wheat": {
		"seed_name": "Семена пшеницы",
		"produce_name": "Пшеница",
		"grow_hours": 18.0,
		"yield_amount": 4,
		"seed_color": "d8c25c",
		"produce_color": "d9c35f",
		"visual": "stalk"
	},
	"carrot": {
		"seed_name": "Семена моркови",
		"produce_name": "Морковь",
		"grow_hours": 16.0,
		"yield_amount": 4,
		"seed_color": "f18d42",
		"produce_color": "f18d42",
		"visual": "root"
	},
	"potato": {
		"seed_name": "Клубни картофеля",
		"produce_name": "Картофель",
		"grow_hours": 22.0,
		"yield_amount": 5,
		"seed_color": "b88a58",
		"produce_color": "b88a58",
		"visual": "mound"
	},
	"cabbage": {
		"seed_name": "Семена капусты",
		"produce_name": "Капуста",
		"grow_hours": 26.0,
		"yield_amount": 3,
		"seed_color": "76b45d",
		"produce_color": "76b45d",
		"visual": "cabbage"
	},
	"tomato": {
		"seed_name": "Семена томата",
		"produce_name": "Томаты",
		"grow_hours": 20.0,
		"yield_amount": 4,
		"seed_color": "d6554e",
		"produce_color": "d6554e",
		"visual": "tomato"
	},
	"cucumber": {
		"seed_name": "Семена огурца",
		"produce_name": "Огурцы",
		"grow_hours": 19.0,
		"yield_amount": 4,
		"seed_color": "5fb75a",
		"produce_color": "5fb75a",
		"visual": "vine"
	},
	"onion": {
		"seed_name": "Семена лука",
		"produce_name": "Лук",
		"grow_hours": 17.0,
		"yield_amount": 4,
		"seed_color": "c793d4",
		"produce_color": "c793d4",
		"visual": "bulb"
	},
	"pumpkin": {
		"seed_name": "Семена тыквы",
		"produce_name": "Тыквы",
		"grow_hours": 28.0,
		"yield_amount": 2,
		"seed_color": "d7833a",
		"produce_color": "d7833a",
		"visual": "pumpkin"
	},
	"corn": {
		"seed_name": "Семена кукурузы",
		"produce_name": "Кукуруза",
		"grow_hours": 24.0,
		"yield_amount": 3,
		"seed_color": "f0cf5b",
		"produce_color": "f0cf5b",
		"visual": "corn"
	},
	"apple_tree": {
		"seed_name": "Саженец яблони",
		"produce_name": "Яблоки",
		"grow_hours": 36.0,
		"yield_amount": 5,
		"seed_color": "da574f",
		"produce_color": "da574f",
		"visual": "tree"
	}
}

const FARM_STARTER_SEEDS := {
	"wheat": 18,
	"carrot": 12,
	"potato": 10,
	"cabbage": 8,
	"tomato": 10,
	"cucumber": 10,
	"onion": 10,
	"pumpkin": 6,
	"corn": 8,
	"apple_tree": 4
}

var bank_essence := 0
var pending_chest_essence := 0
var forge_built := false
var garden_built := false
var next_run_attack_bonus := 0
var next_run_health_bonus := 0
var next_run_dash_bonus := 0
var town_message_key := ""
var town_message_params := {}

var farm_unlocked_fields := FARM_START_UNLOCKED_FIELDS
var farm_fields: Array = []
var farm_shed_seeds := {}
var farm_shed_produce := {}


func _localizer() -> Node:
	return get_node_or_null("/root/Localizer")


func can_afford(cost: int) -> bool:
	return bank_essence >= cost


func spend_essence(cost: int) -> bool:
	if cost > bank_essence:
		return false
	bank_essence -= cost
	return true


func collect_chest() -> int:
	var collected := pending_chest_essence
	bank_essence += pending_chest_essence
	pending_chest_essence = 0
	return collected


func stash_city_reward(base_reward: int) -> int:
	var multiplier := 1.25 if forge_built else 1.0
	var stored := int(round(base_reward * multiplier))
	pending_chest_essence += stored
	return stored


func build_forge() -> bool:
	if forge_built or not spend_essence(FORGE_COST):
		return false
	forge_built = true
	return true


func build_garden() -> bool:
	if garden_built or not spend_essence(GARDEN_COST):
		return false
	garden_built = true
	return true


func buy_attack_tonic() -> bool:
	if not spend_essence(6):
		return false
	next_run_attack_bonus += 1
	return true


func buy_ration_pack() -> bool:
	if not spend_essence(5):
		return false
	next_run_health_bonus += 1
	return true


func buy_dash_boots() -> bool:
	if not spend_essence(5):
		return false
	next_run_dash_bonus += 1
	return true


func set_town_message(key: String, params := {}) -> void:
	town_message_key = key
	town_message_params = params.duplicate()


func consume_town_message() -> String:
	if town_message_key == "":
		return ""
	var localizer := _localizer()
	var message := town_message_key
	if localizer != null:
		message = localizer.t(town_message_key, town_message_params)
	town_message_key = ""
	town_message_params = {}
	return message


func consume_expedition_setup() -> Dictionary:
	var setup := {
		"attack_damage_bonus": next_run_attack_bonus,
		"max_health_bonus": next_run_health_bonus + (1 if garden_built else 0),
		"dash_speed_bonus": float(next_run_dash_bonus) * 90.0,
		"dash_charge_bonus": next_run_dash_bonus,
		"slash_range_bonus": 10.0 if forge_built else 0.0
	}
	next_run_attack_bonus = 0
	next_run_health_bonus = 0
	next_run_dash_bonus = 0
	return setup


func describe_next_run_bonus() -> String:
	var localizer := _localizer()
	var parts: Array[String] = []
	if next_run_attack_bonus > 0:
		parts.append(localizer.t("bonus.attack", {"value": next_run_attack_bonus}) if localizer != null else "+%d attack" % next_run_attack_bonus)
	if next_run_health_bonus > 0:
		parts.append(localizer.t("bonus.hp", {"value": next_run_health_bonus}) if localizer != null else "+%d max HP" % next_run_health_bonus)
	if next_run_dash_bonus > 0:
		parts.append(localizer.t("bonus.dash", {"value": next_run_dash_bonus}) if localizer != null else "+%d dash tune" % next_run_dash_bonus)
	if garden_built:
		parts.append(localizer.t("bonus.garden") if localizer != null else "garden blessing")
	if forge_built:
		parts.append(localizer.t("bonus.forge") if localizer != null else "forge edge")
	return ", ".join(parts)


func serialize() -> Dictionary:
	_normalize_farm_state()
	return {
		"bank_essence": bank_essence,
		"pending_chest_essence": pending_chest_essence,
		"forge_built": forge_built,
		"garden_built": garden_built,
		"next_run_attack_bonus": next_run_attack_bonus,
		"next_run_health_bonus": next_run_health_bonus,
		"next_run_dash_bonus": next_run_dash_bonus,
		"town_message_key": town_message_key,
		"town_message_params": town_message_params.duplicate(true),
		"farm_unlocked_fields": farm_unlocked_fields,
		"farm_fields": farm_fields.duplicate(true),
		"farm_shed_seeds": farm_shed_seeds.duplicate(true),
		"farm_shed_produce": farm_shed_produce.duplicate(true)
	}


func deserialize(data: Dictionary) -> void:
	bank_essence = int(data.get("bank_essence", 0))
	pending_chest_essence = int(data.get("pending_chest_essence", 0))
	forge_built = bool(data.get("forge_built", false))
	garden_built = bool(data.get("garden_built", false))
	next_run_attack_bonus = int(data.get("next_run_attack_bonus", 0))
	next_run_health_bonus = int(data.get("next_run_health_bonus", 0))
	next_run_dash_bonus = int(data.get("next_run_dash_bonus", 0))
	town_message_key = str(data.get("town_message_key", ""))
	town_message_params = Dictionary(data.get("town_message_params", {})).duplicate(true)
	farm_unlocked_fields = int(data.get("farm_unlocked_fields", FARM_START_UNLOCKED_FIELDS))
	farm_fields = Array(data.get("farm_fields", _build_default_fields())).duplicate(true)
	farm_shed_seeds = Dictionary(data.get("farm_shed_seeds", FARM_STARTER_SEEDS)).duplicate(true)
	farm_shed_produce = Dictionary(data.get("farm_shed_produce", _empty_crop_stock())).duplicate(true)
	_normalize_farm_state()


func get_farm_field_count() -> int:
	return FARM_FIELD_COUNT


func get_unlocked_farm_fields() -> int:
	_normalize_farm_state()
	return farm_unlocked_fields


func get_locked_farm_fields() -> int:
	return maxi(0, FARM_FIELD_COUNT - get_unlocked_farm_fields())


func get_farm_field_buy_cost(field_index: int) -> int:
	return 8 + field_index * 3


func can_buy_farm_field(field_index: int) -> bool:
	_normalize_farm_state()
	if field_index < 0 or field_index >= FARM_FIELD_COUNT:
		return false
	if field_index != farm_unlocked_fields:
		return false
	return can_afford(get_farm_field_buy_cost(field_index))


func buy_farm_field(field_index: int) -> bool:
	_normalize_farm_state()
	if field_index < 0 or field_index >= FARM_FIELD_COUNT:
		return false
	if field_index != farm_unlocked_fields:
		return false
	var cost := get_farm_field_buy_cost(field_index)
	if not spend_essence(cost):
		return false
	farm_unlocked_fields += 1
	_normalize_farm_state()
	return true


func get_farm_summary(current_hours: float) -> String:
	_normalize_farm_state()
	var planted := 0
	var ready := 0
	for field_index in range(farm_unlocked_fields):
		for cell in _field_cells(field_index):
			var cell_data := Dictionary(cell)
			if _cell_has_crop(cell_data):
				planted += 1
				if _resolve_cell_stage(cell_data, current_hours) == "ready":
					ready += 1
	return "Открыто полей %d / %d\nЗанято ячеек %d / %d\nГотово к сбору %d\nСемян на складе %d" % [
		farm_unlocked_fields,
		FARM_FIELD_COUNT,
		planted,
		farm_unlocked_fields * FARM_CELLS_PER_FIELD,
		ready,
		_total_seed_count()
	]


func get_total_planted_cells(current_hours: float) -> int:
	_normalize_farm_state()
	var total := 0
	for field_index in range(farm_unlocked_fields):
		for cell in _field_cells(field_index):
			if _cell_has_crop(Dictionary(cell)):
				total += 1
	return total


func get_total_ready_cells(current_hours: float) -> int:
	_normalize_farm_state()
	var total := 0
	for field_index in range(farm_unlocked_fields):
		for cell in _field_cells(field_index):
			if _resolve_cell_stage(Dictionary(cell), current_hours) == "ready":
				total += 1
	return total


func get_total_seed_count() -> int:
	_normalize_farm_state()
	return _total_seed_count()


func get_farm_fields_status(current_hours: float) -> Array:
	_normalize_farm_state()
	var result: Array = []
	for field_index in range(FARM_FIELD_COUNT):
		var field_status := {
			"index": field_index,
			"unlocked": field_index < farm_unlocked_fields,
			"buy_cost": get_farm_field_buy_cost(field_index),
			"cells": []
		}
		var cells: Array = []
		for raw_cell in _field_cells(field_index):
			var cell := Dictionary(raw_cell)
			var cell_status := {
				"crop_id": str(cell.get("crop_id", "")),
				"stage": _resolve_cell_stage(cell, current_hours),
				"progress": _cell_progress(cell, current_hours)
			}
			cells.append(cell_status)
		field_status["cells"] = cells
		result.append(field_status)
	return result


func get_farm_cell_status(field_index: int, cell_index: int, current_hours: float) -> Dictionary:
	_normalize_farm_state()
	if not _valid_field_and_cell(field_index, cell_index):
		return {}
	var field := Dictionary(farm_fields[field_index])
	var cells: Array = field.get("cells", [])
	var cell := Dictionary(cells[cell_index])
	return {
		"field_index": field_index,
		"cell_index": cell_index,
		"unlocked": field_index < farm_unlocked_fields,
		"buy_cost": get_farm_field_buy_cost(field_index),
		"crop_id": str(cell.get("crop_id", "")),
		"stage": _resolve_cell_stage(cell, current_hours),
		"progress": _cell_progress(cell, current_hours)
	}


func plant_seed(field_index: int, cell_index: int, crop_id: String, current_hours: float) -> bool:
	_normalize_farm_state()
	if not _valid_field_and_cell(field_index, cell_index):
		return false
	if field_index >= farm_unlocked_fields:
		return false
	if not FARM_CROP_DEFS.has(crop_id):
		return false
	if int(farm_shed_seeds.get(crop_id, 0)) <= 0:
		return false
	var field := Dictionary(farm_fields[field_index])
	var cells: Array = Array(field.get("cells", [])).duplicate(true)
	var cell := Dictionary(cells[cell_index])
	if _cell_has_crop(cell):
		return false
	cell["crop_id"] = crop_id
	cell["planted_at_hours"] = current_hours
	cells[cell_index] = cell
	field["cells"] = cells
	farm_fields[field_index] = field
	farm_shed_seeds[crop_id] = int(farm_shed_seeds.get(crop_id, 0)) - 1
	return true


func harvest_farm_cell(field_index: int, cell_index: int, current_hours: float) -> Dictionary:
	_normalize_farm_state()
	if not _valid_field_and_cell(field_index, cell_index):
		return {}
	if field_index >= farm_unlocked_fields:
		return {}
	var field := Dictionary(farm_fields[field_index])
	var cells: Array = Array(field.get("cells", [])).duplicate(true)
	var cell := Dictionary(cells[cell_index])
	if _resolve_cell_stage(cell, current_hours) != "ready":
		return {}
	var crop_id := str(cell.get("crop_id", ""))
	var crop_def := Dictionary(FARM_CROP_DEFS.get(crop_id, {}))
	var amount := int(crop_def.get("yield_amount", 0))
	if amount <= 0:
		return {}
	farm_shed_produce[crop_id] = int(farm_shed_produce.get(crop_id, 0)) + amount
	cells[cell_index] = _empty_field_cell()
	field["cells"] = cells
	farm_fields[field_index] = field
	return {
		"crop_id": crop_id,
		"produce_name": str(crop_def.get("produce_name", crop_id)),
		"amount": amount
	}


func get_farm_available_seed_ids() -> Array[String]:
	_normalize_farm_state()
	var ids: Array[String] = []
	for crop_id in FARM_CROP_DEFS.keys():
		if int(farm_shed_seeds.get(crop_id, 0)) > 0:
			ids.append(String(crop_id))
	return ids


func get_farm_seed_count(crop_id: String) -> int:
	_normalize_farm_state()
	return int(farm_shed_seeds.get(crop_id, 0))


func get_farm_produce_count(crop_id: String) -> int:
	_normalize_farm_state()
	return int(farm_shed_produce.get(crop_id, 0))


func get_farm_crop_seed_name(crop_id: String) -> String:
	return str(FARM_CROP_DEFS.get(crop_id, {}).get("seed_name", crop_id))


func get_farm_crop_produce_name(crop_id: String) -> String:
	return str(FARM_CROP_DEFS.get(crop_id, {}).get("produce_name", crop_id))


func get_farm_crop_visual(crop_id: String) -> String:
	return str(FARM_CROP_DEFS.get(crop_id, {}).get("visual", "sprout"))


func get_farm_crop_seed_color(crop_id: String) -> Color:
	return Color(str(FARM_CROP_DEFS.get(crop_id, {}).get("seed_color", "ffffff")))


func get_farm_shed_items() -> Array:
	_normalize_farm_state()
	var items: Array = []
	for crop_id in FARM_CROP_DEFS.keys():
		items.append({
			"id": "%s_seed" % crop_id,
			"crop_id": crop_id,
			"type": "seed",
			"name": get_farm_crop_seed_name(crop_id),
			"count": int(farm_shed_seeds.get(crop_id, 0)),
			"visual": get_farm_crop_visual(crop_id),
			"color": get_farm_crop_seed_color(crop_id)
		})
		items.append({
			"id": "%s_produce" % crop_id,
			"crop_id": crop_id,
			"type": "produce",
			"name": get_farm_crop_produce_name(crop_id),
			"count": int(farm_shed_produce.get(crop_id, 0)),
			"visual": get_farm_crop_visual(crop_id),
			"color": get_farm_crop_seed_color(crop_id)
		})
	return items


func build_farm_shed_summary() -> String:
	_normalize_farm_state()
	var lines: Array[String] = ["[b]Семена[/b]"]
	for crop_id in FARM_CROP_DEFS.keys():
		lines.append("%s: %d" % [get_farm_crop_seed_name(crop_id), int(farm_shed_seeds.get(crop_id, 0))])
	lines.append("")
	lines.append("[b]Урожай[/b]")
	for crop_id in FARM_CROP_DEFS.keys():
		lines.append("%s: %d" % [get_farm_crop_produce_name(crop_id), int(farm_shed_produce.get(crop_id, 0))])
	return "\n".join(lines)


func _normalize_farm_state() -> void:
	farm_unlocked_fields = clampi(farm_unlocked_fields, FARM_START_UNLOCKED_FIELDS, FARM_FIELD_COUNT)
	if farm_fields.size() != FARM_FIELD_COUNT:
		farm_fields = _build_default_fields()
	for field_index in range(FARM_FIELD_COUNT):
		var field := Dictionary(farm_fields[field_index])
		var cells: Array = Array(field.get("cells", [])).duplicate(true)
		if cells.size() != FARM_CELLS_PER_FIELD:
			cells = _build_empty_cells()
		for cell_index in range(FARM_CELLS_PER_FIELD):
			var cell := Dictionary(cells[cell_index])
			var crop_id := str(cell.get("crop_id", ""))
			if crop_id != "" and not FARM_CROP_DEFS.has(crop_id):
				cell = _empty_field_cell()
			cells[cell_index] = {
				"crop_id": str(cell.get("crop_id", "")),
				"planted_at_hours": float(cell.get("planted_at_hours", 0.0))
			}
		field["cells"] = cells
		farm_fields[field_index] = field
	var normalized_seeds := _empty_crop_stock()
	for crop_id in FARM_CROP_DEFS.keys():
		normalized_seeds[crop_id] = int(farm_shed_seeds.get(crop_id, FARM_STARTER_SEEDS.get(crop_id, 0)))
	farm_shed_seeds = normalized_seeds
	var normalized_produce := _empty_crop_stock()
	for crop_id in FARM_CROP_DEFS.keys():
		normalized_produce[crop_id] = int(farm_shed_produce.get(crop_id, 0))
	farm_shed_produce = normalized_produce


func _resolve_cell_stage(cell: Dictionary, current_hours: float) -> String:
	if not _cell_has_crop(cell):
		return "empty"
	var crop_id := str(cell.get("crop_id", ""))
	var planted_at := float(cell.get("planted_at_hours", current_hours))
	var grow_hours := float(FARM_CROP_DEFS[crop_id].get("grow_hours", 24.0))
	return "ready" if current_hours - planted_at >= grow_hours else "growing"


func _cell_progress(cell: Dictionary, current_hours: float) -> float:
	if not _cell_has_crop(cell):
		return 0.0
	var crop_id := str(cell.get("crop_id", ""))
	var planted_at := float(cell.get("planted_at_hours", current_hours))
	var grow_hours := maxf(1.0, float(FARM_CROP_DEFS[crop_id].get("grow_hours", 24.0)))
	return clampf((current_hours - planted_at) / grow_hours, 0.0, 1.0)


func _field_cells(field_index: int) -> Array:
	return Array(Dictionary(farm_fields[field_index]).get("cells", []))


func _valid_field_and_cell(field_index: int, cell_index: int) -> bool:
	return field_index >= 0 and field_index < FARM_FIELD_COUNT and cell_index >= 0 and cell_index < FARM_CELLS_PER_FIELD


func _cell_has_crop(cell: Dictionary) -> bool:
	return str(cell.get("crop_id", "")) != ""


func _empty_field_cell() -> Dictionary:
	return {
		"crop_id": "",
		"planted_at_hours": 0.0
	}


func _build_empty_cells() -> Array:
	var cells: Array = []
	for _i in range(FARM_CELLS_PER_FIELD):
		cells.append(_empty_field_cell())
	return cells


func _build_default_fields() -> Array:
	var fields: Array = []
	for field_index in range(FARM_FIELD_COUNT):
		fields.append({
			"field_index": field_index,
			"cells": _build_empty_cells()
		})
	return fields


func _empty_crop_stock() -> Dictionary:
	var stock := {}
	for crop_id in FARM_CROP_DEFS.keys():
		stock[crop_id] = 0
	return stock


func _total_seed_count() -> int:
	var total := 0
	for crop_id in FARM_CROP_DEFS.keys():
		total += int(farm_shed_seeds.get(crop_id, 0))
	return total
