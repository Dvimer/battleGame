extends Node

var battlefield
var attacker
var defender
var environment := {}
var return_scene := ""
var return_spawn_id := ""
var on_finished: Callable = Callable()


func setup(p_battlefield, p_attacker, p_defender, p_environment := {}, p_return_scene := "", p_return_spawn_id := "", p_on_finished := Callable()) -> void:
	battlefield = p_battlefield
	attacker = p_attacker
	defender = p_defender
	environment = p_environment.duplicate(true)
	return_scene = p_return_scene
	return_spawn_id = p_return_spawn_id
	on_finished = p_on_finished


func is_ready() -> bool:
	return battlefield != null and attacker != null and defender != null


func consume() -> Dictionary:
	var data := {
		"battlefield": battlefield,
		"attacker": attacker,
		"defender": defender,
		"environment": environment.duplicate(true),
		"return_scene": return_scene,
		"return_spawn_id": return_spawn_id,
		"on_finished": on_finished
	}
	clear()
	return data


func clear() -> void:
	battlefield = null
	attacker = null
	defender = null
	environment = {}
	return_scene = ""
	return_spawn_id = ""
	on_finished = Callable()
