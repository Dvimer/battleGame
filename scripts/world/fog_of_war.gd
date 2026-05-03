extends Node

const STATE_UNSEEN := 0
const STATE_SEEN := 1
const STATE_VISIBLE := 2

var world_tiles := Vector2i.ZERO
var tile_size := 64
var visibility_radius_tiles := 5
var states := PackedByteArray()


func reset_for_world(world_meta) -> void:
	world_tiles = world_meta.world_tiles
	tile_size = world_meta.config.tile_size
	visibility_radius_tiles = world_meta.config.visibility_radius_tiles
	states.resize(world_tiles.x * world_tiles.y)
	for index in range(states.size()):
		states[index] = STATE_UNSEEN


func update_from_world_position(world_position: Vector2) -> void:
	if world_tiles == Vector2i.ZERO:
		return
	for index in range(states.size()):
		if states[index] == STATE_VISIBLE:
			states[index] = STATE_SEEN
	var center = Vector2i(
		clampi(int(floor(world_position.x / float(tile_size))), 0, world_tiles.x - 1),
		clampi(int(floor(world_position.y / float(tile_size))), 0, world_tiles.y - 1)
	)
	for y in range(center.y - visibility_radius_tiles, center.y + visibility_radius_tiles + 1):
		for x in range(center.x - visibility_radius_tiles, center.x + visibility_radius_tiles + 1):
			if x < 0 or y < 0 or x >= world_tiles.x or y >= world_tiles.y:
				continue
			if Vector2(x - center.x, y - center.y).length() > visibility_radius_tiles + 0.25:
				continue
			states[y * world_tiles.x + x] = STATE_VISIBLE


func build_visibility_image() -> Image:
	var image = Image.create(world_tiles.x, world_tiles.y, false, Image.FORMAT_RGBA8)
	for y in range(world_tiles.y):
		for x in range(world_tiles.x):
			var state = states[y * world_tiles.x + x]
			var alpha = 1.0
			if state == STATE_VISIBLE:
				alpha = 0.0
			elif state == STATE_SEEN:
				alpha = 0.42
			image.set_pixel(x, y, Color(0.0, 0.0, 0.0, alpha))
	return image


func serialize() -> PackedByteArray:
	return states


func deserialize(data: PackedByteArray, size: Vector2i, loaded_tile_size: int, radius_tiles: int) -> void:
	world_tiles = size
	tile_size = loaded_tile_size
	visibility_radius_tiles = radius_tiles
	states = data
