extends Node2D

var location_data
var config
var interact_radius := 72.0
var logical_position := Vector2.ZERO


func _menu_manager() -> Node:
	return get_node_or_null("/root/MenuManager")


func _resource_manager() -> Node:
	return get_node_or_null("/root/ResourceManager")


func setup(data, world_config) -> void:
	location_data = data
	config = world_config
	logical_position = data.map_position
	var local_logical_position = data.map_position - Vector2((data.world_tile / world_config.chunk_size) * world_config.get_chunk_pixel_size())
	position = _to_iso(local_logical_position)
	z_index = int(position.y)
	add_to_group("world_resource_nodes")
	var resource_manager := _resource_manager()
	if resource_manager != null:
		resource_manager.ensure_node_registered(location_data)
	queue_redraw()


func _physics_process(_delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player_avatar")
	if player == null or location_data == null:
		return
	if not is_player_near(player.global_position):
		return
	if Input.is_action_just_pressed("interact"):
		open_resource_menu()


func is_player_near(player_position: Vector2) -> bool:
	return logical_position.distance_to(player_position) <= interact_radius


func get_display_name() -> String:
	return location_data.display_name if location_data != null else "Источник"


func open_resource_menu() -> void:
	if location_data == null:
		return
	var menu_manager := _menu_manager()
	var resource_manager := _resource_manager()
	if menu_manager == null or resource_manager == null:
		return
	var actions: Array = []
	actions.append({
		"label": "Добыча идёт\nПолная партия уедет в городской склад автоматически.",
		"variant": "neutral"
	})
	actions.append({
		"label": "Улучшение\nПока в разработке. Позже здесь появится рост скорости, склада и лимита накопления.",
		"variant": "neutral"
	})
	menu_manager.open_menu({
		"title": "Источник ресурсов",
		"body": resource_manager.build_node_summary(location_data),
		"actions": actions,
		"closable": true,
		"close_on_backdrop": true
	})


func _draw() -> void:
	if location_data == null:
		return
	var tint := Color(str(location_data.metadata.get("color", "ffffff")))
	draw_circle(Vector2.ZERO, 16.0, tint)
	draw_circle(Vector2.ZERO, 23.0, Color(0.0, 0.0, 0.0, 0.18))
	draw_rect(Rect2(Vector2(-10.0, 12.0), Vector2(20.0, 10.0)), tint.darkened(0.35))
	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(font, Vector2(-72.0, -30.0), location_data.display_name, HORIZONTAL_ALIGNMENT_LEFT, 180.0, 17, Color("f3efe6"))


func _to_iso(local_position: Vector2) -> Vector2:
	return Vector2(
		(local_position.x - local_position.y) * 0.5,
		(local_position.x + local_position.y) * 0.25
	)
