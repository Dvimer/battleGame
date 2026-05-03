extends Resource
class_name TerrainData

@export var terrain_id := ""
@export var display_name := ""
@export var move_cost := 1
@export var cover := 0
@export var fatigue_delta := 0
@export var morale_delta := 0
@export var color := Color("5f8d62")


func describe_effects() -> String:
	var parts: Array[String] = []
	if cover > 0:
		parts.append("cover +%d" % cover)
	if fatigue_delta != 0:
		parts.append("fatigue %+d" % fatigue_delta)
	if morale_delta != 0:
		parts.append("morale %+d" % morale_delta)
	return ", ".join(parts) if not parts.is_empty() else "no modifiers"
