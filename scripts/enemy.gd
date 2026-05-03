extends Node2D

signal died(enemy: Node2D)
signal projectile_requested(spawn_position: Vector2, direction: Vector2, config: Dictionary)

const BASE_RADIUS := 18.0

var player: Node2D
var arena_size := Vector2(1280.0, 720.0)
var enemy_name := "Striker"
var behavior := "chase"
var speed := 120.0
var max_health := 2
var health := 2
var touch_damage := 1
var touch_cooldown := 0.85
var touch_timer := 0.0
var radius := BASE_RADIUS
var tint := Color("ff6b6b")
var knockback := Vector2.ZERO
var ranged_cooldown := 1.9
var ranged_timer := 0.4
var charge_cooldown := 2.4
var charge_timer := 0.8
var charge_direction := Vector2.ZERO
var charge_speed := 420.0
var charge_duration := 0.45
var charge_windup := 0.5
var charge_state := "idle"
var leap_cooldown := 1.8
var leap_timer := 0.7
var leap_speed := 500.0
var leap_duration := 0.22
var leap_windup := 0.35
var leap_state := "idle"
var leap_target := Vector2.ZERO
var flash_timer := 0.0
var essence_value := 1
var contact_padding := 18.0
var alive := true


func configure(target: Node2D, config: Dictionary) -> void:
	player = target
	enemy_name = str(config.get("name", enemy_name))
	behavior = str(config.get("behavior", behavior))
	speed = float(config.get("speed", speed))
	max_health = int(config.get("max_health", max_health))
	health = max_health
	touch_damage = int(config.get("touch_damage", touch_damage))
	touch_cooldown = float(config.get("touch_cooldown", touch_cooldown))
	radius = float(config.get("radius", radius))
	tint = Color(config.get("tint", tint))
	ranged_cooldown = float(config.get("ranged_cooldown", ranged_cooldown))
	ranged_timer = randf() * ranged_cooldown
	charge_cooldown = float(config.get("charge_cooldown", charge_cooldown))
	charge_speed = float(config.get("charge_speed", charge_speed))
	charge_duration = float(config.get("charge_duration", charge_duration))
	charge_windup = float(config.get("charge_windup", charge_windup))
	leap_cooldown = float(config.get("leap_cooldown", leap_cooldown))
	leap_speed = float(config.get("leap_speed", leap_speed))
	leap_duration = float(config.get("leap_duration", leap_duration))
	leap_windup = float(config.get("leap_windup", leap_windup))
	leap_timer = randf_range(0.25, leap_cooldown)
	leap_state = "idle"
	leap_target = global_position
	essence_value = int(config.get("essence_value", essence_value))
	contact_padding = float(config.get("contact_padding", contact_padding))
	queue_redraw()


func _ready() -> void:
	add_to_group("enemies")
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not alive or not is_instance_valid(player):
		return

	touch_timer = maxf(touch_timer - delta, 0.0)
	knockback = knockback.move_toward(Vector2.ZERO, 800.0 * delta)
	flash_timer = maxf(flash_timer - delta, 0.0)

	var to_player := player.global_position - global_position
	var direction := to_player.normalized() if to_player.length_squared() > 0.0 else Vector2.ZERO
	var frame_velocity := knockback

	match behavior:
		"chase":
			frame_velocity += direction * speed
		"ranged":
			ranged_timer = maxf(ranged_timer - delta, 0.0)
			var preferred_distance := 250.0
			if to_player.length() < preferred_distance * 0.75:
				frame_velocity -= direction * speed * 0.85
			elif to_player.length() > preferred_distance:
				frame_velocity += direction * speed * 0.65
			frame_velocity += direction.orthogonal() * sin(Time.get_ticks_msec() * 0.004) * 28.0
			if ranged_timer <= 0.0 and to_player.length() > 90.0:
				projectile_requested.emit(global_position + direction * radius, direction, {
					"speed": 340.0,
					"lifetime": 2.5,
					"radius": 8.0,
					"damage": 1,
					"tint": Color("ffd166")
				})
				ranged_timer = ranged_cooldown
		"charger":
			charge_timer = maxf(charge_timer - delta, 0.0)
			match charge_state:
				"idle":
					frame_velocity += direction * speed
					if charge_timer <= 0.0 and to_player.length() > 110.0:
						charge_state = "windup"
						charge_timer = charge_windup
						charge_direction = direction
				"windup":
					frame_velocity += charge_direction * 28.0
					if charge_timer <= 0.0:
						charge_state = "dash"
						charge_timer = charge_duration
				"dash":
					frame_velocity += charge_direction * charge_speed
					if charge_timer <= 0.0:
						charge_state = "idle"
						charge_timer = charge_cooldown
		"leaper":
			leap_timer = maxf(leap_timer - delta, 0.0)
			match leap_state:
				"idle":
					frame_velocity += direction * speed * 0.8
					if leap_timer <= 0.0 and to_player.length() > 80.0:
						leap_state = "windup"
						leap_timer = leap_windup
						leap_target = player.global_position
				"windup":
					frame_velocity -= direction * speed * 0.22
					if leap_timer <= 0.0:
						leap_state = "jump"
						leap_timer = leap_duration
				"jump":
					var leap_direction := (leap_target - global_position).normalized()
					frame_velocity += leap_direction * leap_speed
					if leap_timer <= 0.0:
						leap_state = "idle"
						leap_timer = leap_cooldown
		_:
			frame_velocity += direction * speed

	global_position += frame_velocity * delta
	_clamp_to_arena()

	if to_player.length() <= radius + contact_padding and touch_timer <= 0.0 and player.has_method("take_damage"):
		player.take_damage(touch_damage)
		touch_timer = touch_cooldown

	queue_redraw()


func take_damage(amount: int, push_direction: Vector2 = Vector2.ZERO) -> Dictionary:
	if not alive:
		return {"killed": false, "essence": 0}

	health -= amount
	knockback = push_direction.normalized() * 240.0
	flash_timer = 0.12
	queue_redraw()

	if health <= 0:
		alive = false
		died.emit(self)
		queue_free()
		return {"killed": true, "essence": essence_value}

	return {"killed": false, "essence": 0}


func _clamp_to_arena() -> void:
	var margin := radius + 12.0
	global_position.x = clampf(global_position.x, margin, arena_size.x - margin)
	global_position.y = clampf(global_position.y, margin, arena_size.y - margin)


func _draw() -> void:
	var draw_tint := Color.WHITE if flash_timer > 0.0 else tint
	draw_circle(Vector2.ZERO, radius, draw_tint)
	draw_circle(Vector2(-radius * 0.35, -4.0), 2.5, Color.BLACK)
	draw_circle(Vector2(radius * 0.35, -4.0), 2.5, Color.BLACK)
	draw_line(Vector2(-radius * 0.3, radius * 0.25), Vector2(radius * 0.3, radius * 0.25), Color("2a1212"), 2.0)
	if behavior == "ranged":
		draw_circle(Vector2.ZERO, radius * 0.45, Color("ffe7a3"))
	elif behavior == "charger":
		draw_arc(Vector2.ZERO, radius + 6.0, -0.7, 0.7, 12, Color("fff0cf"), 3.0)
		if charge_state == "windup":
			draw_line(Vector2.ZERO, charge_direction * (radius + 18.0), Color("ffffff"), 3.0)
	elif behavior == "leaper":
		draw_arc(Vector2.ZERO, radius + 5.0, -0.9, 0.9, 12, Color("b8fff5"), 3.0)
		if leap_state == "windup":
			draw_line(Vector2.ZERO, (leap_target - global_position).normalized() * (radius + 22.0), Color("e9fffb"), 3.0)

	var bar_width := radius * 2.0
	draw_rect(Rect2(Vector2(-radius, -radius - 12.0), Vector2(bar_width, 5.0)), Color("3a2323"))
	var ratio := float(health) / float(max_health)
	draw_rect(Rect2(Vector2(-radius, -radius - 12.0), Vector2(bar_width * ratio, 5.0)), Color("9bf6a7"))
