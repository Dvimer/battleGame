extends RefCounted
class_name WoundInstance

var data: WoundData
var remaining_hours := 0


static func from_data(wound_data: WoundData, hours := 0) -> WoundInstance:
	var wound := WoundInstance.new()
	wound.data = wound_data
	wound.remaining_hours = hours
	return wound


static func from_dict(payload: Dictionary, catalog: Dictionary) -> WoundInstance:
	var wound_id := str(payload.get("wound_id", ""))
	if not catalog.has(wound_id):
		return null
	return WoundInstance.from_data(catalog[wound_id], int(payload.get("remaining_hours", 0)))


func duplicate_instance() -> WoundInstance:
	return WoundInstance.from_data(data, remaining_hours)


func to_dict() -> Dictionary:
	return {
		"wound_id": data.wound_id if data != null else "",
		"remaining_hours": remaining_hours
	}
