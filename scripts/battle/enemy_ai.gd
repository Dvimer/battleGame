extends Node
class_name EnemyAI


func choose_action(state: BattleState, unit: UnitInstance) -> Dictionary:
	var target: UnitInstance = _nearest_enemy(state, unit)
	if target == null:
		return {"type": "wait"}
	if HexCoord.distance(unit.coord, target.coord) <= unit.data.attack_range and unit.can_spend(unit.data.attack_ap_cost):
		return {"type": "attack", "target": target}
	if unit.can_spend(unit.data.move_ap_cost):
		var reachable := Pathfinder.reachable(state.grid, unit.coord, unit.data.movement, unit)
		var best_coord := unit.coord
		var best_distance := HexCoord.distance(unit.coord, target.coord)
		for coord in reachable.keys():
			if coord == unit.coord:
				continue
			var distance := HexCoord.distance(coord, target.coord)
			if distance < best_distance:
				best_distance = distance
				best_coord = coord
		if best_coord != unit.coord:
			return {"type": "move", "coord": best_coord}
	return {"type": "wait"}


func _nearest_enemy(state: BattleState, unit: UnitInstance) -> UnitInstance:
	var best: UnitInstance = null
	var best_distance := 999999
	for candidate in state.living_units(1 - unit.team):
		var distance := HexCoord.distance(unit.coord, candidate.coord)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best
