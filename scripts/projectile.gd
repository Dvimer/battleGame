extends Node2D

signal hit_player

var velocity := Vector2.ZERO
var lifetime := 2.4
var radius := 8.0
var damage := 1
var tint := Color("ffdf7a")
var player: Node2D
var arena_size := Vector2(1280.0, 720.0)
var alive := true


func configure(target: Node2D, spawn_position: Vector2, direction: Vector2, config: Dictionary) -> void:
	player = target
	global_position = spawn_position
	velocity = direction.normalized() * float(config.get("speed", 320.0))
	lifetime = float(config.get("lifetime", lifetime))
	radius = float(config.get("radius", radius))
	damage = int(config.get("damage", damage))
	tint = Color(config.get("tint", tint))
	queue_redraw()


func _ready() -> void:
	add_to_group("enemy_projectiles")
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not alive:
		return

	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	global_position += velocity * delta
	if _is_outside_arena():
		queue_free()
		return

	if is_instance_valid(player) and player.has_method("take_damage"):
		if global_position.distance_to(player.global_position) <= radius + 14.0:
			player.take_damage(damage)
			hit_player.emit()
			alive = false
			queue_free()

	queue_redraw()


func _is_outside_arena() -> bool:
	return global_position.x < -30.0 or global_position.y < -30.0 or global_position.x > arena_size.x + 30.0 or global_position.y > arena_size.y + 30.0


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, tint)
	draw_circle(Vector2.ZERO, radius * 0.45, Color.WHITE)
