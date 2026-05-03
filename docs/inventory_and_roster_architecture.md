# Архитектура: инвентарь, ростер, лагерь

## Context

Система живёт **только на мировой карте** (out of battle). Сцена боя [docs/battle_scene_architecture.md](battle_scene_architecture.md) её не использует напрямую — она получает уже собранный `ArmySlotData` с экипировкой и возвращает `BattleResult` с дельтами. Контракт между мирами описан в боевом доке, раздел «Контракт боя с системой экипировки».

Что входит:

- **Общий инвентарь отряда** (списковый, с фильтрами, ёмкостью, как обоз в Battle Brothers).
- **Ростер бойцов** — персистентные профили юнитов между боями (имя, уровень, экипировка, постоянные раны).
- **Слоты экипировки** на каждом бойце (голова/тело/основное оружие/второе оружие/пояс).
- **Лагерь** — починка через Tools, лечение через Medicine, крафт, кастомизация внешности.
- **Прочность** — атрибут самих предметов (`ItemInstance.durability`). На бойце не хранится: вещь можно передать, положить в обоз или поднять с врага, прочность едет вместе с ней.
- **Раны** — атрибут бойца (`RosterUnit.persistent_wounds`). Принадлежат человеку, а не его шмоту. В бою временно отражаются как `StatusEffect` в `UnitInstance.status_effects`, после боя `BattleResult` возвращает изменения обратно в персонажа.

Сцены боя и арены `city_run.tscn` это не касается.

## Ключевой принцип: Data vs Instance

Тот же раскол, что у юнитов в боевом слое (`UnitData` — статичный шаблон; `UnitInstance` — runtime), применяется ко всему предметному миру:

- **`*Data`** (`extends Resource`, `.tres`) — неизменяемый шаблон: «Iron Sword», «Bandage», «Plate Armor». Один на все экземпляры в игре.
- **`*Instance`** (обычный класс GDScript, не Resource — чтобы избежать кеширования между save-load) — конкретная вещь в инвентаре: ссылка на Data + изменяемое состояние (`durability`, `charges`, `paint`, `enchants`, кастомное имя).

Это критично для прочности, краски, заряженных расходников и трофеев — у каждой вещи **свой** мутируемый стейт.

## Структура каталогов

```
scripts/items/
  data/
	item_data.gd              # base: id, display_name, weight, value, icon, stack_size, rarity, max_durability
	weapon_data.gd            # extends ItemData: damage, reach, attack_abilities[], two_handed, weapon_class, wear_per_hit
	shield_data.gd            # extends ItemData: block_chance, block_value, off_hand_abilities[], wear_per_block
	armor_data.gd             # extends ItemData: slot (HEAD|BODY), armor_value, fatigue_penalty, wear_per_block
	consumable_data.gd        # extends ItemData: charges, use_ability (AbilityData), out_of_battle_use
	tool_data.gd              # extends ItemData: repair_efficiency, craft_efficiency
	material_data.gd          # extends ItemData: trophy / craft_input / food
	paint_data.gd             # extends ItemData: tint Color, allowed_targets [shield|cape|armor]
	emblem_data.gd            # extends ItemData: emblem texture id
	loot_table_data.gd        # entries: [item_data, drop_chance, count_min, count_max]
	weapon_enchant_data.gd    # input mats, applies_to weapon_class[], stat modifiers
  item_instance.gd            # runtime: data, durability, charges, paint, emblem, enchants[], custom_name

scripts/world/roster/
  roster_inventory.gd         # autoload: items[], capacity, currency, tools, medicine, supplies
  roster_unit.gd              # persistent profile: id, name, level, base_unit_data, equipped, quick_slots, secondary_set,
							  #   appearance, persistent_wounds, total_battles, perm_stat_bonuses
  roster_manager.gd           # autoload: roster_units[], hire/fire, party selection, apply_battle_result(result)

scripts/world/camp/
  camp_manager.gd             # autoload: оркестратор привала, состояние "идёт привал", прогресс времени
  repair_service.gd           # repair_item(item, tools_pool) -> RepairResult
  craft_service.gd            # craft(recipe, inputs) -> ItemInstance | error; apply_enchant(item, enchant)
  medicine_service.gd         # treat_wound(unit, wound, consumable) -> TreatResult

scripts/world/appearance/
  appearance_state.gd         # Resource: skin_tint, hair_id, shield_paint, shield_emblem, cape_paint

scripts/world/wounds/
  wound_data.gd               # extends StatusEffectData: requires_consumable_class, severity, persist_after_battle=true

scenes/inventory/
  inventory.tscn              # экран общего инвентаря + drag-drop в слоты выбранного юнита
scenes/camp/
  camp.tscn                   # экран лагеря: вкладки Repair / Craft / Medicine / Customize

resources/items/
  weapons/{...}.tres
  armor/{...}.tres
  consumables/{bandage,splint,antibiotic_herbs,...}.tres
  materials/{leather,sinew,venom_gland,...}.tres
  tools/{repair_kit,...}.tres
  paints/{red,blue,...}.tres
  emblems/{wolf,raven,...}.tres
resources/wounds/
  bleeding.tres
  broken_bone.tres
  infection.tres
resources/recipes/
  reinforced_grip.tres
  poison_coating.tres
resources/tuning/
  inventory_tuning.tres       # carry_capacity, stack_size, weight scalars
  combat_tuning.tres          # k_fatigue, k_init, k_overload, threshold (читает бой через свой слой)
```

`scripts/items/` намеренно вне `world/` — предметы не привязаны к миру, бой тоже о них «знает» через `ItemInstance`. Это общий слой.

## Слоты экипировки

Слоты — на стороне юнита, не глобальный enum. `UnitData` уже описан в боевом доке, расширение:

```gdscript
# UnitData (extends Resource) — расширение для экипировки
@export var allowed_slots: Array[int]      # enum Slot: HEAD, BODY, MAIN_HAND, OFF_HAND, BACK, NECK, BELT_1..BELT_4
@export var quick_slot_count: int = 3      # пояс/карманы для расходников
@export var has_secondary_set: bool = false  # второй комплект MAIN/OFF для свапа в бою
@export var carry_capacity: int = 30       # вес, выше которого начинается перегруз
```

`Slot` — глобальный enum в `scripts/items/data/item_data.gd`:

```gdscript
enum Slot {
	HEAD, BODY, MAIN_HAND, OFF_HAND, BACK, NECK,
	BELT_1, BELT_2, BELT_3, BELT_4
}
```

**RosterUnit** (persistent, между боями) хранит экипировку:

```gdscript
class_name RosterUnit
@export var id: String
@export var display_name: String
@export var base_unit_data: UnitData               # шаблон класса
@export var level: int = 1
@export var equipped: Dictionary = {}              # Slot -> ItemInstance
@export var quick_slots: Array[ItemInstance] = []
@export var secondary_set: Dictionary = {}         # Slot -> ItemInstance (только MAIN/OFF при has_secondary_set)
@export var appearance: AppearanceState = null
@export var persistent_wounds: Array[StatusEffect] = []
@export var perm_stat_bonuses: Dictionary = {}     # ручные/прокачные бонусы

func equip(slot: int, item: ItemInstance) -> void
func unequip(slot: int) -> ItemInstance
func swap_secondary_set() -> void                  # вне боя — мгновенно, в бою — через AbilityData "swap_set"
func to_army_slot() -> ArmySlotData                # сборка для передачи в бой
```

`base_unit_data` определяет **тип** (footman/archer/spearman) и `allowed_slots`. Левел и постоянные бонусы — на ростер-юните, а не на data — позволяет двум одинаковым «footman»-ам прокачиваться независимо.

## Общий инвентарь (обоз)

Списковый, с ёмкостью и фильтрами:

```gdscript
class_name RosterInventory  # autoload
var items: Array[ItemInstance] = []
var capacity: int = 80                  # увеличивается покупкой телег/животных
var currency: int = 0                   # золото/эссенция

# отдельные пулы расходных ресурсов кампа — не в общем списке предметов
var tools: int = 0
var medicine: int = 0
var supplies: int = 0                   # еда/вода для отдыха

func add(item: ItemInstance) -> bool    # false если перевес
func remove(item: ItemInstance) -> void
func filter(predicate: Callable) -> Array[ItemInstance]
func current_weight() -> int
func is_overloaded() -> bool
```

Фильтры в UI: `weapons / armor / consumables / materials / tools / trophies / all` — реализуются как замыкания над `data.get_class()` или `data.tag`.

`tools/medicine/supplies` вынесены отдельными счётчиками, а не как стек `ItemInstance` — это сознательно: они тратятся непрерывно (на починку каждого предмета — дробная доля). Удобнее одно число, чем «расходовать половину Repair Kit».

## Вес → fatigue → инициатива

Эта формула срабатывает **в бою** при сборке `UnitInstance` и при изменении экипировки в бою (свап сета). Параметры читаются из `resources/tuning/combat_tuning.tres`:

```
total_weight = Σ item.data.weight для equipped + quick_slots
weight_overload = max(0, total_weight - unit.data.carry_capacity)

unit.max_fatigue   = base_max_fatigue - total_weight * k_fatigue
unit.initiative    = base_initiative  - total_weight * k_init - weight_overload * k_overload
unit.move_ap_cost  = base_move_cost   + floor(total_weight / threshold)
```

Балансер тюнит через `combat_tuning.tres` без правок кода.

## Прочность и расход зарядов

`ItemInstance` — единственное место, где живёт мутируемый стейт:

```gdscript
class_name ItemInstance
var data: ItemData
var durability: int = -1                   # -1 = нерасходуемое; иначе остаток HP предмета
var max_durability: int                    # копия data.max_durability при создании
var charges: int = -1                      # для расходников
var paint: PaintData = null
var emblem: EmblemData = null
var enchants: Array[WeaponEnchantData] = []
var custom_name: String = ""

static func from_data(data: ItemData) -> ItemInstance
func is_broken() -> bool                   # durability == 0
func tick_wear(amount: int) -> void
func consume_charge() -> bool              # false если зарядов нет
```

**Бой не мутирует ItemInstance напрямую.** Он копит `durability_delta` и `charges_delta` в `BattleResult` и передаёт их в `RosterManager.apply_battle_result(result)`, который применяет дельты атомарно. Это нужно, чтобы:

- проигранный бой можно было «откатить» без потери прочности (если введём такую механику);
- save-load был детерминирован — мутации только в одном месте;
- тестирование боя возможно без подмены ItemInstance моками.

## Починка через Tools

`RepairService.repair_item(item, tools_pool) -> RepairResult`:

```
missing = item.max_durability - item.durability
tools_needed = ceil(missing * item.data.weight / item.data.repair_efficiency_factor)
if tools_pool.tools < tools_needed:
	restore_partial = tools_pool.tools * item.data.repair_efficiency_factor / item.data.weight
	item.durability += floor(restore_partial)
	tools_pool.tools = 0
else:
	item.durability = item.max_durability
	tools_pool.tools -= tools_needed
return RepairResult(restored_amount, tools_spent)
```

Вызывается из UI лагеря. Принципиально: **один пул Tools на весь отряд** — обоз делит ресурсы, а не каждый юнит свои.

## Раны и медицина

Раны — `StatusEffect` с `persist_after_battle = true`. Бой кладёт их в `BattleResult.persistent_wounds_per_unit`, ростер переносит в `RosterUnit.persistent_wounds`. На мировой карте они продолжают тикать (в зависимости от типа — кровотечение перестаёт само через N часов, инфекция нет).

Лечение — через `MedicineService.treat_wound(unit, wound, consumable)`:

- расходует `Medicine` (общеотрядный счётчик) или конкретный `ConsumableData` из инвентаря;
- удаляет/ослабляет конкретный `WoundData` по `requires_consumable_class`;
- `severity` определяет цену лечения и шанс осложнений.

Каталог ран:

| Wound | Severity | Эффект | Снимается |
|---|---|---|---|
| `bleeding.tres` | 1 | −1 HP/раунд в бою, −1 HP/час на карте | `bandage` (ConsumableData) |
| `broken_bone.tres` | 2 | move_ap_cost ×2, нельзя экипировать тяжёлое в эту руку | `splint` |
| `infection.tres` | 3 | +1 fatigue/раунд, прогрессирует в смерть на карте | `antibiotic_herbs` |
| `concussion.tres` | 2 | −2 initiative, −20% accuracy | время (3 дня) или `medicine_kit` |

В **бою** расходники работают через `ConsumableData.use_ability` → синтетическая `AbilityData` в `quick_slots`. Это уже описано в боевом доке как часть контракта.

## Лут и трофеи

Дроп с врагов — на стороне `UnitData.loot_table: LootTableData`. Бой кидает кости при смерти и собирает в `BattleResult.pending_loot`. После боя:

1. UI экрана добычи (`scenes/loot/loot_screen.tscn`, отдельная сцена) показывает выпавшее.
2. Игрок выбирает что забрать с учётом `RosterInventory.is_overloaded()`.
3. `RosterInventory.add(item)` для каждого выбранного.

Трофеи (`MaterialData` с `tag = "trophy"`) идут в инвентарь как обычный материал — отличаются только тем, что используются в рецептах крафта.

## Крафт и энчанты

`CraftService` принимает рецепты двух типов:

**Создание предмета** (`CraftRecipeData`):
```
input: [(material_data, count), ...]
output: ItemData
tools_cost: int
```

**Энчант оружия** (`WeaponEnchantData`):
```
input: [(material_data, count), ...]
applies_to: Array[String]   # weapon_class
modifiers: Dictionary       # damage +N, fatigue_per_hit -1, и т.п.
adds_status_to_attacks: StatusEffectData | null
```

Применение: `CraftService.apply_enchant(item_instance, enchant)`:
- проверяет `weapon_class` против `enchant.applies_to`;
- проверяет наличие материалов в `RosterInventory`;
- мутирует `item_instance.enchants.append(enchant)`;
- списывает материалы.

Бой при подсчёте урона учитывает `weapon.enchants[].modifiers` через `DamageCalculator.compute()` — это уже часть формулы оружия, в боевом доке не выделяется отдельно.

## Кастомизация внешнего вида

`AppearanceState` — Resource на `RosterUnit`:

```gdscript
class_name AppearanceState extends Resource
@export var skin_tint: Color = Color.WHITE
@export var hair_id: String = ""
@export var shield_paint: Color = Color.WHITE
@export var shield_emblem: EmblemData = null
@export var cape_paint: Color = Color.WHITE
```

Применение в бою: `UnitView._ready()` копирует `appearance` из `UnitInstance` (заполненного из `ArmySlotData.appearance`) и применяет `modulate` к слоям-Sprite2D (тело, щит, плащ) + текстуру эмблемы.

Краска и эмблемы — `ConsumableData` с `out_of_battle_use = true`. Использование в лагере (вкладка Customize):
- выбираешь юнита → выбираешь слот (щит/плащ/броня) → выбираешь баночку краски → `paint.charges -= 1`, `unit.appearance.shield_paint = paint.tint`.

Никакой особой логики — тот же `ConsumableData.use_ability` pipeline, только цель — `AppearanceState`, а не `UnitInstance.status_effects`.

## Связь со сценой боя

Один направленный канал в каждую сторону, через `BattleContext` (см. боевой док):

**В бой:**

```gdscript
# мировой код перед запуском боя
var party = RosterManager.selected_party       # Array[RosterUnit]
var attacker_army := ArmyData.new()
for ru in party:
	attacker_army.units.append(ru.to_army_slot())   # копирует equipped/quick_slots/appearance/persistent_wounds

BattleContext.setup(battlefield, attacker_army, defender_army)
SceneRouter.go_to_scene("res://scenes/battle/battle.tscn", "")
```

`RosterUnit.to_army_slot()` — единственная точка сериализации ростер-юнита в боевую форму. Если поле появилось в `RosterUnit`, но забыли пробросить в `ArmySlotData` — оно не доедет до боя.

**Из боя:**

```gdscript
# BattleContext.on_finished — Callable, выставленный мировым кодом
func _on_battle_finished(result: BattleResult) -> void:
	RosterManager.apply_battle_result(result)
```

`RosterManager.apply_battle_result(result)`:

```gdscript
func apply_battle_result(result: BattleResult) -> void:
	for unit_id in result.killed:
		_remove_from_roster(unit_id)
	for unit_id in result.persistent_wounds_per_unit:
		var ru := _find(unit_id)
		ru.persistent_wounds.append_array(result.persistent_wounds_per_unit[unit_id])
	for item in result.durability_delta:
		item.durability = max(0, item.durability + result.durability_delta[item])
	for item in result.charges_delta:
		item.charges = max(0, item.charges + result.charges_delta[item])
	# лут пробрасывается отдельно — после loot screen
```

Ключевое: ростер не зависит от внутренней структуры боя, бой не зависит от ростера. Контракт — `BattleResult` + `ArmySlotData`.

## Сохранение/загрузка

Расширение [scripts/world/game_state.gd](scripts/world/game_state.gd):

```
save format additions:
  roster_inventory: { items: [...], capacity, currency, tools, medicine, supplies }
  roster_units: [ {id, name, level, base_unit_data: <resource_path>, equipped: {slot: item}, ...} ]
```

`ItemData` сериализуется как `resource_path` (паттерн уже используется для `BiomeData`/`SettlementData`). Сам `ItemInstance` — словарь runtime-полей (`durability`, `charges`, `paint`, `emblem`, `enchants`, `custom_name`) + ссылка на data.

`RosterUnit` сериализуется как Resource (`@export` поля + `ResourceSaver`) или как dict — TBD на этапе реализации.

## UI: сцены вне боя

### `scenes/inventory/inventory.tscn`

Две колонки:
- **слева**: список инвентаря с фильтрами (segment-buttons по типу), поиск, сортировка (вес/название/ценность);
- **справа**: «карта юнита» выбранного `RosterUnit` со слотами экипировки (paper-doll), drag-drop из списка в слоты;

Внизу — индикатор `current_weight / capacity`, кнопки `Repair All` / `Sort` / `Drop Selected`.

### `scenes/camp/camp.tscn`

Вкладки:
- **Rest** — отдых на N часов: восстанавливает HP, fatigue, перерыв ран, тратит `supplies`.
- **Repair** — список повреждённых предметов, выбор «починить всё» / выборочно, тратит `tools`.
- **Treat** — список юнитов с активными ранами, выбор расходника или `medicine`, тратит `medicine`/конкретный consumable.
- **Craft** — список рецептов, проверка материалов, кнопка «создать»; отдельно подвкладка «Энчанты» для оружия.
- **Customize** — выбор юнита → выбор слота (щит/плащ/доспех) → краска или эмблема, тратит `PaintData.charges`.

Лагерь — самостоятельная сцена, вызывается из `world.tscn` (например, через действие «Разбить лагерь» на дороге или в поселении).

### `scenes/loot/loot_screen.tscn`

Показывается между `BattleController.finalize()` и возвратом в мир. Список выпавшего, чекбоксы, индикатор веса, «Take» / «Leave».

## Точки расширения (не реализуются в MVP)

- **Покупка телег/животных** для расширения `RosterInventory.capacity` — отдельная сцена «Караван».
- **Деградация качества при починке** — после N репараций предмет теряет `max_durability`.
- **Ритуальные предметы** — `ItemData` с пассивным эффектом на отряд, не занимающий слот.
- **Перковая система** на `RosterUnit` — отдельная вкладка инвентаря.
- **Торговля** в поселениях — `MarketData` со списком, скидки от репутации.

## Что нужно от MVP боя (повтор для удобства)

В боевом доке это раздел «Контракт боя с систшемой экипировки». Шесть хуков:

1. `UnitInstance.equipped`, `quick_slots` (поля).
2. `UnitInstance.get_combat_abilities()` (метод, единственный источник для HUD/AI).
3. `UnitInstance.compute_armor / total_weight / initiative / max_fatigue` (производные стат-методы).
4. `AbilityData.allowed_weapon_classes` (поле).
5. `StatusEffect.persist_after_battle` (флаг в data).
6. `BattleResult` со всеми полями (даже пустыми в MVP).

Когда эти шесть точек на месте, инвентарь/ростер/лагерь добавляются как отдельная пост-MVP задача без правок боевого кода.

## Открытые вопросы

- `RosterUnit.persistent_wounds` хранит `StatusEffect` или `WoundData`-ссылку с runtime-таймером? — рекомендую отдельный класс `WoundInstance` с `data + remaining_time`, чтобы не плодить `StatusEffect`-объекты вне боя.
- Прочность: одна шкала или две (быстрая «острота» оружия + долгая «структура»)? — MVP одна шкала.
- Веса предметов: целые числа или дробные? — рекомендую целые (BB), проще баланс.
- Делить ли `tools/medicine/supplies` на пулы по типам или один общий? — рекомендую три отдельных пула (BB style), фокус ресурс-менеджмента.
- Камп — мгновенный (нажал — применилось) или тратит игровое время? — рекомендую тратит время, чтобы лагерь конкурировал с продвижением по миру.
- Карта paper-doll: один шаблон на всех или зависит от `UnitData.allowed_slots`? — динамически по `allowed_slots`, чтобы зверь без брони не показывал пустые слоты.
