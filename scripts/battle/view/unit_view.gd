extends Node2D
class_name UnitView

var unit: UnitInstance
var hex_size := 42.0


func setup(p_unit: UnitInstance, p_hex_size: float) -> void:
	unit = p_unit
	hex_size = p_hex_size
	position = HexCoord.axial_to_pixel(unit.coord, hex_size)
	z_index = int(position.y)
	unit.moved.connect(_on_unit_moved)
	unit.damaged.connect(func(_unit, _amount, _result): queue_redraw())
	unit.resources_changed.connect(func(_unit): queue_redraw())
	unit.died.connect(_on_unit_died)
	queue_redraw()


func _on_unit_moved(_unit, _from_coord: Vector2i, to_coord: Vector2i) -> void:
	var target := HexCoord.axial_to_pixel(to_coord, hex_size)
	var tween := create_tween()
	tween.tween_property(self, "position", target, 0.18).set_trans(Tween.TRANS_SINE)
	z_index = int(target.y)
	queue_redraw()


func _on_unit_died(_unit) -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)


func _draw() -> void:
	if unit == null:
		return
	var body_color := unit.data.color
	if unit.team == 1:
		body_color = body_color.darkened(0.1)
	draw_circle(Vector2.ZERO, 20.0, body_color)
	draw_circle(Vector2.ZERO, 23.0, Color(0, 0, 0, 0.22))
	var face_dir := HexCoord.direction_to_pixel(unit.facing, 18.0)
	draw_line(Vector2.ZERO, face_dir, Color("fff3b0"), 4.0)

	var font := ThemeDB.fallback_font
	if font == null:
		return
	var hp_text := "%d/%d" % [unit.hp, unit.max_hp]
	_draw_label_with_backing(font, hp_text, Vector2(-25.0, -39.0), 50.0, 14, Color("ffffff"), Color(0.03, 0.05, 0.07, 0.82))
	_draw_label_with_backing(font, unit.data.display_name, Vector2(-41.0, 35.0), 82.0, 12, Color("f5f1e8"), Color(0.03, 0.05, 0.07, 0.72))
	if unit.action_points > 0:
		_draw_label_with_backing(font, "AP %d" % unit.action_points, Vector2(-22.0, 51.0), 44.0, 11, Color("9df3ff"), Color(0.03, 0.05, 0.07, 0.68))


func _draw_label_with_backing(font: Font, text: String, origin: Vector2, width: float, size: int, color: Color, backing: Color) -> void:
	var height := float(size) + 8.0
	draw_rect(Rect2(origin + Vector2(0.0, -float(size)), Vector2(width, height)), backing)
	draw_string(font, origin + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_CENTER, width, size, Color(0, 0, 0, 0.75))
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, color)
