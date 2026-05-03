extends CanvasLayer
class_name BattleHud

signal end_turn_pressed
signal wait_pressed
signal defend_pressed
signal flee_pressed
signal return_pressed

@onready var title_label: Label = $Panel/Margin/Rows/Title
@onready var turn_label: Label = $Panel/Margin/Rows/Turn
@onready var selected_label: Label = $Panel/Margin/Rows/Selected
@onready var terrain_label: Label = $Panel/Margin/Rows/Terrain
@onready var forecast_label: Label = $Panel/Margin/Rows/Forecast
@onready var log_label: RichTextLabel = $Panel/Margin/Rows/Log
@onready var wait_button: Button = $Panel/Margin/Rows/Actions/Wait
@onready var defend_button: Button = $Panel/Margin/Rows/Actions/Defend
@onready var flee_button: Button = $Panel/Margin/Rows/Actions/Flee
@onready var end_turn_button: Button = $Panel/Margin/Rows/EndTurn
@onready var return_button: Button = $Panel/Margin/Rows/Return
@onready var turn_order_title_label: Label = $TurnOrderPanel/Margin/Rows/Title
@onready var turn_order_scroll: ScrollContainer = $TurnOrderPanel/Margin/Rows/Scroll
@onready var turn_order_container: Control = $TurnOrderPanel/Margin/Rows/Scroll/Order

var log_lines: Array[String] = []
const MAX_LOG_LINES := 40
const TURN_ORDER_CARD_SIZE := Vector2(122.0, 82.0)
const TURN_ORDER_CARD_SPACING := 10.0
const PLAYER_LOG_NAME_COLOR := "9df3ff"
const ENEMY_LOG_NAME_COLOR := "ffb38a"

var turn_order_cards := {}
var turn_order_ids: Array[String] = []
var turn_order_tween: Tween


func _ready() -> void:
	end_turn_button.pressed.connect(func(): end_turn_pressed.emit())
	wait_button.pressed.connect(func(): wait_pressed.emit())
	defend_button.pressed.connect(func(): defend_pressed.emit())
	flee_button.pressed.connect(func(): flee_pressed.emit())
	return_button.pressed.connect(func(): return_pressed.emit())
	return_button.visible = false
	turn_order_title_label.text = "Очередность хода"


func setup(title: String, environment := {}) -> void:
	var weather := str(environment.get("weather", "clear"))
	var time_of_day := str(environment.get("time_of_day", "day"))
	title_label.text = "%s | %s, %s" % [title, weather, time_of_day]
	push_log("Бой загружен с моковыми данными.")


func update_turn(unit: UnitInstance, round_number: int) -> void:
	var side := "Игрок" if unit.team == 0 else "Враг"
	turn_label.text = "Раунд %d | Ход: %s (%s), AP %d" % [round_number, unit.display_name(), side, unit.action_points]


func update_selection(unit: UnitInstance) -> void:
	if unit == null:
		selected_label.text = "Выбор: нет"
		return
	selected_label.text = "%s | HP %d/%d | AP %d | morale %+d | fatigue %d" % [
		unit.display_name(),
		unit.hp,
		unit.max_hp,
		unit.action_points,
		unit.morale,
		unit.fatigue
	]


func update_terrain(terrain: TerrainData) -> void:
	if terrain == null:
		terrain_label.text = "Местность: -"
		return
	terrain_label.text = "Местность: %s | move %d | %s" % [
		terrain.display_name,
		terrain.move_cost,
		terrain.describe_effects()
	]


func update_forecast(text: String) -> void:
	forecast_label.text = text


func show_result(result: Dictionary) -> void:
	var winner := int(result.get("winner_team", -1))
	var reason := str(result.get("reason", "victory"))
	turn_label.text = "Бой завершен"
	if reason == "retreat":
		selected_label.text = "Отряд отступил с поля боя"
	elif winner == -1:
		selected_label.text = "Победитель не определен"
	else:
		selected_label.text = "Победитель: %s" % ("отряд игрока" if winner == 0 else "враги")
	end_turn_button.disabled = true
	wait_button.disabled = true
	defend_button.disabled = true
	flee_button.disabled = true
	return_button.visible = true


func set_player_turn(enabled: bool) -> void:
	end_turn_button.disabled = not enabled
	wait_button.disabled = not enabled
	defend_button.disabled = not enabled
	flee_button.disabled = not enabled


func update_turn_order(units: Array[UnitInstance], current_unit: UnitInstance) -> void:
	if units.is_empty():
		_clear_turn_order_cards()
		return
	var new_ids: Array[String] = []
	var unit_by_id := {}
	for unit in units:
		if unit == null:
			continue
		new_ids.append(unit.instance_id)
		unit_by_id[unit.instance_id] = unit

	var previous_ids: Array[String] = turn_order_ids.duplicate()
	var previous_current_id: String = previous_ids[0] if not previous_ids.is_empty() else ""

	for unit_id in turn_order_cards.keys():
		if not unit_by_id.has(unit_id):
			var removed_card: Control = turn_order_cards[unit_id]
			turn_order_cards.erase(unit_id)
			_animate_removed_turn_order_card(removed_card)

	for unit_id in new_ids:
		var unit: UnitInstance = unit_by_id[unit_id]
		var card: PanelContainer = turn_order_cards.get(unit_id, null)
		if card == null:
			card = _build_turn_order_card(unit)
			turn_order_cards[unit_id] = card
			turn_order_container.add_child(card)
		_update_turn_order_card(card, unit, new_ids.find(unit_id), unit == current_unit)

	_animate_turn_order(previous_ids, new_ids, current_unit, previous_current_id)
	turn_order_ids = new_ids


func push_log(text: String) -> void:
	log_lines.append(text)
	while log_lines.size() > MAX_LOG_LINES:
		log_lines.pop_front()
	log_label.text = "\n".join(log_lines)
	log_label.scroll_to_line(max(log_lines.size() - 1, 0))


func format_unit_name(unit: UnitInstance) -> String:
	if unit == null:
		return "Неизвестный"
	var color := PLAYER_LOG_NAME_COLOR if unit.team == 0 else ENEMY_LOG_NAME_COLOR
	return "[color=#%s]%s[/color]" % [color, unit.display_name()]


func _build_turn_order_card(unit: UnitInstance) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = TURN_ORDER_CARD_SIZE
	card.size = TURN_ORDER_CARD_SIZE
	card.pivot_offset = TURN_ORDER_CARD_SIZE * 0.5
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 2)
	margin.add_child(rows)

	var position_label := Label.new()
	position_label.name = "PositionLabel"
	position_label.add_theme_font_size_override("font_size", 12)
	rows.add_child(position_label)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(name_label)

	var stats_label := Label.new()
	stats_label.name = "StatsLabel"
	stats_label.add_theme_font_size_override("font_size", 12)
	rows.add_child(stats_label)

	var side_label := Label.new()
	side_label.name = "SideLabel"
	side_label.add_theme_font_size_override("font_size", 12)
	rows.add_child(side_label)

	_update_turn_order_card(card, unit, 0, false)
	return card


func _turn_order_background(unit: UnitInstance, is_current: bool) -> Color:
	var base := unit.data.color if unit != null and unit.data != null else Color("5f6b78")
	base = base.darkened(0.28 if unit != null and unit.team == 1 else 0.12)
	if is_current:
		return base.lightened(0.18)
	return Color(base.r, base.g, base.b, 0.92)


func _update_turn_order_card(card: PanelContainer, unit: UnitInstance, index: int, is_current: bool) -> void:
	card.set_meta("unit_id", unit.instance_id)
	var style := StyleBoxFlat.new()
	style.bg_color = _turn_order_background(unit, is_current)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color("fff3b0") if is_current else Color(1.0, 1.0, 1.0, 0.14)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	card.add_theme_stylebox_override("panel", style)

	var position_label: Label = card.get_node("Margin/Rows/PositionLabel")
	position_label.text = "Сейчас" if is_current else "#%d далее" % (index + 1)
	position_label.modulate = Color("fff3b0") if is_current else Color(1.0, 1.0, 1.0, 0.72)

	var name_label: Label = card.get_node("Margin/Rows/NameLabel")
	name_label.text = unit.display_name()

	var stats_label: Label = card.get_node("Margin/Rows/StatsLabel")
	stats_label.text = "HP %d/%d  AP %d" % [unit.hp, unit.max_hp, unit.action_points]
	stats_label.modulate = Color("dbe7ef")

	var side_label: Label = card.get_node("Margin/Rows/SideLabel")
	side_label.text = "Игрок" if unit.team == 0 else "Враг"
	side_label.modulate = Color("9df3ff") if unit.team == 0 else Color("ffb38a")


func _animate_turn_order(previous_ids: Array[String], new_ids: Array[String], current_unit: UnitInstance, previous_current_id: String) -> void:
	if turn_order_tween != null and turn_order_tween.is_valid():
		turn_order_tween.kill()
	turn_order_tween = create_tween()
	turn_order_tween.set_parallel(true)
	_update_turn_order_container_size(new_ids.size())

	for index in range(new_ids.size()):
		var unit_id := new_ids[index]
		var card: Control = turn_order_cards.get(unit_id, null)
		if card == null:
			continue
		var target_position := _turn_order_card_position(index)
		var existed_before := previous_ids.has(unit_id)
		var is_rotated_current := previous_current_id != "" and previous_current_id == unit_id and index > 0
		if not existed_before:
			card.position = target_position + Vector2(0.0, 18.0)
			card.scale = Vector2(0.9, 0.9)
			card.modulate = Color(1, 1, 1, 0)
			turn_order_tween.tween_property(card, "position", target_position, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			turn_order_tween.tween_property(card, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			turn_order_tween.tween_property(card, "modulate", Color.WHITE, 0.18)
		elif is_rotated_current:
			turn_order_tween.tween_property(card, "scale", Vector2(0.72, 0.72), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			turn_order_tween.tween_property(card, "modulate", Color(0.55, 0.55, 0.55, 0.2), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			turn_order_tween.tween_callback(func():
				if is_instance_valid(card):
					card.position = target_position + Vector2(0.0, 14.0)
			).set_delay(0.12)
			turn_order_tween.tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.12)
			turn_order_tween.tween_property(card, "modulate", Color.WHITE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(0.12)
			turn_order_tween.tween_property(card, "position", target_position, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(0.12)
		else:
			turn_order_tween.tween_property(card, "position", target_position, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			turn_order_tween.tween_property(card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			turn_order_tween.tween_property(card, "modulate", Color.WHITE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if current_unit != null and turn_order_cards.has(current_unit.instance_id):
		var current_card: Control = turn_order_cards[current_unit.instance_id]
		turn_order_tween.tween_property(turn_order_scroll, "scroll_horizontal", maxi(int(current_card.position.x - 32.0), 0), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _animate_removed_turn_order_card(card: Control) -> void:
	if card == null:
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "scale", Vector2(0.8, 0.8), 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(card, "modulate", Color(1, 1, 1, 0), 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(card.queue_free).set_delay(0.14)


func _turn_order_card_position(index: int) -> Vector2:
	return Vector2(index * (TURN_ORDER_CARD_SIZE.x + TURN_ORDER_CARD_SPACING), 0.0)


func _update_turn_order_container_size(card_count: int) -> void:
	var width := maxf(TURN_ORDER_CARD_SIZE.x, card_count * (TURN_ORDER_CARD_SIZE.x + TURN_ORDER_CARD_SPACING) - TURN_ORDER_CARD_SPACING)
	turn_order_container.custom_minimum_size = Vector2(width, TURN_ORDER_CARD_SIZE.y)
	turn_order_container.size = turn_order_container.custom_minimum_size


func _clear_turn_order_cards() -> void:
	for card in turn_order_cards.values():
		if is_instance_valid(card):
			card.queue_free()
	turn_order_cards.clear()
	turn_order_ids.clear()
