extends Node

const FORGE_COST := 12
const GARDEN_COST := 10

var bank_essence := 0
var pending_chest_essence := 0
var forge_built := false
var garden_built := false
var next_run_attack_bonus := 0
var next_run_health_bonus := 0
var next_run_dash_bonus := 0
var town_message_key := ""
var town_message_params := {}


func _localizer() -> Node:
	return get_node_or_null("/root/Localizer")


func can_afford(cost: int) -> bool:
	return bank_essence >= cost


func spend_essence(cost: int) -> bool:
	if cost > bank_essence:
		return false
	bank_essence -= cost
	return true


func collect_chest() -> int:
	var collected := pending_chest_essence
	bank_essence += pending_chest_essence
	pending_chest_essence = 0
	return collected


func stash_city_reward(base_reward: int) -> int:
	var multiplier := 1.25 if forge_built else 1.0
	var stored := int(round(base_reward * multiplier))
	pending_chest_essence += stored
	return stored


func build_forge() -> bool:
	if forge_built or not spend_essence(FORGE_COST):
		return false
	forge_built = true
	return true


func build_garden() -> bool:
	if garden_built or not spend_essence(GARDEN_COST):
		return false
	garden_built = true
	return true


func buy_attack_tonic() -> bool:
	if not spend_essence(6):
		return false
	next_run_attack_bonus += 1
	return true


func buy_ration_pack() -> bool:
	if not spend_essence(5):
		return false
	next_run_health_bonus += 1
	return true


func buy_dash_boots() -> bool:
	if not spend_essence(5):
		return false
	next_run_dash_bonus += 1
	return true


func set_town_message(key: String, params := {}) -> void:
	town_message_key = key
	town_message_params = params.duplicate()


func consume_town_message() -> String:
	if town_message_key == "":
		return ""
	var localizer := _localizer()
	var message := town_message_key
	if localizer != null:
		message = localizer.t(town_message_key, town_message_params)
	town_message_key = ""
	town_message_params = {}
	return message


func consume_expedition_setup() -> Dictionary:
	var setup := {
		"attack_damage_bonus": next_run_attack_bonus,
		"max_health_bonus": next_run_health_bonus + (1 if garden_built else 0),
		"dash_speed_bonus": float(next_run_dash_bonus) * 90.0,
		"dash_charge_bonus": next_run_dash_bonus,
		"slash_range_bonus": 10.0 if forge_built else 0.0
	}
	next_run_attack_bonus = 0
	next_run_health_bonus = 0
	next_run_dash_bonus = 0
	return setup


func describe_next_run_bonus() -> String:
	var localizer := _localizer()
	var parts: Array[String] = []
	if next_run_attack_bonus > 0:
		parts.append(localizer.t("bonus.attack", {"value": next_run_attack_bonus}) if localizer != null else "+%d attack" % next_run_attack_bonus)
	if next_run_health_bonus > 0:
		parts.append(localizer.t("bonus.hp", {"value": next_run_health_bonus}) if localizer != null else "+%d max HP" % next_run_health_bonus)
	if next_run_dash_bonus > 0:
		parts.append(localizer.t("bonus.dash", {"value": next_run_dash_bonus}) if localizer != null else "+%d dash tune" % next_run_dash_bonus)
	if garden_built:
		parts.append(localizer.t("bonus.garden") if localizer != null else "garden blessing")
	if forge_built:
		parts.append(localizer.t("bonus.forge") if localizer != null else "forge edge")
	return ", ".join(parts)
