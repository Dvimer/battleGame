extends RefCounted
class_name BattleCommand

var command_type := ""
var actor: UnitInstance
var target_unit: UnitInstance
var target_coord := Vector2i(-999, -999)
var ends_turn := false


static func move(actor_unit: UnitInstance, coord: Vector2i) -> BattleCommand:
	var command := BattleCommand.new()
	command.command_type = "move"
	command.actor = actor_unit
	command.target_coord = coord
	return command


static func attack(actor_unit: UnitInstance, target: UnitInstance) -> BattleCommand:
	var command := BattleCommand.new()
	command.command_type = "attack"
	command.actor = actor_unit
	command.target_unit = target
	command.target_coord = target.coord if target != null else Vector2i(-999, -999)
	command.ends_turn = true
	return command


static func wait(actor_unit: UnitInstance) -> BattleCommand:
	var command := BattleCommand.new()
	command.command_type = "wait"
	command.actor = actor_unit
	command.ends_turn = true
	return command


static func defend(actor_unit: UnitInstance) -> BattleCommand:
	var command := BattleCommand.new()
	command.command_type = "defend"
	command.actor = actor_unit
	command.ends_turn = true
	return command
