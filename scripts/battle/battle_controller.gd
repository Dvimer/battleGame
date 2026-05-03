extends Node2D
class_name BattleController

const HEX_SIZE := 38.0
const BOARD_ORIGIN := Vector2(560.0, 140.0)

@onready var camera: Camera2D = $Camera2D
@onready var hex_map: HexTileMap = $HexTileMap
@onready var units_layer: Node2D = $UnitsLayer
@onready var turn_manager: TurnManager = $TurnManager
@onready var input_controller: BattleInputController = $InputController
@onready var enemy_ai: EnemyAI = $EnemyAI
@onready var hud: BattleHud = $HUD

var unit_view_scene := preload("res://scenes/battle/unit_view.tscn")
var battle_state: BattleState
var selected_unit: UnitInstance
var context := {}
var ai_busy := false
var current_path_preview: Array[Vector2i] = []
var current_forecast_coord := Vector2i(-999, -999)


func _ready() -> void:
	context = _load_context()
	_build_state()
	hex_map.position = BOARD_ORIGIN
	units_layer.position = BOARD_ORIGIN
	hex_map.setup(battle_state, HEX_SIZE)
	_spawn_unit_views()
	_connect_events()
	hud.setup(context["battlefield"].display_name, context.get("environment", {}))
	camera.position = Vector2(960.0, 540.0)
	turn_manager.start(battle_state)


func _load_context() -> Dictionary:
	var battle_context := get_node_or_null("/root/BattleContext")
	if battle_context != null and battle_context.has_method("is_ready") and battle_context.is_ready():
		return battle_context.consume()
	return BattleMockFactory.create_context()


func _build_state() -> void:
	var grid: HexGrid = HexGrid.new().setup(context["battlefield"])
	battle_state = BattleState.new().setup(
		grid,
		context["attacker"],
		context["defender"],
		context.get("environment", {})
	)


func _spawn_unit_views() -> void:
	for unit in battle_state.units:
		var view = unit_view_scene.instantiate()
		units_layer.add_child(view)
		view.setup(unit, HEX_SIZE)


func _connect_events() -> void:
	hex_map.hex_clicked.connect(_on_hex_clicked)
	hex_map.hex_hovered.connect(_on_hex_hovered)
	hud.end_turn_pressed.connect(_end_player_turn)
	hud.wait_pressed.connect(_wait_player_turn)
	hud.defend_pressed.connect(_defend_player_turn)
	hud.return_pressed.connect(_return_after_battle)
	input_controller.end_turn_requested.connect(_end_player_turn)
	turn_manager.turn_started.connect(_on_turn_started)
	turn_manager.round_started.connect(func(round_number): hud.push_log("Раунд %d." % round_number))
	battle_state.unit_moved.connect(_on_unit_moved)
	battle_state.unit_damaged.connect(_on_unit_damaged)
	battle_state.unit_died.connect(func(unit): hud.push_log("%s выбывает из боя." % unit.display_name()))
	battle_state.unit_waited.connect(func(unit): hud.push_log("%s ждёт удобного момента." % unit.display_name()))
	battle_state.unit_defended.connect(func(unit): hud.push_log("%s занимает защитную стойку." % unit.display_name()))
	battle_state.battle_finished.connect(_on_battle_finished)


func _on_turn_started(unit: UnitInstance) -> void:
	selected_unit = unit if unit.team == 0 else null
	hud.update_turn(unit, battle_state.round_number)
	hud.update_selection(unit)
	hud.set_player_turn(unit.team == 0)
	_refresh_overlays()
	if unit.team == 1:
		_run_ai_turn(unit)


func _on_hex_clicked(coord: Vector2i) -> void:
	var active := battle_state.active_unit
	if active == null or active.team != 0 or battle_state.phase == "resolution":
		return
	var clicked_unit = battle_state.get_unit_at(coord)
	if clicked_unit == active:
		selected_unit = active
		_refresh_overlays()
		return
	if clicked_unit != null and clicked_unit.team != active.team:
		_try_player_attack(clicked_unit)
		return
	if selected_unit == active:
		_try_player_move(coord)


func _on_hex_hovered(coord: Vector2i) -> void:
	hud.update_terrain(battle_state.grid.get_terrain(coord))
	_update_hover_preview(coord)


func _try_player_move(coord: Vector2i) -> void:
	var active := battle_state.active_unit
	var reachable := Pathfinder.reachable(battle_state.grid, active.coord, active.data.movement, active)
	if not reachable.has(coord) or coord == active.coord:
		return
	var result := _apply_player_command(BattleCommand.move(active, coord))
	if bool(result.get("ok", false)):
		_maybe_auto_end(active)


func _try_player_attack(target: UnitInstance) -> void:
	var active := battle_state.active_unit
	var result := _apply_player_command(BattleCommand.attack(active, target))
	if not bool(result.get("ok", false)):
		hud.push_log("Цель недоступна: %s." % str(result.get("reason", "unknown")))
		return
	hex_map.show_attack_trace(active.coord, target.coord)
	hud.push_log("%s атакует %s: -%d HP." % [active.display_name(), target.display_name(), int(result["damage"])])
	if battle_state.phase != "resolution":
		turn_manager.end_turn()


func _end_player_turn() -> void:
	var active := battle_state.active_unit
	if active == null or active.team != 0 or battle_state.phase == "resolution":
		return
	turn_manager.end_turn()


func _wait_player_turn() -> void:
	var active := battle_state.active_unit
	if active == null or active.team != 0 or battle_state.phase == "resolution":
		return
	_apply_player_command(BattleCommand.wait(active))
	turn_manager.wait_turn()


func _defend_player_turn() -> void:
	var active := battle_state.active_unit
	if active == null or active.team != 0 or battle_state.phase == "resolution":
		return
	_apply_player_command(BattleCommand.defend(active))
	turn_manager.end_turn()


func _run_ai_turn(unit: UnitInstance) -> void:
	if ai_busy:
		return
	ai_busy = true
	await get_tree().create_timer(0.35).timeout
	while unit.alive and unit.action_points > 0 and battle_state.phase != "resolution":
		var action := enemy_ai.choose_action(battle_state, unit)
		match str(action.get("type", "wait")):
			"attack":
				var target: UnitInstance = action["target"]
				var from_coord := unit.coord
				var result := battle_state.apply_command(BattleCommand.attack(unit, target))
				if bool(result.get("ok", false)):
					hex_map.show_attack_trace(from_coord, target.coord)
					hud.push_log("%s атакует %s: -%d HP." % [unit.display_name(), target.display_name(), int(result.get("damage", 0))])
				else:
					hud.push_log("%s не может атаковать: %s." % [unit.display_name(), str(result.get("reason", "unknown"))])
				break
			"move":
				var result := battle_state.apply_command(BattleCommand.move(unit, action["coord"]))
				if not bool(result.get("ok", false)):
					hud.push_log("%s не может двигаться: %s." % [unit.display_name(), str(result.get("reason", "unknown"))])
					break
			_:
				break
		await get_tree().create_timer(0.25).timeout
	ai_busy = false
	if battle_state.phase != "resolution":
		turn_manager.end_turn()


func _refresh_overlays() -> void:
	var active := battle_state.active_unit
	if active == null or active.team != 0:
		hex_map.set_overlays(Vector2i(-999, -999), {}, {}, [], Vector2i(-999, -999))
		return
	var reachable := Pathfinder.reachable(battle_state.grid, active.coord, active.data.movement, active)
	var attackable := {}
	for unit in battle_state.living_units(1):
		if HexCoord.distance(active.coord, unit.coord) <= active.data.attack_range:
			attackable[unit.coord] = true
	hex_map.set_overlays(active.coord, reachable, attackable, current_path_preview, current_forecast_coord)


func _update_hover_preview(coord: Vector2i) -> void:
	current_path_preview.clear()
	current_forecast_coord = Vector2i(-999, -999)
	hud.update_forecast("")
	var active := battle_state.active_unit
	if active == null or active.team != 0 or battle_state.phase == "resolution":
		_refresh_overlays()
		return
	var hovered_unit: UnitInstance = battle_state.get_unit_at(coord)
	if hovered_unit != null and hovered_unit.team != active.team:
		if HexCoord.distance(active.coord, hovered_unit.coord) <= active.data.attack_range:
			var forecast := DamageCalculator.compute(active, hovered_unit, battle_state.grid)
			current_forecast_coord = hovered_unit.coord
			hud.update_forecast("Прогноз атаки: %s получит %d урона. cover -%d, defend -%d, flank +%d." % [
				hovered_unit.display_name(),
				int(forecast["damage"]),
				int(forecast["cover"]),
				int(forecast["defend_bonus"]),
				int(forecast["flank_bonus"])
			])
		else:
			hud.update_forecast("Цель вне дальности: %d / %d." % [HexCoord.distance(active.coord, hovered_unit.coord), active.data.attack_range])
	elif battle_state.grid.is_walkable(coord, active):
		var reachable := Pathfinder.reachable(battle_state.grid, active.coord, active.data.movement, active)
		if reachable.has(coord) and coord != active.coord:
			current_path_preview = Pathfinder.find_path(battle_state.grid, active.coord, coord, active)
			hud.update_forecast("Маршрут: %d клетк., стоимость %d, AP %d." % [current_path_preview.size(), int(reachable[coord]), active.data.move_ap_cost])
	_refresh_overlays()


func _apply_player_command(command: BattleCommand) -> Dictionary:
	var result := battle_state.apply_command(command)
	hud.update_selection(command.actor)
	current_path_preview.clear()
	current_forecast_coord = Vector2i(-999, -999)
	hud.update_forecast("")
	_refresh_overlays()
	return result


func _maybe_auto_end(unit: UnitInstance) -> void:
	if unit.action_points <= 0 and battle_state.phase != "resolution":
		turn_manager.end_turn()


func _on_unit_moved(unit: UnitInstance, from_coord: Vector2i, to_coord: Vector2i) -> void:
	hud.push_log("%s: %s -> %s." % [unit.display_name(), from_coord, to_coord])


func _on_unit_damaged(unit: UnitInstance, amount: int, result: Dictionary) -> void:
	hud.update_selection(battle_state.active_unit)
	if int(result.get("cover", 0)) > 0 or int(result.get("flank_bonus", 0)) > 0:
		hud.push_log("Модификаторы: cover -%d, flank +%d." % [int(result.get("cover", 0)), int(result.get("flank_bonus", 0))])


func _on_battle_finished(result: Dictionary) -> void:
	hex_map.set_overlays(Vector2i(-999, -999), {}, {}, [], Vector2i(-999, -999))
	hud.show_result(result)
	var callback: Callable = context.get("on_finished", Callable())
	if callback.is_valid():
		callback.call(result)


func _return_after_battle() -> void:
	var return_scene := str(context.get("return_scene", ""))
	var scene_router := get_node_or_null("/root/SceneRouter")
	if return_scene != "" and scene_router != null:
		scene_router.go_to_scene(return_scene, str(context.get("return_spawn_id", "")))
		return
	get_tree().reload_current_scene()
