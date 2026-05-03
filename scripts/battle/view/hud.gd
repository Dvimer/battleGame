extends CanvasLayer
class_name BattleHud

signal end_turn_pressed
signal wait_pressed
signal defend_pressed
signal return_pressed

@onready var title_label: Label = $Panel/Margin/Rows/Title
@onready var turn_label: Label = $Panel/Margin/Rows/Turn
@onready var selected_label: Label = $Panel/Margin/Rows/Selected
@onready var terrain_label: Label = $Panel/Margin/Rows/Terrain
@onready var forecast_label: Label = $Panel/Margin/Rows/Forecast
@onready var log_label: RichTextLabel = $Panel/Margin/Rows/Log
@onready var wait_button: Button = $Panel/Margin/Rows/Actions/Wait
@onready var defend_button: Button = $Panel/Margin/Rows/Actions/Defend
@onready var end_turn_button: Button = $Panel/Margin/Rows/EndTurn
@onready var return_button: Button = $Panel/Margin/Rows/Return

var log_lines: Array[String] = []


func _ready() -> void:
	end_turn_button.pressed.connect(func(): end_turn_pressed.emit())
	wait_button.pressed.connect(func(): wait_pressed.emit())
	defend_button.pressed.connect(func(): defend_pressed.emit())
	return_button.pressed.connect(func(): return_pressed.emit())
	return_button.visible = false


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
	turn_label.text = "Бой завершен"
	if winner == -1:
		selected_label.text = "Победитель не определен"
	else:
		selected_label.text = "Победитель: %s" % ("отряд игрока" if winner == 0 else "враги")
	end_turn_button.disabled = true
	wait_button.disabled = true
	defend_button.disabled = true
	return_button.visible = true


func set_player_turn(enabled: bool) -> void:
	end_turn_button.disabled = not enabled
	wait_button.disabled = not enabled
	defend_button.disabled = not enabled


func push_log(text: String) -> void:
	log_lines.append(text)
	while log_lines.size() > 8:
		log_lines.pop_front()
	log_label.text = "\n".join(log_lines)
