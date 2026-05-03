extends Node

signal storage_changed
signal node_state_changed(node_id: String)

const DEFAULT_MAX_ACCUMULATION_MINUTES := 480

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

var city_resources := {}
var resource_nodes := {}


func _ready() -> void:
	reset_defaults()


func reset_defaults() -> void:
	city_resources = {}
	for resource_type in RESOURCE_DEFS.keys():
		city_resources[resource_type] = 0
	resource_nodes.clear()
	storage_changed.emit()


func get_resource_amount(resource_type: String) -> int:
	return int(city_resources.get(resource_type, 0))


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
	if not resource_nodes.has(node_id):
		resource_nodes[node_id] = {
			"claimed": false,
			"level": 1,
			"stored_amount": 0.0,
			"last_tick_unix": Time.get_unix_time_from_system(),
			"max_accumulation_minutes": int(location_data.metadata.get("max_accumulation_minutes", DEFAULT_MAX_ACCUMULATION_MINUTES))
		}
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
	state["last_tick_unix"] = Time.get_unix_time_from_system()
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
	city_resources[resource_type] = get_resource_amount(resource_type) + whole_amount
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
	var yield_per_minute := _yield_per_minute_for(location_data, state)
	var max_accumulation := int(state.get("max_accumulation_minutes", DEFAULT_MAX_ACCUMULATION_MINUTES))
	var status := "Подключён" if bool(state.get("claimed", false)) else "Не подключён"
	var description := str(location_data.metadata.get("description", ""))
	return "[b]%s[/b]\nТип: %s\nРесурс: %s\nСтатус: %s\nДобыча: %.1f / мин\nНакоплено: %.1f / %.1f\nУровень: %d\nЛимит накопления: %d ч.\n\n%s" % [
		location_data.display_name,
		source_type,
		get_resource_name(resource_type),
		status,
		yield_per_minute,
		stored_amount,
		cap,
		int(state.get("level", 1)),
		int(round(max_accumulation / 60.0)),
		description
	]


func build_storage_summary() -> String:
	var lines: Array[String] = []
	for resource_type in RESOURCE_DEFS.keys():
		lines.append("%s: %d" % [get_resource_name(resource_type), get_resource_amount(resource_type)])
	return "\n".join(lines)


func to_dict() -> Dictionary:
	return {
		"city_resources": city_resources.duplicate(true),
		"resource_nodes": resource_nodes.duplicate(true)
	}


func load_from_dict(payload: Dictionary) -> void:
	reset_defaults()
	for resource_type in Dictionary(payload.get("city_resources", {})).keys():
		city_resources[str(resource_type)] = int(payload["city_resources"][resource_type])
	resource_nodes = Dictionary(payload.get("resource_nodes", {})).duplicate(true)
	storage_changed.emit()


func _sync_node_state(location_data) -> void:
	var node_id := _node_id_from_location(location_data)
	var state := ensure_node_registered(location_data)
	if state.is_empty() or not bool(state.get("claimed", false)):
		return
	var now_unix := Time.get_unix_time_from_system()
	var last_tick := int(state.get("last_tick_unix", now_unix))
	var elapsed_seconds := maxi(0, now_unix - last_tick)
	if elapsed_seconds <= 0:
		return
	var elapsed_minutes := minf(float(elapsed_seconds) / 60.0, float(state.get("max_accumulation_minutes", DEFAULT_MAX_ACCUMULATION_MINUTES)))
	if elapsed_minutes <= 0.0:
		return
	var produced := elapsed_minutes * _yield_per_minute_for(location_data, state)
	state["stored_amount"] = minf(float(state.get("stored_amount", 0.0)) + produced, _storage_cap_for(location_data, state))
	state["last_tick_unix"] = now_unix
	resource_nodes[node_id] = state


func _yield_per_minute_for(location_data, state: Dictionary) -> float:
	var base_value := float(location_data.metadata.get("yield_per_minute", 1.0))
	var level := int(state.get("level", 1))
	return base_value * (1.0 + float(level - 1) * 0.35)


func _storage_cap_for(location_data, state: Dictionary) -> float:
	var base_value := float(location_data.metadata.get("storage_cap", 30.0))
	var level := int(state.get("level", 1))
	return base_value * (1.0 + float(level - 1) * 0.4)


func _node_id_from_location(location_data) -> String:
	return str(location_data.metadata.get("node_id", ""))
