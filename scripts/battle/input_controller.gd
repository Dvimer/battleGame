extends Node
class_name BattleInputController

signal end_turn_requested


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		end_turn_requested.emit()
