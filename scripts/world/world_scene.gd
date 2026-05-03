extends Node2D

const INVENTORY_SCENE := preload("res://scenes/inventory/inventory.tscn")

@onready var player := $Player
@onready var player_visual: Polygon2D = $PlayerVisual
@onready var camera: Camera2D = $Camera2D
@onready var title_label: Label = $HUD/TitleLabel
@onready var hint_label: Label = $HUD/HintLabel
@onready var status_label: Label = $HUD/StatusLabel
@onready var quest_label: Label = $HUD/QuestLabel
@onready var minimap_panel: Panel = $HUD/MiniMapPanel
@onready var minimap_title_label: Label = $HUD/MiniMapPanel/MiniMapTitle
@onready var minimap_hint_label: Label = $HUD/MiniMapPanel/MiniMapHint
@onready var minimap_camera: Camera2D = $HUD/MiniMapPanel/MiniMapFrame/MiniMapViewport/MiniMapRoot/MiniMapCamera
@onready var minimap_base: Sprite2D = $HUD/MiniMapPanel/MiniMapFrame/MiniMapViewport/MiniMapRoot/MiniMapBase
@onready var minimap_fog: Sprite2D = $HUD/MiniMapPanel/MiniMapFrame/MiniMapViewport/MiniMapRoot/MiniMapFog
@onready var minimap_player_marker: Polygon2D = $HUD/MiniMapPanel/MiniMapFrame/MiniMapViewport/MiniMapRoot/MiniMapPlayerMarker
@onready var zoom_out_button: Button = $HUD/MiniMapPanel/ZoomOutButton
@onready var zoom_in_button: Button = $HUD/MiniMapPanel/ZoomInButton
@onready var inventory_button: Button = $HUD/InventoryButton

var current_hover_settlement := ""
var world_meta
var last_saved_world_position := Vector2(-9999.0, -9999.0)
var minimap_zoom := 2.4
var minimap_base_image: Image
var world_visual_offset := Vector2.ZERO
var inventory_ui


func _localizer() -> Node:
	return get_node_or_null("/root/Localizer")


func _world_generator() -> Node:
	return get_node_or_null("/root/WorldGenerator")


func _chunk_manager() -> Node:
	return get_node_or_null("/root/ChunkManager")


func _fog_of_war() -> Node:
	return get_node_or_null("/root/FogOfWar")


func _quest_manager() -> Node:
	return get_node_or_null("/root/QuestManager")


func _game_state() -> Node:
	return get_node_or_null("/root/GameState")


func _ready() -> void:
	world_meta = _world_generator().get_world_meta()
	var game_state = _game_state()
	if game_state != null:
		game_state.ensure_loaded()
	player.arena_size = world_meta.world_pixels
	player.allow_attack = false
	player.allow_dash = false
	player.allow_click_move = true
	player.set_movement_locked(false)
	player.visible = false
	player.global_position = game_state.get_world_player_position(world_meta.spawn_pos) if game_state != null else world_meta.spawn_pos
	last_saved_world_position = player.global_position
	world_visual_offset = Vector2(world_meta.world_pixels.y * 0.5 + 220.0, 140.0)
	$Chunks.position = world_visual_offset
	inventory_ui = INVENTORY_SCENE.instantiate()
	add_child(inventory_ui)
	inventory_ui.open_state_changed.connect(_on_inventory_state_changed)
	_chunk_manager().register_world(self)
	zoom_out_button.pressed.connect(_zoom_out_minimap)
	zoom_in_button.pressed.connect(_zoom_in_minimap)
	inventory_button.pressed.connect(func():
		if inventory_ui != null:
			inventory_ui.toggle_inventory()
	)
	_build_minimap_base()
	if _fog_of_war() != null:
		if _fog_of_war().serialize().is_empty():
			_fog_of_war().reset_for_world(world_meta)
		_refresh_minimap_fog()
	_refresh_world_visuals()
	_refresh_minimap_camera()
	_refresh_hud()


func _exit_tree() -> void:
	var game_state = _game_state()
	if game_state != null:
		game_state.set_world_player_position(player.global_position)
		game_state.save_game()
	var chunk_manager = _chunk_manager()
	if chunk_manager != null:
		chunk_manager.unregister_world(self)


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("inventory") and inventory_ui != null:
		inventory_ui.toggle_inventory()
		return
	var chunk_manager = _chunk_manager()
	if chunk_manager != null:
		chunk_manager.update_for_player(player.global_position)
	_refresh_world_visuals()
	_refresh_minimap_fog()
	_refresh_minimap_camera()
	_maybe_store_world_position()
	_refresh_hover_state()


func _refresh_hover_state() -> void:
	current_hover_settlement = ""
	for settlement in get_tree().get_nodes_in_group("world_settlements"):
		if settlement.has_method("is_player_near") and settlement.call("is_player_near", player.global_position):
			current_hover_settlement = str(settlement.call("get_display_name"))
			break
	_refresh_hud()


func _refresh_hud() -> void:
	var localizer = _localizer()
	title_label.text = localizer.t("world.title") if localizer != null else "Карта мира"
	minimap_title_label.text = localizer.t("world.minimap.title") if localizer != null else "Миникарта"
	minimap_hint_label.text = localizer.t("world.minimap.hint", {"value": String.num(minimap_zoom, 1)}) if localizer != null else "Туман только на миникарте. Масштаб: %s" % String.num(minimap_zoom, 1)
	var capital_name = world_meta.capital.settlement_name if world_meta != null and world_meta.capital != null else "Столица"
	var discovered_count = _game_state().get_discovered_settlement_count() if _game_state() != null else 0
	status_label.text = localizer.t("world.status", {"capital": capital_name, "count": discovered_count}) if localizer != null else "Текущая столица: %s. Открыто поселений: %d." % [capital_name, discovered_count]
	hint_label.text = localizer.t("world.hint") if localizer != null else "ЛКМ или WASD для движения. Подойди к поселению и нажми E или ЛКМ, чтобы войти."
	if current_hover_settlement == "":
		quest_label.text = _build_quest_text()
	else:
		quest_label.text = localizer.t("world.near", {"value": current_hover_settlement}) if localizer != null else "Рядом: %s. Это точка входа в локацию." % current_hover_settlement


func _build_quest_text() -> String:
	var quest_manager = _quest_manager()
	if quest_manager == null:
		var localizer = _localizer()
		return localizer.t("world.quest.pending") if localizer != null else "Активные задания появятся при входе в новые точки."
	var quests: Array = quest_manager.call("get_active_quest_titles")
	if quests.is_empty():
		var localizer = _localizer()
		return localizer.t("world.quest.empty") if localizer != null else "Активных цепочек пока нет."
	var localizer = _localizer()
	return localizer.t("world.quest.some", {"value": ", ".join(quests)}) if localizer != null else "Квесты: %s" % ", ".join(quests)


func _maybe_store_world_position() -> void:
	if player.global_position.distance_to(last_saved_world_position) < 96.0:
		return
	last_saved_world_position = player.global_position
	var game_state = _game_state()
	if game_state != null:
		game_state.set_world_player_position(player.global_position)


func _refresh_minimap_fog() -> void:
	var fog = _fog_of_war()
	if fog == null or minimap_fog == null:
		return
	fog.update_from_world_position(player.global_position)
	var fog_image = fog.build_visibility_image()
	var texture = ImageTexture.create_from_image(fog_image)
	minimap_fog.texture = texture
	minimap_fog.centered = true
	minimap_fog.position = Vector2(world_meta.world_tiles) * 0.5


func _refresh_world_visuals() -> void:
	var iso_position = _world_to_iso(player.global_position)
	player_visual.position = world_visual_offset + iso_position
	player_visual.z_index = int(player_visual.position.y)
	camera.position = player_visual.position


func _build_minimap_base() -> void:
	var image = Image.create(world_meta.world_tiles.x, world_meta.world_tiles.y, false, Image.FORMAT_RGBA8)
	for y in range(world_meta.world_tiles.y):
		for x in range(world_meta.world_tiles.x):
			image.set_pixel(x, y, _biome_color_for_tile(Vector2i(x, y)))
	for road in world_meta.roads:
		for index in range(road.size() - 1):
			_draw_line_on_image(
				image,
				Vector2i(road[index] / world_meta.config.tile_size),
				Vector2i(road[index + 1] / world_meta.config.tile_size),
				Color("d2bd95")
			)
	for settlement in world_meta.settlements:
		var color = Color("f1d48a") if settlement.settlement_type == "capital" else Color("dce9f2")
		_plot_dot(image, settlement.world_tile, color, 2)
	for location in world_meta.locations:
		_plot_dot(image, location.world_tile, Color("f08a5d"), 1)
	minimap_base_image = image
	minimap_base.texture = ImageTexture.create_from_image(image)
	minimap_base.centered = true
	minimap_base.position = Vector2(world_meta.world_tiles) * 0.5


func _biome_color_for_tile(tile: Vector2i) -> Color:
	var config = world_meta.config
	var chunk_coord = Vector2i(tile.x / config.chunk_size, tile.y / config.chunk_size)
	var biome_index = chunk_coord.y * config.biome_grid.x + chunk_coord.x
	if biome_index < 0 or biome_index >= world_meta.biomes.size():
		return Color("60785d")
	return world_meta.biomes[biome_index].color


func _draw_line_on_image(image: Image, from_tile: Vector2i, to_tile: Vector2i, color: Color) -> void:
	var x0 = from_tile.x
	var y0 = from_tile.y
	var x1 = to_tile.x
	var y1 = to_tile.y
	var dx = absi(x1 - x0)
	var sx = 1 if x0 < x1 else -1
	var dy = -absi(y1 - y0)
	var sy = 1 if y0 < y1 else -1
	var err = dx + dy
	while true:
		if x0 >= 0 and y0 >= 0 and x0 < image.get_width() and y0 < image.get_height():
			image.set_pixel(x0, y0, color)
		if x0 == x1 and y0 == y1:
			break
		var e2 = err * 2
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


func _plot_dot(image: Image, tile: Vector2i, color: Color, radius: int) -> void:
	for y in range(tile.y - radius, tile.y + radius + 1):
		for x in range(tile.x - radius, tile.x + radius + 1):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			if Vector2(x - tile.x, y - tile.y).length() > float(radius) + 0.2:
				continue
			image.set_pixel(x, y, color)


func _refresh_minimap_camera() -> void:
	if minimap_camera == null:
		return
	var tile_position = player.global_position / world_meta.config.tile_size
	minimap_camera.position = tile_position
	minimap_camera.zoom = Vector2.ONE * minimap_zoom
	minimap_player_marker.position = tile_position


func _zoom_in_minimap() -> void:
	minimap_zoom = maxf(0.8, minimap_zoom - 0.25)
	_refresh_minimap_camera()
	_refresh_hud()


func _zoom_out_minimap() -> void:
	minimap_zoom = minf(5.0, minimap_zoom + 0.25)
	_refresh_minimap_camera()
	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if inventory_ui != null and inventory_ui.is_open():
		return
	if minimap_panel == null:
		return
	if event is InputEventMouseButton and event.pressed:
		var mouse_event: InputEventMouseButton = event
		if not minimap_panel.get_global_rect().has_point(mouse_event.position):
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				player.set_move_target(_screen_to_world(mouse_event.position))
				get_viewport().set_input_as_handled()
			return
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_in_minimap()
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_out_minimap()
			get_viewport().set_input_as_handled()


func _world_to_iso(world_position: Vector2) -> Vector2:
	return Vector2(
		(world_position.x - world_position.y) * 0.5,
		(world_position.x + world_position.y) * 0.25
	)


func _iso_to_world(iso_position: Vector2) -> Vector2:
	return Vector2(
		iso_position.x + iso_position.y * 2.0,
		iso_position.y * 2.0 - iso_position.x
	)


func _screen_to_world(screen_position: Vector2) -> Vector2:
	var viewport_transform := get_viewport().get_canvas_transform()
	var canvas_position := viewport_transform.affine_inverse() * screen_position
	var iso_position := canvas_position - world_visual_offset
	return Vector2(
		clampf(_iso_to_world(iso_position).x, 36.0, world_meta.world_pixels.x - 36.0),
		clampf(_iso_to_world(iso_position).y, 36.0, world_meta.world_pixels.y - 36.0)
	)


func _on_inventory_state_changed(is_open: bool) -> void:
	player.set_movement_locked(is_open)
