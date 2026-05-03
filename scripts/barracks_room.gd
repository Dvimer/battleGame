extends Node2D

const ROOM_SIZE := Vector2(1480.0, 900.0)
const DOOR_POS := Vector2(740.0, 760.0)
const BUNKS_POS := Vector2(280.0, 220.0)
const TRAINING_POS := Vector2(1120.0, 250.0)
const SCENE_PATH := "res://scenes/barracks.tscn"

@onready var player := $Player
@onready var camera: Camera2D = $Camera2D
@onready var title_label: Label = $HUD/TitleLabel
@onready var prompt_label: Label = $HUD/PromptLabel
@onready var hint_label: Label = $HUD/HintLabel
@onready var silver_label: Label = $HUD/RootPanel/Margin/VBox/TopBar/SilverLabel
@onready var party_list: ItemList = $HUD/RootPanel/Margin/VBox/Content/PartyColumn/PartyList
@onready var party_details: Label = $HUD/RootPanel/Margin/VBox/Content/PartyColumn/PartyDetails
@onready var recruit_list: ItemList = $HUD/RootPanel/Margin/VBox/Content/RecruitColumn/RecruitList
@onready var recruit_details: Label = $HUD/RootPanel/Margin/VBox/Content/RecruitColumn/RecruitDetails
@onready var invite_button: Button = $HUD/RootPanel/Margin/VBox/Actions/InviteButton
@onready var replace_button: Button = $HUD/RootPanel/Margin/VBox/Actions/ReplaceButton
@onready var close_button: Button = $HUD/RootPanel/Margin/VBox/TopBar/CloseButton
@onready var status_label: Label = $HUD/RootPanel/Margin/VBox/StatusLabel
@onready var root_panel: Panel = $HUD/RootPanel

var party_unit_ids: Array[String] = []
var recruit_ids: Array[String] = []
var selected_party_unit_id := ""
var selected_recruit_id := ""
var panel_open := true
var last_saved_position := Vector2(-9999.0, -9999.0)


func _scene_router() -> Node:
	return get_node_or_null("/root/SceneRouter")


func _roster_manager() -> Node:
	return get_node_or_null("/root/RosterManager")


func _inventory() -> Node:
	return get_node_or_null("/root/RosterInventory")


func _game_state() -> Node:
	return get_node_or_null("/root/GameState")


func _ready() -> void:
	player.arena_size = ROOM_SIZE
	player.allow_attack = false
	player.allow_dash = false
	player.allow_click_move = true
	player.set_movement_locked(false)
	var game_state := _game_state()
	if game_state != null:
		game_state.ensure_loaded()
		game_state.set_current_scene(SCENE_PATH)
	var scene_router := _scene_router()
	if scene_router != null:
		var fallback_position: Vector2 = game_state.get_scene_player_position(SCENE_PATH, player.global_position) if game_state != null else player.global_position
		scene_router.apply_spawn(player, fallback_position)
	last_saved_position = player.global_position
	title_label.text = "Казарма ополчения"
	prompt_label.text = "ЛКМ по полу двигает. Esc или крестик скрывают список. Дверь внизу выводит обратно в город."
	hint_label.text = "Выбирай рекрута справа. Invite добавляет его в отряд, Replace меняет выбранного бойца, ПКМ по бойцу увольняет."
	root_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_panel()
	party_list.item_selected.connect(_on_party_selected)
	party_list.item_clicked.connect(_on_party_clicked)
	recruit_list.item_selected.connect(_on_recruit_selected)
	invite_button.pressed.connect(_on_invite_pressed)
	replace_button.pressed.connect(_on_replace_pressed)
	close_button.pressed.connect(func(): _set_panel_open(false))
	var roster_manager := _roster_manager()
	if roster_manager != null and not roster_manager.roster_changed.is_connected(_on_roster_changed):
		roster_manager.roster_changed.connect(_on_roster_changed)
	var inventory := _inventory()
	if inventory != null and not inventory.inventory_changed.is_connected(_on_inventory_changed):
		inventory.inventory_changed.connect(_on_inventory_changed)
	_refresh_all()
	_set_panel_open(true)


func _physics_process(_delta: float) -> void:
	camera.position = player.global_position
	_maybe_store_scene_position()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_set_panel_open(not panel_open)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if panel_open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		player.set_move_target(_screen_to_world(event.position))
		get_viewport().set_input_as_handled()


func _screen_to_world(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position


func _refresh_all() -> void:
	_refresh_silver()
	_refresh_party_list()
	_refresh_recruit_list()
	_refresh_party_details()
	_refresh_recruit_details()
	_refresh_buttons()


func _refresh_silver() -> void:
	var inventory: Node = _inventory()
	var silver: int = inventory.currency if inventory != null else 0
	silver_label.text = "Казна: %d" % silver


func _refresh_party_list() -> void:
	party_unit_ids.clear()
	party_list.clear()
	var roster_manager := _roster_manager()
	if roster_manager == null:
		return
	for unit in roster_manager.get_party_units():
		party_unit_ids.append(unit.id)
		var unit_text := "%s | %s | HP %d/%d" % [
			unit.display_name,
			unit.base_unit_data.display_name if unit.base_unit_data != null else "Юнит",
			unit.current_hp,
			unit.get_max_hp()
		]
		if unit.id == "captain_01":
			unit_text += " | капитан"
		party_list.add_item(unit_text)
	if selected_party_unit_id == "" and not party_unit_ids.is_empty():
		selected_party_unit_id = party_unit_ids[0]
	if not party_unit_ids.has(selected_party_unit_id):
		selected_party_unit_id = party_unit_ids[0] if not party_unit_ids.is_empty() else ""
	var selected_index := party_unit_ids.find(selected_party_unit_id)
	if selected_index != -1:
		party_list.select(selected_index)


func _refresh_recruit_list() -> void:
	recruit_ids.clear()
	recruit_list.clear()
	var roster_manager := _roster_manager()
	if roster_manager == null:
		return
	for offer in roster_manager.get_recruit_offers():
		var recruit_id := str(offer.get("recruit_id", ""))
		recruit_ids.append(recruit_id)
		var recruit_text := "%s | %s | %s" % [
			str(offer.get("display_name", "Рекрут")),
			_class_label(str(offer.get("base_unit_id", "footman"))),
			_price_label(int(offer.get("price", 0)))
		]
		recruit_list.add_item(recruit_text)
	if not recruit_ids.has(selected_recruit_id):
		selected_recruit_id = recruit_ids[0] if not recruit_ids.is_empty() else ""
	var selected_index := recruit_ids.find(selected_recruit_id)
	if selected_index != -1:
		recruit_list.select(selected_index)


func _refresh_party_details() -> void:
	var unit = _selected_party_unit()
	if unit == null:
		party_details.text = "Текущий отряд пуст."
		return
	party_details.text = "%s\nКласс: %s\nHP: %d/%d\nАтака: %d  Защита: %d\nИнициатива: %d  ОД: %d\nДвижение: %d  Дальность: %d" % [
		unit.display_name,
		unit.base_unit_data.display_name if unit.base_unit_data != null else "Юнит",
		unit.current_hp,
		unit.get_max_hp(),
		unit.get_attack(),
		unit.get_defense(),
		unit.get_initiative(),
		unit.get_action_points(),
		unit.get_movement(),
		unit.get_attack_range()
	]


func _refresh_recruit_details() -> void:
	var offer := _selected_offer()
	if offer.is_empty():
		recruit_details.text = "Свободных рекрутов пока нет."
		return
	recruit_details.text = "%s\nКласс: %s\nЦена: %s\nБонусы: %s" % [
		str(offer.get("display_name", "Рекрут")),
		_class_label(str(offer.get("base_unit_id", "footman"))),
		_price_label(int(offer.get("price", 0))),
		_bonus_label(Dictionary(offer.get("perm_stat_bonuses", {})))
	]


func _refresh_buttons() -> void:
	var roster_manager: Node = _roster_manager()
	if roster_manager == null:
		invite_button.disabled = true
		replace_button.disabled = true
		return
	var has_offer: bool = not _selected_offer().is_empty()
	var party_size: int = roster_manager.get_party_units().size()
	var can_afford: bool = _can_afford_selected_offer()
	invite_button.disabled = not has_offer or party_size >= roster_manager.get_party_capacity() or not can_afford
	replace_button.disabled = not has_offer or selected_party_unit_id == "" or selected_party_unit_id == "captain_01" or not can_afford


func _selected_party_unit():
	var roster_manager := _roster_manager()
	if roster_manager == null:
		return null
	return roster_manager.find_unit(selected_party_unit_id)


func _selected_offer() -> Dictionary:
	var roster_manager := _roster_manager()
	if roster_manager == null:
		return {}
	for offer in roster_manager.get_recruit_offers():
		if str(offer.get("recruit_id", "")) == selected_recruit_id:
			return offer
	return {}


func _can_afford_selected_offer() -> bool:
	var offer := _selected_offer()
	var inventory := _inventory()
	if offer.is_empty():
		return false
	if inventory == null:
		return int(offer.get("price", 0)) <= 0
	return inventory.currency >= int(offer.get("price", 0))


func _class_label(base_unit_id: String) -> String:
	return "Стрелок" if base_unit_id == "archer" else "Ополченец"


func _price_label(price: int) -> String:
	return "бесплатно" if price <= 0 else "%d серебра" % price


func _bonus_label(bonuses: Dictionary) -> String:
	if bonuses.is_empty():
		return "без особенностей"
	var labels: Array[String] = []
	for key in bonuses.keys():
		var value := int(bonuses[key])
		var stat_name := str(key)
		match str(key):
			"max_hp":
				stat_name = "HP"
			"attack":
				stat_name = "атака"
			"defense":
				stat_name = "защита"
			"initiative":
				stat_name = "инициатива"
			"action_points":
				stat_name = "ОД"
			"movement":
				stat_name = "движение"
			"attack_range":
				stat_name = "дальность"
		labels.append("%s %+d" % [stat_name, value])
	return ", ".join(labels)


func _dismiss_unit(unit_id: String) -> void:
	var roster_manager := _roster_manager()
	if roster_manager == null or unit_id == "":
		return
	if roster_manager.dismiss_unit(unit_id):
		selected_party_unit_id = party_unit_ids[0] if not party_unit_ids.is_empty() else ""
		_set_status("Боец уволен из отряда.")
		_save_game()
	else:
		_set_status("Капитана нельзя уволить.")
	_refresh_all()


func _set_status(text: String) -> void:
	status_label.text = text


func _set_panel_open(is_open: bool) -> void:
	panel_open = is_open
	root_panel.visible = panel_open
	if panel_open:
		status_label.text = ""
		_refresh_all()
		prompt_label.text = "Esc скрывает список. Дверь внизу выводит обратно в город."
	else:
		prompt_label.text = "Панель скрыта. Нажми Esc, чтобы снова открыть список рекрутов."


func _save_game() -> void:
	var game_state := _game_state()
	if game_state != null:
		game_state.set_current_scene(SCENE_PATH)
		game_state.set_scene_player_position(SCENE_PATH, player.global_position)
		game_state.save_game()


func _exit_tree() -> void:
	var game_state := _game_state()
	if game_state != null:
		game_state.set_current_scene(SCENE_PATH)
		game_state.set_scene_player_position(SCENE_PATH, player.global_position)
		game_state.save_game()


func _maybe_store_scene_position() -> void:
	if player.global_position.distance_to(last_saved_position) < 64.0:
		return
	last_saved_position = player.global_position
	var game_state := _game_state()
	if game_state != null:
		game_state.set_current_scene(SCENE_PATH)
		game_state.set_scene_player_position(SCENE_PATH, player.global_position)


func _on_party_selected(index: int) -> void:
	if index < 0 or index >= party_unit_ids.size():
		return
	selected_party_unit_id = party_unit_ids[index]
	_refresh_party_details()
	_refresh_buttons()


func _on_party_clicked(index: int, _at_position: Vector2, mouse_button_index: int) -> void:
	if index < 0 or index >= party_unit_ids.size():
		return
	selected_party_unit_id = party_unit_ids[index]
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		_dismiss_unit(selected_party_unit_id)
		return
	_refresh_party_details()
	_refresh_buttons()


func _on_recruit_selected(index: int) -> void:
	if index < 0 or index >= recruit_ids.size():
		return
	selected_recruit_id = recruit_ids[index]
	_refresh_recruit_details()
	_refresh_buttons()


func _on_invite_pressed() -> void:
	var roster_manager := _roster_manager()
	if roster_manager == null or selected_recruit_id == "":
		return
	if roster_manager.hire_recruit(selected_recruit_id):
		_set_status("Новый боец приглашён в отряд.")
		_save_game()
	else:
		_set_status("Нет свободного места в отряде. Используй Replace или увольнение ПКМ.")
	_refresh_all()


func _on_replace_pressed() -> void:
	var roster_manager := _roster_manager()
	if roster_manager == null or selected_recruit_id == "" or selected_party_unit_id == "":
		return
	if roster_manager.hire_recruit(selected_recruit_id, selected_party_unit_id):
		_set_status("Боец в отряде заменён новым рекрутом.")
		selected_party_unit_id = ""
		_save_game()
	else:
		_set_status("Заменить можно только обычного бойца. Капитан остаётся в отряде.")
	_refresh_all()


func _on_roster_changed() -> void:
	_refresh_all()


func _on_inventory_changed() -> void:
	_refresh_all()


func _style_panel() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.08, 0.06, 0.94)
	panel_style.border_color = Color(0.72, 0.63, 0.44, 0.55)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	root_panel.add_theme_stylebox_override("panel", panel_style)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, ROOM_SIZE), Color("c6b38c"))
	draw_rect(Rect2(Vector2(70.0, 90.0), Vector2(1340.0, 730.0)), Color("e7d8b4"))
	draw_rect(Rect2(Vector2(140.0, 140.0), Vector2(280.0, 150.0)), Color("8a6a50"))
	draw_rect(Rect2(Vector2(1010.0, 150.0), Vector2(260.0, 170.0)), Color("927158"))
	draw_rect(Rect2(Vector2(660.0, 700.0), Vector2(160.0, 84.0)), Color("6b4a35"))
	draw_circle(BUNKS_POS, 12.0, Color("9be7ff"))
	draw_circle(TRAINING_POS, 12.0, Color("ffd166"))
	draw_circle(DOOR_POS, 12.0, Color("f08a5d"))
	_draw_world_label(BUNKS_POS + Vector2(-34.0, -24.0), "Койки", Color("9be7ff"))
	_draw_world_label(TRAINING_POS + Vector2(-54.0, -24.0), "Плац", Color("ffd166"))
	_draw_world_label(DOOR_POS + Vector2(-22.0, -24.0), "Выход", Color("f08a5d"))


func _draw_world_label(pos: Vector2, text: String, tint: Color) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, tint)
