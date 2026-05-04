extends Resource
class_name TimeTuning

## Все игровые константы времени — меняй здесь, не трогая логику

## 1 игровой день = сколько реальных секунд (при скорости 1×)
@export var real_seconds_per_day: float = 105.0

## Множители скорости
@export var speed_normal: float = 1.0
@export var speed_fast:   float = 2.0

## Границы суток (час 0–23)
@export var dawn_start_hour:  int = 5    # 05:00 — рассвет
@export var day_start_hour:   int = 7    # 07:00 — день
@export var dusk_start_hour:  int = 19   # 19:00 — сумерки
@export var night_start_hour: int = 21   # 21:00 — ночь

## Час ежесуточного расчёта (зарплата, еда, лечение)
@export var daily_tick_hour: int = 6

## Механические эффекты ночи
@export var night_vision_mult:    float = 0.5   # множитель радиуса обзора
@export var night_ranged_penalty: int   = -3    # штраф к дальнобойной атаке в ночном бою
