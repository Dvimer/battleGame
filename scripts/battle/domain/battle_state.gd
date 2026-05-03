extends RefCounted
class_name BattleState

signal unit_moved(unit, from_coord: Vector2i, to_coord: Vector2i)
signal unit_damaged(unit, amount: int, result: Dictionary)
signal unit_died(unit)
signal battle_finished(result: Dictionary)
signal unit_defended(unit)
signal unit_waited(unit)

var grid: HexGrid
var units: Array[UnitInstance] = []
var phase := "combat"
var round_number := 1
var active_unit: UnitInstance
var environment := {}


func setup(p_grid: HexGrid, attacker: ArmyData, defender: ArmyData, p_environment := {}):
	grid = p_grid
	environment = p_environment.duplicate(true)
	units.clear()
	_add_army(attacker, 0)
	_add_army(defender, 1)
	return self


func living_units(team_filter := -1) -> Array[UnitInstance]:
	var result: Array[UnitInstance] = []
	for unit in units:
		if unit.alive and (team_filter == -1 or unit.team == team_filter):
			result.append(unit)
	return result


func get_unit_at(coord: Vector2i):
	return grid.get_occupant(coord)


func finish_battle(winner_team: int, reason := "victory") -> void:
	if phase == "resolution":
		return
	phase = "resolution"
	active_unit = null
	battle_finished.emit({"winner_team": winner_team, "reason": reason})


func validate_move(unit: UnitInstance, target: Vector2i) -> Dictionary:
	if unit == null or not unit.alive:
		return {"ok": false, "reason": "invalid_actor"}
	if target == unit.coord:
		return {"ok": false, "reason": "same_cell"}
	if not unit.can_spend(unit.data.move_ap_cost):
		return {"ok": false, "reason": "not_enough_ap"}
	if grid == null or not grid.is_walkable(target, unit):
		return {"ok": false, "reason": "blocked"}
	var reachable := Pathfinder.reachable(grid, unit.coord, unit.data.movement, unit)
	if not reachable.has(target):
		return {"ok": false, "reason": "unreachable"}
	return {"ok": true, "type": "move", "cost": int(reachable[target])}


func move_unit(unit: UnitInstance, target: Vector2i) -> bool:
	var validation := validate_move(unit, target)
	if not bool(validation.get("ok", false)):
		return false
	var terrain := grid.get_terrain(target)
	var previous := unit.coord
	if not unit.spend(unit.data.move_ap_cost):
		return false
	if not grid.move_unit(unit, target):
		unit.action_points += unit.data.move_ap_cost
		unit.resources_changed.emit(unit)
		return false
	unit.facing = HexCoord.direction_index(previous, target)
	unit.apply_move_strain(terrain)
	unit.moved.emit(unit, previous, target)
	return true


func apply_command(command: BattleCommand) -> Dictionary:
	if command == null or command.actor == null:
		return {"ok": false, "reason": "invalid_command"}
	match command.command_type:
		"move":
			var validation := validate_move(command.actor, command.target_coord)
			if not bool(validation.get("ok", false)):
				return validation
			if move_unit(command.actor, command.target_coord):
				return {"ok": true, "type": "move", "cost": int(validation.get("cost", 0))}
			return {"ok": false, "type": "move", "reason": "move_failed"}
		"attack":
			return attack(command.actor, command.target_unit)
		"wait":
			command.actor.wait_turn()
			unit_waited.emit(command.actor)
			return {"ok": true, "type": "wait"}
		"defend":
			command.actor.defend()
			unit_defended.emit(command.actor)
			return {"ok": true, "type": "defend"}
		_:
			return {"ok": false, "reason": "unknown_command"}


func validate_attack(attacker: UnitInstance, defender: UnitInstance) -> Dictionary:
	if attacker == null or not attacker.alive:
		return {"ok": false, "reason": "invalid_actor"}
	if defender == null:
		return {"ok": false, "reason": "invalid_target"}
	if not defender.alive:
		return {"ok": false, "reason": "dead_target"}
	if attacker.team == defender.team:
		return {"ok": false, "reason": "friendly_target"}
	if grid == null or grid.get_occupant(defender.coord) != defender:
		return {"ok": false, "reason": "stale_target"}
	if not attacker.can_spend(attacker.data.attack_ap_cost):
		return {"ok": false, "reason": "not_enough_ap"}
	if HexCoord.distance(attacker.coord, defender.coord) > attacker.data.attack_range:
		return {"ok": false, "reason": "out_of_range"}
	return {"ok": true, "type": "attack"}


func attack(attacker: UnitInstance, defender: UnitInstance) -> Dictionary:
	var validation := validate_attack(attacker, defender)
	if not bool(validation.get("ok", false)):
		return validation
	attacker.spend(attacker.data.attack_ap_cost)
	attacker.facing = HexCoord.direction_index(attacker.coord, defender.coord)
	var result := DamageCalculator.compute(attacker, defender, grid)
	defender.take_damage(int(result["damage"]), result)
	if not defender.alive:
		grid.set_occupant(defender.coord, null)
	var winner := check_winner()
	if winner != -1:
		finish_battle(winner)
	result["ok"] = true
	return result


func check_winner() -> int:
	var attackers_alive := not living_units(0).is_empty()
	var defenders_alive := not living_units(1).is_empty()
	if attackers_alive and not defenders_alive:
		return 0
	if defenders_alive and not attackers_alive:
		return 1
	return -1


func _add_army(army: ArmyData, team: int) -> void:
	if army == null:
		return
	for index in range(army.slots.size()):
		var unit: UnitInstance = UnitInstance.new().setup(army.slots[index], team, index)
		var deploy_coord := _find_deploy_coord(unit.coord, unit)
		if deploy_coord == Vector2i(-999, -999):
			continue
		unit.coord = deploy_coord
		units.append(unit)
		grid.set_occupant(unit.coord, unit)
		unit.moved.connect(func(moved_unit, from_coord, to_coord): unit_moved.emit(moved_unit, from_coord, to_coord))
		unit.damaged.connect(func(damaged_unit, amount, result): unit_damaged.emit(damaged_unit, amount, result))
		unit.died.connect(func(dead_unit): unit_died.emit(dead_unit))


func _find_deploy_coord(preferred: Vector2i, unit: UnitInstance) -> Vector2i:
	if grid == null:
		return Vector2i(-999, -999)
	if grid.is_walkable(preferred, unit) and grid.get_occupant(preferred) == null:
		return preferred
	var best_coord := Vector2i(-999, -999)
	var best_distance := 999999
	for coord in grid.cells.keys():
		var typed_coord: Vector2i = coord
		if not grid.is_walkable(typed_coord, unit) or grid.get_occupant(typed_coord) != null:
			continue
		var distance := HexCoord.distance(preferred, typed_coord)
		if distance < best_distance:
			best_distance = distance
			best_coord = typed_coord
	return best_coord
