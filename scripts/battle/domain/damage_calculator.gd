extends RefCounted
class_name DamageCalculator


static func compute(attacker: UnitInstance, defender: UnitInstance, grid: HexGrid) -> Dictionary:
	var terrain := grid.get_terrain(defender.coord)
	var cover := terrain.cover if terrain != null else 0
	var defend_bonus := 2 if defender.defending else 0
	var flank_bonus := _flank_bonus(attacker, defender)
	var fatigue_bonus := 1 if defender.fatigue >= 6 else 0
	var morale_bonus := 1 if attacker.morale > defender.morale else 0
	var raw := attacker.data.attack + flank_bonus + fatigue_bonus + morale_bonus
	var reduced := maxi(1, raw - defender.data.defense - cover - defend_bonus)
	return {
		"damage": reduced,
		"raw": raw,
		"cover": cover,
		"defend_bonus": defend_bonus,
		"flank_bonus": flank_bonus,
		"fatigue_bonus": fatigue_bonus,
		"morale_bonus": morale_bonus,
		"terrain": terrain.display_name if terrain != null else ""
	}


static func _flank_bonus(attacker: UnitInstance, defender: UnitInstance) -> int:
	var direction_from_defender := HexCoord.direction_index(defender.coord, attacker.coord)
	var rear_direction := wrapi(defender.facing + 3, 0, 6)
	if direction_from_defender == rear_direction:
		return 2
	if direction_from_defender == wrapi(rear_direction - 1, 0, 6) or direction_from_defender == wrapi(rear_direction + 1, 0, 6):
		return 1
	return 0
