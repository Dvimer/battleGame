# Battle Scene Implementation Tasks

## Phase 1. Independent Mock Vertical Slice

- [x] Create `scripts/battle/` architecture folders
- [x] Add battle data resources for terrain, units, armies, battlefield
- [x] Add `BattleContext` autoload entry point
- [x] Add mock context factory for isolated editor launch
- [x] Add axial hex helpers, grid, cells, and pathfinder
- [x] Add runtime domain model: battle state, unit instance, damage calculator
- [x] Add turn manager, input controller, and simple enemy AI
- [x] Add custom-drawn hex map, unit view, and HUD
- [x] Add `scenes/battle/battle.tscn`
- [x] Verify new battle scripts with Godot `--check-only`
- [x] Verify `battle.tscn` loads headless with mock data

## Phase 2. Tactical MVP

- [x] Add explicit command objects: move, attack, wait, defend
- [x] Add visible path preview before movement
- [x] Add attack target preview and combat forecast
- [x] Add zones of control
- [x] Add defend/wait actions in HUD
- [x] Add battle result screen with return button

## Phase 2.1. Tactical Polish

- [ ] Add separate action bar driven by `UnitData.abilities`
- [ ] Add command validation messages per failure type
- [ ] Add right-click/ESC cancel for pending actions
- [ ] Add visible turn queue strip
- [ ] Add better unit hover cards
- [ ] Add movement animation along every path step, not direct tween to final hex

## Phase 3. Content Resources

- [ ] Move mock terrains into `.tres` resources
- [ ] Move mock unit definitions into `.tres` resources
- [ ] Add `AbilityData` and basic melee/ranged abilities
- [ ] Add `BattlefieldData` resource presets
- [ ] Add simple unit sprites or icons

## Phase 4. World Integration

- [ ] Add `BattleTrigger` for world-map testing
- [ ] Feed `BattleContext` from a settlement/encounter
- [ ] Return result through `BattleContext.on_finished`
- [ ] Apply rewards/losses to world state
- [ ] Add `EventBus` battle_started/battle_finished signals
