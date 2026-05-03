extends RefCounted
class_name UnitInstance

signal moved(unit, from_coord: Vector2i, to_coord: Vector2i)
signal damaged(unit, amount: int, result: Dictionary)
signal died(unit)
signal resources_changed(unit)

var instance_id := ""
var data: UnitData
var coord := Vector2i.ZERO
var team := 0
var facing := 0
var hp := 1
var max_hp := 1
var action_points := 0
var morale := 0
var fatigue := 0
var alive := true
var defending := false
var waited_this_round := false
var equipped := {}
var quick_slots: Array = []
var secondary_set := {}
var appearance: Resource
var persistent_wounds: Array = []
var roster_unit_id := ""


func setup(slot: ArmySlotData, p_team: int, index: int):
	data = slot.unit_data
	team = p_team
	instance_id = "%d_%s_%d" % [team, data.unit_id, index]
	coord = slot.deploy_hex
	facing = slot.facing
	max_hp = data.max_hp
	hp = slot.starting_hp if slot.starting_hp >= 0 else max_hp
	action_points = data.action_points
	morale = data.base_morale
	fatigue = data.base_fatigue
	equipped = Dictionary(slot.equipped).duplicate(true)
	quick_slots = Array(slot.quick_slots).duplicate(true)
	secondary_set = Dictionary(slot.secondary_set).duplicate(true)
	appearance = slot.appearance
	persistent_wounds = Array(slot.persistent_wounds).duplicate(true)
	roster_unit_id = slot.roster_unit_id
	alive = hp > 0
	return self


func begin_turn(terrain: TerrainData, environment := {}) -> void:
	action_points = data.action_points
	defending = false
	fatigue = maxi(0, fatigue - 2)
	if terrain != null:
		fatigue = maxi(0, fatigue + terrain.fatigue_delta)
		morale = clampi(morale + terrain.morale_delta, -3, 3)
	morale = clampi(morale + int(environment.get("global_morale_delta", 0)), -3, 3)
	resources_changed.emit(self)


func can_spend(cost: int) -> bool:
	return alive and action_points >= cost


func spend(cost: int) -> bool:
	if not can_spend(cost):
		return false
	action_points -= cost
	resources_changed.emit(self)
	return true


func wait_turn() -> void:
	if waited_this_round:
		action_points = 0
		resources_changed.emit(self)
		return
	waited_this_round = true
	action_points = maxi(1, int(floor(float(action_points) * 0.5)))
	resources_changed.emit(self)


func defend() -> void:
	defending = true
	action_points = 0
	fatigue = maxi(0, fatigue - 1)
	resources_changed.emit(self)


func set_coord(value: Vector2i) -> void:
	var previous := coord
	coord = value
	moved.emit(self, previous, coord)


func apply_move_strain(terrain: TerrainData) -> void:
	if terrain != null:
		fatigue = maxi(0, fatigue + terrain.move_cost + terrain.fatigue_delta)
	resources_changed.emit(self)


func take_damage(amount: int, result := {}) -> void:
	if not alive:
		return
	hp = maxi(0, hp - amount)
	damaged.emit(self, amount, result)
	if hp <= 0:
		alive = false
		died.emit(self)


func display_name() -> String:
	return data.display_name if data != null else "Unit"


func get_combat_abilities() -> Array[String]:
	return data.abilities.duplicate() if data != null else []


func compute_armor() -> int:
	var armor := 0
	for item in equipped.values():
		if item == null or item.data == null:
			continue
		if str(item.data.item_class) == "armor":
			armor += int(item.data.armor_value)
		elif str(item.data.item_class) == "shield":
			armor += int(item.data.block_value)
	return armor


func compute_total_weight() -> int:
	var total := 0
	for item in equipped.values():
		if item != null and item.data != null:
			total += int(item.data.weight)
	for item in quick_slots:
		if item != null and item.data != null:
			total += int(item.data.weight)
	return total


func compute_initiative() -> int:
	var base_value := data.initiative if data != null else 0
	return maxi(1, base_value - compute_total_weight())


func compute_max_fatigue() -> int:
	var base_value := 12 + (data.base_fatigue if data != null else 0)
	return maxi(1, base_value - int(floor(compute_total_weight() * 0.5)))
