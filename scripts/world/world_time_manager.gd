extends Node
## Autoload: WorldTimeManager
## Управляет игровым временем на глобальной карте.
## Время течёт только здесь; бой / поселение / инвентарь вызывают freeze() / unfreeze().

# ── Сигналы ──────────────────────────────────────────────────────────────────

## Каждую игровую минуту (≈0.073 сек реального при 1×)
signal minute_changed(hour: int, minute: int)
## Каждый игровой час (≈4.375 сек реального при 1×)
signal hour_changed(hour: int)
## Каждый игровой день — триггер ежесуточного расчёта
signal day_changed(day: int)
## При смене периода суток: "dawn" | "day" | "dusk" | "night"
signal time_of_day_changed(period: String)
## При изменении скорости (0.0 = пауза, 1.0, 2.0)
signal speed_changed(new_speed: float)

# ── Tuning ───────────────────────────────────────────────────────────────────
const TUNING_PATH := "res://resources/world/time_tuning.tres"
var tuning: TimeTuning
var _has_deserialized_state := false

# ── Состояние (сохраняется) ──────────────────────────────────────────────────
## Суммарное игровое время с начала игры, в игровых часах
var total_hours: float = 0.0
## Текущая скорость: 0.0 = на паузе, 1.0 = нормальная, 2.0 = ускоренная
var current_speed: float = 1.0

# ── Внутреннее ───────────────────────────────────────────────────────────────
var _freeze_stack: int = 0   # стек заморозок — вложенные сцены не ломают паузу
var _prev_minute:  int    = -1
var _prev_hour:    int    = -1
var _prev_day:     int    = -1
var _prev_period:  String = ""

# ── Вычисляемые свойства ─────────────────────────────────────────────────────
var current_day: int:
	get: return int(total_hours / 24.0)

var current_hour: int:
	get: return int(fmod(total_hours, 24.0))

var current_minute: int:
	get: return int(fmod(total_hours * 60.0, 60.0))

var is_frozen: bool:
	get: return _freeze_stack > 0

var is_paused: bool:
	get: return _freeze_stack > 0 or current_speed == 0.0

var time_of_day: String:
	get:
		var active_tuning := _ensure_tuning()
		var h := current_hour
		if h >= active_tuning.night_start_hour or h < active_tuning.dawn_start_hour:
			return "night"
		if h >= active_tuning.dusk_start_hour:
			return "dusk"
		if h >= active_tuning.day_start_hour:
			return "day"
		return "dawn"

# ── Жизненный цикл ───────────────────────────────────────────────────────────

func _ready() -> void:
	var active_tuning := _ensure_tuning()
	if not _has_deserialized_state:
		current_speed = active_tuning.speed_normal
	set_process(true)


func _process(delta: float) -> void:
	if _freeze_stack > 0 or current_speed == 0.0:
		return
	var active_tuning := _ensure_tuning()
	var seconds_per_hour: float = active_tuning.real_seconds_per_day / 24.0
	total_hours += (delta * current_speed) / seconds_per_hour
	_emit_changed_signals()

# ── Публичный API ─────────────────────────────────────────────────────────────

## Заморозить время. Вызывать при входе в бой / поселение / инвентарь.
func freeze() -> void:
	_freeze_stack += 1

## Разморозить. Парно с freeze(). Стек не уходит ниже 0.
func unfreeze() -> void:
	_freeze_stack = maxi(0, _freeze_stack - 1)

## Установить скорость вручную (0.0 / speed_normal / speed_fast).
func set_speed(speed: float) -> void:
	current_speed = speed
	speed_changed.emit(current_speed)

## Переключить паузу / обычная скорость.
func toggle_pause() -> void:
	var active_tuning := _ensure_tuning()
	if current_speed != 0.0:
		set_speed(0.0)
	else:
		set_speed(active_tuning.speed_normal)

## Переключить 1× / 2×. Если на паузе — возобновить с нормальной скоростью.
func toggle_fast() -> void:
	var active_tuning := _ensure_tuning()
	if current_speed == 0.0:
		set_speed(active_tuning.speed_normal)
	elif current_speed >= active_tuning.speed_fast:
		set_speed(active_tuning.speed_normal)
	else:
		set_speed(active_tuning.speed_fast)

## Пропустить N игровых часов (для стоянки лагерем / лечения).
func advance_hours(hours: float) -> void:
	total_hours += maxf(0.0, hours)
	_emit_changed_signals()

## Форматированная строка для HUD: "День 3  🌙 22:14"
func format_hud() -> String:
	var period_icon := {"dawn": "🌅", "day": "☀", "dusk": "🌆", "night": "🌙"}
	var icon: String = period_icon.get(time_of_day, "")
	return "День %d  %s %02d:%02d" % [current_day + 1, icon, current_hour, current_minute]

## Форматированная строка скорости для кнопок: "⏸" / "▶" / "⏩"
func format_speed() -> String:
	var active_tuning := _ensure_tuning()
	if current_speed == 0.0:
		return "⏸"
	if current_speed >= active_tuning.speed_fast:
		return "⏩ ×%.0f" % active_tuning.speed_fast
	return "▶ ×1"

# ── Сохранение / загрузка ─────────────────────────────────────────────────────

func serialize() -> Dictionary:
	return {
		"total_hours": total_hours,
		"speed": current_speed
	}

func deserialize(data: Dictionary) -> void:
	var active_tuning := _ensure_tuning()
	total_hours   = float(data.get("total_hours", 0.0))
	current_speed = float(data.get("speed", active_tuning.speed_normal))
	_has_deserialized_state = true
	# Форсировать переэмиссию всех сигналов после загрузки
	_prev_minute = -1
	_prev_hour   = -1
	_prev_day    = -1
	_prev_period = ""
	_emit_changed_signals()

# ── Внутреннее ───────────────────────────────────────────────────────────────

func _emit_changed_signals() -> void:
	var active_tuning := _ensure_tuning()
	var m := current_minute
	var h := current_hour
	var d := current_day
	var p := time_of_day

	if m != _prev_minute:
		_prev_minute = m
		minute_changed.emit(h, m)

	if h != _prev_hour:
		_prev_hour = h
		hour_changed.emit(h)
		# Ежесуточный тик — ровно в daily_tick_hour
		if h == active_tuning.daily_tick_hour:
			var event_bus := get_node_or_null("/root/EventBus")
			if event_bus != null:
				event_bus.day_tick.emit(d)

	if d != _prev_day:
		_prev_day = d
		day_changed.emit(d)

	if p != _prev_period:
		_prev_period = p
		time_of_day_changed.emit(p)


func _ensure_tuning() -> TimeTuning:
	if tuning != null:
		return tuning
	if ResourceLoader.exists(TUNING_PATH):
		tuning = load(TUNING_PATH) as TimeTuning
	if tuning == null:
		tuning = TimeTuning.new()
		push_warning("WorldTimeManager: time_tuning.tres не найден, используются дефолты.")
	return tuning
