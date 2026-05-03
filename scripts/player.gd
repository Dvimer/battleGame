extends Node2D

signal slash_requested(origin: Vector2, direction: Vector2, attack_data: Dictionary)
signal shot_requested(origin: Vector2, direction: Vector2, shot_data: Dictionary)
signal health_changed(current: int, maximum: int)
signal combo_changed(count: int, timer_ratio: float)
signal weapon_changed(active_weapon: String, secondary_weapon: String)
signal died

const MOVE_SPEED := 260.0
const DASH_SPEED := 560.0
const DASH_DURATION := 0.16
const DASH_COOLDOWN := 0.8
const ATTACK_BASE_COOLDOWN := 0.28
const PISTOL_BASE_COOLDOWN := 0.24
const INVULNERABILITY_TIME := 0.65
const COMBO_TIMEOUT := 0.95
const BODY_SIZE := Vector2(18.0, 24.0)
const WEAPON_SWORD := "sword"
const WEAPON_PISTOL := "pistol"

@export var arena_size := Vector2(1280.0, 720.0)
@export var allow_attack := true
@export var allow_dash := true
@export var allow_click_move := false

var max_health := 5
var health := 5
var facing := Vector2.RIGHT
var velocity := Vector2.ZERO
var attack_cooldown := 0.0
var dash_cooldown := 0.0
var dash_timer := 0.0
var invulnerability_timer := 0.0
var attack_flash_timer := 0.0
var combo_timer := 0.0
var combo_step := 0
var attack_damage_bonus := 0
var slash_range_bonus := 0.0
var attack_cooldown_scale := 1.0
var dash_speed_bonus := 0.0
var move_speed_bonus := 0.0
var heal_on_kill := 0
var dash_charge_bonus := 0
var alive := true
var movement_locked := false
var active_weapon_id := WEAPON_SWORD
var secondary_weapon_id := ""
var ranged_damage_bonus := 0
var move_target := Vector2.ZERO
var has_move_target := false


func _ready() -> void:
	add_to_group("player_avatar")
	health_changed.emit(health, max_health)
	combo_changed.emit(combo_step, 0.0)
	weapon_changed.emit(active_weapon_id, secondary_weapon_id)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not alive:
		return

	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	dash_cooldown = maxf(dash_cooldown - delta, 0.0)
	dash_timer = maxf(dash_timer - delta, 0.0)
	invulnerability_timer = maxf(invulnerability_timer - delta, 0.0)
	attack_flash_timer = maxf(attack_flash_timer - delta, 0.0)
	combo_timer = maxf(combo_timer - delta, 0.0)
	if combo_timer <= 0.0 and combo_step != 0:
		combo_step = 0
		combo_changed.emit(combo_step, 0.0)

	var input_vector := Vector2.ZERO if movement_locked else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector.length_squared() > 0.0:
		clear_move_target()
	elif allow_click_move and has_move_target and not movement_locked:
		var to_target := move_target - global_position
		if to_target.length() <= 8.0:
			clear_move_target()
		else:
			input_vector = to_target.normalized()
	if input_vector.length_squared() > 0.0:
		facing = input_vector.normalized()

	var mouse_direction := get_global_mouse_position() - global_position
	if mouse_direction.length_squared() > 16.0:
		facing = mouse_direction.normalized()

	if Input.is_action_just_pressed("upgrade_1"):
		equip_weapon(WEAPON_SWORD)
	elif has_secondary_weapon() and Input.is_action_just_pressed("upgrade_2"):
		equip_weapon(secondary_weapon_id)

	if allow_attack and Input.is_action_just_pressed("attack") and attack_cooldown <= 0.0:
		if active_weapon_id == WEAPON_PISTOL:
			_perform_ranged_attack()
		else:
			_perform_attack()

	if allow_dash and Input.is_action_just_pressed("dash") and dash_cooldown <= 0.0 and input_vector.length_squared() > 0.0:
		dash_timer = DASH_DURATION
		dash_cooldown = DASH_COOLDOWN - minf(0.3, dash_charge_bonus * 0.08)
		invulnerability_timer = 0.2

	var speed := DASH_SPEED + dash_speed_bonus if dash_timer > 0.0 else MOVE_SPEED + move_speed_bonus
	velocity = input_vector * speed
	global_position += velocity * delta
	_clamp_to_arena()

	var combo_ratio := combo_timer / COMBO_TIMEOUT if combo_step > 0 else 0.0
	combo_changed.emit(combo_step, combo_ratio)
	queue_redraw()


func _perform_attack() -> void:
	combo_step = 1 if combo_timer <= 0.0 else clampi(combo_step + 1, 1, 3)
	combo_timer = COMBO_TIMEOUT
	attack_flash_timer = 0.16
	attack_cooldown = ATTACK_BASE_COOLDOWN * attack_cooldown_scale
	var attack_data := {
		"combo_step": combo_step,
		"damage": 1 + attack_damage_bonus + max(0, combo_step - 1),
		"range": 82.0 + slash_range_bonus + combo_step * 8.0,
		"arc_cos": 0.26 - combo_step * 0.04,
		"knockback": 240.0 + combo_step * 70.0,
		"life_steal": heal_on_kill,
		"color": [Color("fff3b0"), Color("9df3ff"), Color("ff9bd1")][combo_step - 1]
	}
	slash_requested.emit(global_position + facing * 18.0, facing, attack_data)
	combo_changed.emit(combo_step, 1.0)


func _perform_ranged_attack() -> void:
	combo_step = 0
	combo_timer = 0.0
	combo_changed.emit(combo_step, 0.0)
	attack_flash_timer = 0.1
	attack_cooldown = PISTOL_BASE_COOLDOWN * attack_cooldown_scale
	var shot_data := {
		"damage": 1 + ranged_damage_bonus + attack_damage_bonus,
		"speed": 760.0,
		"lifetime": 1.15,
		"radius": 7.0,
		"knockback": 180.0,
		"tint": Color("9df3ff")
	}
	shot_requested.emit(global_position + facing * 20.0, facing, shot_data)


func has_secondary_weapon() -> bool:
	return secondary_weapon_id != ""


func unlock_secondary_weapon(weapon_id: String) -> void:
	secondary_weapon_id = weapon_id
	weapon_changed.emit(active_weapon_id, secondary_weapon_id)


func equip_weapon(weapon_id: String) -> void:
	if weapon_id == WEAPON_SWORD:
		active_weapon_id = WEAPON_SWORD
	elif weapon_id == secondary_weapon_id and has_secondary_weapon():
		active_weapon_id = secondary_weapon_id
	else:
		return

	combo_step = 0
	combo_timer = 0.0
	combo_changed.emit(combo_step, 0.0)
	weapon_changed.emit(active_weapon_id, secondary_weapon_id)
	queue_redraw()


func get_active_weapon_id() -> String:
	return active_weapon_id


func get_secondary_weapon_id() -> String:
	return secondary_weapon_id


func heal(amount: int) -> void:
	if amount <= 0 or not alive:
		return

	health = mini(max_health, health + amount)
	health_changed.emit(health, max_health)
	queue_redraw()


func take_damage(amount: int) -> void:
	if not alive or invulnerability_timer > 0.0:
		return

	health = maxi(health - amount, 0)
	invulnerability_timer = INVULNERABILITY_TIME
	health_changed.emit(health, max_health)
	queue_redraw()

	if health <= 0:
		alive = false
		died.emit()


func apply_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"edge":
			attack_damage_bonus += 1
			ranged_damage_bonus += 1
		"haste":
			attack_cooldown_scale = maxf(0.72, attack_cooldown_scale - 0.08)
			move_speed_bonus += 14.0
		"reach":
			slash_range_bonus += 18.0
		"blood":
			heal_on_kill += 1
		"vigor":
			max_health += 1
			health += 1
			health_changed.emit(health, max_health)
		"blink":
			dash_speed_bonus += 120.0
			dash_charge_bonus += 1
		_:
			pass


func apply_run_setup(setup: Dictionary) -> void:
	attack_damage_bonus += int(setup.get("attack_damage_bonus", 0))
	slash_range_bonus += float(setup.get("slash_range_bonus", 0.0))
	move_speed_bonus += float(setup.get("move_speed_bonus", 0.0))
	dash_speed_bonus += float(setup.get("dash_speed_bonus", 0.0))
	dash_charge_bonus += int(setup.get("dash_charge_bonus", 0))
	if int(setup.get("max_health_bonus", 0)) > 0:
		max_health += int(setup.get("max_health_bonus", 0))
		health = mini(max_health, health + int(setup.get("max_health_bonus", 0)))
	if int(setup.get("heal_on_kill", 0)) > 0:
		heal_on_kill += int(setup.get("heal_on_kill", 0))
	health_changed.emit(health, max_health)
	queue_redraw()


func set_movement_locked(value: bool) -> void:
	movement_locked = value
	if movement_locked:
		velocity = Vector2.ZERO
		clear_move_target()


func set_move_target(target: Vector2) -> void:
	move_target = target
	has_move_target = true


func clear_move_target() -> void:
	has_move_target = false


func reset_for_run(start_position: Vector2) -> void:
	global_position = start_position
	max_health = 5
	health = max_health
	facing = Vector2.RIGHT
	velocity = Vector2.ZERO
	attack_cooldown = 0.0
	dash_cooldown = 0.0
	dash_timer = 0.0
	invulnerability_timer = 0.0
	attack_flash_timer = 0.0
	combo_timer = 0.0
	combo_step = 0
	attack_damage_bonus = 0
	slash_range_bonus = 0.0
	attack_cooldown_scale = 1.0
	dash_speed_bonus = 0.0
	move_speed_bonus = 0.0
	heal_on_kill = 0
	dash_charge_bonus = 0
	alive = true
	active_weapon_id = WEAPON_SWORD
	secondary_weapon_id = ""
	ranged_damage_bonus = 0
	clear_move_target()
	health_changed.emit(health, max_health)
	combo_changed.emit(combo_step, 0.0)
	weapon_changed.emit(active_weapon_id, secondary_weapon_id)
	queue_redraw()


func _clamp_to_arena() -> void:
	var margin := 36.0
	global_position.x = clampf(global_position.x, margin, arena_size.x - margin)
	global_position.y = clampf(global_position.y, margin, arena_size.y - margin)


func _draw() -> void:
	var body_color := Color("7ce7ff")
	if invulnerability_timer > 0.0 and int(invulnerability_timer * 20.0) % 2 == 0:
		body_color = Color("ffffff")
	draw_rect(Rect2(-BODY_SIZE / 2.0, BODY_SIZE), body_color)
	draw_rect(Rect2(Vector2(-BODY_SIZE.x * 0.35, -BODY_SIZE.y * 0.8), Vector2(BODY_SIZE.x * 0.7, BODY_SIZE.y * 0.4)), Color("d5f5ff"))

	if active_weapon_id == WEAPON_PISTOL:
		var gun_tip := facing * 22.0
		var gun_color := Color("9df3ff") if attack_flash_timer > 0.0 else Color("a6b6cf")
		draw_line(facing * 8.0, gun_tip, gun_color, 6.0)
		draw_circle(gun_tip, 4.0, gun_color)
	else:
		var sword_tip := facing * 28.0
		var sword_color := Color("fff3b0") if attack_flash_timer > 0.0 else Color("d9d9d9")
		draw_line(facing * 8.0, sword_tip, sword_color, 5.0)
		draw_circle(sword_tip, 3.0, sword_color)
	if combo_step > 0:
		draw_arc(Vector2.ZERO, 30.0 + combo_step * 4.0, 0.0, TAU * clampf(combo_timer / COMBO_TIMEOUT, 0.08, 1.0), 18, Color(1.0, 1.0, 1.0, 0.18), 3.0)
