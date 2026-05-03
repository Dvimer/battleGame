extends CanvasLayer

signal menu_opened(config: Dictionary)
signal menu_closed
signal menu_state_changed(is_open: bool)

var modal_scene := preload("res://scenes/modal_menu.tscn")
var modal: Control
var current_config: Dictionary = {}
var language_button: Button


func _localizer() -> Node:
	return get_node_or_null("/root/Localizer")


func _ready() -> void:
	layer = 20
	modal = modal_scene.instantiate()
	add_child(modal)
	modal.action_pressed.connect(_on_modal_action_pressed)
	modal.close_requested.connect(_on_modal_close_requested)
	_create_language_button()
	var localizer := _localizer()
	if localizer != null and not localizer.language_changed.is_connected(_on_language_changed):
		localizer.language_changed.connect(_on_language_changed)
	_update_language_button()


func open_menu(config: Dictionary) -> void:
	current_config = config
	modal.show_menu(config)
	menu_opened.emit(config)
	menu_state_changed.emit(true)


func close_menu() -> void:
	if modal == null or not modal.visible:
		return
	modal.hide_menu()
	current_config = {}
	menu_closed.emit()
	menu_state_changed.emit(false)


func is_open() -> bool:
	return modal != null and modal.visible


func _on_modal_action_pressed(action: Dictionary) -> void:
	if action.has("callback"):
		var callback: Callable = action["callback"]
		if callback.is_valid():
			callback.call()
	if bool(action.get("close_on_select", true)):
		close_menu()


func _on_modal_close_requested() -> void:
	if not bool(current_config.get("closable", true)):
		return
	close_menu()


func _create_language_button() -> void:
	language_button = Button.new()
	language_button.custom_minimum_size = Vector2(134, 48)
	language_button.offset_left = 1730.0
	language_button.offset_top = 22.0
	language_button.offset_right = 1864.0
	language_button.offset_bottom = 70.0
	language_button.add_theme_font_size_override("font_size", 20)
	language_button.mouse_filter = Control.MOUSE_FILTER_STOP
	language_button.pressed.connect(_toggle_language)
	add_child(language_button)
	_style_language_button()


func _style_language_button() -> void:
	if language_button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.12, 0.16, 0.88)
	normal.border_color = Color(0.86, 0.79, 0.60, 0.55)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	normal.content_margin_left = 10.0
	normal.content_margin_right = 10.0
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 8.0

	var hover := normal.duplicate()
	hover.bg_color = Color(0.16, 0.18, 0.24, 0.96)

	language_button.add_theme_stylebox_override("normal", normal)
	language_button.add_theme_stylebox_override("hover", hover)
	language_button.add_theme_stylebox_override("pressed", hover)
	language_button.add_theme_stylebox_override("focus", hover)
	language_button.add_theme_color_override("font_color", Color("f5f1e8"))


func _toggle_language() -> void:
	var localizer := _localizer()
	if localizer != null:
		localizer.toggle_language()


func _update_language_button() -> void:
	var localizer := _localizer()
	if localizer == null or language_button == null:
		return
	language_button.text = localizer.t("lang.button")
	language_button.tooltip_text = localizer.t("lang.current")


func _on_language_changed(_language: String) -> void:
	_update_language_button()
