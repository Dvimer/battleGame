extends Node

const SAVE_PATH := "user://world_save.json"

var loaded := false
var world_player_position := Vector2.ZERO
var has_world_player_position := false
var discovered_settlements := {}
var active_quest_titles: Array = []


func _world_generator() -> Node:
	return get_node_or_null("/root/WorldGenerator")


func _fog_of_war() -> Node:
	return get_node_or_null("/root/FogOfWar")


func _quest_manager() -> Node:
	return get_node_or_null("/root/QuestManager")


func ensure_loaded() -> void:
	if loaded:
		return
	loaded = true
	_begin_new_session()


func save_game() -> void:
	var world_meta = _world_generator().get_world_meta()
	var quest_titles: Array = active_quest_titles.duplicate()
	var quest_manager = _quest_manager()
	if quest_manager != null:
		quest_titles = quest_manager.get_active_quest_titles()
	active_quest_titles = quest_titles.duplicate()
	var data = {
		"seed": world_meta.config.seed,
		"quests": quest_titles,
		"world_player_position": [world_player_position.x, world_player_position.y],
		"has_world_player_position": has_world_player_position,
		"discovered_settlements": discovered_settlements.keys(),
		"fog": Marshalls.raw_to_base64(_fog_of_war().serialize()),
		"world_tiles": [world_meta.world_tiles.x, world_meta.world_tiles.y],
		"tile_size": world_meta.config.tile_size,
		"visibility_radius": world_meta.config.visibility_radius_tiles
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))


func _begin_new_session() -> void:
	world_player_position = Vector2.ZERO
	has_world_player_position = false
	discovered_settlements.clear()
	active_quest_titles.clear()
	var fog = _fog_of_war()
	var world_meta = _world_generator().get_world_meta()
	if fog != null:
		fog.reset_for_world(world_meta)
	_apply_discovered_settlements()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func load_game() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	var world_generator = _world_generator()
	if int(data.get("seed", world_generator.get_config().seed)) != world_generator.get_config().seed:
		world_generator.regenerate(int(data.get("seed", world_generator.get_config().seed)))
	active_quest_titles.clear()
	for title in Array(data.get("quests", [])):
		active_quest_titles.append(str(title))
	has_world_player_position = bool(data.get("has_world_player_position", false))
	var saved_position = data.get("world_player_position", [0, 0])
	if saved_position is Array and saved_position.size() >= 2:
		world_player_position = Vector2(float(saved_position[0]), float(saved_position[1]))
	discovered_settlements.clear()
	for settlement_name in Array(data.get("discovered_settlements", [])):
		discovered_settlements[str(settlement_name)] = true
	_apply_discovered_settlements()
	var fog_data = Marshalls.base64_to_raw(str(data.get("fog", "")))
	if fog_data.size() > 0:
		_fog_of_war().deserialize(
			fog_data,
			Vector2i(int(data.get("world_tiles", [0, 0])[0]), int(data.get("world_tiles", [0, 0])[1])),
			int(data.get("tile_size", 64)),
			int(data.get("visibility_radius", 5))
		)


func set_world_player_position(value: Vector2, save_immediately := false) -> void:
	world_player_position = value
	has_world_player_position = true
	if save_immediately:
		save_game()


func get_world_player_position(default_value: Vector2) -> Vector2:
	return world_player_position if has_world_player_position else default_value


func register_settlement_visit(settlement_name: String, save_immediately := false) -> void:
	if settlement_name == "":
		return
	discovered_settlements[settlement_name] = true
	_apply_discovered_settlements()
	if save_immediately:
		save_game()


func get_discovered_settlement_count() -> int:
	return discovered_settlements.size()


func get_active_quest_titles() -> Array[String]:
	var titles: Array[String] = []
	for title in active_quest_titles:
		titles.append(str(title))
	return titles


func set_active_quest_titles(titles: Array[String], save_immediately := false) -> void:
	active_quest_titles.clear()
	for title in titles:
		active_quest_titles.append(str(title))
	if save_immediately:
		save_game()


func _apply_discovered_settlements() -> void:
	var world_meta = _world_generator().get_world_meta()
	for settlement in world_meta.settlements:
		settlement.discovered = settlement.settlement_name == world_meta.capital.settlement_name or discovered_settlements.has(settlement.settlement_name)
