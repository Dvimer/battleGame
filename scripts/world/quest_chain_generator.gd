extends RefCounted
class_name QuestChainGenerator

var counter := 0


func generate(location_id: String, payload: Dictionary):
	counter += 1
	var chain = preload("res://scripts/world/quest_chain_data.gd").new()
	chain.chain_id = "chain_%d" % counter
	chain.title = "Путь через %s" % location_id
	chain.steps = [
		"Осмотреть окрестности поселения",
		"Найти следы дороги или руин",
		"Вернуться с донесением в столицу"
	]
	chain.trigger_criteria = payload.duplicate()
	chain.reward_text = "Открывает новые точки на карте"
	return chain
