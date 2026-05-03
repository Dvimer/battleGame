extends Node2D

const ROOM_SIZE := Vector2(1280.0, 720.0)
const DOOR_POS := Vector2(640.0, 620.0)
const BED_POS := Vector2(330.0, 250.0)
const DESK_POS := Vector2(910.0, 250.0)
const INTERACT_RADIUS := 72.0

@onready var player := $Player
@onready var camera: Camera2D = $Camera2D
@onready var title_label: Label = $HUD/TitleLabel
@onready var prompt_label: Label = $HUD/PromptLabel
@onready var hint_label: Label = $HUD/HintLabel

var banner_timer := 0.0
var banner_text := ""


func _world_state() -> Node:
	return get_node_or_null("/root/WorldState")


func _localizer() -> Node:
	return get_node_or_null("/root/Localizer")


func _scene_router() -> Node:
	return get_node_or_null("/root/SceneRouter")


func _ready() -> void:
	player.arena_size = ROOM_SIZE
	player.allow_attack = false
	player.allow_dash = false
	player.set_movement_locked(false)
	var scene_router := _scene_router()
	if scene_router != null:
		scene_router.apply_spawn(player, player.global_position)
	var localizer := _localizer()
	if localizer != null and not localizer.language_changed.is_connected(_on_language_changed):
		localizer.language_changed.connect(_on_language_changed)
	var world_state := _world_state()
	title_label.text = localizer.t("house.title") if localizer != null else "Cedar House"
	hint_label.text = localizer.t("house.hint.default") if localizer != null else "This is a safe interior room. Step back outside when you want to continue exploring town."
	if world_state != null and world_state.garden_built:
		hint_label.text = localizer.t("house.hint.garden") if localizer != null else "The herb scent from the garden carries inside. Your next expedition starts a little stronger."


func _physics_process(delta: float) -> void:
	camera.position = player.global_position
	banner_timer = maxf(banner_timer - delta, 0.0)
	var nearest := _nearest_spot()
	var localizer := _localizer()
	if nearest == "":
		prompt_label.text = localizer.t("house.prompt.default") if localizer != null else "Walk around the house. The door leads back outside."
	else:
		prompt_label.text = localizer.t("house.prompt.near", {"value": nearest}) if localizer != null else "Press E or left click near %s." % nearest

	if nearest != "" and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("attack")):
		var bed_spot: String = localizer.t("house.spot.bed") if localizer != null else "the bed"
		var desk_spot: String = localizer.t("house.spot.desk") if localizer != null else "the desk"
		if nearest == bed_spot:
			_show_note(localizer.t("house.note.bed") if localizer != null else "A quiet rest. The town feels safer when there is something worth returning to.")
		elif nearest == desk_spot:
			_show_note(localizer.t("house.note.desk") if localizer != null else "Hand-drawn district maps. One day this room can grow into quest logs, blueprints, and story notes.")

	queue_redraw()


func _nearest_spot() -> String:
	var localizer := _localizer()
	var points := {
		localizer.t("house.spot.bed") if localizer != null else "the bed": BED_POS,
		localizer.t("house.spot.desk") if localizer != null else "the desk": DESK_POS
	}
	for label in points.keys():
		if player.global_position.distance_to(points[label]) < INTERACT_RADIUS:
			return label
	return ""


func _show_note(text: String) -> void:
	var localizer := _localizer()
	title_label.text = localizer.t("house.title") if localizer != null else "Cedar House"
	hint_label.text = text
	banner_timer = 2.0
	banner_text = text


func _on_language_changed(_language: String) -> void:
	var localizer := _localizer()
	title_label.text = localizer.t("house.title") if localizer != null else "Cedar House"
	var world_state := _world_state()
	if world_state != null and world_state.garden_built:
		hint_label.text = localizer.t("house.hint.garden") if localizer != null else hint_label.text
	else:
		hint_label.text = localizer.t("house.hint.default") if localizer != null else hint_label.text


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, ROOM_SIZE), Color("ccb893"))
	draw_rect(Rect2(Vector2(70.0, 90.0), Vector2(1140.0, 560.0)), Color("efe2c2"))
	draw_rect(Rect2(Vector2(250.0, 180.0), Vector2(210.0, 120.0)), Color("9f7656"))
	draw_rect(Rect2(Vector2(840.0, 180.0), Vector2(220.0, 110.0)), Color("8c654f"))
	draw_rect(Rect2(Vector2(596.0, 560.0), Vector2(88.0, 90.0)), Color("6b4a35"))
	draw_circle(BED_POS, 12.0, Color("9be7ff"))
	draw_circle(DESK_POS, 12.0, Color("ffd166"))
	draw_circle(DOOR_POS, 12.0, Color("f08a5d"))
	var localizer := _localizer()
	_draw_world_label(BED_POS + Vector2(-18.0, -22.0), localizer.t("house.label.bed") if localizer != null else "Bed", Color("9be7ff"))
	_draw_world_label(DESK_POS + Vector2(-18.0, -22.0), localizer.t("house.label.desk") if localizer != null else "Desk", Color("ffd166"))
	_draw_world_label(DOOR_POS + Vector2(-14.0, -26.0), localizer.t("house.label.exit") if localizer != null else "Exit", Color("f08a5d"))


func _draw_world_label(pos: Vector2, text: String, tint: Color) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, tint)
