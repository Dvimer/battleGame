extends Node2D

const INVENTORY_SCENE := preload("res://scenes/inventory/inventory.tscn")
const SCENE_PATH := "res://scenes/world.tscn"

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
@onready var interact_button: Button = $HUD/InteractButton

var current_hover_settlement := ""
var current_hover_resource := ""
var world_meta
var last_saved_world_position := Vector2(-9999.0, -9999.0)
var minimap_zoom := 2.4
var minimap_base_image: Image
var world_visual_offset := Vector2.ZERO
var inventory_ui
var _discovery_banner: Label
var _discovery_banner_timer := 0.0
var _discovery_banner_settlement := ""

# Time HUD — создаётся в _ready() программно
var _time_day_label: Label
var _time_clock_label: Label
var _time_period_label: Label
var _time_pause_button: Button
var _time_play_button: Button
var _time_fast_button: Button

# Fog throttle: пересоздаём текстуру только при смене тайла игрока
var _last_fog_player_tile := Vector2i(-9999, -9999)
var _fog_texture: ImageTexture


func _world_time_manager() -> Node:
	return get_node_or_null("/root/WorldTimeManager")


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


func _menu_manager() -> Node:
	return get_node_or_null("/root/MenuManager")


func _scene_router() -> Node:
	return get_node_or_null("/root/SceneRouter")


func _event_bus() -> Node:
	return get_node_or_null("/root/EventBus")


func _ready() -> void:
	var game_state = _game_state()
	if game_state != null:
		game_state.ensure_loaded()
		game_state.set_current_scene(SCENE_PATH)
	var world_generator := _world_generator()
	if world_generator == null:
		push_error("WorldScene: WorldGenerator autoload is unavailable.")
		return
	world_meta = world_generator.get_world_meta()
	player.arena_size = world_meta.world_pixels
	player.allow_attack = false
	player.allow_dash = false
	player.allow_click_move = true
	player.set_movement_locked(false)
	player.visible = false
	player.global_position = game_state.get_world_player_position(world_meta.spawn_pos) if game_state != null else world_meta.spawn_pos
	var scene_router := _scene_router()
	if scene_router != null:
		scene_router.apply_spawn(player, player.global_position)
	last_saved_world_position = player.global_position
	world_visual_offset = Vector2(world_meta.world_pixels.y * 0.5 + 220.0, 140.0)
	$Chunks.position = world_visual_offset
	inventory_ui = INVENTORY_SCENE.instantiate()
	add_child(inventory_ui)
	inventory_ui.open_state_changed.connect(_on_inventory_state_changed)
	var menu_manager := _menu_manager()
	if menu_manager != null and not menu_manager.menu_state_changed.is_connected(_on_menu_state_changed):
		menu_manager.menu_state_changed.connect(_on_menu_state_changed)
	var localizer := _localizer()
	if localizer != null and not localizer.language_changed.is_connected(_on_language_changed):
		localizer.language_changed.connect(_on_language_changed)
	var event_bus := _event_bus()
	if event_bus != null and not event_bus.settlement_discovered.is_connected(_on_settlement_discovered):
		event_bus.settlement_discovered.connect(_on_settlement_discovered)
	_chunk_manager().register_world(self)
	zoom_out_button.pressed.connect(_zoom_out_minimap)
	zoom_in_button.pressed.connect(_zoom_in_minimap)
	inventory_button.pressed.connect(func():
		if inventory_ui != null:
			inventory_ui.toggle_inventory()
	)
	interact_button.pressed.connect(_interact_nearest)
	_setup_discovery_banner()
	_setup_time_hud()
	_apply_world_time_state()
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
		game_state.set_current_scene(SCENE_PATH)
		game_state.set_scene_player_position(SCENE_PATH, player.global_position)
		game_state.set_world_player_position(player.global_position)
		game_state.save_game()
	var chunk_manager = _chunk_manager()
	if chunk_manager != null:
		chunk_manager.unregister_world(self)
	# Разморозить то, что заморожено этой сценой (инвентарь / меню).
	# Freeze от поселений управляется в сценах самих поселений.
	var wtm := _world_time_manager()
	if wtm != null:
		if inventory_ui != null and inventory_ui.is_open():
			wtm.unfreeze()
		var menu_manager := _menu_manager()
		if menu_manager != null and menu_manager.is_open():
			wtm.unfreeze()


func _physics_process(delta: float) -> void:
	_update_discovery_banner(delta)
	if Input.is_action_just_pressed("inventory") and inventory_ui != null:
		var menu_manager := _menu_manager()
		if menu_manager != null and menu_manager.is_open():
			menu_manager.close_menu()
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
	current_hover_resource = ""
	for settlement in get_tree().get_nodes_in_group("world_settlements"):
		if settlement.has_method("is_player_near") and settlement.call("is_player_near", player.global_position):
			current_hover_settlement = str(settlement.call("get_display_name"))
			break
	if current_hover_settlement == "":
		for resource_node in get_tree().get_nodes_in_group("world_resource_nodes"):
			if resource_node.has_method("is_player_near") and resource_node.call("is_player_near", player.global_position):
				current_hover_resource = str(resource_node.call("get_display_name"))
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
	hint_label.text = localizer.t("world.hint") if localizer != null else "ЛКМ или WASD для движения. Подойди к поселению или источнику и нажми E."
	if current_hover_settlement == "" and current_hover_resource == "":
		quest_label.text = _build_quest_text()
	elif current_hover_resource != "":
		quest_label.text = "Рядом источник: %s. Открой его, чтобы посмотреть добычу и собрать ресурс." % current_hover_resource
	else:
		quest_label.text = localizer.t("world.near", {"value": current_hover_settlement}) if localizer != null else "Рядом: %s. Это точка входа в локацию." % current_hover_settlement
	_update_time_hud()


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


func _interact_nearest() -> void:
	if inventory_ui != null and inventory_ui.is_open():
		return
	var menu_manager := _menu_manager()
	if menu_manager != null and menu_manager.is_open():
		return
	for resource_node in get_tree().get_nodes_in_group("world_resource_nodes"):
		if resource_node.has_method("is_player_near") and resource_node.call("is_player_near", player.global_position):
			if resource_node.has_method("open_resource_menu"):
				resource_node.call("open_resource_menu")
			return
	for settlement in get_tree().get_nodes_in_group("world_settlements"):
		if settlement.has_method("is_player_near") and settlement.call("is_player_near", player.global_position):
			if settlement.has_method("enter_settlement"):
				settlement.call("enter_settlement")
			return


func _maybe_store_world_position() -> void:
	if player.global_position.distance_to(last_saved_world_position) < 96.0:
		return
	last_saved_world_position = player.global_position
	var game_state = _game_state()
	if game_state != null:
		game_state.set_current_scene(SCENE_PATH)
		game_state.set_scene_player_position(SCENE_PATH, player.global_position)
		game_state.set_world_player_position(player.global_position)


func _refresh_minimap_fog() -> void:
	var fog = _fog_of_war()
	if fog == null or minimap_fog == null or world_meta == null:
		return
	# Обновляем только при смене тайла (избегаем O(world²) пересчёта каждый кадр)
	var tile_size: int = world_meta.config.tile_size
	var current_tile := Vector2i(
		int(player.global_position.x / float(tile_size)),
		int(player.global_position.y / float(tile_size))
	)
	if current_tile == _last_fog_player_tile:
		return
	_last_fog_player_tile = current_tile
	fog.update_from_world_position(player.global_position)
	var fog_image: Image = fog.build_visibility_image()
	if _fog_texture == null:
		_fog_texture = ImageTexture.create_from_image(fog_image)
		minimap_fog.texture = _fog_texture
		minimap_fog.centered = true
		minimap_fog.position = Vector2(world_meta.world_tiles) * 0.5
	else:
		_fog_texture.update(fog_image)   # переиспользуем GPU-объект, не создаём новый


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
		var color := Color(str(location.metadata.get("color", "f08a5d")))
		_plot_dot(image, location.world_tile, color, 1)
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
	# Пауза / ускорение времени
	if event is InputEventKey and event.pressed and not event.echo:
		var wtm := _world_time_manager()
		if wtm != null:
			if event.keycode == KEY_SPACE:
				wtm.toggle_pause()
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_TAB:
				wtm.toggle_fast()
				get_viewport().set_input_as_handled()
				return
	if inventory_ui != null and inventory_ui.is_open():
		return
	var menu_manager := _menu_manager()
	if menu_manager != null and menu_manager.is_open():
		return
	if _is_world_time_stopped():
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
	var menu_manager := _menu_manager()
	player.set_movement_locked(is_open or (menu_manager != null and menu_manager.is_open()))
	var wtm := _world_time_manager()
	if wtm != null:
		if is_open: wtm.freeze()
		else:        wtm.unfreeze()


func _on_menu_state_changed(is_open: bool) -> void:
	player.set_movement_locked(is_open or (inventory_ui != null and inventory_ui.is_open()))
	var wtm := _world_time_manager()
	if wtm != null:
		if is_open: wtm.freeze()
		else:        wtm.unfreeze()


# ── Time HUD ─────────────────────────────────────────────────────────────────

func _setup_time_hud() -> void:
	var hud := get_node_or_null("HUD")
	if hud == null:
		return
	# Панель времени — по центру сверху, как глобальный HUD карты.
	var panel := PanelContainer.new()
	panel.name = "TimePanel"
	panel.anchor_left   = 0.5
	panel.anchor_top    = 0.0
	panel.anchor_right  = 0.5
	panel.anchor_bottom = 0.0
	panel.offset_left   = -220.0
	panel.offset_top    = 18.0
	panel.offset_right  = 220.0
	panel.offset_bottom = 118.0
	hud.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 10)
	vbox.add_child(header)

	_time_day_label = Label.new()
	_time_day_label.name = "TimeDayLabel"
	_time_day_label.text = "День 1"
	_time_day_label.add_theme_font_size_override("font_size", 16)
	header.add_child(_time_day_label)

	_time_clock_label = Label.new()
	_time_clock_label.name = "TimeClockLabel"
	_time_clock_label.text = "07:00"
	_time_clock_label.add_theme_font_size_override("font_size", 22)
	header.add_child(_time_clock_label)

	_time_period_label = Label.new()
	_time_period_label.name = "TimePeriodLabel"
	_time_period_label.text = "День"
	_time_period_label.add_theme_font_size_override("font_size", 16)
	header.add_child(_time_period_label)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 8)
	vbox.add_child(controls)

	_time_pause_button = Button.new()
	_time_pause_button.name = "PauseButton"
	_time_pause_button.custom_minimum_size = Vector2(64.0, 34.0)
	_time_pause_button.text = "⏸"
	_time_pause_button.toggle_mode = true
	_time_pause_button.pressed.connect(func(): _set_time_speed(0.0))
	controls.add_child(_time_pause_button)

	_time_play_button = Button.new()
	_time_play_button.name = "PlayButton"
	_time_play_button.custom_minimum_size = Vector2(64.0, 34.0)
	_time_play_button.text = "▶"
	_time_play_button.toggle_mode = true
	_time_play_button.pressed.connect(func():
		var wtm := _world_time_manager()
		if wtm != null and wtm.tuning != null:
			_set_time_speed(wtm.tuning.speed_normal)
	)
	controls.add_child(_time_play_button)

	_time_fast_button = Button.new()
	_time_fast_button.name = "FastButton"
	_time_fast_button.custom_minimum_size = Vector2(72.0, 34.0)
	_time_fast_button.text = "×2"
	_time_fast_button.toggle_mode = true
	_time_fast_button.pressed.connect(func():
		var wtm := _world_time_manager()
		if wtm != null and wtm.tuning != null:
			_set_time_speed(wtm.tuning.speed_fast)
	)
	controls.add_child(_time_fast_button)

	var wtm := _world_time_manager()
	if wtm != null:
		wtm.minute_changed.connect(_on_world_minute_changed)
		wtm.time_of_day_changed.connect(_on_time_of_day_changed)
		wtm.speed_changed.connect(_on_time_speed_changed)
	_update_time_hud()
	_refresh_time_buttons()


func _update_time_hud() -> void:
	if _time_day_label == null or _time_clock_label == null or _time_period_label == null:
		return
	var wtm := _world_time_manager()
	if wtm == null:
		return
	var localizer := _localizer()
	var day_text: String = localizer.t("world.time.day", {"value": wtm.current_day + 1}) if localizer != null else "День %d" % [wtm.current_day + 1]
	_time_day_label.text = day_text
	_time_clock_label.text = "%02d:%02d" % [wtm.current_hour, wtm.current_minute]
	_time_period_label.text = _localized_time_period(wtm.time_of_day)
	_time_period_label.modulate = _time_period_color(wtm.time_of_day)
	_refresh_time_button_tooltips()


func _on_time_speed_changed(_new_speed: float) -> void:
	_refresh_time_buttons()
	_apply_world_time_state()


func _on_world_minute_changed(_hour: int, _minute: int) -> void:
	_update_time_hud()


func _on_time_of_day_changed(_period: String) -> void:
	_update_time_hud()


func _set_time_speed(speed: float) -> void:
	var wtm := _world_time_manager()
	if wtm == null:
		return
	wtm.set_speed(speed)


func _refresh_time_buttons() -> void:
	if _time_pause_button == null or _time_play_button == null or _time_fast_button == null:
		return
	var wtm := _world_time_manager()
	if wtm == null or wtm.tuning == null:
		return
	_time_pause_button.set_pressed_no_signal(is_equal_approx(wtm.current_speed, 0.0))
	_time_play_button.set_pressed_no_signal(is_equal_approx(wtm.current_speed, wtm.tuning.speed_normal))
	_time_fast_button.set_pressed_no_signal(wtm.current_speed >= wtm.tuning.speed_fast and not is_equal_approx(wtm.current_speed, 0.0))
	_refresh_time_button_tooltips()


func _refresh_time_button_tooltips() -> void:
	var localizer := _localizer()
	if _time_pause_button != null:
		_time_pause_button.tooltip_text = localizer.t("world.time.stop") if localizer != null else "Остановить время и движение"
	if _time_play_button != null:
		_time_play_button.tooltip_text = localizer.t("world.time.play") if localizer != null else "Обычная скорость"
	if _time_fast_button != null:
		_time_fast_button.tooltip_text = localizer.t("world.time.fast") if localizer != null else "Ускорить время и движение x2"


func _apply_world_time_state() -> void:
	var wtm := _world_time_manager()
	if wtm == null or player == null:
		return
	var speed_scale := 1.0
	if wtm.tuning != null and wtm.tuning.speed_normal > 0.0:
		speed_scale = maxf(0.0, wtm.current_speed / wtm.tuning.speed_normal)
	player.set_movement_speed_scale(speed_scale)
	_update_time_hud()


func _is_world_time_stopped() -> bool:
	var wtm := _world_time_manager()
	return wtm != null and is_equal_approx(wtm.current_speed, 0.0)


func _localized_time_period(period: String) -> String:
	var localizer := _localizer()
	if localizer == null:
		match period:
			"dawn":
				return "Рассвет"
			"day":
				return "День"
			"dusk":
				return "Сумерки"
			"night":
				return "Ночь"
			_:
				return period
	return localizer.t("world.time.period.%s" % period)


func _time_period_color(period: String) -> Color:
	match period:
		"dawn":
			return Color("f4cf88")
		"day":
			return Color("c9f58f")
		"dusk":
			return Color("f4a982")
		"night":
			return Color("91a7ff")
		_:
			return Color.WHITE


func _on_language_changed(_language: String) -> void:
	_refresh_hud()
	_refresh_time_buttons()
	if _discovery_banner_timer > 0.0 and _discovery_banner_settlement != "":
		_show_discovery_banner(_discovery_banner_settlement)


func _setup_discovery_banner() -> void:
	var hud := get_node_or_null("HUD")
	if hud == null:
		return
	_discovery_banner = Label.new()
	_discovery_banner.name = "DiscoveryBanner"
	_discovery_banner.anchor_left = 0.5
	_discovery_banner.anchor_top = 0.0
	_discovery_banner.anchor_right = 0.5
	_discovery_banner.anchor_bottom = 0.0
	_discovery_banner.offset_left = -280.0
	_discovery_banner.offset_top = 128.0
	_discovery_banner.offset_right = 280.0
	_discovery_banner.offset_bottom = 168.0
	_discovery_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_discovery_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_discovery_banner.visible = false
	_discovery_banner.add_theme_font_size_override("font_size", 28)
	_discovery_banner.add_theme_color_override("font_color", Color("f5f1e8"))
	hud.add_child(_discovery_banner)


func _update_discovery_banner(delta: float) -> void:
	if _discovery_banner == null or not _discovery_banner.visible:
		return
	_discovery_banner_timer = maxf(0.0, _discovery_banner_timer - delta)
	if _discovery_banner_timer <= 0.0:
		_discovery_banner.visible = false
		_discovery_banner_settlement = ""


func _on_settlement_discovered(settlement_name: String) -> void:
	if settlement_name == "":
		return
	_show_discovery_banner(settlement_name)
	_refresh_hud()


func _show_discovery_banner(settlement_name: String) -> void:
	if _discovery_banner == null:
		return
	_discovery_banner_settlement = settlement_name
	var localizer := _localizer()
	_discovery_banner.text = localizer.t("world.banner.discovered", {"value": settlement_name}) if localizer != null else "Открыто поселение: %s" % settlement_name
	_discovery_banner.visible = true
	_discovery_banner_timer = 2.2
