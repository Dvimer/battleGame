extends Node

signal location_entered(location_id: String, payload: Dictionary)
signal settlement_discovered(settlement_name: String)
signal quest_triggered(chain_id: String, payload: Dictionary)
signal player_moved(world_position: Vector2)
signal chunk_loaded(chunk_coord: Vector2i)

## Срабатывает раз в игровые сутки (в daily_tick_hour из TimeTuning).
## Подписчики: RosterInventory (еда), RosterManager (зарплата), раны.
signal day_tick(day: int)
