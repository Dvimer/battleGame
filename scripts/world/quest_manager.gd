extends Node

var generator = preload("res://scripts/world/quest_chain_generator.gd").new()
var active_quests: Array = []


func _ready() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		game_state.ensure_loaded()
		var saved_titles: Array[String] = game_state.get_active_quest_titles()
		for title in saved_titles:
			var restored_chain = preload("res://scripts/world/quest_chain_data.gd").new()
			restored_chain.chain_id = "restored_%s" % str(title).to_snake_case()
			restored_chain.title = title
			active_quests.append(restored_chain)
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus != null and not event_bus.location_entered.is_connected(_on_location_entered):
		event_bus.location_entered.connect(_on_location_entered)


func _on_location_entered(location_id: String, payload: Dictionary) -> void:
	for quest in active_quests:
		if quest.trigger_criteria.get("location_id", "") == location_id:
			return
	var chain = generator.generate(location_id, payload)
	chain.trigger_criteria["location_id"] = location_id
	active_quests.append(chain)
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		game_state.set_active_quest_titles(get_active_quest_titles(), true)
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.emit_signal("quest_triggered", chain.chain_id, {"title": chain.title})


func get_active_quest_titles() -> Array[String]:
	var titles: Array[String] = []
	for quest in active_quests:
		titles.append(quest.title)
	return titles
