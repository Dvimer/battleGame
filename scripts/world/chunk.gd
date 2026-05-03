extends Node2D

const LAYER_GROUND := 0
const LAYER_ROAD := 1
const LAYER_OBJECT := 2

var chunk_coord := Vector2i.ZERO
var chunk_data := {}
var config


func setup(coord: Vector2i, data: Dictionary, world_config) -> void:
	chunk_coord = coord
	chunk_data = data
	config = world_config
	position = _to_iso(Vector2(coord * config.get_chunk_pixel_size()))
	z_index = int(position.y)
	queue_redraw()


func _draw() -> void:
	if config == null or chunk_data.is_empty():
		return
	var tile_size = float(config.tile_size)
	var chunk_size = config.chunk_size
	var ground: PackedColorArray = chunk_data.get("ground", PackedColorArray())
	var roads: PackedByteArray = chunk_data.get("roads", PackedByteArray())
	var objects: PackedByteArray = chunk_data.get("objects", PackedByteArray())
	for y in range(chunk_size):
		for x in range(chunk_size):
			var idx = y * chunk_size + x
			var ground_color = ground[idx] if idx < ground.size() else Color("66885d")
			var logical_center = Vector2((x + 0.5) * tile_size, (y + 0.5) * tile_size)
			var iso_center = _to_iso(logical_center)
			var diamond = PackedVector2Array([
				iso_center + Vector2(0.0, -tile_size * 0.25),
				iso_center + Vector2(tile_size * 0.5, 0.0),
				iso_center + Vector2(0.0, tile_size * 0.25),
				iso_center + Vector2(-tile_size * 0.5, 0.0)
			])
			draw_colored_polygon(diamond, ground_color)
			if idx < roads.size() and roads[idx] == 1:
				var road_diamond = PackedVector2Array([
					iso_center + Vector2(0.0, -tile_size * 0.12),
					iso_center + Vector2(tile_size * 0.24, 0.0),
					iso_center + Vector2(0.0, tile_size * 0.12),
					iso_center + Vector2(-tile_size * 0.24, 0.0)
				])
				draw_colored_polygon(road_diamond, Color("c9b38a"))
			if idx < objects.size() and objects[idx] == 1:
				draw_circle(iso_center + Vector2(0.0, -tile_size * 0.08), tile_size * 0.12, Color("f0d26e"))


func _to_iso(local_position: Vector2) -> Vector2:
	return Vector2(
		(local_position.x - local_position.y) * 0.5,
		(local_position.x + local_position.y) * 0.25
	)
