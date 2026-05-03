extends RefCounted
class_name BattleMockFactory


static func create_context() -> Dictionary:
	var plains := _terrain("plains", "Луг", 1, 0, 0, 0, Color("6fa868"))
	var forest := _terrain("forest", "Лес", 2, 1, 1, 0, Color("3f7d4c"))
	var marsh := _terrain("marsh", "Топь", 3, 0, 2, -1, Color("4d6f68"))
	var hill := _terrain("hill", "Холм", 2, 2, 1, 1, Color("9a9466"))

	var battlefield := BattlefieldData.new()
	battlefield.battlefield_id = "mock_border_skirmish"
	battlefield.display_name = "Учебная стычка у старой дороги"
	battlefield.size = Vector2i(11, 9)
	battlefield.default_terrain = plains
	battlefield.environment = {
		"weather": "drizzle",
		"time_of_day": "dusk",
		"global_morale_delta": -1
	}

	for coord in [Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5)]:
		battlefield.terrain_overrides[coord] = forest
	for coord in [Vector2i(7, 3), Vector2i(8, 3), Vector2i(7, 4), Vector2i(8, 4)]:
		battlefield.terrain_overrides[coord] = marsh
	for coord in [Vector2i(2, 2), Vector2i(2, 3), Vector2i(8, 6), Vector2i(9, 6)]:
		battlefield.terrain_overrides[coord] = hill

	var footman := _unit("footman", "Ополченец", 13, 5, 2, 10, 7, 2, 1, Color("7ce7ff"))
	var archer := _unit("archer", "Стрелок", 9, 4, 1, 12, 7, 4, 3, Color("9df3ff"))
	var raider := _unit("raider", "Налетчик", 11, 5, 1, 11, 7, 2, 1, Color("ff9f43"))
	var brute := _unit("brute", "Громила", 16, 6, 2, 7, 6, 3, 1, Color("ff6b6b"))

	var attacker := ArmyData.new()
	attacker.army_id = "player_mock"
	attacker.display_name = "Отряд игрока"
	var attacker_slots: Array[ArmySlotData] = [
		_slot(footman, Vector2i(1, 3), 0),
		_slot(footman, Vector2i(1, 5), 0),
		_slot(archer, Vector2i(0, 4), 0)
	]
	attacker.slots = attacker_slots

	var defender := ArmyData.new()
	defender.army_id = "enemy_mock"
	defender.display_name = "Разбойники"
	var defender_slots: Array[ArmySlotData] = [
		_slot(raider, Vector2i(9, 3), 3),
		_slot(raider, Vector2i(9, 5), 3),
		_slot(brute, Vector2i(10, 4), 3)
	]
	defender.slots = defender_slots

	return {
		"battlefield": battlefield,
		"attacker": attacker,
		"defender": defender,
		"environment": battlefield.environment,
		"return_scene": "res://scenes/main.tscn",
		"return_spawn_id": "hub_default",
		"apply_to_roster": false
	}


static func create_context_from_roster(roster_manager: Node) -> Dictionary:
	var context := create_context()
	if roster_manager == null or not roster_manager.has_method("create_attacker_army_from_selected_party"):
		return context
	var attacker: ArmyData = roster_manager.create_attacker_army_from_selected_party()
	if attacker == null or attacker.slots.is_empty():
		return context
	context["attacker"] = attacker
	context["apply_to_roster"] = true
	return context


static func _terrain(id: String, title: String, move_cost: int, cover: int, fatigue_delta: int, morale_delta: int, color: Color) -> TerrainData:
	var terrain := TerrainData.new()
	terrain.terrain_id = id
	terrain.display_name = title
	terrain.move_cost = move_cost
	terrain.cover = cover
	terrain.fatigue_delta = fatigue_delta
	terrain.morale_delta = morale_delta
	terrain.color = color
	return terrain


static func _unit(id: String, title: String, hp: int, attack: int, defense: int, initiative: int, ap: int, movement: int, attack_range: int, color: Color) -> UnitData:
	var data := UnitData.new()
	data.unit_id = id
	data.display_name = title
	data.max_hp = hp
	data.attack = attack
	data.defense = defense
	data.initiative = initiative
	data.action_points = ap
	data.movement = movement
	data.attack_range = attack_range
	data.color = color
	return data


static func _slot(unit_data: UnitData, coord: Vector2i, facing: int) -> ArmySlotData:
	var slot := ArmySlotData.new()
	slot.unit_data = unit_data
	slot.deploy_hex = coord
	slot.facing = facing
	return slot
