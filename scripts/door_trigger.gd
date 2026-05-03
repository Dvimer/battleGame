extends Node2D

@export_file("*.tscn") var target_scene_path := ""
@export var target_spawn_id := ""
@export_enum("auto", "interact") var transition_mode := "auto"
@export var trigger_radius := 48.0
@export var enabled := true
@export var player_path: NodePath

var player: Node2D


func _scene_router() -> Node:
	return get_node_or_null("/root/SceneRouter")


func _ready() -> void:
	if player_path != NodePath():
		player = get_node_or_null(player_path)
	else:
		player = get_parent().get_node_or_null("Player")
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if not enabled or target_scene_path == "" or player == null:
		return

	if player.global_position.distance_to(global_position) > trigger_radius:
		return

	if transition_mode == "interact" and not Input.is_action_just_pressed("interact"):
		return

	var scene_router := _scene_router()
	if scene_router != null:
		scene_router.go_to_scene(target_scene_path, target_spawn_id)
