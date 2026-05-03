extends Control

signal action_pressed(action: Dictionary)
signal close_requested

@onready var backdrop: ColorRect = $Backdrop
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/Margin/Content/Header/Title
@onready var close_button: Button = $Panel/Margin/Content/Header/CloseButton
@onready var body_label: RichTextLabel = $Panel/Margin/Content/Body
@onready var actions_container: VBoxContainer = $Panel/Margin/Content/Actions

var close_on_backdrop := true
var current_actions: Array = []


func _localizer() -> Node:
	return get_node_or_null("/root/Localizer")


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.pressed.connect(func() -> void: close_requested.emit())
	_apply_base_style()
	var localizer := _localizer()
	if localizer != null and not localizer.language_changed.is_connected(_on_language_changed):
		localizer.language_changed.connect(_on_language_changed)
	_update_close_caption()


func show_menu(config: Dictionary) -> void:
	visible = true
	close_on_backdrop = bool(config.get("close_on_backdrop", true))
	title_label.text = str(config.get("title", "Menu"))
	body_label.text = str(config.get("body", ""))
	close_button.visible = bool(config.get("closable", true))
	_rebuild_actions(config.get("actions", []))


func hide_menu() -> void:
	visible = false
	_clear_actions()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if close_on_backdrop and not panel.get_global_rect().has_point(event.position):
			close_requested.emit()
			accept_event()
			return

	if event.is_action_pressed("restart") and close_button.visible:
		close_requested.emit()
		accept_event()


func _rebuild_actions(actions: Array) -> void:
	_clear_actions()
	current_actions = actions
	for action in actions:
		var action_data: Dictionary = action
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 92)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 26)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = str(action_data.get("label", "Action"))
		_style_action_button(button, str(action_data.get("variant", "neutral")))
		button.pressed.connect(func() -> void: action_pressed.emit(action_data))
		actions_container.add_child(button)


func _clear_actions() -> void:
	for child in actions_container.get_children():
		child.queue_free()
	current_actions.clear()


func _apply_base_style() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.11, 0.12, 0.15, 0.96)
	panel_style.border_color = Color(0.85, 0.79, 0.60, 0.45)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 18
	panel_style.corner_radius_top_right = 18
	panel_style.corner_radius_bottom_left = 18
	panel_style.corner_radius_bottom_right = 18
	panel.add_theme_stylebox_override("panel", panel_style)

	title_label.add_theme_color_override("font_color", Color("f8f2dc"))
	body_label.add_theme_color_override("default_color", Color("f0eee6"))
	_style_action_button(close_button, "danger")


func _update_close_caption() -> void:
	var localizer := _localizer()
	close_button.text = "X"
	if localizer != null:
		close_button.tooltip_text = localizer.t("common.close_hint")


func _on_language_changed(_language: String) -> void:
	_update_close_caption()


func _style_action_button(button: Button, variant: String) -> void:
	var accent := _variant_color(variant)
	button.add_theme_color_override("font_color", Color("f7fbff"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)

	var normal := StyleBoxFlat.new()
	normal.bg_color = accent.darkened(0.38)
	normal.border_color = accent.lightened(0.16)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_left = 12
	normal.corner_radius_bottom_right = 12
	normal.content_margin_left = 18.0
	normal.content_margin_right = 18.0
	normal.content_margin_top = 14.0
	normal.content_margin_bottom = 14.0

	var hover := normal.duplicate()
	hover.bg_color = accent.darkened(0.18)
	hover.border_color = accent.lightened(0.32)

	var pressed := normal.duplicate()
	pressed.bg_color = accent.darkened(0.08)
	pressed.border_color = accent.lightened(0.42)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)


func _variant_color(variant: String) -> Color:
	match variant:
		"danger":
			return Color("9b4a4a")
		"success":
			return Color("4c8b63")
		"warning":
			return Color("b7863d")
		"damage":
			return Color("d66a4f")
		"tempo":
			return Color("d5a443")
		"range":
			return Color("5c9ecf")
		"sustain":
			return Color("c34d74")
		"vitality":
			return Color("5aa06f")
		"mobility":
			return Color("7b68cf")
		_:
			return Color("4f6d7a")
