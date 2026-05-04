extends Node

signal storage_changed
signal node_state_changed(node_id: String)

const DEFAULT_MAX_ACCUMULATION_MINUTES := 480
const AUTO_CLAIM_ON_REGISTER := true
const DEFAULT_FULL_STORAGE_DAYS := 1.0

const RESOURCE_DEFS := {
	"wood": {"name": "Дерево", "color": "8fce72"},
	"ore": {"name": "Железная руда", "color": "c4c9cf"},
	"herbs": {"name": "Травы", "color": "6bd48a"},
	"stone": {"name": "Камень", "color": "b6aa96"},
	"hides": {"name": "Шкуры", "color": "b27c52"},
	"clay": {"name": "Глина", "color": "c77758"},
	"coal": {"name": "Уголь", "color": "5e5f66"},
	"scrap": {"name": "Лом", "color": "d5b173"}
}

var city_storages := {}
var resource_nodes := {}


func _world_time_manager() -> Node:
	return get_node_or_null("/root/WorldTimeManager")


func _ready() -> void:
	reset_defaults()
	var wtm := _world_time_manager()
	if wtm != null and not wtm.minute_changed.is_connected(_on_world_minute_changed):
		wtm.minute_changed.connect(_on_world_minute_changed)


func reset_defaults() -> void:
	city_storages = {}
	resource_nodes.clear()
	_ensure_city_storage(_default_city_name())
	storage_changed.emit()


func get_resource_amount(resource_type: String, settlement_name := "") -> int:
	var city_name := _resolve_city_name(settlement_name)
	var storage := _ensure_city_storage(city_name)
	return int(storage.get(resource_type, 0))


func get_resource_name(resource_type: String) -> String:
	return str(RESOURCE_DEFS.get(resource_type, {}).get("name", resource_type))


func get_resource_color(resource_type: String) -> Color:
	return Color(str(RESOURCE_DEFS.get(resource_type, {}).get("color", "ffffff")))


func ensure_node_registered(location_data) -> Dictionary:
	if location_data == null:
		return {}
	var node_id := _node_id_from_location(location_data)
	if node_id == "":
		return {}
	var settlement_name := _resolve_node_settlement_name(location_data)
	if not resource_nodes.has(node_id):
		resource_nodes[node_id] = {
			"claimed": AUTO_CLAIM_ON_REGISTER,
			"level": 1,
			"stored_amount": 0.0,
			"last_game_hour": _current_game_hours(),
			"max_accumulation_minutes": int(location_data.metadata.get("max_accumulation_minutes", DEFAULT_MAX_ACCUMULATION_MINUTES)),
			"settlement_name": settlement_name,
			"resource_type": str(location_data.metadata.get("resource_type", "wood")),
			"yield_per_minute": float(location_data.metadata.get("yield_per_minute", 1.0)),
			"storage_cap": float(location_data.metadata.get("storage_cap", 30.0)),
			"full_storage_days": float(location_data.metadata.get("full_storage_days", DEFAULT_FULL_STORAGE_DAYS))
		}
	elif AUTO_CLAIM_ON_REGISTER and not bool(resource_nodes[node_id].get("claimed", false)):
		resource_nodes[node_id]["claimed"] = true
	if str(resource_nodes[node_id].get("settlement_name", "")) == "":
		resource_nodes[node_id]["settlement_name"] = settlement_name
	resource_nodes[node_id]["resource_type"] = str(location_data.metadata.get("resource_type", resource_nodes[node_id].get("resource_type", "wood")))
	resource_nodes[node_id]["yield_per_minute"] = float(location_data.metadata.get("yield_per_minute", resource_nodes[node_id].get("yield_per_minute", 1.0)))
	resource_nodes[node_id]["storage_cap"] = float(location_data.metadata.get("storage_cap", resource_nodes[node_id].get("storage_cap", 30.0)))
	resource_nodes[node_id]["full_storage_days"] = float(location_data.metadata.get("full_storage_days", resource_nodes[node_id].get("full_storage_days", DEFAULT_FULL_STORAGE_DAYS)))
	resource_nodes[node_id]["max_accumulation_minutes"] = int(location_data.metadata.get("max_accumulation_minutes", resource_nodes[node_id].get("max_accumulation_minutes", DEFAULT_MAX_ACCUMULATION_MINUTES)))
	_ensure_city_storage(str(resource_nodes[node_id].get("settlement_name", settlement_name)))
	return Dictionary(resource_nodes[node_id])


func get_node_snapshot(location_data) -> Dictionary:
	var state := ensure_node_registered(location_data)
	if state.is_empty():
		return {}
	_sync_node_state(location_data)
	return Dictionary(resource_nodes[_node_id_from_location(location_data)]).duplicate(true)


func claim_node(location_data) -> bool:
	var node_id := _node_id_from_location(location_data)
	var state := ensure_node_registered(location_data)
	if state.is_empty():
		return false
	if bool(state.get("claimed", false)):
		return true
	state["claimed"] = true
	state["stored_amount"] = 0.0
	state["last_game_hour"] = _current_game_hours()
	resource_nodes[node_id] = state
	node_state_changed.emit(node_id)
	return true


func collect_node(location_data) -> int:
	var node_id := _node_id_from_location(location_data)
	var state := get_node_snapshot(location_data)
	if state.is_empty() or not bool(state.get("claimed", false)):
		return 0
	var whole_amount := int(floor(float(state.get("stored_amount", 0.0))))
	if whole_amount <= 0:
		return 0
	var resource_type := str(location_data.metadata.get("resource_type", "wood"))
	var settlement_name := str(state.get("settlement_name", _resolve_node_settlement_name(location_data)))
	var storage := _ensure_city_storage(settlement_name)
	storage[resource_type] = int(storage.get(resource_type, 0)) + whole_amount
	state["stored_amount"] = float(state.get("stored_amount", 0.0)) - whole_amount
	resource_nodes[node_id] = state
	storage_changed.emit()
	node_state_changed.emit(node_id)
	return whole_amount


func build_node_summary(location_data) -> String:
	var state := get_node_snapshot(location_data)
	if state.is_empty():
		return "Источник недоступен."
	var source_type := str(location_data.metadata.get("source_type", "resource"))
	var resource_type := str(location_data.metadata.get("resource_type", "wood"))
	var stored_amount := float(state.get("stored_amount", 0.0))
	var cap := _storage_cap_for(location_data, state)
	var display_stored := int(floor(stored_amount))
	var display_cap := int(round(cap))
	var yield_per_minute := _yield_per_minute_for(location_data, state)
	var full_storage_days := float(state.get("full_storage_days", DEFAULT_FULL_STORAGE_DAYS))
	var settlement_name := str(state.get("settlement_name", _resolve_node_settlement_name(location_data)))
	var status := "Активен" if bool(state.get("claimed", false)) else "Отключён"
	var description := str(location_data.metadata.get("description", ""))
	return "[b]%s[/b]\nТип: %s\nРесурс: %s\nСклад: %s\nСтатус: %s\nДобыча: %.3f / мин\nПолный цикл: %.2f сут.\nНакоплено: %.1f / %.1f\nУровень: %d\n\n%s" % [
		location_data.display_name,
		source_type,
		get_resource_name(resource_type),
		settlement_name,
		status,
		yield_per_minute,
		full_storage_days,
		display_stored,
		display_cap,
		int(state.get("level", 1)),
		description
	]


func build_storage_summary(settlement_name := "") -> String:
	var city_name := _resolve_city_name(settlement_name)
	var storage := _ensure_city_storage(city_name)
	var lines: Array[String] = []
	for resource_type in RESOURCE_DEFS.keys():
		lines.append("%s: %d" % [get_resource_name(resource_type), int(storage.get(resource_type, 0))])
	return "\n".join(lines)


func to_dict() -> Dictionary:
	return {
		"city_storages": city_storages.duplicate(true),
		"resource_nodes": resource_nodes.duplicate(true)
	}


func load_from_dict(payload: Dictionary) -> void:
	reset_defaults()
	var storages_payload := Dictionary(payload.get("city_storages", {}))
	for city_name in storages_payload.keys():
		var storage := _ensure_city_storage(str(city_name))
		for resource_type in Dictionary(storages_payload[city_name]).keys():
			storage[str(resource_type)] = int(storages_payload[city_name][resource_type])
	var legacy_resources := Dictionary(payload.get("city_resources", {}))
	if not legacy_resources.is_empty():
		var default_storage := _ensure_city_storage(_default_city_name())
		for resource_type in legacy_resources.keys():
			default_storage[str(resource_type)] = int(legacy_resources[resource_type])
	resource_nodes = Dictionary(payload.get("resource_nodes", {})).duplicate(true)
	if AUTO_CLAIM_ON_REGISTER:
		for node_id in resource_nodes.keys():
			resource_nodes[node_id]["claimed"] = true
			if str(resource_nodes[node_id].get("settlement_name", "")) == "":
				resource_nodes[node_id]["settlement_name"] = _default_city_name()
	storage_changed.emit()


func _sync_node_state(location_data) -> void:
	var node_id := _node_id_from_location(location_data)
	var state := ensure_node_registered(location_data)
	if state.is_empty():
		return
	_sync_node_state_by_id(node_id)


func _sync_node_state_by_id(node_id: String) -> void:
	if not resource_nodes.has(node_id):
		return
	var state: Dictionary = Dictionary(resource_nodes[node_id])
	if state.is_empty() or not bool(state.get("claimed", false)):
		return
	var now_hours := _current_game_hours()
	var last_hour: float = float(state.get("last_game_hour", now_hours))
	var elapsed_hours := maxf(0.0, now_hours - last_hour)
	if elapsed_hours <= 0.0:
		return
	var elapsed_minutes := elapsed_hours * 60.0
	if elapsed_minutes <= 0.0:
		return
	var produced := elapsed_minutes * _yield_per_minute_for(null, state)
	state["stored_amount"] = float(state.get("stored_amount", 0.0)) + produced
	state["last_game_hour"] = now_hours
	var storage_changed_now := _auto_ship_completed_batches(state)
	resource_nodes[node_id] = state
	if storage_changed_now:
		storage_changed.emit()
	node_state_changed.emit(node_id)


func _auto_ship_completed_batches(state: Dictionary) -> bool:
	var cap := _storage_cap_for(null, state)
	if cap <= 0.0:
		return false
	var stored_amount: float = float(state.get("stored_amount", 0.0))
	if stored_amount < cap:
		return false
	var completed_batches: int = int(floor(stored_amount / cap))
	if completed_batches <= 0:
		return false
	var shipment_amount: int = int(floor(float(completed_batches) * cap))
	if shipment_amount <= 0:
		return false
	var settlement_name := str(state.get("settlement_name", _default_city_name()))
	var resource_type := str(state.get("resource_type", "wood"))
	var storage := _ensure_city_storage(settlement_name)
	storage[resource_type] = int(storage.get(resource_type, 0)) + shipment_amount
	state["stored_amount"] = maxf(0.0, stored_amount - float(shipment_amount))
	return true


func _current_game_hours() -> float:
	var wtm := get_node_or_null("/root/WorldTimeManager")
	if wtm != null:
		return float(wtm.total_hours)
	# Фоллбэк на реальное время (в случае запуска без WorldTimeManager)
	return float(Time.get_unix_time_from_system()) / 3600.0


func _yield_per_minute_for(location_data, state: Dictionary) -> float:
	var full_storage_days := float(state.get("full_storage_days", DEFAULT_FULL_STORAGE_DAYS))
	if location_data != null:
		full_storage_days = float(location_data.metadata.get("full_storage_days", full_storage_days))
	if full_storage_days > 0.0:
		var cycle_minutes := full_storage_days * 24.0 * 60.0
		var effective_cap := _storage_cap_for(location_data, state)
		return effective_cap / cycle_minutes
	var base_value := float(state.get("yield_per_minute", 1.0))
	if location_data != null:
		base_value = float(location_data.metadata.get("yield_per_minute", base_value))
	var level := int(state.get("level", 1))
	return base_value * (1.0 + float(level - 1) * 0.35)


func _storage_cap_for(location_data, state: Dictionary) -> float:
	var base_value := float(state.get("storage_cap", 30.0))
	if location_data != null:
		base_value = float(location_data.metadata.get("storage_cap", base_value))
	var level := int(state.get("level", 1))
	return base_value * (1.0 + float(level - 1) * 0.4)


func _node_id_from_location(location_data) -> String:
	return str(location_data.metadata.get("node_id", ""))


func _ensure_city_storage(settlement_name: String) -> Dictionary:
	var city_name := _resolve_city_name(settlement_name)
	if not city_storages.has(city_name):
		var storage := {}
		for resource_type in RESOURCE_DEFS.keys():
			storage[resource_type] = 0
		city_storages[city_name] = storage
	return city_storages[city_name]


func _resolve_city_name(settlement_name: String) -> String:
	if settlement_name != "":
		return settlement_name
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and game_state.has_method("get_current_settlement"):
		var current_name := str(game_state.get_current_settlement())
		if current_name != "":
			return current_name
	return _default_city_name()


func _default_city_name() -> String:
	var world_generator := get_node_or_null("/root/WorldGenerator")
	if world_generator == null:
		return "Столица"
	var world_meta = world_generator.get_world_meta()
	if world_meta == null or world_meta.capital == null:
		return "Столица"
	return str(world_meta.capital.settlement_name)


func _resolve_node_settlement_name(location_data) -> String:
	if location_data == null:
		return _default_city_name()
	var metadata: Dictionary = location_data.metadata
	var explicit_name := str(metadata.get("settlement_name", ""))
	if explicit_name != "":
		return explicit_name
	var world_generator := get_node_or_null("/root/WorldGenerator")
	if world_generator == null:
		return _default_city_name()
	var world_meta = world_generator.get_world_meta()
	if world_meta == null or world_meta.settlements.is_empty():
		return _default_city_name()
	var best_name := _default_city_name()
	var best_distance := INF
	for settlement in world_meta.settlements:
		var distance: float = settlement.map_position.distance_to(location_data.map_position)
		if distance < best_distance:
			best_distance = distance
			best_name = str(settlement.settlement_name)
	return best_name


func _on_world_minute_changed(_hour: int, _minute: int) -> void:
	var node_ids: Array = resource_nodes.keys()
	for raw_node_id in node_ids:
		_sync_node_state_by_id(str(raw_node_id))
