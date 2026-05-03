extends Node2D
class_name HexTileMap

signal hex_clicked(coord: Vector2i)
signal hex_hovered(coord: Vector2i)

var battle_state: BattleState
var hex_size := 42.0
var hover_coord := Vector2i(-999, -999)
var selected_coord := Vector2i(-999, -999)
var reachable := {}
var attackable := {}
var path_preview: Array[Vector2i] = []
var forecast_coord := Vector2i(-999, -999)
var attack_trace_from := Vector2i(-999, -999)
var attack_trace_to := Vector2i(-999, -999)
var attack_trace_timer := 0.0


func setup(state: BattleState, p_hex_size: float) -> void:
	battle_state = state
	hex_size = p_hex_size
	set_process(true)
	queue_redraw()


func set_overlays(p_selected: Vector2i, p_reachable := {}, p_attackable := {}, p_path_preview: Array[Vector2i] = [], p_forecast_coord := Vector2i(-999, -999)) -> void:
	selected_coord = p_selected
	reachable = p_reachable
	attackable = p_attackable
	path_preview = p_path_preview
	forecast_coord = p_forecast_coord
	queue_redraw()


func show_attack_trace(from_coord: Vector2i, to_coord: Vector2i, duration := 0.55) -> void:
	attack_trace_from = from_coord
	attack_trace_to = to_coord
	attack_trace_timer = duration
	queue_redraw()


func _process(delta: float) -> void:
	if attack_trace_timer <= 0.0:
		return
	attack_trace_timer = maxf(attack_trace_timer - delta, 0.0)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if battle_state == null:
		return
	var coord := HexCoord.pixel_to_axial(to_local(get_global_mouse_position()), hex_size)
	if event is InputEventMouseMotion:
		if coord != hover_coord and battle_state.grid.in_bounds(coord):
			hover_coord = coord
			hex_hovered.emit(coord)
			queue_redraw()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if battle_state.grid.in_bounds(coord):
			hex_clicked.emit(coord)
			get_viewport().set_input_as_handled()


func _draw() -> void:
	if battle_state == null or battle_state.grid == null:
		return
	for coord in battle_state.grid.cells.keys():
		var cell: HexCell = battle_state.grid.cells[coord]
		var center := HexCoord.axial_to_pixel(coord, hex_size)
		var color := cell.terrain.color
		draw_colored_polygon(HexCoord.corners(center, hex_size - 1.0), color)
		draw_polyline(_closed_corners(center, hex_size - 1.0), Color(0, 0, 0, 0.22), 1.5, true)
		if reachable.has(coord) and coord != selected_coord:
			draw_colored_polygon(HexCoord.corners(center, hex_size - 8.0), Color(0.35, 0.72, 1.0, 0.28))
		if attackable.has(coord):
			draw_colored_polygon(HexCoord.corners(center, hex_size - 10.0), Color(1.0, 0.25, 0.22, 0.34))
		if coord == forecast_coord:
			draw_polyline(_closed_corners(center, hex_size - 12.0), Color("ff7a7a"), 3.0, true)
		if coord == selected_coord:
			draw_polyline(_closed_corners(center, hex_size - 4.0), Color("fff3b0"), 4.0, true)
		if coord == hover_coord:
			draw_polyline(_closed_corners(center, hex_size - 7.0), Color(1, 1, 1, 0.75), 2.0, true)
	for coord in path_preview:
		var center := HexCoord.axial_to_pixel(coord, hex_size)
		draw_circle(center, 7.0, Color("b9ecff"))
		draw_circle(center, 3.0, Color("1f2435"))
	if attack_trace_timer > 0.0 and battle_state.grid.in_bounds(attack_trace_from) and battle_state.grid.in_bounds(attack_trace_to):
		var ratio := attack_trace_timer / 0.55
		var from_pos := HexCoord.axial_to_pixel(attack_trace_from, hex_size)
		var to_pos := HexCoord.axial_to_pixel(attack_trace_to, hex_size)
		var pulse := Color(1.0, 0.86, 0.28, clampf(ratio, 0.15, 1.0))
		draw_line(from_pos, to_pos, pulse, 8.0)
		draw_line(from_pos, to_pos, Color(0.12, 0.04, 0.02, clampf(ratio, 0.12, 0.75)), 3.0)
		draw_circle(to_pos, 26.0 + (1.0 - ratio) * 18.0, Color(1.0, 0.22, 0.18, clampf(ratio * 0.55, 0.0, 0.55)))
		draw_circle(from_pos, 10.0, Color(1.0, 0.95, 0.72, clampf(ratio, 0.0, 1.0)))


func _closed_corners(center: Vector2, radius: float) -> PackedVector2Array:
	var points := HexCoord.corners(center, radius)
	if not points.is_empty():
		points.append(points[0])
	return points
