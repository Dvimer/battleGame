extends Control

const WORLD_SCENE := "res://scenes/world.tscn"

@onready var title_label: Label = $Root/Panel/Margin/VBox/Title
@onready var subtitle_label: Label = $Root/Panel/Margin/VBox/Subtitle
@onready var continue_button: Button = $Root/Panel/Margin/VBox/ContinueButton
@onready var new_game_button: Button = $Root/Panel/Margin/VBox/NewGameButton
@onready var hint_label: Label = $Root/Panel/Margin/VBox/Hint


func _game_state() -> Node:
	return get_node_or_null("/root/GameState")


func _ready() -> void:
	title_label.text = "Shardfall Arena"
	subtitle_label.text = "Выбери, начать новую партию или продолжить текущую."
	hint_label.text = "Continue загружает текущее сохранение. New Game полностью сбрасывает мир, отряд и рекрутов в казарме."
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	var game_state := _game_state()
	continue_button.disabled = game_state == null or not game_state.has_save()


func _on_continue_pressed() -> void:
	var game_state := _game_state()
	var target_scene := WORLD_SCENE
	if game_state != null:
		game_state.continue_game()
		target_scene = game_state.get_current_scene()
	get_tree().change_scene_to_file(target_scene)


func _on_new_game_pressed() -> void:
	var game_state := _game_state()
	if game_state != null:
		game_state.start_new_game()
	get_tree().change_scene_to_file(WORLD_SCENE)
