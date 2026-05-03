extends RefCounted
class_name Pathfinder


static func reachable(grid: HexGrid, start: Vector2i, budget: int, unit = null, respect_zoc := true) -> Dictionary:
	var costs := {start: 0}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		frontier.sort_custom(func(a, b): return int(costs[a]) < int(costs[b]))
		var current: Vector2i = frontier.pop_front()
		if respect_zoc and current != start and _is_enemy_zoc(grid, current, unit):
			continue
		for neighbor_cell in grid.neighbor_cells(current):
			var next := neighbor_cell.coord
			if not grid.is_walkable(next, unit):
				continue
			var next_cost := int(costs[current]) + maxi(1, neighbor_cell.terrain.move_cost)
			if next_cost > budget:
				continue
			if not costs.has(next) or next_cost < int(costs[next]):
				costs[next] = next_cost
				frontier.append(next)
	return costs


static func find_path(grid: HexGrid, start: Vector2i, goal: Vector2i, unit = null, respect_zoc := true) -> Array[Vector2i]:
	if not grid.is_walkable(goal, unit):
		return []
	var frontier: Array[Vector2i] = [start]
	var came_from := {start: start}
	var costs := {start: 0}
	while not frontier.is_empty():
		frontier.sort_custom(func(a, b): return int(costs[a]) < int(costs[b]))
		var current: Vector2i = frontier.pop_front()
		if current == goal:
			break
		if respect_zoc and current != start and _is_enemy_zoc(grid, current, unit):
			continue
		for neighbor_cell in grid.neighbor_cells(current):
			var next := neighbor_cell.coord
			if not grid.is_walkable(next, unit):
				continue
			var next_cost := int(costs[current]) + maxi(1, neighbor_cell.terrain.move_cost)
			if not costs.has(next) or next_cost < int(costs[next]):
				costs[next] = next_cost
				came_from[next] = current
				frontier.append(next)
	if not came_from.has(goal):
		return []
	var path: Array[Vector2i] = []
	var current := goal
	while current != start:
		path.push_front(current)
		current = came_from[current]
	return path


static func _is_enemy_zoc(grid: HexGrid, coord: Vector2i, unit) -> bool:
	if unit == null:
		return false
	for neighbor_cell in grid.neighbor_cells(coord):
		var occupant = neighbor_cell.occupant
		if occupant != null and occupant.alive and occupant.team != unit.team:
			return true
	return false
