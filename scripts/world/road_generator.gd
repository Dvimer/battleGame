extends RefCounted
class_name RoadGenerator

const CAPITAL_LINK_COUNT := 2
const EXTRA_EDGE_RATIO := 0.25


func generate(config, rng: RandomNumberGenerator, settlements: Array) -> Array[PackedVector2Array]:
	var roads: Array[PackedVector2Array] = []
	if settlements.size() < 2:
		return roads

	var edges = _build_network_edges(settlements)
	_add_capital_links(edges, settlements)
	_add_extra_links(edges, settlements)

	for edge_key in edges.keys():
		var pair: Vector2i = edges[edge_key]
		roads.append(_build_road(settlements[pair.x], settlements[pair.y], config, rng))
	return roads


func _build_network_edges(settlements: Array) -> Dictionary:
	var edges = {}
	var visited = {0: true}

	while visited.size() < settlements.size():
		var best_from = -1
		var best_to = -1
		var best_distance = INF
		for from_index in visited.keys():
			for to_index in range(settlements.size()):
				if visited.has(to_index):
					continue
				var distance = settlements[from_index].map_position.distance_to(settlements[to_index].map_position)
				if distance < best_distance:
					best_distance = distance
					best_from = int(from_index)
					best_to = to_index
		if best_from == -1 or best_to == -1:
			break
		visited[best_to] = true
		_store_edge(edges, best_from, best_to)

	return edges


func _add_capital_links(edges: Dictionary, settlements: Array) -> void:
	var capital_index = _find_capital_index(settlements)
	if capital_index == -1:
		return

	var distances: Array = []
	for index in range(settlements.size()):
		if index == capital_index:
			continue
		distances.append({
			"index": index,
			"distance": settlements[capital_index].map_position.distance_to(settlements[index].map_position)
		})
	distances.sort_custom(func(a, b): return a["distance"] < b["distance"])

	var link_count = mini(CAPITAL_LINK_COUNT, distances.size())
	for offset in range(link_count):
		_store_edge(edges, capital_index, int(distances[offset]["index"]))


func _add_extra_links(edges: Dictionary, settlements: Array) -> void:
	var target_count = maxi(1, int(floor(settlements.size() * EXTRA_EDGE_RATIO)))
	var candidates: Array = []
	for from_index in range(settlements.size()):
		for to_index in range(from_index + 1, settlements.size()):
			var key = _edge_key(from_index, to_index)
			if edges.has(key):
				continue
			candidates.append({
				"from": from_index,
				"to": to_index,
				"distance": settlements[from_index].map_position.distance_to(settlements[to_index].map_position)
			})
	candidates.sort_custom(func(a, b): return a["distance"] < b["distance"])

	for edge_index in range(mini(target_count, candidates.size())):
		var edge: Dictionary = candidates[edge_index]
		_store_edge(edges, int(edge["from"]), int(edge["to"]))


func _build_road(from_settlement, to_settlement, config, rng: RandomNumberGenerator) -> PackedVector2Array:
	var path = PackedVector2Array()
	var start: Vector2 = from_settlement.map_position
	var finish: Vector2 = to_settlement.map_position
	var direction: Vector2 = finish - start
	var distance = direction.length()
	var tangent = direction.normalized()
	var normal = tangent.orthogonal()
	var bend_strength = minf(config.road_curviness, distance * 0.22)
	var bend_side = -1.0 if rng.randf() < 0.5 else 1.0
	var bend = normal * bend_strength * bend_side

	var control_a = start.lerp(finish, 0.32) + bend
	var control_b = start.lerp(finish, 0.68) + bend * 0.65
	var samples = maxi(10, int(distance / float(config.tile_size * 1.5)))
	for step in range(samples + 1):
		var t = float(step) / float(samples)
		path.append(_sample_cubic_bezier(start, control_a, control_b, finish, t))

	return path


func _sample_cubic_bezier(start: Vector2, control_a: Vector2, control_b: Vector2, finish: Vector2, t: float) -> Vector2:
	var inv = 1.0 - t
	return (
		inv * inv * inv * start
		+ 3.0 * inv * inv * t * control_a
		+ 3.0 * inv * t * t * control_b
		+ t * t * t * finish
	)


func _find_capital_index(settlements: Array) -> int:
	for index in range(settlements.size()):
		if settlements[index].settlement_type == "capital":
			return index
	return -1


func _store_edge(edges: Dictionary, from_index: int, to_index: int) -> void:
	edges[_edge_key(from_index, to_index)] = Vector2i(mini(from_index, to_index), maxi(from_index, to_index))


func _edge_key(from_index: int, to_index: int) -> String:
	return "%d:%d" % [mini(from_index, to_index), maxi(from_index, to_index)]
