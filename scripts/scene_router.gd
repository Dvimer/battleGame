extends Node

var pending_spawn_id := ""
var transition_in_progress := false


func _menu_manager() -> Node:
	return get_node_or_null("/root/MenuManager")


func go_to_scene(scene_path: String, spawn_id := "") -> void:
	if transition_in_progress:
		return
	transition_in_progress = true
	pending_spawn_id = spawn_id
	var menu_manager := _menu_manager()
	if menu_manager != null and menu_manager.is_open():
		menu_manager.close_menu()
	get_tree().change_scene_to_file(scene_path)


func apply_spawn(player: Node2D, fallback_position: Vector2) -> void:
	if player == null:
		return

	var spawn_position := fallback_position
	if pending_spawn_id != "":
		for node in get_tree().get_nodes_in_group("spawn_points"):
			if node.has_method("get_spawn_id") and String(node.call("get_spawn_id")) == pending_spawn_id:
				spawn_position = node.global_position
				break

	player.global_position = spawn_position
	if player.has_method("set_movement_locked"):
		player.call("set_movement_locked", false)
	pending_spawn_id = ""
	transition_in_progress = false
