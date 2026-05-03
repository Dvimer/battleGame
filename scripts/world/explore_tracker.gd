extends Node


func _event_bus() -> Node:
	return get_node_or_null("/root/EventBus")


func _fog_of_war() -> Node:
	return get_node_or_null("/root/FogOfWar")


func _process(_delta: float) -> void:
	var player = get_parent().get_node_or_null("Player")
	if player == null:
		return
	var event_bus = _event_bus()
	if event_bus != null:
		event_bus.emit_signal("player_moved", player.global_position)
	var fog = _fog_of_war()
	if fog != null:
		fog.update_from_world_position(player.global_position)
