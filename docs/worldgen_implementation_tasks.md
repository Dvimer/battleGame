# Worldgen Implementation Tasks

## Phase 1. Data Layer

- [x] 1.1 Create `WorldGenConfig` resource with tile, chunk, biome, seed, and road settings
- [x] 1.2 Create `BiomeData` resource
- [x] 1.3 Create `SettlementData` resource
- [x] 1.4 Create `LocationData` resource
- [x] 1.5 Create `WorldMeta` resource container

## Phase 2. Generation Pipeline

- [x] 2.1 Create `BiomeGenerator`
- [x] 2.2 Create `SettlementGenerator`
- [x] 2.3 Create `RoadGenerator`
- [x] 2.4 Create `ObjectGenerator`
- [x] 2.5 Create `WorldAssembler`
- [x] 2.6 Create `WorldGenerator` autoload entry point

## Phase 3. Chunk System And Scene Tree

- [x] 3.1 Create `ChunkTileGenerator`
- [x] 3.2 Create `ChunkCache` autoload
- [x] 3.3 Create `ChunkManager` autoload
- [x] 3.4 Create `LocationSpawner`
- [x] 3.5 Create `Chunk` scene with layered rendering
- [x] 3.6 Create `World` scene

## Phase 4. Fog Of War

- [x] 4.1 Create `FogOfWar` autoload
- [x] 4.2 Create fog shader
- [x] 4.3 Create `ExploreTracker`

## Phase 5. Locations And Quests

- [x] 5.1 Create `EventBus` autoload
- [x] 5.2 Create `Settlement` scene with location enter flow
- [x] 5.3 Create `QuestChainData` resource
- [x] 5.4 Create `QuestChainGenerator`
- [x] 5.5 Create `QuestManager` autoload

## Phase 6. Save System

- [x] 6.1 Create `GameState` autoload
- [x] 6.2 Create `SaveManager`

## Integration

- [x] Add a new gate menu option that opens the generated world map
- [x] Treat the current city scene as the capital on the world map

## Next Tasks

- [x] Restore world-map player position between map visits
- [x] Persist discovered settlements and world exploration progress
- [x] Improve gate and world-map UI text for continued exploration
