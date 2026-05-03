extends Node2D

var velocity := Vector2.ZERO
var lifetime := 1.0
var radius := 7.0
var damage := 1
var knockback := 180.0
var tint := Color("9df3ff")
var arena_size := Vector2(1280.0, 720.0)
var alive := true


func configure(spawn_position: Vector2, direction: Vector2, config: Dictionary) -> void:
	global_position = spawn_position
	velocity = direction.normalized() * float(config.get("speed", 760.0))
	lifetime = float(config.get("lifetime", lifetime))
	radius = float(config.get("radius", radius))
	damage = int(config.get("damage", damage))
	knockback = float(config.get("knockback", knockback))
	tint = Color(config.get("tint", tint))
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

	var tree := get_tree()
	if tree == null:
		return

	for enemy in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) <= radius + float(enemy.radius):
			enemy.take_damage(damage, velocity.normalized() * knockback)
			alive = false
			queue_free()
			return

	queue_redraw()


func _is_outside_arena() -> bool:
	return global_position.x < -30.0 or global_position.y < -30.0 or global_position.x > arena_size.x + 30.0 or global_position.y > arena_size.y + 30.0


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, tint)
	draw_circle(Vector2.ZERO, radius * 0.4, Color.WHITE)
