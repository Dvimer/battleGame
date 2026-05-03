extends Resource
class_name WorldMeta

@export var biomes: Array = []
@export var settlements: Array = []
@export var locations: Array = []
@export var roads: Array[PackedVector2Array] = []
@export var capital: Resource
@export var spawn_pos := Vector2.ZERO
@export var world_tiles := Vector2i.ZERO
@export var world_pixels := Vector2.ZERO
@export var config: Resource


func get_settlement_by_name(settlement_name: String):
	for settlement in settlements:
		if settlement.settlement_name == settlement_name:
			return settlement
	return null
