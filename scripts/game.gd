extends Node2D

const ARENA_SIZE := Vector2(1920.0, 1080.0)
const PLAYER_START := Vector2(960.0, 540.0)
const TOTAL_WAVES := 5
const WAVE_CLEAR_DELAY := 0.75
const RETURN_TO_TOWN_DELAY := 1.5
const UPGRADE_POOL := [
	{"id": "edge", "name_key": "upgrade.edge.name", "desc_key": "upgrade.edge.desc", "variant": "damage"},
	{"id": "haste", "name_key": "upgrade.haste.name", "desc_key": "upgrade.haste.desc", "variant": "tempo"},
	{"id": "reach", "name_key": "upgrade.reach.name", "desc_key": "upgrade.reach.desc", "variant": "range"},
	{"id": "blood", "name_key": "upgrade.blood.name", "desc_key": "upgrade.blood.desc", "variant": "sustain"},
	{"id": "vigor", "name_key": "upgrade.vigor.name", "desc_key": "upgrade.vigor.desc", "variant": "vitality"},
	{"id": "blink", "name_key": "upgrade.blink.name", "desc_key": "upgrade.blink.desc", "variant": "mobility"}
]
const NORMAL_ROOM_TEMPLATES := [
	{
		"id": "gauntlet",
		"tier": 1,
		"enemy_count": 5,
		"guaranteed": ["Striker", "Striker"],
		"pool": ["Striker", "Skitter", "Bulwark"],
		"reinforcements": 1,
		"reinforcement_pool": ["Striker", "Skitter"]
	},
	{
		"id": "battery",
		"tier": 2,
		"enemy_count": 6,
		"guaranteed": ["Hexer"],
		"pool": ["Striker", "Bulwark", "Spitter", "Skitter"],
		"reinforcements": 2,
		"reinforcement_pool": ["Skitter", "Spitter", "Hexer"]
	},
	{
		"id": "hunt",
		"tier": 2,
		"enemy_count": 6,
		"guaranteed": ["Leaper"],
		"pool": ["Striker", "Skitter", "Bulwark", "Leaper"],
		"reinforcements": 2,
		"reinforcement_pool": ["Skitter", "Leaper"]
	},
	{
		"id": "crush",
		"tier": 3,
		"enemy_count": 6,
		"guaranteed": ["Bulwark", "Bulwark"],
		"pool": ["Striker", "Leaper", "Skitter"],
		"reinforcements": 1,
		"reinforcement_pool": ["Bulwark", "Leaper"]
	},
	{
		"id": "storm",
		"tier": 3,
		"enemy_count": 7,
		"guaranteed": ["Spitter", "Hexer"],
		"pool": ["Striker", "Leaper", "Skitter", "Bulwark"],
		"reinforcements": 2,
		"reinforcement_pool": ["Spitter", "Hexer", "Leaper"]
	},
	{
		"id": "ambush",
		"tier": 4,
		"enemy_count": 7,
		"guaranteed": ["Bulwark", "Leaper"],
		"pool": ["Striker", "Skitter", "Hexer", "Spitter"],
		"reinforcements": 2,
		"reinforcement_pool": ["Leaper", "Spitter", "Skitter"]
	}
]
const BOSS_ROOM_TEMPLATE := {
	"id": "warlord_keep",
	"tier": 5,
	"enemy_count": 4,
	"guaranteed": ["Warlord", "Hexer"],
	"pool": ["Leaper", "Bulwark", "Spitter"],
	"reinforcements": 2,
	"reinforcement_pool": ["Leaper", "Hexer", "Spitter"]
}

const ENEMY_ARCHETYPES := [
	{
		"name": "Striker",
		"behavior": "chase",
		"speed": 120.0,
		"max_health": 2,
		"touch_damage": 1,
		"touch_cooldown": 0.8,
		"radius": 18.0,
		"tint": Color("ff6b6b"),
		"essence_value": 1
	},
	{
		"name": "Brute",
		"behavior": "chase",
		"speed": 82.0,
		"max_health": 4,
		"touch_damage": 1,
		"touch_cooldown": 1.0,
		"radius": 24.0,
		"tint": Color("ff9f43"),
		"essence_value": 2,
		"contact_padding": 22.0
	},
	{
		"name": "Skitter",
		"behavior": "chase",
		"speed": 172.0,
		"max_health": 1,
		"touch_damage": 1,
		"touch_cooldown": 0.65,
		"radius": 14.0,
		"tint": Color("ffd166"),
		"essence_value": 1,
		"contact_padding": 14.0
	},
	{
		"name": "Bulwark",
		"behavior": "chase",
		"speed": 72.0,
		"max_health": 7,
		"touch_damage": 1,
		"touch_cooldown": 1.05,
		"radius": 28.0,
		"tint": Color("9c88ff"),
		"essence_value": 3,
		"contact_padding": 26.0
	},
	{
		"name": "Hexer",
		"behavior": "ranged",
		"speed": 98.0,
		"max_health": 3,
		"touch_damage": 1,
		"touch_cooldown": 0.9,
		"radius": 20.0,
		"tint": Color("b794f6"),
		"essence_value": 2,
		"ranged_cooldown": 2.1
	},
	{
		"name": "Spitter",
		"behavior": "ranged",
		"speed": 92.0,
		"max_health": 3,
		"touch_damage": 1,
		"touch_cooldown": 0.85,
		"radius": 18.0,
		"tint": Color("7bd389"),
		"essence_value": 2,
		"ranged_cooldown": 1.35
	},
	{
		"name": "Lancer",
		"behavior": "charger",
		"speed": 110.0,
		"max_health": 4,
		"touch_damage": 1,
		"touch_cooldown": 0.9,
		"radius": 22.0,
		"tint": Color("7dd3fc"),
		"essence_value": 3,
		"charge_cooldown": 2.5,
		"charge_speed": 500.0,
		"charge_duration": 0.42,
		"charge_windup": 0.45
	},
	{
		"name": "Leaper",
		"behavior": "leaper",
		"speed": 104.0,
		"max_health": 3,
		"touch_damage": 1,
		"touch_cooldown": 0.75,
		"radius": 19.0,
		"tint": Color("76e4f7"),
		"essence_value": 2,
		"contact_padding": 18.0,
		"leap_cooldown": 1.75,
		"leap_speed": 520.0,
		"leap_duration": 0.22,
		"leap_windup": 0.32
	},
	{
		"name": "Warlord",
		"behavior": "charger",
		"speed": 104.0,
		"max_health": 18,
		"touch_damage": 2,
		"touch_cooldown": 0.75,
		"radius": 34.0,
		"tint": Color("ff4d6d"),
		"essence_value": 8,
		"contact_padding": 30.0,
		"charge_cooldown": 1.8,
		"charge_speed": 560.0,
		"charge_duration": 0.6,
		"charge_windup": 0.35
	}
]

@onready var player := $Player
@onready var camera: Camera2D = $Camera2D
@onready var health_label: Label = $HUD/HealthLabel
@onready var wave_label: Label = $HUD/WaveLabel
@onready var essence_label: Label = $HUD/EssenceLabel
@onready var combo_label: Label = $HUD/ComboLabel
@onready var weapon_label: Label = $HUD/WeaponLabel
@onready var status_label: Label = $HUD/StatusLabel
@onready var objective_label: Label = $HUD/ObjectiveLabel
@onready var hint_label: Label = $HUD/HintLabel
@onready var center_banner: Label = $HUD/CenterBanner

var enemy_scene := preload("res://scenes/enemy.tscn")
var projectile_scene := preload("res://scenes/projectile.tscn")
var player_projectile_scene := preload("res://scenes/player_projectile.tscn")
var rng := RandomNumberGenerator.new()
var wave := 0
var between_wave_timer := 0.0
var state := "intro"
var slash_effect_timer := 0.0
var slash_effect_origin := Vector2.ZERO
var slash_effect_direction := Vector2.RIGHT
var slash_effect_range := 84.0
var slash_effect_color := Color("fff3b0")
var pending_upgrade_choices: Array = []
var essence := 0
var kills := 0
var camera_shake := 0.0
var banner_timer := 0.0
var combo_peak := 0
var active_enemies: Array[Node2D] = []
var wave_clear_timer := 0.0
var return_home_timer := 0.0
var expedition_setup: Dictionary = {}
var expedition_reward_sent := false
var current_banner_key := ""
var current_banner_params := {}
var room_sequence: Array = []
var current_room_plan: Dictionary = {}
var reinforcements_left := 0
var reinforcement_timer := 0.0


func _world_state() -> Node:
	return get_node_or_null("/root/WorldState")


func _menu_manager() -> Node:
	return get_node_or_null("/root/MenuManager")


func _localizer() -> Node:
	return get_node_or_null("/root/Localizer")


func _scene_router() -> Node:
	return get_node_or_null("/root/SceneRouter")


func _ready() -> void:
	var world_state := _world_state()
	var menu_manager := _menu_manager()

	rng.randomize()
	player.arena_size = ARENA_SIZE
	player.health_changed.connect(_on_player_health_changed)
	player.combo_changed.connect(_on_player_combo_changed)
	player.slash_requested.connect(_on_player_slash_requested)
	player.shot_requested.connect(_on_player_shot_requested)
	player.weapon_changed.connect(_on_player_weapon_changed)
	player.died.connect(_on_player_died)
	player.set_movement_locked(false)
	var scene_router := _scene_router()
	if scene_router != null:
		scene_router.apply_spawn(player, player.global_position)

	if menu_manager != null and not menu_manager.menu_state_changed.is_connected(_on_menu_state_changed):
		menu_manager.menu_state_changed.connect(_on_menu_state_changed)
	var localizer := _localizer()
	if localizer != null and not localizer.language_changed.is_connected(_on_language_changed):
		localizer.language_changed.connect(_on_language_changed)

	camera.position = PLAYER_START
	if world_state != null:
		expedition_setup = world_state.consume_expedition_setup()
	_start_new_run()


func _physics_process(delta: float) -> void:
	var tree := get_tree()
	if tree == null:
		return

	slash_effect_timer = maxf(slash_effect_timer - delta, 0.0)
	camera_shake = maxf(camera_shake - delta * 4.0, 0.0)
	banner_timer = maxf(banner_timer - delta, 0.0)
	if banner_timer <= 0.0 and state not in ["upgrade", "defeat", "victory"]:
		center_banner.text = ""

	if state == "between_waves":
		between_wave_timer -= delta
		if between_wave_timer <= 0.0:
			_spawn_wave()
	elif state == "wave_clear":
		wave_clear_timer -= delta
		if wave_clear_timer <= 0.0:
			_finish_wave_clear()
	elif state == "combat":
		_prune_active_enemies()
		_process_reinforcements(delta)
		if active_enemies.is_empty() and reinforcements_left <= 0:
			_check_wave_completion()
	elif state in ["defeat", "victory"]:
		return_home_timer -= delta
		if return_home_timer <= 0.0:
			var scene_router := _scene_router()
			if scene_router != null:
				scene_router.go_to_scene("res://scenes/main.tscn", "hub_city_return")
			else:
				tree.change_scene_to_file("res://scenes/main.tscn")

	if state in ["defeat", "victory"] and Input.is_action_just_pressed("restart"):
		_start_new_run()

	_update_camera()
	queue_redraw()


func _start_new_run() -> void:
	var menu_manager := _menu_manager()
	if menu_manager != null and menu_manager.is_open():
		menu_manager.close_menu()

	_clear_enemies()
	_clear_projectiles()
	wave = 0
	essence = 0
	kills = 0
	combo_peak = 0
	active_enemies.clear()
	wave_clear_timer = 0.0
	return_home_timer = 0.0
	expedition_reward_sent = false
	reinforcements_left = 0
	reinforcement_timer = 0.0
	current_room_plan = {}
	room_sequence = _build_room_sequence()
	state = "between_waves"
	between_wave_timer = 0.8
	pending_upgrade_choices.clear()
	player.reset_for_run(PLAYER_START)
	player.apply_run_setup(expedition_setup)
	_update_essence_label()
	_update_wave_label()
	_on_player_weapon_changed(player.get_active_weapon_id(), player.get_secondary_weapon_id())
	_show_banner_key("run.title", {}, 1.2)
	var localizer := _localizer()
	status_label.text = localizer.t("run.status.start") if localizer != null else "Arena online. First wave is forming..."
	objective_label.text = localizer.t("run.objective.start") if localizer != null else "Survive five waves and break the Warlord in the final round."
	var world_state := _world_state()
	var setup_summary: String = world_state.describe_next_run_bonus() if world_state != null else ""
	hint_label.text = localizer.t("run.hint.start") if localizer != null else "WASD move, LMB attack, Space dash. After the first room, use 1 and 2 to switch weapons."
	if setup_summary != "":
		status_label.text = localizer.t("run.status.city_buffs", {"value": setup_summary}) if localizer != null else "City buffs active: %s." % setup_summary


func _spawn_wave() -> void:
	wave += 1
	_update_wave_label()
	state = "combat"
	current_room_plan = room_sequence[wave - 1] if wave - 1 < room_sequence.size() else BOSS_ROOM_TEMPLATE
	var composition := _compose_room_enemies(current_room_plan)
	reinforcements_left = int(current_room_plan.get("reinforcements", 0))
	_schedule_next_reinforcement()
	for archetype_name in composition:
		_spawn_enemy_by_name(archetype_name)

	var localizer := _localizer()
	status_label.text = localizer.t("run.status.wave", {"value": wave}) if localizer != null else "Wave %d: hold the center and cut them down." % wave
	_refresh_combat_objective()
	_show_banner_key("run.banner.wave", {"value": wave}, 0.9)


func _on_enemy_died(_enemy: Node2D) -> void:
	_prune_active_enemies()
	_refresh_combat_objective()
	call_deferred("_check_wave_completion")


func _check_wave_completion() -> void:
	_prune_active_enemies()
	var remaining := active_enemies.size() + reinforcements_left
	var localizer := _localizer()
	if remaining > 0:
		status_label.text = localizer.t("run.status.remaining", {"value": remaining}) if localizer != null else "%d enemies still standing." % remaining
		_refresh_combat_objective()
		return

	if wave >= TOTAL_WAVES:
		state = "victory"
		_clear_projectiles()
		center_banner.text = "Arena Cleared"
		var stored := 0
		var world_state := _world_state()
		if not expedition_reward_sent and world_state != null:
			stored = world_state.stash_city_reward(essence + kills + wave * 3)
			expedition_reward_sent = true
		if world_state != null:
			world_state.set_town_message("town.message.victory", {"value": stored})
		status_label.text = localizer.t("run.status.victory", {"kills": kills, "essence": essence, "time": "%.1f" % RETURN_TO_TOWN_DELAY}) if localizer != null else "Victory. %d foes destroyed, %d essence harvested. Recall to town in %.1f..." % [kills, essence, RETURN_TO_TOWN_DELAY]
		objective_label.text = localizer.t("run.objective.victory", {"kills": kills, "combo": combo_peak}) if localizer != null else "Final score: %d kills, combo peak x%d" % [kills, combo_peak]
		hint_label.text = localizer.t("run.hint.victory") if localizer != null else "The recall sigil is active. Your reward is waiting in the base chest."
		return_home_timer = RETURN_TO_TOWN_DELAY
	else:
		_clear_projectiles()
		state = "wave_clear"
		wave_clear_timer = WAVE_CLEAR_DELAY
		status_label.text = localizer.t("run.status.wave_clear", {"value": wave}) if localizer != null else "Wave %d cleared. Catch your breath..." % wave
		objective_label.text = localizer.t("run.objective.upgrade_incoming") if localizer != null else "Skill draft incoming..."
		_show_banner_key("run.banner.wave_clear", {"value": wave}, WAVE_CLEAR_DELAY)


func _on_player_slash_requested(origin: Vector2, direction: Vector2, attack_data: Dictionary) -> void:
	var tree := get_tree()
	if tree == null:
		return

	slash_effect_origin = origin
	slash_effect_direction = direction.normalized()
	slash_effect_timer = 0.14
	slash_effect_range = float(attack_data.get("range", 84.0))
	slash_effect_color = Color(attack_data.get("color", Color("fff3b0")))

	var hits := 0
	var kills_from_swing := 0
	var essence_gained := 0
	for enemy in tree.get_nodes_in_group("enemies"):
		var to_enemy: Vector2 = enemy.global_position - origin
		var distance := to_enemy.length()
		if distance > slash_effect_range or distance <= 0.001:
			continue

		var alignment := slash_effect_direction.dot(to_enemy.normalized())
		if alignment < float(attack_data.get("arc_cos", 0.15)):
			continue

		var result: Dictionary = enemy.take_damage(int(attack_data.get("damage", 1)), slash_effect_direction * float(attack_data.get("knockback", 240.0)))
		hits += 1
		if bool(result.get("killed", false)):
			kills_from_swing += 1
			var gained := int(result.get("essence", 0))
			essence += gained
			essence_gained += gained
			kills += 1
			if int(attack_data.get("life_steal", 0)) > 0:
				player.heal(int(attack_data.get("life_steal", 0)))

	if hits == 0:
		var localizer := _localizer()
		status_label.text = localizer.t("run.status.air") if localizer != null else "Your blade cut air. Keep moving."
	else:
		var localizer := _localizer()
		status_label.text = localizer.t("run.status.hit", {"value": hits}) if localizer != null else "Clean slash. %d hits landed." % hits
		camera_shake = minf(camera_shake + 0.7 + hits * 0.18 + kills_from_swing * 0.25, 2.2)
		if kills_from_swing > 0:
			_show_banner_key("run.banner.execution", {"value": essence_gained}, 0.4)
	_update_essence_label()


func _on_player_shot_requested(origin: Vector2, direction: Vector2, shot_data: Dictionary) -> void:
	if state != "combat":
		return

	var projectile = player_projectile_scene.instantiate()
	add_child(projectile)
	projectile.arena_size = ARENA_SIZE
	projectile.configure(origin, direction, shot_data)
	status_label.text = _localizer().t("run.status.shot") if _localizer() != null else "Shots fired. Keep your spacing."


func _on_player_weapon_changed(active_weapon: String, secondary_weapon: String) -> void:
	var localizer := _localizer()
	var primary_name := _weapon_name("sword")
	var secondary_name := _weapon_name(secondary_weapon) if secondary_weapon != "" else "-"
	var active_name := _weapon_name(active_weapon)
	weapon_label.text = localizer.t("run.weapon.label", {
		"active": active_name,
		"primary": primary_name,
		"secondary": secondary_name
	}) if localizer != null else "Weapon: %s  |  1 %s  2 %s" % [active_name, primary_name, secondary_name]


func _on_player_health_changed(current: int, maximum: int) -> void:
	var localizer := _localizer()
	health_label.text = localizer.t("run.health", {"current": current, "max": maximum}) if localizer != null else "HP: %d / %d" % [current, maximum]


func _on_player_combo_changed(count: int, timer_ratio: float) -> void:
	if count <= 0:
		var localizer := _localizer()
		combo_label.text = localizer.t("run.combo.idle") if localizer != null else "Combo: idle"
		return

	var localizer := _localizer()
	combo_label.text = localizer.t("run.combo.active", {"count": count, "value": int(timer_ratio * 100.0)}) if localizer != null else "Combo: x%d  %d%%" % [count, int(timer_ratio * 100.0)]
	combo_peak = maxi(combo_peak, count)


func _on_player_died() -> void:
	state = "defeat"
	_clear_projectiles()
	var menu_manager := _menu_manager()
	if menu_manager != null and menu_manager.is_open():
		menu_manager.close_menu()
	var world_state := _world_state()
	if world_state != null:
		world_state.set_town_message("town.message.defeat")
	var localizer := _localizer()
	center_banner.text = localizer.t("run.banner.failed") if localizer != null else "Run Failed"
	status_label.text = localizer.t("run.status.defeat", {"wave": max(wave, 1), "time": "%.1f" % RETURN_TO_TOWN_DELAY}) if localizer != null else "You fell in battle on wave %d. Returning to town in %.1f..." % [max(wave, 1), RETURN_TO_TOWN_DELAY]
	objective_label.text = localizer.t("run.objective.defeat", {"kills": kills, "essence": essence}) if localizer != null else "Final score: %d kills, %d essence." % [kills, essence]
	hint_label.text = localizer.t("run.hint.defeat") if localizer != null else "Rest, trade, and try again from the city gate."
	return_home_timer = RETURN_TO_TOWN_DELAY


func _update_wave_label() -> void:
	if wave <= 0:
		var localizer := _localizer()
		wave_label.text = localizer.t("run.wave.label_zero", {"value": TOTAL_WAVES}) if localizer != null else "Wave 0 / %d" % TOTAL_WAVES
	else:
		var localizer := _localizer()
		wave_label.text = localizer.t("run.wave.label", {"current": wave, "total": TOTAL_WAVES}) if localizer != null else "Wave %d / %d" % [wave, TOTAL_WAVES]


func _clear_enemies() -> void:
	active_enemies.clear()
	reinforcements_left = 0
	reinforcement_timer = 0.0
	var tree := get_tree()
	if tree == null:
		return
	for enemy in tree.get_nodes_in_group("enemies"):
		enemy.queue_free()


func _clear_projectiles() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for projectile in tree.get_nodes_in_group("enemy_projectiles"):
		projectile.queue_free()


func _random_spawn_position() -> Vector2:
	var margin := 100.0
	for _attempt in 8:
		var candidate := Vector2.ZERO
		match rng.randi_range(0, 3):
			0:
				candidate = Vector2(rng.randf_range(margin, ARENA_SIZE.x - margin), margin)
			1:
				candidate = Vector2(ARENA_SIZE.x - margin, rng.randf_range(margin, ARENA_SIZE.y - margin))
			2:
				candidate = Vector2(rng.randf_range(margin, ARENA_SIZE.x - margin), ARENA_SIZE.y - margin)
			_:
				candidate = Vector2(margin, rng.randf_range(margin, ARENA_SIZE.y - margin))
		if not is_instance_valid(player) or candidate.distance_to(player.global_position) >= 240.0:
			return candidate
	return Vector2(rng.randf_range(margin, ARENA_SIZE.x - margin), margin)

func _spawn_enemy_by_name(archetype_name: String, spawn_position := Vector2(-1.0, -1.0)) -> void:
	var enemy = enemy_scene.instantiate()
	var archetype := _find_archetype(archetype_name)
	add_child(enemy)
	active_enemies.append(enemy)
	enemy.arena_size = ARENA_SIZE
	enemy.global_position = spawn_position if spawn_position.x >= 0.0 else _random_spawn_position()
	enemy.configure(player, archetype)
	enemy.died.connect(_on_enemy_died)
	enemy.projectile_requested.connect(_on_enemy_projectile_requested)


func _prune_active_enemies() -> void:
	var survivors: Array[Node2D] = []
	for enemy in active_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			survivors.append(enemy)
	active_enemies = survivors


func _find_archetype(archetype_name: String) -> Dictionary:
	for archetype in ENEMY_ARCHETYPES:
		if archetype["name"] == archetype_name:
			return archetype
	return ENEMY_ARCHETYPES[0]


func _build_room_sequence() -> Array:
	var draft: Array = NORMAL_ROOM_TEMPLATES.duplicate(true)
	for index in range(draft.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temp = draft[index]
		draft[index] = draft[swap_index]
		draft[swap_index] = temp

	var sequence: Array = []
	for index in range(TOTAL_WAVES - 1):
		sequence.append(draft[index % draft.size()].duplicate(true))
	sequence.append(BOSS_ROOM_TEMPLATE.duplicate(true))
	return sequence


func _compose_room_enemies(room_plan: Dictionary) -> Array:
	var composition: Array = []
	for enemy_name in room_plan.get("guaranteed", []):
		composition.append(enemy_name)

	var pool: Array = room_plan.get("pool", [])
	var target_count := int(room_plan.get("enemy_count", composition.size()))
	while composition.size() < target_count and not pool.is_empty():
		composition.append(pool[rng.randi_range(0, pool.size() - 1)])
	return composition


func _process_reinforcements(delta: float) -> void:
	if reinforcements_left <= 0:
		return

	reinforcement_timer = maxf(reinforcement_timer - delta, 0.0)
	if active_enemies.is_empty():
		reinforcement_timer = minf(reinforcement_timer, 0.35)
	if reinforcement_timer > 0.0:
		return

	var reinforcement_pool: Array = current_room_plan.get("reinforcement_pool", current_room_plan.get("pool", []))
	if reinforcement_pool.is_empty():
		reinforcements_left = 0
		return

	_spawn_enemy_by_name(reinforcement_pool[rng.randi_range(0, reinforcement_pool.size() - 1)])
	reinforcements_left = maxi(reinforcements_left - 1, 0)
	_schedule_next_reinforcement()
	_refresh_combat_objective()


func _schedule_next_reinforcement() -> void:
	reinforcement_timer = rng.randf_range(1.25, 2.8) if reinforcements_left > 0 else 0.0


func _refresh_combat_objective() -> void:
	if state != "combat":
		return
	var remaining := active_enemies.size() + reinforcements_left
	var localizer := _localizer()
	objective_label.text = localizer.t("run.objective.remaining", {"value": remaining}) if localizer != null else "Enemies remaining: %d" % remaining


func _on_enemy_projectile_requested(spawn_position: Vector2, direction: Vector2, config: Dictionary) -> void:
	if state != "combat":
		return

	var projectile = projectile_scene.instantiate()
	add_child(projectile)
	projectile.arena_size = ARENA_SIZE
	projectile.configure(player, spawn_position, direction, config)
	projectile.hit_player.connect(_on_projectile_hit_player)


func _on_projectile_hit_player() -> void:
	camera_shake = minf(camera_shake + 0.55, 1.8)


func _update_essence_label() -> void:
	var localizer := _localizer()
	essence_label.text = localizer.t("run.essence", {"value": essence}) if localizer != null else "Essence: %d" % essence


func _prepare_upgrade_choices() -> void:
	pending_upgrade_choices.clear()
	var pool := UPGRADE_POOL.duplicate()
	for _i in 3:
		if pool.is_empty():
			break
		var pick_index := rng.randi_range(0, pool.size() - 1)
		pending_upgrade_choices.append(pool[pick_index])
		pool.remove_at(pick_index)

	var menu_manager := _menu_manager()
	if menu_manager == null or pending_upgrade_choices.size() < 3:
		return

	player.set_movement_locked(true)
	var localizer := _localizer()
	center_banner.text = localizer.t("run.menu.upgrade.title") if localizer != null else "Choose Upgrade"
	status_label.text = localizer.t("run.menu.upgrade.status") if localizer != null else "Wave paused. Pick an upgrade to continue."
	objective_label.text = localizer.t("run.menu.upgrade.objective") if localizer != null else "Click one of the upgrade cards."
	hint_label.text = localizer.t("run.menu.upgrade.hint") if localizer != null else "Each color hints at the bonus type: damage, tempo, range, sustain, vitality, or mobility."

	var actions: Array = []
	for upgrade in pending_upgrade_choices:
		actions.append({
			"label": "%s\n%s" % [_upgrade_name(upgrade), _upgrade_desc(upgrade)],
			"variant": str(upgrade.get("variant", "neutral")),
			"callback": Callable(self, "_apply_upgrade_by_id").bind(str(upgrade["id"]))
		})

	menu_manager.open_menu({
		"title": localizer.t("run.menu.upgrade.title") if localizer != null else "Choose Upgrade",
		"body": localizer.t("run.menu.upgrade.body") if localizer != null else "The arena pauses between breaches. Pick one upgrade, then the next wave loads in.",
		"actions": actions,
		"closable": false,
		"close_on_backdrop": false
	})


func _apply_upgrade_by_id(upgrade_id: String) -> void:
	if state != "upgrade":
		return

	var chosen_name := upgrade_id
	for upgrade in pending_upgrade_choices:
		if str(upgrade["id"]) == upgrade_id:
			chosen_name = _upgrade_name(upgrade)
			break

	var menu_manager := _menu_manager()
	if menu_manager != null and menu_manager.is_open():
		menu_manager.close_menu()

	player.apply_upgrade(upgrade_id)
	player.set_movement_locked(false)
	pending_upgrade_choices.clear()
	state = "between_waves"
	between_wave_timer = 1.0
	var localizer := _localizer()
	status_label.text = localizer.t("run.status.upgrade_applied", {"value": chosen_name}) if localizer != null else "%s installed. Next wave is assembling..." % chosen_name
	objective_label.text = localizer.t("run.objective.prepare") if localizer != null else "Prepare for the next breach."
	_show_banner(chosen_name, 0.9)
	_update_essence_label()


func _finish_wave_clear() -> void:
	if state != "wave_clear":
		return
	if wave == 1 and not player.has_secondary_weapon():
		state = "weapon_pick"
		_prepare_weapon_choice()
		return
	state = "upgrade"
	_prepare_upgrade_choices()


func _on_menu_state_changed(is_open: bool) -> void:
	if state in ["upgrade", "weapon_pick"]:
		player.set_movement_locked(is_open)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and state == "wave_clear":
		wave_clear_timer = maxf(wave_clear_timer, 0.2)


func _show_banner(text: String, duration: float) -> void:
	center_banner.text = text
	banner_timer = duration


func _show_banner_key(key: String, params: Dictionary, duration: float) -> void:
	current_banner_key = key
	current_banner_params = params.duplicate()
	var localizer := _localizer()
	center_banner.text = localizer.t(key, params) if localizer != null else key
	banner_timer = duration


func _upgrade_name(upgrade: Dictionary) -> String:
	var localizer := _localizer()
	return localizer.t(str(upgrade.get("name_key", ""))) if localizer != null else str(upgrade.get("id", "upgrade"))


func _upgrade_desc(upgrade: Dictionary) -> String:
	var localizer := _localizer()
	return localizer.t(str(upgrade.get("desc_key", ""))) if localizer != null else str(upgrade.get("id", "upgrade"))


func _on_language_changed(_language: String) -> void:
	_update_wave_label()
	_update_essence_label()
	_on_player_health_changed(player.health, player.max_health)
	_on_player_combo_changed(player.combo_step, player.combo_timer / player.COMBO_TIMEOUT if player.combo_step > 0 else 0.0)
	_on_player_weapon_changed(player.get_active_weapon_id(), player.get_secondary_weapon_id())
	if banner_timer > 0.0 and current_banner_key != "":
		var localizer := _localizer()
		if localizer != null:
			center_banner.text = localizer.t(current_banner_key, current_banner_params)


func _prepare_weapon_choice() -> void:
	var menu_manager := _menu_manager()
	if menu_manager == null:
		return

	player.set_movement_locked(true)
	var localizer := _localizer()
	center_banner.text = localizer.t("run.menu.weapon.title") if localizer != null else "Choose Weapon"
	status_label.text = localizer.t("run.menu.weapon.status") if localizer != null else "The next room waits. Pick a sidearm or keep the blade."
	objective_label.text = localizer.t("run.menu.weapon.objective") if localizer != null else "Choose your second slot for this run."
	hint_label.text = localizer.t("run.menu.weapon.hint") if localizer != null else "1 always returns to the sword. 2 switches to the second slot once you take a weapon."

	menu_manager.open_menu({
		"title": localizer.t("run.menu.weapon.title") if localizer != null else "Choose Weapon",
		"body": localizer.t("run.menu.weapon.body") if localizer != null else "After the first room you can add a ranged weapon. The sword always stays in slot 1.",
		"actions": [
			{
				"label": "%s\n%s" % [
					localizer.t("run.menu.weapon.pistol.name") if localizer != null else "Take Pistol",
					localizer.t("run.menu.weapon.pistol.desc") if localizer != null else "Fast shots from a safe distance. Great for thinning ranged enemies before they close in."
				],
				"variant": "range",
				"callback": Callable(self, "_apply_weapon_choice").bind("pistol")
			},
			{
				"label": "%s\n%s" % [
					localizer.t("run.menu.weapon.keep.name") if localizer != null else "Stay Blade-Only",
					localizer.t("run.menu.weapon.keep.desc") if localizer != null else "Keep the run simple and rely only on the sword for now."
				],
				"variant": "tempo",
				"callback": Callable(self, "_apply_weapon_choice").bind("")
			}
		],
		"closable": false,
		"close_on_backdrop": false
	})


func _apply_weapon_choice(weapon_id: String) -> void:
	if state != "weapon_pick":
		return

	var menu_manager := _menu_manager()
	if menu_manager != null and menu_manager.is_open():
		menu_manager.close_menu()

	var localizer := _localizer()
	if weapon_id != "":
		player.unlock_secondary_weapon(weapon_id)
		player.equip_weapon(weapon_id)
		status_label.text = localizer.t("run.status.weapon_selected", {"value": _weapon_name(weapon_id)}) if localizer != null else "%s equipped in slot 2. Use 1 and 2 to switch." % _weapon_name(weapon_id)
		_show_banner(_weapon_name(weapon_id), 0.9)
	else:
		player.equip_weapon("sword")
		status_label.text = localizer.t("run.status.weapon_skipped") if localizer != null else "You stayed with the sword alone. The next room is forming."
		_show_banner(_weapon_name("sword"), 0.7)

	player.set_movement_locked(false)
	objective_label.text = localizer.t("run.objective.prepare") if localizer != null else "Prepare for the next breach."
	hint_label.text = localizer.t("run.hint.weapon_ready") if localizer != null else "LMB attacks with the active weapon. Press 1 for sword and 2 for the sidearm."
	state = "between_waves"
	between_wave_timer = 1.0


func _weapon_name(weapon_id: String) -> String:
	var localizer := _localizer()
	match weapon_id:
		"pistol":
			return localizer.t("weapon.pistol") if localizer != null else "Pistol"
		"sword":
			return localizer.t("weapon.sword") if localizer != null else "Sword"
		_:
			return "-"


func _update_camera() -> void:
	camera.position = player.global_position
	if camera_shake > 0.0:
		camera.offset = Vector2(rng.randf_range(-7.0, 7.0), rng.randf_range(-7.0, 7.0)) * camera_shake
	else:
		camera.offset = camera.offset.lerp(Vector2.ZERO, 0.3)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, ARENA_SIZE), Color("141722"))
	draw_rect(Rect2(Vector2(40.0, 40.0), ARENA_SIZE - Vector2(80.0, 80.0)), Color("1f2435"))
	draw_rect(Rect2(Vector2(58.0, 58.0), ARENA_SIZE - Vector2(116.0, 116.0)), Color(0.95, 0.98, 1.0, 0.03), false, 2.0)

	for index in 27:
		var x := 80.0 + index * 64.0
		draw_line(Vector2(x, 80.0), Vector2(x, ARENA_SIZE.y - 80.0), Color(1.0, 1.0, 1.0, 0.04), 1.0)
	for index in 15:
		var y := 96.0 + index * 58.0
		draw_line(Vector2(80.0, y), Vector2(ARENA_SIZE.x - 80.0, y), Color(1.0, 1.0, 1.0, 0.04), 1.0)

	if slash_effect_timer > 0.0:
		var reach := slash_effect_direction * slash_effect_range
		var side := slash_effect_direction.orthogonal() * 36.0
		draw_colored_polygon(
			PackedVector2Array([
				slash_effect_origin,
				slash_effect_origin + reach + side,
				slash_effect_origin + reach - side
			]),
			Color(slash_effect_color.r, slash_effect_color.g, slash_effect_color.b, slash_effect_timer / 0.14 * 0.55)
		)
