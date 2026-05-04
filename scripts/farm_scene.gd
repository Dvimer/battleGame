extends Node2D

const FARM_SIZE := Vector2(2720.0, 1560.0)
const BRIDGE_POS := Vector2(1500.0, 1410.0)
const SHED_POS := Vector2(820.0, 1330.0)
const SHED_INTERACT_RADIUS := 200.0
const BRIDGE_INTERACT_RADIUS := 170.0
const SCENE_PATH := "res://scenes/farm.tscn"
const INVENTORY_SCENE := preload("res://scenes/inventory/inventory.tscn")

const FIELD_COLUMNS := 4
const FIELD_ROWS := 3
const FIELD_CELLS_PER_FIELD := 9
const FIELD_OUTER_SIZE := Vector2(260.0, 260.0)
const FIELD_SPACING := Vector2(56.0, 74.0)
const FIELD_ORIGIN := Vector2(650.0, 260.0)
const FIELD_INNER_MARGIN := 28.0
const FIELD_GATE_WIDTH := 72.0
const FIELD_GATE_DEPTH := 22.0

@onready var player := $Player
@onready var camera: Camera2D = $Camera2D
@onready var title_label: Label = $HUD/TitleLabel
@onready var summary_label: Label = $HUD/SummaryLabel
@onready var resource_label: Label = $HUD/ResourceLabel
@onready var center_banner: Label = $HUD/CenterBanner
@onready var prompt_label: Label = $HUD/PromptLabel
@onready var hint_label: Label = $HUD/HintLabel
@onready var inventory_button: Button = $HUD/InventoryButton
@onready var interact_button: Button = $HUD/InteractButton

var inventory_ui
var banner_timer := 0.0
var last_saved_position := Vector2(-9999.0, -9999.0)
var nearest_hotspot := ""

var context_menu_panel: PanelContainer
var context_menu_title: Label
var context_menu_scroll: ScrollContainer
var context_menu_actions: VBoxContainer
var context_menu_target := {}

var shed_panel: PanelContainer
var shed_title_label: Label
var shed_search: LineEdit
var shed_filter: OptionButton
var shed_grid: GridContainer
var shed_empty_label: Label


func _world_state() -> Node:
	return get_node_or_null("/root/WorldState")


func _menu_manager() -> Node:
	return get_node_or_null("/root/MenuManager")


func _scene_router() -> Node:
	return get_node_or_null("/root/SceneRouter")


func _game_state() -> Node:
	return get_node_or_null("/root/GameState")


func _localizer() -> Node:
	return get_node_or_null("/root/Localizer")


func _world_time_manager() -> Node:
	return get_node_or_null("/root/WorldTimeManager")


func _ready() -> void:
	player.arena_size = FARM_SIZE
	player.allow_attack = false
	player.allow_dash = false
	player.allow_click_move = true
	player.screen_space_movement = false
	player.set_movement_locked(false)

	var game_state: Node = _game_state()
	if game_state != null:
		game_state.ensure_loaded()
		game_state.set_current_scene(SCENE_PATH)
	var scene_router: Node = _scene_router()
	if scene_router != null:
		var fallback_position: Vector2 = game_state.get_scene_player_position(SCENE_PATH, player.global_position) if game_state != null else player.global_position
		scene_router.apply_spawn(player, fallback_position)
	camera.position = player.global_position
	last_saved_position = player.global_position

	inventory_ui = INVENTORY_SCENE.instantiate()
	add_child(inventory_ui)
	inventory_ui.open_state_changed.connect(_on_inventory_state_changed)
	inventory_button.pressed.connect(func():
		if inventory_ui != null:
			_close_context_menu()
			_close_shed_panel()
			inventory_ui.toggle_inventory()
	)
	interact_button.pressed.connect(_interact_nearest_hotspot)

	var localizer: Node = _localizer()
	if localizer != null and not localizer.language_changed.is_connected(_on_language_changed):
		localizer.language_changed.connect(_on_language_changed)

	_build_overlay_ui()
	_refresh_labels()


func _physics_process(delta: float) -> void:
	camera.position = player.global_position
	banner_timer = maxf(banner_timer - delta, 0.0)
	if banner_timer <= 0.0:
		center_banner.text = ""
	_maybe_store_scene_position()

	if Input.is_action_just_pressed("inventory"):
		_close_context_menu()
		_close_shed_panel()
		if inventory_ui != null:
			inventory_ui.toggle_inventory()
		queue_redraw()
		return

	if Input.is_action_just_pressed("interact"):
		nearest_hotspot = _find_nearest_hotspot()
		_interact_nearest_hotspot()
		queue_redraw()
		return

	if inventory_ui != null and inventory_ui.is_open():
		prompt_label.text = _raw_text("Inventory open. Press I or Esc to close it.", "Инвентарь открыт. Нажми I или Esc, чтобы закрыть.")
		queue_redraw()
		return
	if _is_custom_ui_open():
		prompt_label.text = _raw_text("Context or shed open. Click outside or close the window.", "Открыто меню или сарай. Кликни вне окна или закрой его.")
		queue_redraw()
		return

	nearest_hotspot = _find_nearest_hotspot()
	var player_field: int = _field_index_for_position(player.global_position)
	if player_field != -1:
		prompt_label.text = _raw_text(
			"Right click a cell to plant or harvest. Leave the field through its gate.",
			"Нажми правой кнопкой по ячейке, чтобы посадить или собрать. Выходить с поля нужно через ворота."
		)
	elif nearest_hotspot == "shed":
		prompt_label.text = _raw_text("Press E near the shed to open storage.", "Нажми E у сарая, чтобы открыть склад.")
	elif nearest_hotspot == "bridge":
		prompt_label.text = _raw_text("Press E at the bridge to return to town.", "Нажми E у моста, чтобы вернуться в город.")
	else:
		prompt_label.text = _raw_text(
			"Use left click to move. Right click a field cell to manage it. You can only enter fields through gates.",
			"Левой кнопкой перемещайся. Правой кликай по ячейке поля. Заходить на поле можно только через ворота."
		)
	queue_redraw()


func _build_overlay_ui() -> void:
	_build_context_menu()
	_build_shed_panel()


func _build_context_menu() -> void:
	var ui_root: Node = $HUD
	context_menu_panel = PanelContainer.new()
	context_menu_panel.visible = false
	context_menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	context_menu_panel.size = Vector2(300.0, 360.0)
	context_menu_panel.z_index = 80
	ui_root.add_child(context_menu_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.15, 0.18, 0.97)
	style.border_color = Color(0.64, 0.59, 0.47, 0.8)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	context_menu_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	context_menu_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	context_menu_title = Label.new()
	context_menu_title.add_theme_font_size_override("font_size", 20)
	context_menu_title.add_theme_color_override("font_color", Color("f6f0dc"))
	root.add_child(context_menu_title)

	context_menu_scroll = ScrollContainer.new()
	context_menu_scroll.custom_minimum_size = Vector2(280.0, 260.0)
	context_menu_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(context_menu_scroll)

	context_menu_actions = VBoxContainer.new()
	context_menu_actions.add_theme_constant_override("separation", 6)
	context_menu_scroll.add_child(context_menu_actions)


func _build_shed_panel() -> void:
	var ui_root: Node = $HUD
	shed_panel = PanelContainer.new()
	shed_panel.visible = false
	shed_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	shed_panel.z_index = 70
	shed_panel.offset_left = 170.0
	shed_panel.offset_top = 120.0
	shed_panel.offset_right = 170.0 + 1180.0
	shed_panel.offset_bottom = 120.0 + 820.0
	ui_root.add_child(shed_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.13, 0.16, 0.97)
	style.border_color = Color(0.70, 0.63, 0.48, 0.85)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	shed_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	shed_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)

	shed_title_label = Label.new()
	shed_title_label.text = _raw_text("Field Shed", "Полевой сарай")
	shed_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shed_title_label.add_theme_font_size_override("font_size", 32)
	shed_title_label.add_theme_color_override("font_color", Color("f7f1dd"))
	header.add_child(shed_title_label)

	var close_button := Button.new()
	close_button.custom_minimum_size = Vector2(68.0, 46.0)
	close_button.text = "X"
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.pressed.connect(_close_shed_panel)
	_style_dark_button(close_button, Color("8b4d4d"))
	header.add_child(close_button)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	root.add_child(controls)

	shed_search = LineEdit.new()
	shed_search.placeholder_text = _raw_text("Search by name", "Фильтр по имени")
	shed_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shed_search.text_changed.connect(_refresh_shed_grid)
	controls.add_child(shed_search)

	shed_filter = OptionButton.new()
	shed_filter.custom_minimum_size = Vector2(180.0, 42.0)
	shed_filter.add_item(_raw_text("All", "Все"), 0)
	shed_filter.add_item(_raw_text("Seeds", "Семена"), 1)
	shed_filter.add_item(_raw_text("Produce", "Урожай"), 2)
	shed_filter.item_selected.connect(func(_index: int) -> void:
		_refresh_shed_grid("")
	)
	controls.add_child(shed_filter)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)

	shed_empty_label = Label.new()
	shed_empty_label.add_theme_font_size_override("font_size", 20)
	shed_empty_label.add_theme_color_override("font_color", Color("d7d7d7"))
	body.add_child(shed_empty_label)

	shed_grid = GridContainer.new()
	shed_grid.columns = 5
	shed_grid.add_theme_constant_override("h_separation", 12)
	shed_grid.add_theme_constant_override("v_separation", 12)
	body.add_child(shed_grid)


func _show_context_menu(title: String, actions: Array, screen_position: Vector2) -> void:
	_clear_context_menu_actions()
	context_menu_title.text = title
	for action in actions:
		var action_data: Dictionary = action
		var button := Button.new()
		button.custom_minimum_size = Vector2(260.0, 42.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = str(action_data.get("label", "Action"))
		_style_dark_button(button, _variant_color(str(action_data.get("variant", "neutral"))))
		button.pressed.connect(func() -> void:
			var callback: Callable = action_data.get("callback", Callable())
			if callback.is_valid():
				callback.call()
			_close_context_menu()
		)
		context_menu_actions.add_child(button)
	var viewport_size := get_viewport_rect().size
	var panel_size := Vector2(300.0, minf(360.0, 62.0 + float(actions.size()) * 48.0))
	var pos := screen_position + Vector2(8.0, 8.0)
	pos.x = clampf(pos.x, 16.0, viewport_size.x - panel_size.x - 16.0)
	pos.y = clampf(pos.y, 16.0, viewport_size.y - panel_size.y - 16.0)
	context_menu_panel.position = pos
	context_menu_panel.size = panel_size
	context_menu_panel.visible = true
	_sync_player_lock()


func _close_context_menu() -> void:
	context_menu_panel.visible = false
	context_menu_target = {}
	_clear_context_menu_actions()
	_sync_player_lock()


func _clear_context_menu_actions() -> void:
	if context_menu_actions == null:
		return
	for child in context_menu_actions.get_children():
		child.queue_free()


func _open_shed_panel() -> void:
	shed_panel.visible = true
	_refresh_shed_grid("")
	_sync_player_lock()


func _close_shed_panel() -> void:
	if shed_panel == null:
		return
	shed_panel.visible = false
	_sync_player_lock()


func _refresh_shed_grid(_unused := "") -> void:
	if shed_grid == null:
		return
	for child in shed_grid.get_children():
		child.queue_free()
	var world_state := _world_state()
	if world_state == null:
		return
	var filter_mode := "all"
	match shed_filter.get_selected_id():
		1:
			filter_mode = "seed"
		2:
			filter_mode = "produce"
	var query := shed_search.text.strip_edges().to_lower()
	var visible_count := 0
	for raw_item in world_state.get_farm_shed_items():
		var item := Dictionary(raw_item)
		var item_type: String = str(item.get("type", ""))
		var item_name: String = str(item.get("name", ""))
		if filter_mode != "all" and item_type != filter_mode:
			continue
		if query != "" and item_name.to_lower().find(query) == -1:
			continue
		visible_count += 1
		shed_grid.add_child(_build_shed_card(item))
	shed_empty_label.text = "" if visible_count > 0 else _raw_text("Nothing matches the current filter.", "По текущему фильтру ничего не найдено.")


func _build_shed_card(item: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(150.0, 150.0)
	card.tooltip_text = str(item.get("name", ""))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.22, 0.27, 0.94)
	style.border_color = Color(0.54, 0.60, 0.66, 0.45)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var icon_holder := CenterContainer.new()
	icon_holder.custom_minimum_size = Vector2(0.0, 76.0)
	root.add_child(icon_holder)

	icon_holder.add_child(_build_crop_package_icon(item))

	var name_label := Label.new()
	name_label.text = str(item.get("name", ""))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color("edf0f3"))
	root.add_child(name_label)

	var count_label := Label.new()
	count_label.text = _raw_text("Count: %d" % int(item.get("count", 0)), "Количество: %d" % int(item.get("count", 0)))
	count_label.add_theme_font_size_override("font_size", 16)
	count_label.add_theme_color_override("font_color", Color("b8c7d2"))
	root.add_child(count_label)
	return card


func _build_crop_package_icon(item: Dictionary) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(74.0, 74.0)

	var package_panel := PanelContainer.new()
	package_panel.offset_left = 10.0
	package_panel.offset_top = 12.0
	package_panel.offset_right = 64.0
	package_panel.offset_bottom = 66.0
	var package_style := StyleBoxFlat.new()
	package_style.bg_color = Color("d9c29a")
	package_style.border_color = Color("9b7f55")
	package_style.border_width_left = 2
	package_style.border_width_top = 2
	package_style.border_width_right = 2
	package_style.border_width_bottom = 2
	package_style.corner_radius_top_left = 8
	package_style.corner_radius_top_right = 8
	package_style.corner_radius_bottom_left = 8
	package_style.corner_radius_bottom_right = 8
	package_panel.add_theme_stylebox_override("panel", package_style)
	wrap.add_child(package_panel)

	var fold := ColorRect.new()
	fold.color = Color(1.0, 1.0, 1.0, 0.18)
	fold.offset_left = 6.0
	fold.offset_top = 8.0
	fold.offset_right = 48.0
	fold.offset_bottom = 14.0
	package_panel.add_child(fold)

	var badge := ColorRect.new()
	badge.color = Color(item.get("color", Color.WHITE))
	badge.offset_left = 40.0
	badge.offset_top = -2.0
	badge.offset_right = 68.0
	badge.offset_bottom = 26.0
	wrap.add_child(badge)

	var badge_label := Label.new()
	badge_label.text = _crop_icon_text(str(item.get("crop_id", "")), str(item.get("type", "")))
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.offset_left = 40.0
	badge_label.offset_top = -2.0
	badge_label.offset_right = 68.0
	badge_label.offset_bottom = 26.0
	badge_label.add_theme_font_size_override("font_size", 13)
	badge_label.add_theme_color_override("font_color", Color.BLACK)
	wrap.add_child(badge_label)

	var type_label := Label.new()
	type_label.text = _raw_text("SEED", "СЕМ") if str(item.get("type", "")) == "seed" else _raw_text("CROP", "УРЖ")
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	type_label.offset_left = 14.0
	type_label.offset_top = 28.0
	type_label.offset_right = 60.0
	type_label.offset_bottom = 54.0
	type_label.add_theme_font_size_override("font_size", 11)
	type_label.add_theme_color_override("font_color", Color("5b4630"))
	wrap.add_child(type_label)

	return wrap


func _crop_icon_text(crop_id: String, item_type: String) -> String:
	match crop_id:
		"wheat":
			return "W"
		"carrot":
			return "C"
		"potato":
			return "P"
		"cabbage":
			return "K"
		"tomato":
			return "T"
		"cucumber":
			return "O"
		"onion":
			return "L"
		"pumpkin":
			return "Y"
		"corn":
			return "M"
		"apple_tree":
			return "A"
		_:
			return "S" if item_type == "seed" else "U"


func _style_dark_button(button: Button, accent: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = accent.darkened(0.32)
	normal.border_color = accent.lightened(0.16)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 8.0
	var hover := normal.duplicate()
	hover.bg_color = accent.darkened(0.18)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color.WHITE)


func _variant_color(variant: String) -> Color:
	match variant:
		"warning":
			return Color("b7863d")
		"success":
			return Color("4c8b63")
		"vitality":
			return Color("5aa06f")
		"damage":
			return Color("c46250")
		_:
			return Color("445e69")


func _is_custom_ui_open() -> bool:
	return (context_menu_panel != null and context_menu_panel.visible) or (shed_panel != null and shed_panel.visible)


func _sync_player_lock() -> void:
	var should_lock: bool = _is_custom_ui_open() or (inventory_ui != null and inventory_ui.is_open())
	player.set_movement_locked(should_lock)


func _find_nearest_hotspot() -> String:
	if player.global_position.distance_to(SHED_POS) <= SHED_INTERACT_RADIUS:
		return "shed"
	if player.global_position.distance_to(BRIDGE_POS) <= BRIDGE_INTERACT_RADIUS:
		return "bridge"
	return ""


func _interact_nearest_hotspot() -> void:
	match nearest_hotspot:
		"shed":
			_close_context_menu()
			_open_shed_panel()
		"bridge":
			_close_context_menu()
			_return_to_town()


func _open_field_cell_menu(field_index: int, cell_index: int, screen_position: Vector2) -> void:
	var world_state := _world_state()
	if world_state == null:
		return
	var status: Dictionary = world_state.get_farm_cell_status(field_index, cell_index, _current_game_hours())
	if status.is_empty():
		return
	var actions: Array = []
	if not bool(status.get("unlocked", false)):
		actions.append({
			"label": _raw_text("Buy field (%d essence)" % int(status.get("buy_cost", 0)), "Купить поле (%d эсс.)" % int(status.get("buy_cost", 0))),
			"variant": "warning",
			"callback": Callable(self, "_buy_field").bind(field_index)
		})
	else:
		var crop_id: String = str(status.get("crop_id", ""))
		var stage: String = str(status.get("stage", "empty"))
		if crop_id == "":
			for seed_id in world_state.get_farm_available_seed_ids():
				var seed_count: int = world_state.get_farm_seed_count(seed_id)
				actions.append({
					"label": "%s (%d)" % [world_state.get_farm_crop_seed_name(seed_id), seed_count],
					"variant": "success",
					"callback": Callable(self, "_plant_seed").bind(field_index, cell_index, seed_id)
				})
			if actions.is_empty():
				actions.append({
					"label": _raw_text("No seeds in the shed", "В сарае нет семян"),
					"variant": "neutral",
					"callback": Callable()
				})
		elif stage == "ready":
			actions.append({
				"label": _raw_text("Harvest", "Собрать"),
				"variant": "vitality",
				"callback": Callable(self, "_harvest_cell").bind(field_index, cell_index)
			})
		else:
			var progress: int = int(round(float(status.get("progress", 0.0)) * 100.0))
			actions.append({
				"label": _raw_text("Growing %d%%" % progress, "Растёт %d%%" % progress),
				"variant": "neutral",
				"callback": Callable()
			})
	actions.append({
		"label": _raw_text("Close", "Закрыть"),
		"variant": "neutral",
		"callback": Callable()
	})
	_show_context_menu("%s | %s" % [_field_name(field_index), _cell_name(cell_index)], actions, screen_position)


func _buy_field(field_index: int) -> void:
	var world_state := _world_state()
	if world_state == null:
		return
	if world_state.buy_farm_field(field_index):
		_show_banner(_raw_text("Field %d unlocked" % (field_index + 1), "Поле %d открыто" % (field_index + 1)), 1.6)
	else:
		_show_banner(_raw_text("Not enough essence or wrong order", "Недостаточно эссенции или неверный порядок покупки"), 1.6)
	_refresh_labels()
	_save_progress()


func _plant_seed(field_index: int, cell_index: int, crop_id: String) -> void:
	var world_state := _world_state()
	if world_state == null:
		return
	if world_state.plant_seed(field_index, cell_index, crop_id, _current_game_hours()):
		_show_banner("%s %s" % [world_state.get_farm_crop_seed_name(crop_id), _raw_text("planted", "посажены")], 1.4)
	else:
		_show_banner(_raw_text("Seed could not be planted", "Не удалось посадить семена"), 1.4)
	_refresh_labels()
	_save_progress()


func _harvest_cell(field_index: int, cell_index: int) -> void:
	var world_state := _world_state()
	if world_state == null:
		return
	var result: Dictionary = world_state.harvest_farm_cell(field_index, cell_index, _current_game_hours())
	if result.is_empty():
		_show_banner(_raw_text("Nothing is ready in this cell", "В этой ячейке пока нечего собирать"), 1.4)
	else:
		_show_banner("%s +%d" % [str(result.get("produce_name", "")), int(result.get("amount", 0))], 1.7)
	_refresh_labels()
	_refresh_shed_grid()
	_save_progress()


func _return_to_town() -> void:
	var scene_router: Node = _scene_router()
	if scene_router != null:
		scene_router.go_to_scene("res://scenes/main.tscn", "hub_farm_return")
	else:
		get_tree().change_scene_to_file("res://scenes/main.tscn")


func _refresh_labels() -> void:
	title_label.text = _raw_text("Bridge Farm", "Ферма у моста")
	var world_state := _world_state()
	if world_state != null:
		var planted: int = world_state.get_total_planted_cells(_current_game_hours())
		var unlocked_fields: int = world_state.get_unlocked_farm_fields()
		var open_cells: int = unlocked_fields * FIELD_CELLS_PER_FIELD
		var total_seeds: int = world_state.get_total_seed_count()
		summary_label.text = "Занято ячеек %d / %d\nПосажено %d\nВсего семян %d" % [
			planted,
			open_cells,
			planted,
			total_seeds
		]
	resource_label.text = ""
	hint_label.text = _raw_text(
		"12 fenced fields with 9 cells each. Two are open now. The shed near the bridge stores seeds and produce.",
		"12 огороженных полей по 9 ячеек. Сейчас открыты 2. Сарай рядом с мостом хранит семена и урожай."
	)
	if shed_panel != null and shed_panel.visible:
		_refresh_shed_grid()
	queue_redraw()


func _show_banner(text: String, duration: float) -> void:
	center_banner.text = text
	banner_timer = duration


func _save_progress() -> void:
	var game_state: Node = _game_state()
	if game_state != null:
		game_state.save_game()


func _on_inventory_state_changed(_is_open: bool) -> void:
	_sync_player_lock()


func _on_language_changed(_language: String) -> void:
	_refresh_labels()


func _unhandled_input(event: InputEvent) -> void:
	if inventory_ui != null and inventory_ui.is_open():
		return
	if event is InputEventMouseButton and event.pressed:
		var world_pos := _screen_to_world(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if context_menu_panel.visible and not context_menu_panel.get_global_rect().has_point(event.position):
				_close_context_menu()
			elif shed_panel.visible and not shed_panel.get_global_rect().has_point(event.position):
				_close_shed_panel()
			var target := _movement_target_for_click(world_pos)
			player.set_move_target(target)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_close_shed_panel()
			var cell_hit := _cell_hit_at(world_pos)
			if not cell_hit.is_empty():
				_open_field_cell_menu(int(cell_hit["field_index"]), int(cell_hit["cell_index"]), event.position)
				get_viewport().set_input_as_handled()
				return
			_close_context_menu()


func _screen_to_world(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position


func _movement_target_for_click(target: Vector2) -> Vector2:
	var target_field := _field_index_for_position(target)
	var player_field := _field_index_for_position(player.global_position)
	if target_field != -1 and player_field != target_field:
		return _field_gate_center(target_field)
	if target_field == -1 and player_field != -1:
		return _field_gate_center(player_field)
	return target


func _exit_tree() -> void:
	var game_state: Node = _game_state()
	if game_state != null:
		game_state.set_current_scene(SCENE_PATH)
		game_state.set_scene_player_position(SCENE_PATH, player.global_position)
		game_state.save_game()


func _maybe_store_scene_position() -> void:
	if player.global_position.distance_to(last_saved_position) < 96.0:
		return
	last_saved_position = player.global_position
	var game_state: Node = _game_state()
	if game_state != null:
		game_state.set_current_scene(SCENE_PATH)
		game_state.set_scene_player_position(SCENE_PATH, player.global_position)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, FARM_SIZE), Color("b8def2"))
	draw_rect(Rect2(Vector2(0.0, 220.0), Vector2(FARM_SIZE.x, 1340.0)), Color("8dbb73"))
	draw_rect(Rect2(Vector2(900.0, 1240.0), Vector2(1080.0, 320.0)), Color("c09d6e"))
	draw_rect(Rect2(Vector2(860.0, 1360.0), Vector2(990.0, 140.0)), Color("a6845d"))
	_draw_shed()
	_draw_bridge()
	_draw_all_fields()
	_draw_marker(SHED_POS, Color("8fd0ff"))
	_draw_marker(BRIDGE_POS, Color("efe8cf"))
	_draw_world_label(SHED_POS + Vector2(-46.0, -102.0), _raw_text("Shed", "Сарай"), Color("8fd0ff"))
	_draw_world_label(BRIDGE_POS + Vector2(-84.0, -24.0), _raw_text("Bridge to Town", "Мост в город"), Color("f8f0d5"))


func _draw_shed() -> void:
	draw_rect(Rect2(Vector2(700.0, 1180.0), Vector2(240.0, 230.0)), Color("8e7254"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(670.0, 1180.0),
		Vector2(970.0, 1180.0),
		Vector2(820.0, 1090.0)
	]), Color("6c4a34"))
	draw_rect(Rect2(Vector2(795.0, 1300.0), Vector2(52.0, 110.0)), Color("5d4331"))
	draw_rect(Rect2(Vector2(730.0, 1236.0), Vector2(36.0, 30.0)), Color("dce8ef"))


func _draw_bridge() -> void:
	draw_rect(Rect2(Vector2(1438.0, 1140.0), Vector2(126.0, 320.0)), Color("b78f65"))
	draw_line(Vector2(1438.0, 1140.0), Vector2(1438.0, 1460.0), Color("734f35"), 7.0)
	draw_line(Vector2(1564.0, 1140.0), Vector2(1564.0, 1460.0), Color("734f35"), 7.0)
	for index in range(7):
		var y := 1178.0 + float(index) * 40.0
		draw_line(Vector2(1438.0, y), Vector2(1564.0, y), Color("7f5a3b"), 4.0)


func _draw_all_fields() -> void:
	var world_state := _world_state()
	if world_state == null:
		return
	var fields: Array = world_state.get_farm_fields_status(_current_game_hours())
	for field_index in range(fields.size()):
		_draw_field(field_index, Dictionary(fields[field_index]))


func _draw_field(field_index: int, status: Dictionary) -> void:
	var outer := _field_outer_rect(field_index)
	var inner := _field_inner_rect(field_index)
	var gate := _field_gate_rect(field_index)
	var unlocked: bool = bool(status.get("unlocked", false))
	draw_rect(outer, Color("7ea45f"))
	draw_rect(inner, Color("8b6948"))
	draw_line(outer.position, outer.position + Vector2(outer.size.x, 0.0), Color("705033"), 5.0)
	draw_line(outer.position, outer.position + Vector2(0.0, outer.size.y), Color("705033"), 5.0)
	draw_line(outer.position + Vector2(outer.size.x, 0.0), outer.position + outer.size, Color("705033"), 5.0)
	var gate_start := gate.position.x
	var gate_end := gate.position.x + gate.size.x
	var bottom_y := outer.position.y + outer.size.y
	draw_line(Vector2(outer.position.x, bottom_y), Vector2(gate_start, bottom_y), Color("705033"), 5.0)
	draw_line(Vector2(gate_end, bottom_y), Vector2(outer.position.x + outer.size.x, bottom_y), Color("705033"), 5.0)
	draw_rect(Rect2(gate.position, Vector2(gate.size.x, 10.0)), Color("d4b27e"))
	_draw_world_label(outer.position + Vector2(12.0, -16.0), _field_name(field_index), Color("f4e7ca"))
	if not unlocked:
		draw_rect(inner, Color(0.15, 0.18, 0.14, 0.58))
		_draw_world_label(inner.position + Vector2(34.0, 52.0), _raw_text("Locked", "Закрыто"), Color("f0d8a0"))
		_draw_world_label(inner.position + Vector2(22.0, 82.0), _raw_text("Buy: %d" % int(status.get("buy_cost", 0)), "Цена: %d" % int(status.get("buy_cost", 0))), Color("f0d8a0"))
	var cells: Array = status.get("cells", [])
	for cell_index in range(FIELD_CELLS_PER_FIELD):
		var cell_rect := _field_cell_rect(field_index, cell_index)
		var cell_status: Dictionary = Dictionary(cells[cell_index]) if cell_index < cells.size() else {}
		_draw_field_cell(cell_rect, cell_status, unlocked)


func _draw_field_cell(rect: Rect2, status: Dictionary, unlocked: bool) -> void:
	if not unlocked:
		draw_rect(rect, Color("577544"))
		draw_rect(Rect2(rect.position - Vector2.ONE, rect.size + Vector2(2.0, 2.0)), Color(0.14, 0.10, 0.07, 0.35), false, 2.0)
		return
	var stage: String = str(status.get("stage", "empty"))
	var crop_id: String = str(status.get("crop_id", ""))
	var soil := Color("9d7851")
	if stage == "growing":
		soil = Color("846345")
	elif stage == "ready":
		soil = Color("805d3b")
	draw_rect(rect, soil)
	draw_rect(Rect2(rect.position - Vector2.ONE, rect.size + Vector2(2.0, 2.0)), Color(0.14, 0.10, 0.07, 0.35), false, 2.0)
	if crop_id == "":
		return
	var progress: float = float(status.get("progress", 0.0))
	_draw_crop_visual(rect, crop_id, progress, stage == "ready")


func _draw_crop_visual(rect: Rect2, crop_id: String, progress: float, ready: bool) -> void:
	var world_state := _world_state()
	if world_state == null:
		return
	var visual: String = world_state.get_farm_crop_visual(crop_id)
	var tint: Color = world_state.get_farm_crop_seed_color(crop_id)
	var center: Vector2 = rect.get_center()
	if progress < 0.2:
		draw_circle(center + Vector2(0.0, 10.0), 6.0, tint.darkened(0.15))
		draw_line(center + Vector2(0.0, 12.0), center + Vector2(0.0, -2.0), Color("7dd57f"), 3.0)
		return
	match visual:
		"stalk":
			for offset in [-10.0, 0.0, 10.0]:
				draw_line(center + Vector2(offset, 12.0), center + Vector2(offset, -18.0), Color("6db95f"), 3.0)
				draw_circle(center + Vector2(offset, -22.0), 5.0, tint if ready else tint.darkened(0.2))
		"root":
			draw_line(center + Vector2(0.0, -10.0), center + Vector2(0.0, 8.0), Color("5cad56"), 3.0)
			draw_circle(center + Vector2(-5.0, 12.0), 7.0, tint if ready else tint.darkened(0.2))
			draw_circle(center + Vector2(4.0, 14.0), 6.0, tint if ready else tint.darkened(0.2))
		"mound":
			draw_circle(center + Vector2(-8.0, 10.0), 7.0, tint if ready else tint.darkened(0.2))
			draw_circle(center + Vector2(2.0, 8.0), 8.0, tint if ready else tint.darkened(0.2))
			draw_circle(center + Vector2(11.0, 12.0), 6.0, tint if ready else tint.darkened(0.2))
		"cabbage":
			draw_circle(center, 16.0, tint if ready else tint.darkened(0.2))
			draw_circle(center + Vector2(-5.0, -4.0), 6.0, Color(1.0, 1.0, 1.0, 0.12))
		"tomato":
			draw_line(center + Vector2(0.0, 10.0), center + Vector2(0.0, -12.0), Color("61af58"), 3.0)
			draw_circle(center + Vector2(-9.0, 0.0), 7.0, tint if ready else tint.darkened(0.2))
			draw_circle(center + Vector2(0.0, 8.0), 7.0, tint if ready else tint.darkened(0.2))
			draw_circle(center + Vector2(9.0, -2.0), 7.0, tint if ready else tint.darkened(0.2))
		"vine":
			draw_arc(center, 12.0, PI * 0.2, PI * 1.2, 14, Color("61af58"), 3.0)
			draw_line(center + Vector2(-12.0, 4.0), center + Vector2(12.0, 10.0), Color("61af58"), 3.0)
			draw_circle(center + Vector2(9.0, 10.0), 8.0, tint if ready else tint.darkened(0.2))
		"bulb":
			draw_line(center + Vector2(0.0, 8.0), center + Vector2(0.0, -12.0), Color("66b55d"), 3.0)
			draw_circle(center + Vector2(0.0, 12.0), 9.0, tint if ready else tint.darkened(0.2))
		"pumpkin":
			draw_circle(center + Vector2(-8.0, 10.0), 8.0, tint if ready else tint.darkened(0.2))
			draw_circle(center + Vector2(0.0, 8.0), 11.0, tint if ready else tint.darkened(0.2))
			draw_circle(center + Vector2(10.0, 10.0), 8.0, tint if ready else tint.darkened(0.2))
			draw_line(center + Vector2(0.0, -6.0), center + Vector2(0.0, -14.0), Color("5fa653"), 3.0)
		"corn":
			draw_line(center + Vector2(-8.0, 14.0), center + Vector2(-4.0, -16.0), Color("5fa653"), 3.0)
			draw_line(center + Vector2(8.0, 14.0), center + Vector2(4.0, -18.0), Color("5fa653"), 3.0)
			draw_rect(Rect2(center + Vector2(-8.0, -4.0), Vector2(8.0, 18.0)), tint if ready else tint.darkened(0.2))
			draw_rect(Rect2(center + Vector2(0.0, -8.0), Vector2(8.0, 18.0)), tint if ready else tint.darkened(0.2))
		"tree":
			draw_rect(Rect2(center + Vector2(-4.0, 4.0), Vector2(8.0, 18.0)), Color("7a563b"))
			draw_circle(center + Vector2(0.0, -6.0), 18.0, Color("6fa04d"))
			draw_circle(center + Vector2(-8.0, -2.0), 5.0, tint if ready else tint.darkened(0.2))
			draw_circle(center + Vector2(8.0, 0.0), 5.0, tint if ready else tint.darkened(0.2))
		_:
			draw_circle(center, 12.0, tint)


func _field_outer_rect(field_index: int) -> Rect2:
	var row := field_index / FIELD_COLUMNS
	var column := field_index % FIELD_COLUMNS
	return Rect2(
		FIELD_ORIGIN + Vector2(column * (FIELD_OUTER_SIZE.x + FIELD_SPACING.x), row * (FIELD_OUTER_SIZE.y + FIELD_SPACING.y)),
		FIELD_OUTER_SIZE
	)


func _field_inner_rect(field_index: int) -> Rect2:
	var outer := _field_outer_rect(field_index)
	return Rect2(
		outer.position + Vector2(FIELD_INNER_MARGIN, FIELD_INNER_MARGIN),
		outer.size - Vector2(FIELD_INNER_MARGIN * 2.0, FIELD_INNER_MARGIN * 2.0)
	)


func _field_gate_rect(field_index: int) -> Rect2:
	var outer := _field_outer_rect(field_index)
	return Rect2(
		Vector2(outer.position.x + (outer.size.x - FIELD_GATE_WIDTH) * 0.5, outer.position.y + outer.size.y - FIELD_GATE_DEPTH),
		Vector2(FIELD_GATE_WIDTH, FIELD_GATE_DEPTH)
	)


func _field_gate_center(field_index: int) -> Vector2:
	return _field_gate_rect(field_index).get_center() + Vector2(0.0, 28.0)


func _field_cell_rect(field_index: int, cell_index: int) -> Rect2:
	var inner := _field_inner_rect(field_index)
	var cell_gap := 10.0
	var cell_size := Vector2(
		(inner.size.x - cell_gap * 2.0) / 3.0,
		(inner.size.y - cell_gap * 2.0) / 3.0
	)
	var row := cell_index / 3
	var column := cell_index % 3
	return Rect2(
		inner.position + Vector2(column * (cell_size.x + cell_gap), row * (cell_size.y + cell_gap)),
		cell_size
	)


func _cell_hit_at(world_position: Vector2) -> Dictionary:
	var world_state := _world_state()
	if world_state == null:
		return {}
	for field_index in range(world_state.get_farm_field_count()):
		var outer := _field_outer_rect(field_index)
		if not outer.has_point(world_position):
			continue
		for cell_index in range(FIELD_CELLS_PER_FIELD):
			if _field_cell_rect(field_index, cell_index).has_point(world_position):
				return {
					"field_index": field_index,
					"cell_index": cell_index
				}
	return {}


func _field_index_for_position(world_position: Vector2) -> int:
	var world_state := _world_state()
	if world_state == null:
		return -1
	for field_index in range(world_state.get_unlocked_farm_fields()):
		if _field_outer_rect(field_index).has_point(world_position):
			return field_index
	return -1


func _field_name(field_index: int) -> String:
	return _raw_text("Field %d" % (field_index + 1), "Поле %d" % (field_index + 1))


func _cell_name(cell_index: int) -> String:
	return _raw_text("Cell %d" % (cell_index + 1), "Ячейка %d" % (cell_index + 1))


func _draw_marker(pos: Vector2, tint: Color) -> void:
	draw_circle(pos, 14.0, tint)
	draw_circle(pos, 5.0, Color.WHITE)


func _draw_world_label(pos: Vector2, text: String, tint: Color) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, tint)


func _current_game_hours() -> float:
	var world_time_manager := _world_time_manager()
	if world_time_manager != null:
		return float(world_time_manager.total_hours)
	return 0.0


func _raw_text(en_text: String, ru_text: String) -> String:
	var localizer: Node = _localizer()
	if localizer != null and localizer.has_method("get_language") and localizer.get_language() == "en":
		return en_text
	return ru_text
