extends Resource
class_name ArmySlotData

@export var unit_data: UnitData
@export var deploy_hex := Vector2i.ZERO
@export var facing := 0
@export var equipped := {}
@export var quick_slots: Array = []
@export var secondary_set := {}
@export var appearance: Resource
@export var persistent_wounds: Array = []
@export var roster_unit_id := ""
