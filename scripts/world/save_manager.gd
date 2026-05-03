extends RefCounted
class_name SaveManager


func save() -> void:
	var game_state := Engine.get_main_loop().root.get_node_or_null("GameState")
	if game_state != null:
		game_state.save_game()


func load() -> void:
	var game_state := Engine.get_main_loop().root.get_node_or_null("GameState")
	if game_state != null:
		game_state.load_game()
