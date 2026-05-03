# План: архитектура сцены пошагового тактического боя

## Context

В проекте `Shardfall Arena` (Godot 4.6) сейчас одна боевая сцена — `scenes/city_run.tscn` — это real-time wave-арена (контроллер [game.gd](scripts/game.gd), 906 строк). Нужно спроектировать **вторую боевую сцену** — пошаговый тактический бой в духе Heroes of Might & Magic 3 и Battle Brothers, с гексагональной сеткой и юнитами-одиночками (каждый боец = одна клетка, своё HP/мораль/усталость).

Сцена должна быть параметризованной: при запуске в неё передаются местность (terrain), составы атакующей и защищающейся армий, погода/время суток и т.п. Архитектура должна закрывать как первую интеграцию (заглушки), так и расширения (новые юниты, способности, типы местности) без переписывания.

Решения из Q&A:
- сетка — **гексагональная flat-top** с odd-q offset-раскладкой `Vector2i(col, row)`, чтобы поле на экране было прямоугольным/квадратным, а не axial-ромбом; ориентация зафиксирована и должна использоваться во всех конвертациях coord↔pixel, подсветке, pathfinding и визуале;
- юниты — **одиночки** (BB-style): мораль, усталость, направление, фланговые штрафы;
- сцена существует **параллельно** `city_run.tscn`, не заменяет её.

## Архитектурный обзор

Слои, изолированные друг от друга:

1. **Data layer** — Resource-классы (`extends Resource` + `@export`), описывают статику: типы юнитов, местность, способности, армии. Шаблон уже устоялся в проекте — `BiomeData`, `SettlementData`, `LocationData`.
2. **Battle context (autoload)** — точка входа параметров. Перед `SceneRouter.go_to_scene("battle.tscn", ...)` вызывающий код заполняет `BattleContext`, на загрузке сцены контроллер читает оттуда. Это согласуется с уже принятым паттерном autoload-синглтонов (см. `WorldState.consume_expedition_setup()` в [scripts/world_state.gd](scripts/world_state.gd)).
3. **Domain (runtime model)** — чистые GDScript-классы без узлов: `HexGrid`, `BattleState`, `UnitInstance`, `TurnQueue`. Управляют логикой, не знают о визуале. Тестируются изолированно.
4. **View** — узлы сцены: `HexTileMap`, `UnitView` (Node2D-обёртка над `UnitInstance`), HUD. Подписаны на сигналы домена.
5. **Controllers** — оркестрация: `BattleController` (root-скрипт сцены), `TurnManager`, `InputController`, `EnemyAI`.

## Структура файлов

Новые директории:

```
scripts/battle/
  battle_context.gd            # autoload, входные параметры
  battle_controller.gd         # root scene script
  turn_manager.gd              # очередь ходов, инициатива
  input_controller.gd          # перевод клика → команда
  enemy_ai.gd                  # AI противника (вынесен из юнита)
  hex/
    hex_coord.gd               # static helpers: axial↔pixel, distance, neighbors, line
    hex_grid.gd                # модель: cells[Vector2i] → HexCell
    hex_cell.gd                # Resource или класс: terrain ref, occupant, cover
    pathfinder.gd              # A* по гексам с учётом movement_cost
  domain/
    battle_state.gd            # текущее состояние боя (ход, фаза, победа)
    unit_instance.gd           # runtime-юнит: hp, fatigue, morale, facing, position
    ability_runtime.gd         # выполнение способности (target, effects)
    damage_calculator.gd       # формулы урона (с фланг/высота/мораль)
  data/
    terrain_data.gd            # Resource: terrain_id, move_cost, cover, vision_mod, art
    unit_data.gd               # Resource: stats, abilities[], faction, sprite, sounds
    ability_data.gd            # Resource: range, AP cost, damage type, effects
    army_data.gd               # Resource: units: Array[ArmySlotData]
    army_slot_data.gd          # Resource: unit_data, level, equipment, deploy_hex
    battlefield_data.gd        # Resource: layout (size, hex_terrain_map), weather, time
  view/
    hex_tilemap.gd             # рисует сетку, подсвечивает доступные/атакуемые клетки
    unit_view.gd               # визуал одного юнита (анимации, поворот к facing)
    hud.gd                     # панели юнитов, очередь ходов, лог боя

scenes/battle/
  battle.tscn                  # корневая сцена
  unit_view.tscn               # инстансится BattleController'ом
  hud.tscn                     # CanvasLayer с UI

resources/battle/
  terrain/{plains,forest,hills,...}.tres
  units/{footman,archer,...}.tres
  abilities/{shield_wall,charge,...}.tres
  battlefields/{forest_skirmish,...}.tres   # тестовые
```

## Передача входных параметров

Autoload `BattleContext` ([scripts/battle/battle_context.gd](scripts/battle/battle_context.gd)) — единственный канал. Регистрируется в `project.godot` после `SceneRouter`.

```gdscript
extends Node
class_name BattleContextAutoload

var battlefield: BattlefieldData       # местность + layout
var attacker: ArmyData                 # инициатор боя (обычно игрок)
var defender: ArmyData                 # защищающаяся сторона
var environment: Dictionary = {}       # weather, time_of_day, modifiers
var return_scene: String = ""          # куда вернуться после боя
var return_spawn_id: String = ""
var on_finished: Callable = Callable() # колбэк-резолвер исхода (награда/потери)

func setup(p_battlefield, p_attacker, p_defender, p_env := {}) -> void: ...
func consume() -> Dictionary: ...      # как WorldState.consume_expedition_setup()
func is_ready() -> bool: ...
```

Триггер боя из мира (например, [scripts/world/settlement.gd](scripts/world/settlement.gd) или новый `BattleTrigger`):

```gdscript
BattleContext.setup(battlefield_res, player_army, enemy_army, {"weather": "rain"})
SceneRouter.go_to_scene("res://scenes/battle/battle.tscn", "")
```

`BattleController._ready()` читает `BattleContext.consume()` и инициализирует `BattleState`. По окончании боя — обратно через `SceneRouter` + результат в `BattleContext.on_finished`.

**Fallback**: если `BattleContext.is_ready() == false` (запуск battle.tscn напрямую из редактора для отладки), контроллер грузит дефолтный `resources/battle/battlefields/dev_default.tres`.

## Гекс-сетка

[scripts/battle/hex/hex_coord.gd](scripts/battle/hex/hex_coord.gd) — статические утилиты по референсу Red Blob Games. Ориентация гекса зафиксирована как **flat-top**, а публичные координаты поля — odd-q offset `Vector2i(col, row)`:

- `axial_to_pixel(coord, hex_size) -> Vector2` — историческое имя, фактически `offset_to_pixel`
- `pixel_to_axial(pos, hex_size) -> Vector2i` — историческое имя, фактически `pixel_to_offset` через cube round
- `distance(a, b) -> int`
- `neighbors(coord) -> Array[Vector2i]` (6 направлений)
- `line(a, b) -> Array[Vector2i]` (для дальнобоев и LOS)
- `range(coord, radius) -> Array[Vector2i]`

`HexGrid` хранит `Dictionary[Vector2i, HexCell]`. `HexCell` — terrain reference, occupant (UnitInstance или null), cover-флаги. `Pathfinder` — A* с `move_cost` из `TerrainData`, учитывает занятые клетки и зоны контроля соседних врагов (BB ZoC).

Визуал — **не TileMap**, а кастомный Node2D (`HexTileMap`) с `_draw()` или Polygon2D на гекс. TileMap в Godot 4 поддерживает гексы, но управление подсветкой/оверлеями проще через свой рендер. (TileMap уже используется в [scenes/chunk.tscn](scenes/chunk.tscn) для мира — здесь это излишне.)

## Domain-модель

`UnitInstance` (НЕ Node) — поля:

- `data: UnitData` (ссылка на статик)
- `coord: Vector2i`, `facing: int` (0–5)
- `hp: int`, `max_hp: int`
- `fatigue: int` (накапливается за действия, влияет на хит-шанс/защиту — BB)
- `morale: int` (Confident/Steady/Wavering/Fleeing — BB enum)
- `action_points: int` (BB-стиль AP, восполняются с началом хода)
- `status_effects: Array[StatusEffect]`
- `team: int` (0 = attacker, 1 = defender)
- сигналы: `damaged`, `moved`, `died`, `morale_changed`

`BattleState`:

- `grid: HexGrid`
- `units: Array[UnitInstance]`
- `turn_queue: TurnQueue` (сортирует по initiative каждый round)
- `phase: enum {Deploy, Combat, Resolution}`
- `round_number: int`
- сигналы: `turn_started(unit)`, `turn_ended(unit)`, `battle_finished(winner_team)`

`DamageCalculator.compute(attacker, defender, ability, context) -> DamageResult` — единая точка для формул. Аргументы: фланг (через `facing` и направление атаки), terrain modifier (через `HexCell.terrain.cover`), мораль, усталость.

## Очередь ходов

`TurnManager` — BB-стиль (initiative-based round): в начале раунда сортирует живых юнитов по `data.initiative + d6`, прогоняет очередь, в конце — обновление статусов и пересборка. UI показывает grid портретов в верхней полосе HUD.

Альтернатива (HoMM): один общий стек по speed — описана в `BattleController` как стратегия (`TurnOrderStrategy`), чтобы можно было переключить флагом в `BattlefieldData`. По умолчанию — BB.

## AI

[scripts/battle/enemy_ai.gd](scripts/battle/enemy_ai.gd) — utility-AI: на ход юнита перебирает возможные `(move_target, ability, target)` кортежи, оценивает функцией `score(action) = damage_potential - threat - position_value`. Изоляция от `UnitInstance` — AI получает `BattleState` read-only, возвращает `Command` объект, который применяет `BattleController`. Это позволит позже добавить разные «архетипы AI» через `UnitData.ai_profile`.

## View и HUD

`HexTileMap` (Node2D в `battle.tscn`):
- рисует гексы по `BattleState.grid`;
- подсвечивает: hover, доступные ходы (синий), атакуемые клетки (красный), путь (точки);
- сигналит `hex_clicked(coord)`, `hex_hovered(coord)`.

`UnitView` (`scenes/battle/unit_view.tscn`) — Node2D с Sprite2D/AnimatedSprite2D + Label HP. Подписан на сигналы своего `UnitInstance`. Один-к-одному с моделью, создаётся `BattleController` после инициализации `BattleState`.

`HUD` (CanvasLayer) — переиспользует паттерн из [scenes/city_run.tscn](scenes/city_run.tscn) (CanvasLayer с Label-узлами). Содержит:
- турн-бар (очередь портретов);
- инфо-панель выбранного юнита;
- инфо-панель цели под курсором;
- **панель действий** (`ActionBar`) — динамическая, перестраивается по `selected_unit.data.abilities`;
- кнопки: Wait, Defend, End Turn;
- лог боя (последние N сообщений).

## Цикл взаимодействия: выбор юнита и действия

Вся логика «клик по своему воину → подсветка → выбор действия → ход → переход хода» строится поверх уже описанных слоёв и не требует новых классов. Вот как именно это укладывается в архитектуру.

### Состояние в `BattleController`

```gdscript
var active_unit: UnitInstance = null      # тот, чей сейчас ход (выставляет TurnManager)
var selected_unit: UnitInstance = null    # выбранный игроком (только во время своего хода)
var pending_ability: AbilityData = null   # выбранное действие, ждёт цели
var reachable_cache: Dictionary = {}      # Vector2i → стоимость пути (precomputed по selection)
var attackable_cache: Array[Vector2i] = []

signal selection_changed(unit: UnitInstance)
signal pending_ability_changed(ability: AbilityData)
```

### Какие действия показываются — берётся из `UnitData`

Тип воина определяет доступный набор действий через поле `UnitData.abilities: Array[AbilityData]`. Никакой `if archer / if spearman` — данные, а не код:

- **Footman**: `move`, `attack_melee`, `shield_wall`, `wait`, `defend`.
- **Archer**: `move`, `shoot` (range 6, требует LOS), `aimed_shot`, `wait`, `defend`.
- **Spearman**: `move`, `thrust` (range 1–2 — копьё бьёт через клетку), `brace` (готовность к контратаке атакующего), `wait`, `defend`.

`move`/`wait`/`defend` — общие для всех, удобно вынести в `resources/battle/abilities/common/` и переиспользовать в `UnitData.abilities` через ссылку. Способности типа `shoot`/`thrust` — уникальные.

`AbilityData` (дополняем уже описанный):

```gdscript
@export var ability_id: String
@export var display_name: String
@export var icon: Texture2D
@export var ap_cost: int
@export var fatigue_cost: int
@export var min_range: int = 1
@export var max_range: int = 1
@export var requires_los: bool = false
@export var target_kind: int        # enum: SELF / ALLY / ENEMY / EMPTY_HEX / ANY_HEX
@export var damage_min: int
@export var damage_max: int
@export var effects: Array[StatusEffectData]
@export var ai_weight: float = 1.0  # подсказка utility-AI
```

### Поток выбора (только когда `active_unit.team == 0`)

1. **Клик по своему юниту** (`HexTileMap.hex_clicked` → `InputController` → `BattleController.try_select(coord)`):
   - если в клетке свой юнит — `selected_unit = unit`, эмитим `selection_changed`;
   - HUD-`ActionBar` слушает сигнал, чистит и заново строит кнопки по `selected_unit.data.abilities` (одна кнопка = один `AbilityData`, неактивна если AP/fatigue не хватает);
   - `HexTileMap` слушает сигнал и подсвечивает рамкой клетку юнита и `reachable_cache` (синие гексы — `Pathfinder.reachable(unit, unit.action_points)`).

2. **Клик по способности в HUD** (или нажатие хоткея 1–9):
   - `pending_ability = ability`, эмитим `pending_ability_changed`;
   - `HexTileMap` пересчитывает оверлей: подсвечивает все валидные цели через `AbilityRuntime.get_valid_targets(state, selected_unit, ability)` (красные/жёлтые гексы в зависимости от target_kind);
   - если способность мгновенная (`target_kind == SELF`, например `defend`) — выполняется сразу.

3. **Клик по целевой клетке**:
   - `BattleController` строит `Command(unit, ability, target_coord)`;
   - валидирует через `AbilityRuntime.is_valid_target(...)`;
   - если валидно — `apply_command(cmd)` (см. ниже);
   - если не валидно — игнор + короткий лог («слишком далеко», «нет линии видимости»).

4. **ESC / правый клик / клик по другой способности** — снимает `pending_ability`, оставляет `selected_unit`. Клик по другому своему юниту — переключает выбор.

`move` обрабатывается единообразно: это `AbilityData` с `target_kind = EMPTY_HEX`, в `AbilityRuntime` вместо урона — анимация прохода по `Pathfinder.find_path()` и обновление `unit.coord`.

### Передача хода

Действия списывают AP/fatigue. Передача хода — у `TurnManager`, не у `BattleController`. Условия конца хода:

- `unit.action_points <= 0` (после последнего действия) — авто-конец;
- любая атака (`attack_melee`, `shoot`, `thrust` и т.п.) всегда завершает ход сразу, даже если у юнита остались AP; после атаки нельзя выбрать `wait`, `defend` или движение;
- игрок нажал **End Turn** в HUD — принудительный конец;
- `wait` — особый случай: юнит отправляется в конец очереди текущего раунда (BB-механика);
- `defend` — заканчивает ход немедленно с бонусом к защите до начала следующего хода.

Поток:

```
apply_command(cmd):
    AbilityRuntime.execute(state, cmd) -> EffectResult   # урон, перемещение, статусы
    unit.spend(cmd.ability.ap_cost, cmd.ability.fatigue_cost)
    emit "command_applied" -> view проигрывает анимации (await)
    проверить условия battle_finished -> если да, выйти
    если cmd.ends_turn or unit.action_points <= 0:
        TurnManager.end_current_turn()

TurnManager.end_current_turn():
    state.emit("turn_ended", active_unit)
    next = turn_queue.advance()                  # следующий живой юнит
    if next == null:
        start_new_round()                        # пересортировка по initiative + d6
        next = turn_queue.peek()
    active_unit = next
    next.refresh_turn()                          # сброс AP, частичный recovery fatigue
    state.emit("turn_started", next)
    if next.team == 0:
        # ход игрока — InputController включает приём кликов
        BattleController.auto_select(next)       # автовыбор активного юнита для удобства
    else:
        # ход AI — InputController блокируется, EnemyAI планирует команду
        await get_tree().create_timer(0.2).timeout
        var cmd = EnemyAI.choose_command(state, next)
        apply_command(cmd)
```

### Что обязан реализовать `InputController`

Тонкая прослойка, без логики правил:

- слушает `HexTileMap.hex_clicked / hex_hovered`;
- маршрутизирует клики в `BattleController.try_select` или `BattleController.try_target` в зависимости от `pending_ability`;
- блокирует ввод когда `active_unit.team != 0` или `phase != Combat` или идёт анимация (`is_busy` в контроллере);
- горячие клавиши: 1–9 — выбор способности по индексу, `Tab` — следующий свой юнит, `Space`/`Enter` — End Turn, `Esc` — отмена pending_ability.

### Подсветка в `HexTileMap`

Один метод `set_overlay(state: OverlayState)`, один `_draw()`. `OverlayState` — структура с массивами клеток по категориям (selected, reachable, attackable, path_preview, hovered). Контроллер вызывает `hex_tilemap.set_overlay(...)` после `selection_changed` и `pending_ability_changed` — никакого размазанного состояния по нодам.

### Почему это масштабируется

- Новый тип воина (например, маг) = новый `unit_mage.tres` + 1–3 новых `ability_*.tres`. Ни одной строки кода в контроллер/HUD добавлять не надо.
- Новая способность с нестандартной логикой (AoE, телепорт) = подкласс `AbilityRuntime` + `AbilityData.runtime_script` ссылка. `BattleController` не меняется.
- AI получает те же `AbilityData` через `UnitData.abilities`, перебирает их в utility-функции — игрок и AI используют единый набор правил.

## Дерево сцены `battle.tscn`

```
BattleRoot (Node2D, battle_controller.gd)
├── Camera2D
├── HexTileMap (Node2D)
│   └── OverlayLayer (Node2D, для подсветки)
├── UnitsLayer (Node2D)               # сюда инстансятся UnitView
├── ProjectilesLayer (Node2D)         # стрелы/магия в полёте
├── InputController (Node)
├── TurnManager (Node)
├── EnemyAI (Node)
└── HUD (CanvasLayer, hud.gd)
```

`BattleController._ready()`:
1. `var ctx = BattleContext.consume()` (или fallback на dev_default).
2. Построить `HexGrid` из `BattlefieldData.layout`.
3. Создать `UnitInstance` для каждого юнита из `attacker` и `defender`, расставить на deploy_hex.
4. Спавн `UnitView` под каждый `UnitInstance`.
5. `TurnManager.start(battle_state)`.

## Интеграция с проектом

- **Autoload**: добавить `BattleContext` в `project.godot` после `SceneRouter` (строки 18–30).
- **EventBus** ([scripts/world/event_bus.gd](scripts/world/event_bus.gd)) — добавить сигналы `battle_started(battlefield_id)`, `battle_finished(result)` для аналитики/ачивок. Не обязательно для MVP.
- **Триггер из мира**: пока — заглушка `BattleTrigger` (Area2D), которую можно положить на settlement или на дороге; в будущем — расширить [scripts/world/settlement.gd](scripts/world/settlement.gd).
- **Возврат**: после `battle_finished` контроллер вызывает `BattleContext.on_finished.call(result)` и `SceneRouter.go_to_scene(return_scene, return_spawn_id)`.
- **Сохранение/загрузка**: в MVP бой не сохраняется в середине; результаты применяются к [game_state.gd](scripts/world/game_state.gd) через колбэк.

## Точки расширения (запланированы, но не реализуются в MVP)

- `BattlefieldData.weather` → пассивные модификаторы (через `StatusEffect`-ы на старте).
- `UnitData.ai_profile` → разные AI-стратегии.
- `AbilityData.script` → способности через GDScript-наследование `AbilityRuntime`.
- `TurnOrderStrategy` интерфейс → переключение HoMM ↔ BB.
- Замена кастомного `HexTileMap` на TileMap, если потребуется тайл-арт.

## Файлы, которые точно создаются в MVP

| Путь | Назначение |
|---|---|
| `scripts/battle/battle_context.gd` | autoload, входные параметры |
| `scripts/battle/battle_controller.gd` | root scene script |
| `scripts/battle/turn_manager.gd` | очередь ходов BB-стиля |
| `scripts/battle/input_controller.gd` | клик → команда |
| `scripts/battle/enemy_ai.gd` | utility-AI |
| `scripts/battle/hex/hex_coord.gd` | axial-математика |
| `scripts/battle/hex/hex_grid.gd` | модель сетки |
| `scripts/battle/hex/hex_cell.gd` | клетка |
| `scripts/battle/hex/pathfinder.gd` | A* |
| `scripts/battle/domain/battle_state.gd` | состояние боя |
| `scripts/battle/domain/unit_instance.gd` | runtime-юнит |
| `scripts/battle/domain/ability_runtime.gd` | способность |
| `scripts/battle/domain/damage_calculator.gd` | формулы |
| `scripts/battle/data/terrain_data.gd` | Resource |
| `scripts/battle/data/unit_data.gd` | Resource |
| `scripts/battle/data/ability_data.gd` | Resource |
| `scripts/battle/data/army_data.gd` | Resource |
| `scripts/battle/data/army_slot_data.gd` | Resource |
| `scripts/battle/data/battlefield_data.gd` | Resource |
| `scripts/battle/view/hex_tilemap.gd` | визуал сетки |
| `scripts/battle/view/unit_view.gd` | визуал юнита |
| `scripts/battle/view/hud.gd` | UI |
| `scenes/battle/battle.tscn` | корневая сцена |
| `scenes/battle/unit_view.tscn` | префаб юнита |
| `scenes/battle/hud.tscn` | префаб HUD |
| `resources/battle/battlefields/dev_default.tres` | для отладки |
| 2–3 `terrain_*.tres`, 2–3 `unit_*.tres` | тестовый набор |
| `project.godot` | регистрация `BattleContext` autoload |

## Verification

После имплементации (в отдельной задаче):

1. **Запуск из редактора напрямую**: открыть `scenes/battle/battle.tscn`, F6 → грузится `dev_default.tres`, расставлены 3 юнита atk vs 3 def на дефолтной местности. Можно ходить, атаковать, получить экран победы/поражения.
2. **Запуск через BattleContext**: добавить временную кнопку в [scenes/main.tscn](scenes/main.tscn), которая вызывает `BattleContext.setup(...)` + `SceneRouter.go_to_scene(...)`. Проверить, что параметры доходят и применяются.
3. **Возврат**: после боя — обратно в hub, `BattleContext.on_finished` вызван с корректным результатом.
4. **Edge cases**: пустая армия (graceful fail), все юниты одной стороны мертвы (`battle_finished` сигналит победителя), путь заблокирован (pathfinder возвращает пустой массив, UI не даёт ход).
5. **Юнит-тесты домена** (опц., через GUT или встроенный): `HexCoord.distance`, `Pathfinder.find_path`, `DamageCalculator.compute` для типовых случаев — фронт/фланг/тыл, разный terrain.

## Открытые вопросы (на этап имплементации, не блокируют план)

- Ориентация гексов зафиксирована: **flat-top**.
- Размер поля по умолчанию — рекомендую 11×9 (BB).
- Deploy phase: автостановка по `army_slot_data.deploy_hex` или ручная расстановка перед боем — MVP автостановка.
- Анимации: статичные спрайты + tween по гексам в MVP, AnimatedSprite2D позже.
