extends CanvasLayer

signal open_state_changed(is_open: bool)

const ItemDataScript = preload("res://scripts/items/data/item_data.gd")

const SLOT_ORDER := [
	ItemDataScript.Slot.HEAD,
	ItemDataScript.Slot.BODY,
	ItemDataScript.Slot.MAIN_HAND,
	ItemDataScript.Slot.OFF_HAND,
	ItemDataScript.Slot.BELT_1,
	ItemDataScript.Slot.BELT_2,
	ItemDataScript.Slot.BELT_3,
	ItemDataScript.Slot.BELT_4
]

const SLOT_NAMES := {
	ItemDataScript.Slot.HEAD: "Head",
	ItemDataScript.Slot.BODY: "Body",
	ItemDataScript.Slot.MAIN_HAND: "Main Hand",
	ItemDataScript.Slot.OFF_HAND: "Off Hand",
	ItemDataScript.Slot.BELT_1: "Belt 1",
	ItemDataScript.Slot.BELT_2: "Belt 2",
	ItemDataScript.Slot.BELT_3: "Belt 3",
	ItemDataScript.Slot.BELT_4: "Belt 4"
}

@onready var root_panel: Panel = $RootPanel
@onready var body_panel: Panel = $RootPanel/Frame/BodyPanel
@onready var title_label: Label = $RootPanel/Frame/BodyPanel/Header/TitleLabel
@onready var close_button: Button = $RootPanel/Frame/BodyPanel/Header/CloseButton
@onready var resource_label: Label = $RootPanel/Frame/BodyPanel/TopBar/ResourceLabel
@onready var help_label: Label = $RootPanel/Frame/BodyPanel/TopBar/HelpLabel
@onready var inventory_title_label: Label = $RootPanel/Frame/BodyPanel/Content/InventoryColumn/InventoryTitle
@onready var roster_title_label: Label = $RootPanel/Frame/BodyPanel/Content/RosterColumn/RosterTitle
@onready var inventory_list: ItemList = $RootPanel/Frame/BodyPanel/Content/InventoryColumn/InventoryList
@onready var unit_list: ItemList = $RootPanel/Frame/BodyPanel/Content/RosterColumn/UnitList
@onready var unit_label: Label = $RootPanel/Frame/BodyPanel/Content/RosterColumn/UnitLabel
@onready var slot_grid: GridContainer = $RootPanel/Frame/BodyPanel/Content/RosterColumn/SlotGrid
@onready var status_label: Label = $RootPanel/Frame/BodyPanel/Footer/StatusLabel

var slot_buttons := {}
var roster_unit_ids: Array[String] = []
var inventory_instance_ids: Array[String] = []
var selected_unit_id := ""
var selected_item_instance_id := ""


func _ready() -> void:
	layer = 25
	visible = false
	close_button.pressed.connect(close_inventory)
	inventory_list.item_selected.connect(_on_inventory_item_selected)
	unit_list.item_selected.connect(_on_unit_selected)
	root_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_panels()
	_build_slot_grid()
	_apply_texts()
	var roster_manager := _roster_manager()
	if roster_manager != null and not roster_manager.roster_changed.is_connected(_on_roster_changed):
		roster_manager.roster_changed.connect(_on_roster_changed)
	var inventory := _inventory()
	if inventory != null and not inventory.inventory_changed.is_connected(_on_inventory_changed):
		inventory.inventory_changed.connect(_on_inventory_changed)
	var localizer := _localizer()
	if localizer != null and not localizer.language_changed.is_connected(_on_language_changed):
		localizer.language_changed.connect(_on_language_changed)


func open_inventory() -> void:
	var roster_manager := _roster_manager()
	if roster_manager != null:
		roster_manager.ensure_initialized()
	visible = true
	selected_item_instance_id = ""
	status_label.text = ""
	_apply_texts()
	_refresh_all()
	open_state_changed.emit(true)


func close_inventory() -> void:
	if not visible:
		return
	visible = false
	selected_item_instance_id = ""
	status_label.text = ""
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		game_state.save_game()
	open_state_changed.emit(false)


func toggle_inventory() -> void:
	if visible:
		close_inventory()
	else:
		open_inventory()


func is_open() -> bool:
	return visible


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_inventory()


func _build_slot_grid() -> void:
	for child in slot_grid.get_children():
		child.queue_free()
	slot_buttons.clear()
	for slot_id in SLOT_ORDER:
		var button := Button.new()
		button.custom_minimum_size = Vector2(180, 54)
		button.text = _slot_name(slot_id)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_on_slot_pressed.bind(slot_id))
		slot_grid.add_child(button)
		slot_buttons[slot_id] = button


func _style_panels() -> void:
	var shell := StyleBoxFlat.new()
	shell.bg_color = Color(0.08, 0.09, 0.10, 0.96)
	shell.border_color = Color(0.72, 0.68, 0.55, 0.35)
	shell.border_width_left = 2
	shell.border_width_top = 2
	shell.border_width_right = 2
	shell.border_width_bottom = 2
	shell.corner_radius_top_left = 16
	shell.corner_radius_top_right = 16
	shell.corner_radius_bottom_left = 16
	shell.corner_radius_bottom_right = 16
	body_panel.add_theme_stylebox_override("panel", shell)

	var root_style := StyleBoxEmpty.new()
	root_panel.add_theme_stylebox_override("panel", root_style)


func _refresh_all() -> void:
	_refresh_roster_list()
	_refresh_inventory_list()
	_refresh_summary()
	_refresh_unit_panel()


func _refresh_roster_list() -> void:
	roster_unit_ids.clear()
	unit_list.clear()
	var roster_manager := _roster_manager()
	if roster_manager == null:
		return
	for unit in roster_manager.roster_units:
		roster_unit_ids.append(unit.id)
		var item_text := _t("inventory.unit.level", {"name": unit.display_name, "level": unit.level})
		if unit.is_dead():
			item_text += " [МЁРТВ]"
		else:
			item_text += " | HP %d/%d" % [unit.current_hp, unit.get_max_hp()]
		unit_list.add_item(item_text)
	if selected_unit_id == "" and not roster_unit_ids.is_empty():
		selected_unit_id = roster_unit_ids[0]
	var selected_index := roster_unit_ids.find(selected_unit_id)
	if selected_index != -1:
		unit_list.select(selected_index)


func _refresh_inventory_list() -> void:
	inventory_instance_ids.clear()
	inventory_list.clear()
	var inventory := _inventory()
	if inventory == null:
		return
	for item in inventory.items:
		inventory_instance_ids.append(item.instance_id)
		inventory_list.add_item(_format_item(item))
	var selected_index := inventory_instance_ids.find(selected_item_instance_id)
	if selected_index != -1:
		inventory_list.select(selected_index)


func _refresh_summary() -> void:
	var inventory := _inventory()
	if inventory == null:
		resource_label.text = _t("inventory.resources.missing")
		return
	resource_label.text = _t("inventory.resources", {
		"current": inventory.current_weight(),
		"capacity": inventory.capacity,
		"currency": inventory.currency,
		"tools": inventory.tools,
		"medicine": inventory.medicine,
		"supplies": inventory.supplies
	})


func _refresh_unit_panel() -> void:
	var unit: Variant = _selected_unit()
	if unit == null:
		unit_label.text = _t("inventory.unit.none")
		for button in slot_buttons.values():
			button.disabled = true
			button.text = _t("inventory.slot.unavailable")
		return
	var status_text := "Мёртв" if unit.is_dead() else "В строю"
	unit_label.text = "%s\nКласс: %s\nСтатус: %s\nHP: %d/%d\nВес: %d/%d\nРаны: %d" % [
		unit.display_name,
		unit.base_unit_data.display_name if unit.base_unit_data != null else _t("inventory.unit.unknown_class"),
		status_text,
		unit.current_hp,
		unit.get_max_hp(),
		unit.compute_total_weight(),
		unit.base_unit_data.carry_capacity if unit.base_unit_data != null else 0,
		unit.persistent_wounds.size()
	]
	for slot_id in SLOT_ORDER:
		var button: Button = slot_buttons[slot_id]
		var enabled: bool = _slot_available_for_unit(unit, slot_id) and not unit.is_dead()
		button.disabled = not enabled
		if not enabled:
			button.text = "%s\n%s" % [_slot_name(slot_id), ("Юнит мёртв" if unit.is_dead() else _t("inventory.slot.unavailable"))]
			continue
		var item = _item_in_slot(unit, slot_id)
		if item == null:
			button.text = "%s\n%s" % [_slot_name(slot_id), _t("inventory.slot.empty")]
		else:
			button.text = "%s\n%s" % [_slot_name(slot_id), _format_item(item)]


func _selected_unit():
	var roster_manager := _roster_manager()
	if roster_manager == null:
		return null
	return roster_manager.find_unit(selected_unit_id)


func _inventory() -> Node:
	return get_node_or_null("/root/RosterInventory")


func _roster_manager() -> Node:
	return get_node_or_null("/root/RosterManager")


func _on_unit_selected(index: int) -> void:
	if index < 0 or index >= roster_unit_ids.size():
		return
	selected_unit_id = roster_unit_ids[index]
	selected_item_instance_id = ""
	status_label.text = ""
	_refresh_inventory_list()
	_refresh_unit_panel()


func _on_inventory_item_selected(index: int) -> void:
	if index < 0 or index >= inventory_instance_ids.size():
		return
	selected_item_instance_id = inventory_instance_ids[index]
	status_label.text = _t("inventory.status.selected", {"value": inventory_list.get_item_text(index)})


func _on_slot_pressed(slot_id: int) -> void:
	var unit = _selected_unit()
	var inventory := _inventory()
	if unit == null or inventory == null:
		return

	if selected_item_instance_id != "":
		var item = inventory.find_by_instance_id(selected_item_instance_id)
		if item == null:
			selected_item_instance_id = ""
			_refresh_inventory_list()
			return
		if not _can_place_item(unit, item, slot_id):
			status_label.text = _t("inventory.status.cannot_place", {"value": _slot_name(slot_id)})
			return
		inventory.remove(item)
		var displaced = _assign_item_to_slot(unit, slot_id, item)
		if displaced == item:
			inventory.add(item)
			status_label.text = _t("inventory.status.equip_failed", {"value": item.get_display_name()})
			return
		if displaced != null:
			inventory.add(displaced)
		selected_item_instance_id = ""
		status_label.text = _t("inventory.status.equipped", {"value": item.get_display_name()})
		_refresh_all()
		return

	var removed = _remove_item_from_slot(unit, slot_id)
	if removed != null:
		inventory.add(removed)
		status_label.text = _t("inventory.status.moved_back", {"value": removed.get_display_name()})
		_refresh_all()


func _assign_item_to_slot(unit, slot_id: int, item):
	if _is_belt_slot(slot_id):
		var index: int = slot_id - ItemDataScript.Slot.BELT_1
		return unit.assign_quick_slot(index, item)
	return unit.equip(slot_id, item)


func _remove_item_from_slot(unit, slot_id: int):
	if _is_belt_slot(slot_id):
		var index: int = slot_id - ItemDataScript.Slot.BELT_1
		if index < 0 or index >= unit.quick_slots.size():
			return null
		return unit.assign_quick_slot(index, null)
	return unit.unequip(slot_id)


func _can_place_item(unit, item, slot_id: int) -> bool:
	if unit == null or item == null or item.data == null:
		return false
	if not _slot_available_for_unit(unit, slot_id):
		return false
	if not item.data.equip_slots.is_empty() and not item.data.equip_slots.has(slot_id):
		return false
	return true


func _slot_available_for_unit(unit, slot_id: int) -> bool:
	if unit == null or unit.base_unit_data == null:
		return false
	if _is_belt_slot(slot_id):
		var index: int = slot_id - ItemDataScript.Slot.BELT_1
		return index >= 0 and index < unit.get_quick_slot_count()
	return unit.base_unit_data.allowed_slots.is_empty() or unit.base_unit_data.allowed_slots.has(slot_id)


func _item_in_slot(unit, slot_id: int):
	if unit == null:
		return null
	if _is_belt_slot(slot_id):
		var index: int = slot_id - ItemDataScript.Slot.BELT_1
		if index < 0 or index >= unit.quick_slots.size():
			return null
		return unit.quick_slots[index]
	return unit.equipped.get(slot_id)


func _is_belt_slot(slot_id: int) -> bool:
	return slot_id >= ItemDataScript.Slot.BELT_1 and slot_id <= ItemDataScript.Slot.BELT_4


func _format_item(item) -> String:
	if item == null:
		return _t("inventory.item.empty")
	var parts: Array[String] = [item.get_display_name()]
	if item.max_durability > 0:
		parts.append(_t("inventory.item.durability", {"current": item.durability, "max": item.max_durability}))
	if item.charges >= 0:
		parts.append(_t("inventory.item.charges", {"value": item.charges}))
	return " | ".join(parts)


func _on_roster_changed() -> void:
	if visible:
		_refresh_all()


func _on_inventory_changed() -> void:
	if visible:
		_refresh_all()


func _apply_texts() -> void:
	title_label.text = _t("inventory.title")
	close_button.text = _t("inventory.close")
	inventory_title_label.text = _t("inventory.section.shared")
	roster_title_label.text = _t("inventory.section.roster")
	help_label.text = _t("inventory.help")


func _slot_name(slot_id: int) -> String:
	match slot_id:
		ItemDataScript.Slot.HEAD:
			return _t("inventory.slot.head")
		ItemDataScript.Slot.BODY:
			return _t("inventory.slot.body")
		ItemDataScript.Slot.MAIN_HAND:
			return _t("inventory.slot.main_hand")
		ItemDataScript.Slot.OFF_HAND:
			return _t("inventory.slot.off_hand")
		ItemDataScript.Slot.BELT_1:
			return _t("inventory.slot.belt_1")
		ItemDataScript.Slot.BELT_2:
			return _t("inventory.slot.belt_2")
		ItemDataScript.Slot.BELT_3:
			return _t("inventory.slot.belt_3")
		ItemDataScript.Slot.BELT_4:
			return _t("inventory.slot.belt_4")
		_:
			return SLOT_NAMES.get(slot_id, str(slot_id))


func _localizer() -> Node:
	return get_node_or_null("/root/Localizer")


func _t(key: String, params := {}) -> String:
	var localizer := _localizer()
	if localizer != null:
		return localizer.t(key, params)
	return key


func _on_language_changed(_language: String) -> void:
	_apply_texts()
	if visible:
		_refresh_all()
