extends Node2D

var settlement_data
var config
var interact_radius := 80.0
var reveal_radius := 150.0
var logical_position := Vector2.ZERO


func _scene_router() -> Node:
	return get_node_or_null("/root/SceneRouter")


func _world_time_manager() -> Node:
	return get_node_or_null("/root/WorldTimeManager")


func _event_bus() -> Node:
	return get_node_or_null("/root/EventBus")


func setup(data, world_config) -> void:
	settlement_data = data
	config = world_config
	logical_position = data.map_position
	var local_logical_position = data.map_position - Vector2((data.world_tile / world_config.chunk_size) * world_config.get_chunk_pixel_size())
	position = _to_iso(local_logical_position)
	z_index = int(position.y)
	add_to_group("world_settlements")
	queue_redraw()


func _physics_process(_delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player_avatar")
	if player == null or settlement_data == null:
		return
	if not settlement_data.discovered and is_player_in_reveal_radius(player.global_position):
		_reveal_settlement(player.global_position)
	if not is_player_near(player.global_position):
		return
	if Input.is_action_just_pressed("interact"):
		enter_settlement()


func is_player_near(player_position: Vector2) -> bool:
	return logical_position.distance_to(player_position) <= interact_radius


func is_player_in_reveal_radius(player_position: Vector2) -> bool:
	return logical_position.distance_to(player_position) <= reveal_radius


func get_display_name() -> String:
	return settlement_data.settlement_name if settlement_data != null else "Поселение"


func enter_settlement() -> void:
	if settlement_data == null:
		return
	var player = get_tree().get_first_node_in_group("player_avatar")
	if player != null:
		_reveal_settlement(player.global_position)
	var game_state = get_node_or_null("/root/GameState")
	if game_state != null:
		game_state.set_current_settlement(settlement_data.settlement_name)
		if player != null:
			game_state.set_world_player_position(player.global_position)
		game_state.register_settlement_visit(settlement_data.settlement_name, true)
	var event_bus = _event_bus()
	if event_bus != null:
		event_bus.emit_signal("location_entered", settlement_data.settlement_name, {
			"type": settlement_data.settlement_type,
			"biome_id": settlement_data.biome_id
		})
	var wtm := _world_time_manager()
	if wtm != null:
		wtm.freeze()   # разморозится в _exit_tree сцены поселения
	var scene_router = _scene_router()
	if scene_router != null:
		scene_router.go_to_scene(settlement_data.scene_path, settlement_data.spawn_id)


func _reveal_settlement(player_position: Vector2 = Vector2.ZERO) -> void:
	if settlement_data == null or settlement_data.discovered:
		return
	if player_position != Vector2.ZERO and not is_player_in_reveal_radius(player_position):
		return
	settlement_data.discovered = true
	var game_state = get_node_or_null("/root/GameState")
	if game_state != null:
		game_state.register_settlement_visit(settlement_data.settlement_name, true)
	var event_bus := _event_bus()
	if event_bus != null:
		event_bus.settlement_discovered.emit(settlement_data.settlement_name)
	queue_redraw()


func _draw() -> void:
	if settlement_data == null:
		return
	var fill = Color("f1d48a") if settlement_data.settlement_type == "capital" else (Color("dce9f2") if settlement_data.discovered else Color("6f7b84"))
	draw_circle(Vector2.ZERO, 24.0, fill)
	draw_circle(Vector2.ZERO, 30.0, Color(0.0, 0.0, 0.0, 0.18))
	var font = ThemeDB.fallback_font
	if font != null:
		var label = settlement_data.settlement_name if settlement_data.discovered or settlement_data.settlement_type == "capital" else "Неизвестное поселение"
		draw_string(font, Vector2(-58.0, -44.0), label, HORIZONTAL_ALIGNMENT_LEFT, 160.0, 18, Color("f5f1e8"))


func _to_iso(local_position: Vector2) -> Vector2:
	return Vector2(
		(local_position.x - local_position.y) * 0.5,
		(local_position.x + local_position.y) * 0.25
	)
