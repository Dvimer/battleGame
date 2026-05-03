extends Resource
class_name AppearanceState

@export var skin_tint := Color.WHITE
@export var hair_id := ""
@export var shield_paint := Color.WHITE
@export var shield_emblem_id := ""
@export var cape_paint := Color.WHITE


func duplicate_state() -> AppearanceState:
	var state := AppearanceState.new()
	state.skin_tint = skin_tint
	state.hair_id = hair_id
	state.shield_paint = shield_paint
	state.shield_emblem_id = shield_emblem_id
	state.cape_paint = cape_paint
	return state


func to_dict() -> Dictionary:
	return {
		"skin_tint": [skin_tint.r, skin_tint.g, skin_tint.b, skin_tint.a],
		"hair_id": hair_id,
		"shield_paint": [shield_paint.r, shield_paint.g, shield_paint.b, shield_paint.a],
		"shield_emblem_id": shield_emblem_id,
		"cape_paint": [cape_paint.r, cape_paint.g, cape_paint.b, cape_paint.a]
	}


static func from_dict(payload: Dictionary) -> AppearanceState:
	var state := AppearanceState.new()
	state.skin_tint = _color_from_value(payload.get("skin_tint", []), Color.WHITE)
	state.hair_id = str(payload.get("hair_id", ""))
	state.shield_paint = _color_from_value(payload.get("shield_paint", []), Color.WHITE)
	state.shield_emblem_id = str(payload.get("shield_emblem_id", ""))
	state.cape_paint = _color_from_value(payload.get("cape_paint", []), Color.WHITE)
	return state


static func _color_from_value(value, fallback: Color) -> Color:
	if value is Array and value.size() >= 4:
		return Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
	return fallback
