extends Node2D

const HUB_SIZE := Vector2(1920.0, 1080.0)
const CHEST_POS := Vector2(280.0, 430.0)
const TRADER_POS := Vector2(1360.0, 450.0)
const WORKSHOP_POS := Vector2(620.0, 280.0)
const HOUSE_POS := Vector2(1180.0, 220.0)
const BARRACKS_POS := Vector2(360.0, 220.0)
const CITY_GATE_POS := Vector2(960.0, 150.0)
const PATROL_POS := Vector2(1600.0, 210.0)
const INTERACT_RADIUS := 90.0
const INVENTORY_SCENE := preload("res://scenes/inventory/inventory.tscn")

@onready var player := $Player
@onready var camera: Camera2D = $Camera2D
@onready var bank_label: Label = $HUD/BankLabel
@onready var chest_label: Label = $HUD/ChestLabel
@onready var town_label: Label = $HUD/TownLabel
@onready var center_banner: Label = $HUD/CenterBanner
@onready var prompt_label: Label = $HUD/PromptLabel
@onready var hint_label: Label = $HUD/HintLabel
@onready var inventory_button: Button = $HUD/InventoryButton

var nearest_hotspot := ""
var banner_timer := 0.0
var current_banner_key := ""
var current_banner_params := {}
var inventory_ui


func _world_state() -> Node:
	return get_node_or_null("/root/WorldState")


func _menu_manager() -> Node:
	return get_node_or_null("/root/MenuManager")


func _localizer() -> Node:
	return get_node_or_null("/root/Localizer")


func _scene_router() -> Node:
	return get_node_or_null("/root/SceneRouter")


func _ready() -> void:
	var world_state := _world_state()
	var menu_manager := _menu_manager()

	player.arena_size = HUB_SIZE
	player.allow_attack = false
	player.allow_dash = false
	player.allow_click_move = true
	player.set_movement_locked(false)
	var scene_router := _scene_router()
	if scene_router != null:
		scene_router.apply_spawn(player, player.global_position)
	camera.position = player.global_position
	inventory_ui = INVENTORY_SCENE.instantiate()
	add_child(inventory_ui)
	inventory_ui.open_state_changed.connect(_on_inventory_state_changed)
	inventory_button.pressed.connect(func():
		var active_menu_manager := _menu_manager()
		if active_menu_manager != null and active_menu_manager.is_open():
			active_menu_manager.close_menu()
		if inventory_ui != null:
			inventory_ui.toggle_inventory()
	)

	if menu_manager != null and not menu_manager.menu_state_changed.is_connected(_on_menu_state_changed):
		menu_manager.menu_state_changed.connect(_on_menu_state_changed)
	var localizer := _localizer()
	if localizer != null and not localizer.language_changed.is_connected(_on_language_changed):
		localizer.language_changed.connect(_on_language_changed)

	_refresh_labels()
	if world_state != null:
		var town_message: String = world_state.consume_town_message()
		if town_message != "":
			center_banner.text = town_message
			banner_timer = 2.2


func _physics_process(delta: float) -> void:
	camera.position = player.global_position
	banner_timer = maxf(banner_timer - delta, 0.0)
	if banner_timer <= 0.0:
		center_banner.text = ""

	var menu_manager := _menu_manager()
	var menu_open: bool = menu_manager != null and menu_manager.is_open()
	if Input.is_action_just_pressed("inventory"):
		if menu_open and menu_manager != null:
			menu_manager.close_menu()
		inventory_ui.toggle_inventory()
		queue_redraw()
		return
	if inventory_ui != null and inventory_ui.is_open():
		prompt_label.text = "Inventory open. Press I or Esc to close it."
		queue_redraw()
		return
	nearest_hotspot = _find_nearest_hotspot()
	var localizer := _localizer()

	if menu_open:
		prompt_label.text = localizer.t("common.close_hint") if localizer != null else "Menu open. Click an option or press R to close it."
		queue_redraw()
		return

	if nearest_hotspot == "":
		prompt_label.text = localizer.t("base.prompt.walk") if localizer != null else "Walk through town. Chest, trader, workshop, barracks, house, and city gate are all active."
	else:
		var hotspot_name := _hotspot_name(nearest_hotspot)
		prompt_label.text = localizer.t("base.prompt.near", {"value": hotspot_name}) if localizer != null else "Press E or left click near %s." % hotspot_name

	if (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("attack")) and nearest_hotspot != "":
		_open_hotspot(nearest_hotspot)

	queue_redraw()


func _find_nearest_hotspot() -> String:
	var hotspots: Dictionary = {
		"chest": CHEST_POS,
		"trader": TRADER_POS,
		"workshop": WORKSHOP_POS,
		"gate": CITY_GATE_POS,
		"patrol": PATROL_POS
	}
	var best := ""
	var best_distance := INF
	for hotspot_id in hotspots.keys():
		var distance: float = player.global_position.distance_to(hotspots[hotspot_id])
		if distance < INTERACT_RADIUS and distance < best_distance:
			best = hotspot_id
			best_distance = distance
	return best


func _hotspot_name(hotspot_id: String) -> String:
	var localizer := _localizer()
	match hotspot_id:
		"chest":
			return localizer.t("base.hotspot.chest") if localizer != null else "the stash chest"
		"trader":
			return localizer.t("base.hotspot.trader") if localizer != null else "the trader stall"
		"workshop":
			return localizer.t("base.hotspot.workshop") if localizer != null else "the workshop board"
		"house":
			return localizer.t("base.hotspot.house") if localizer != null else "the house door"
		"gate":
			return localizer.t("base.hotspot.gate") if localizer != null else "the city gate"
		"patrol":
			return "разбойничий дозор"
		_:
			return "marker"


func _open_hotspot(hotspot_id: String) -> void:
	match hotspot_id:
		"chest":
			_open_chest_menu()
		"trader":
			_open_trader_menu()
		"workshop":
			_open_workshop_menu()
		"gate":
			_open_gate_menu()
		"patrol":
			_start_patrol_battle()


func _open_menu(title: String, body: String, actions: Array, closable := true) -> void:
	var menu_manager := _menu_manager()
	if menu_manager == null:
		return

	menu_manager.open_menu({
		"title": title,
		"body": body,
		"actions": actions,
		"closable": closable,
		"close_on_backdrop": closable
	})


func _open_chest_menu() -> void:
	var world_state := _world_state()
	var localizer := _localizer()
	if world_state == null:
		return

	var body := ""
	var actions: Array = []
	if world_state.pending_chest_essence > 0:
		body = localizer.t("base.menu.chest.body_full", {"value": world_state.pending_chest_essence}) if localizer != null else "[b]City returns[/b]\nThe crate hums with %d essence waiting to be banked." % world_state.pending_chest_essence
		actions.append({
			"label": localizer.t("base.menu.chest.collect", {"value": world_state.pending_chest_essence}) if localizer != null else "Collect %d essence" % world_state.pending_chest_essence,
			"variant": "success",
			"callback": Callable(self, "_collect_chest")
		})
	else:
		body = localizer.t("base.menu.chest.empty") if localizer != null else "The chest is empty. Clear the city waves to send new rewards home."
		actions.append({
			"label": localizer.t("base.menu.chest.empty_action") if localizer != null else "Nothing to collect right now",
			"variant": "neutral"
		})

	_open_menu(localizer.t("base.menu.chest.title") if localizer != null else "Stash Chest", body, actions)


func _open_trader_menu() -> void:
	var localizer := _localizer()
	_open_menu(
		localizer.t("base.menu.trader.title") if localizer != null else "Broker Neral",
		localizer.t("base.menu.trader.body") if localizer != null else "[b]Prepared supplies[/b]\nSpend stored essence to tune the next city run.",
		[
			{
				"label": localizer.t("base.menu.trader.attack") if localizer != null else "Sharpening Oil (6)\n+1 attack for the next city run",
				"variant": "damage",
				"callback": Callable(self, "_buy_attack_tonic")
			},
			{
				"label": localizer.t("base.menu.trader.hp") if localizer != null else "Ration Pack (5)\n+1 max HP for the next city run",
				"variant": "vitality",
				"callback": Callable(self, "_buy_ration_pack")
			},
			{
				"label": localizer.t("base.menu.trader.dash") if localizer != null else "Trail Boots (5)\nFaster dash and better escape timing",
				"variant": "mobility",
				"callback": Callable(self, "_buy_dash_boots")
			}
		]
	)


func _open_workshop_menu() -> void:
	var world_state := _world_state()
	var localizer := _localizer()
	if world_state == null:
		return

	var actions: Array = []
	if not world_state.forge_built:
		actions.append({
			"label": localizer.t("base.menu.workshop.build_forge", {"value": world_state.FORGE_COST}) if localizer != null else "Build Forge Beacon (%d)\nBigger expedition payout and a stronger start" % world_state.FORGE_COST,
			"variant": "warning",
			"callback": Callable(self, "_build_forge")
		})
	if not world_state.garden_built:
		actions.append({
			"label": localizer.t("base.menu.workshop.build_garden", {"value": world_state.GARDEN_COST}) if localizer != null else "Plant Herb Garden (%d)\nAdds a small blessing to future runs" % world_state.GARDEN_COST,
			"variant": "success",
			"callback": Callable(self, "_build_garden")
		})
	if actions.is_empty():
		actions.append({
			"label": localizer.t("base.menu.workshop.complete") if localizer != null else "Workshop complete\nBoth town projects are already active",
			"variant": "neutral"
		})

	var forge_text: String = localizer.t("base.menu.workshop.built") if world_state.forge_built and localizer != null else (localizer.t("base.menu.workshop.missing") if localizer != null else ("Built" if world_state.forge_built else "Missing"))
	var garden_text: String = localizer.t("base.menu.workshop.built") if world_state.garden_built and localizer != null else (localizer.t("base.menu.workshop.missing") if localizer != null else ("Built" if world_state.garden_built else "Missing"))
	var body: String = localizer.t("base.menu.workshop.body", {"forge": forge_text, "garden": garden_text}) if localizer != null else "[b]Town workshop[/b]\nForge: %s\nGarden: %s\n\nThe forge improves expedition payouts. The garden adds a small blessing to each run." % [forge_text, garden_text]
	_open_menu(localizer.t("base.menu.workshop.title") if localizer != null else "Workshop Board", body, actions)


func _open_gate_menu() -> void:
	var world_state := _world_state()
	var localizer := _localizer()
	if world_state == null:
		return

	var bonus: String = world_state.describe_next_run_bonus()
	var bonus_line: String = localizer.t("base.menu.gate.bonus_some", {"value": bonus}) if bonus != "" and localizer != null else (localizer.t("base.menu.gate.bonus_none") if localizer != null else "No queued town bonuses yet.")
	var game_state := get_node_or_null("/root/GameState")
	var map_line: String = localizer.t("base.menu.gate.map_resume") if game_state != null and game_state.get_discovered_settlement_count() > 0 and localizer != null else (localizer.t("base.menu.gate.map_fresh") if localizer != null else "The world road waits beyond the gate.")
	var body: String = localizer.t("base.menu.gate.body", {"bonus_line": "%s\n%s" % [bonus_line, map_line]}) if localizer != null else "[b]City Expedition[/b]\nPush through five waves, secure the district reward, then the recall sigil pulls you back home.\n%s\n%s" % [bonus_line, map_line]

	_open_menu(
		localizer.t("base.menu.gate.title") if localizer != null else "City Gate",
		body,
		[
			{
				"label": localizer.t("base.menu.gate.depart") if localizer != null else "Depart for the city\nStart a five-wave run and send any reward back to the chest",
				"variant": "mobility",
				"callback": Callable(self, "_start_city_run")
			},
			{
				"label": localizer.t("base.menu.gate.map") if localizer != null else "Open world map\nTravel through the generated overworld and return via the capital",
				"variant": "warning",
				"callback": Callable(self, "_open_world_map")
			},
			{
				"label": localizer.t("base.menu.gate.stay") if localizer != null else "Stay in town\nKeep preparing before you head out",
				"variant": "neutral"
			}
		]
	)


func _collect_chest() -> void:
	var world_state := _world_state()
	var localizer := _localizer()
	if world_state == null:
		return
	var collected: int = world_state.collect_chest()
	if localizer != null:
		_show_banner_key("base.banner.banked", {"value": collected}, 1.5)
	else:
		center_banner.text = "+%d essence banked" % collected
		banner_timer = 1.5
	_refresh_labels()


func _buy_attack_tonic() -> void:
	var world_state := _world_state()
	var localizer := _localizer()
	if world_state == null:
		return
	if world_state.buy_attack_tonic():
		_show_banner_key("base.banner.attack_packed", {}, 1.4)
	else:
		_show_banner_key("common.not_enough_essence", {}, 1.2) if localizer != null else _show_banner("Not enough essence", 1.2)
	_refresh_labels()


func _buy_ration_pack() -> void:
	var world_state := _world_state()
	var localizer := _localizer()
	if world_state == null:
		return
	if world_state.buy_ration_pack():
		_show_banner_key("base.banner.rations_packed", {}, 1.4)
	else:
		_show_banner_key("common.not_enough_essence", {}, 1.2) if localizer != null else _show_banner("Not enough essence", 1.2)
	_refresh_labels()


func _buy_dash_boots() -> void:
	var world_state := _world_state()
	var localizer := _localizer()
	if world_state == null:
		return
	if world_state.buy_dash_boots():
		_show_banner_key("base.banner.boots_ready", {}, 1.4)
	else:
		_show_banner_key("common.not_enough_essence", {}, 1.2) if localizer != null else _show_banner("Not enough essence", 1.2)
	_refresh_labels()


func _build_forge() -> void:
	var world_state := _world_state()
	var localizer := _localizer()
	if world_state == null:
		return
	if world_state.build_forge():
		_show_banner_key("base.banner.forge_built", {}, 1.6)
	else:
		_show_banner_key("common.need_more_essence", {}, 1.2) if localizer != null else _show_banner("Need more essence", 1.2)
	_refresh_labels()


func _build_garden() -> void:
	var world_state := _world_state()
	var localizer := _localizer()
	if world_state == null:
		return
	if world_state.build_garden():
		_show_banner_key("base.banner.garden_built", {}, 1.6)
	else:
		_show_banner_key("common.need_more_essence", {}, 1.2) if localizer != null else _show_banner("Need more essence", 1.2)
	_refresh_labels()


func _start_city_run() -> void:
	var scene_router := _scene_router()
	if scene_router != null:
		scene_router.go_to_scene("res://scenes/city_run.tscn", "city_entry")
	else:
		get_tree().change_scene_to_file("res://scenes/city_run.tscn")


func _start_patrol_battle() -> void:
	var roster_manager := get_node_or_null("/root/RosterManager")
	if roster_manager == null or roster_manager.get_selected_party().is_empty():
		_show_banner("В отряде нет живых бойцов для боя.", 1.6)
		return
	var context := BattleMockFactory.create_context_from_roster(roster_manager)
	var battle_context := get_node_or_null("/root/BattleContext")
	if battle_context != null:
		battle_context.setup(
			context["battlefield"],
			context["attacker"],
			context["defender"],
			context.get("environment", {}),
			"res://scenes/main.tscn",
			"hub_default"
		)
	var scene_router := _scene_router()
	if scene_router != null:
		scene_router.go_to_scene("res://scenes/battle/battle.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")


func _open_world_map() -> void:
	var scene_router := _scene_router()
	if scene_router != null:
		scene_router.go_to_scene("res://scenes/world.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/world.tscn")


func _on_menu_state_changed(is_open: bool) -> void:
	player.set_movement_locked(is_open or (inventory_ui != null and inventory_ui.is_open()))
	if not is_open:
		_refresh_labels()


func _on_inventory_state_changed(is_open: bool) -> void:
	var menu_manager := _menu_manager()
	var menu_open: bool = menu_manager != null and menu_manager.is_open()
	player.set_movement_locked(is_open or menu_open)
	if not is_open:
		_refresh_labels()


func _refresh_labels() -> void:
	var world_state := _world_state()
	var localizer := _localizer()
	if world_state == null:
		bank_label.text = "?"
		chest_label.text = "?"
		town_label.text = "World state unavailable"
		return

	bank_label.text = localizer.t("base.bank_essence", {"value": world_state.bank_essence}) if localizer != null else "Bank Essence: %d" % world_state.bank_essence
	chest_label.text = localizer.t("base.chest_ready", {"value": world_state.pending_chest_essence}) if localizer != null else "Chest: %d ready to collect" % world_state.pending_chest_essence
	var status_parts: Array[String] = []
	status_parts.append(localizer.t("base.forge_online") if world_state.forge_built and localizer != null else (localizer.t("base.forge_offline") if localizer != null else "Forge offline"))
	status_parts.append(localizer.t("base.garden_grown") if world_state.garden_built and localizer != null else (localizer.t("base.garden_empty") if localizer != null else "Garden empty"))
	var queued: String = world_state.describe_next_run_bonus()
	if queued != "":
		status_parts.append(localizer.t("base.queued", {"value": queued}) if localizer != null else "Queued: %s" % queued)
	town_label.text = " | ".join(status_parts)
	hint_label.text = localizer.t("base.hint") if localizer != null else "The town is peaceful. Visit the city gate when you are ready for a five-wave run."


func _show_banner(text: String, duration: float) -> void:
	center_banner.text = text
	banner_timer = duration
	_refresh_labels()


func _show_banner_key(key: String, params: Dictionary, duration: float) -> void:
	current_banner_key = key
	current_banner_params = params.duplicate()
	var localizer := _localizer()
	center_banner.text = localizer.t(key, params) if localizer != null else key
	banner_timer = duration
	_refresh_labels()


func _on_language_changed(_language: String) -> void:
	_refresh_labels()
	if banner_timer > 0.0 and current_banner_key != "":
		var localizer := _localizer()
		if localizer != null:
			center_banner.text = localizer.t(current_banner_key, current_banner_params)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if inventory_ui != null and inventory_ui.is_open():
		return
	var menu_manager := _menu_manager()
	if menu_manager != null and menu_manager.is_open():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _find_nearest_hotspot() != "":
			return
		player.set_move_target(_screen_to_world(event.position))
		get_viewport().set_input_as_handled()


func _screen_to_world(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, HUB_SIZE), Color("d8cfad"))
	draw_rect(Rect2(Vector2(0.0, 575.0), Vector2(HUB_SIZE.x, 505.0)), Color("8fb47b"))
	draw_rect(Rect2(Vector2(690.0, 120.0), Vector2(540.0, 150.0)), Color("8db6d9"))

	_draw_house(Vector2(1050.0, 150.0), Vector2(270.0, 200.0), Color("c98c5d"))
	_draw_house(Vector2(240.0, 150.0), Vector2(240.0, 190.0), Color("b9855b"))
	_draw_house(Vector2(120.0, 360.0), Vector2(230.0, 150.0), Color("b98466"))
	_draw_house(Vector2(1240.0, 370.0), Vector2(280.0, 160.0), Color("cda274"))
	_draw_workshop()
	_draw_gate()
	_draw_patrol()
	_draw_marker(CHEST_POS, Color("e0c341"))
	_draw_marker(TRADER_POS, Color("6ac3ff"))
	_draw_marker(HOUSE_POS, Color("f08a5d"))
	_draw_marker(BARRACKS_POS, Color("d98842"))
	_draw_marker(WORKSHOP_POS, Color("8fce72"))
	_draw_marker(CITY_GATE_POS, Color("b18cff"))
	_draw_marker(PATROL_POS, Color("d24f4f"))
	var localizer := _localizer()
	_draw_world_label(CHEST_POS + Vector2(-28.0, -30.0), localizer.t("base.world_label.chest") if localizer != null else "Chest", Color("e0c341"))
	_draw_world_label(TRADER_POS + Vector2(-30.0, -30.0), localizer.t("base.world_label.trader") if localizer != null else "Trader", Color("6ac3ff"))
	_draw_world_label(WORKSHOP_POS + Vector2(-62.0, -38.0), localizer.t("base.world_label.workshop") if localizer != null else "Workshop", Color("8fce72"))
	_draw_world_label(HOUSE_POS + Vector2(-28.0, -38.0), localizer.t("base.world_label.house") if localizer != null else "House", Color("f08a5d"))
	_draw_world_label(BARRACKS_POS + Vector2(-38.0, -38.0), "Казарма", Color("d98842"))
	_draw_world_label(CITY_GATE_POS + Vector2(-44.0, -90.0), localizer.t("base.world_label.gate") if localizer != null else "City Gate", Color("b18cff"))
	_draw_world_label(PATROL_POS + Vector2(-72.0, -38.0), "Дозор", Color("d24f4f"))


func _draw_house(pos: Vector2, size: Vector2, wall: Color) -> void:
	draw_rect(Rect2(pos, size), wall)
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-16.0, 0.0),
		pos + Vector2(size.x + 16.0, 0.0),
		pos + Vector2(size.x * 0.5, -66.0)
	]), Color("6f4d38"))
	draw_rect(Rect2(pos + Vector2(size.x * 0.42, size.y * 0.52), Vector2(38.0, size.y * 0.48)), Color("553622"))
	draw_rect(Rect2(pos + Vector2(30.0, 40.0), Vector2(42.0, 32.0)), Color("dbefff"))


func _draw_workshop() -> void:
	draw_rect(Rect2(Vector2(500.0, 230.0), Vector2(220.0, 150.0)), Color("8e7764"))
	draw_rect(Rect2(Vector2(520.0, 256.0), Vector2(56.0, 74.0)), Color("5f4636"))
	draw_line(Vector2(618.0, 230.0), Vector2(618.0, 140.0), Color("4e3a2f"), 7.0)
	draw_rect(Rect2(Vector2(580.0, 140.0), Vector2(76.0, 36.0)), Color("f2efe2"))


func _draw_gate() -> void:
	draw_arc(CITY_GATE_POS, 76.0, PI, TAU, 28, Color("6f5aa5"), 12.0)
	draw_arc(CITY_GATE_POS, 48.0, PI, TAU, 28, Color("d7c9ff"), 8.0)


func _draw_patrol() -> void:
	draw_circle(PATROL_POS + Vector2(-22.0, 10.0), 16.0, Color("8f2b2b"))
	draw_circle(PATROL_POS + Vector2(0.0, -8.0), 18.0, Color("b53a3a"))
	draw_circle(PATROL_POS + Vector2(22.0, 8.0), 16.0, Color("8f2b2b"))
	draw_line(PATROL_POS + Vector2(-32.0, 22.0), PATROL_POS + Vector2(32.0, 22.0), Color("5a3a24"), 6.0)


func _draw_marker(pos: Vector2, tint: Color) -> void:
	draw_circle(pos, 14.0, tint)
	draw_circle(pos, 5.0, Color.WHITE)


func _draw_world_label(pos: Vector2, text: String, tint: Color) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, tint)
