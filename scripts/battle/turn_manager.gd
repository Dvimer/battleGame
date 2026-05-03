extends Node
class_name TurnManager

signal turn_started(unit: UnitInstance)
signal round_started(round_number: int)
signal turn_ended(unit: UnitInstance)

var battle_state: BattleState
var queue: Array[UnitInstance] = []


func start(state: BattleState) -> void:
	battle_state = state
	battle_state.round_number = 0
	_start_next_round()


func end_turn() -> void:
	var unit: UnitInstance = battle_state.active_unit
	if unit != null:
		unit.action_points = 0
		turn_ended.emit(unit)
	_next_turn()


func wait_turn() -> void:
	var unit: UnitInstance = battle_state.active_unit
	if unit == null:
		return
	if unit.action_points > 0:
		queue.append(unit)
	turn_ended.emit(unit)
	_next_turn()


func _start_next_round() -> void:
	if _finish_if_no_contest():
		return
	battle_state.round_number += 1
	for unit in battle_state.living_units():
		unit.waited_this_round = false
	queue = battle_state.living_units()
	queue.sort_custom(func(a, b): return _initiative_score(a) > _initiative_score(b))
	round_started.emit(battle_state.round_number)
	_next_turn()


func _next_turn() -> void:
	if battle_state == null or battle_state.phase == "resolution":
		return
	while not queue.is_empty() and not queue[0].alive:
		queue.pop_front()
	if queue.is_empty():
		_start_next_round()
		return
	if _finish_if_no_contest():
		return
	var unit: UnitInstance = queue.pop_front()
	battle_state.active_unit = unit
	if not unit.waited_this_round:
		unit.begin_turn(battle_state.grid.get_terrain(unit.coord), battle_state.environment)
	turn_started.emit(unit)


func _initiative_score(unit: UnitInstance) -> int:
	return unit.data.initiative + unit.morale - int(unit.fatigue * 0.5)


func build_turn_order_preview() -> Array[UnitInstance]:
	var preview: Array[UnitInstance] = []
	var seen := {}
	if battle_state == null:
		return preview
	if battle_state.active_unit != null and battle_state.active_unit.alive:
		preview.append(battle_state.active_unit)
		seen[battle_state.active_unit.instance_id] = true
	for unit in queue:
		if unit == null or not unit.alive:
			continue
		if seen.has(unit.instance_id):
			continue
		preview.append(unit)
		seen[unit.instance_id] = true
	var next_round := battle_state.living_units()
	next_round.sort_custom(func(a, b): return _initiative_score(a) > _initiative_score(b))
	for unit in next_round:
		if unit == null or seen.has(unit.instance_id):
			continue
		preview.append(unit)
		seen[unit.instance_id] = true
	return preview


func _finish_if_no_contest() -> bool:
	if battle_state == null or battle_state.phase == "resolution":
		return true
	var living := battle_state.living_units()
	if living.is_empty():
		battle_state.finish_battle(-1, "no_units")
		return true
	var winner := battle_state.check_winner()
	if winner != -1:
		battle_state.finish_battle(winner)
		return true
	return false
