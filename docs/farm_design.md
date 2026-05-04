# Farm Design

## Goal
Build a dedicated farm scene connected to town by a bridge. The farm should feel structured and readable:

- 12 separate fenced fields
- each field contains 9 cells
- only 2 fields are open at the start
- the remaining fields are future progression purchases
- the shed stores both seeds and harvested produce
- planting happens per cell, not per zone

## Albion Inspiration

What we keep from Albion:

- farming happens in a separate owned location
- the loop is simple: plant, wait, harvest
- expansion is tied to unlocking more productive space
- farming feeds the larger game instead of standing alone

What we adapt:

- no freeform placement
- no full MMO island economy
- no real-time mandatory daily login loop
- one field can hold vegetables, grain, trees, or other crops cell by cell

## Scene Structure

### Farm Layout

- `12` fields total
- `4 x 3` grid of fields
- every field is fenced
- every field has a gate on the lower side
- the intended movement rule is: fields are entered through gates
- the bridge is the exit back to town
- the shed sits near the bridge and acts as farm storage

### Field Structure

Each field contains:

- `9` cells
- `3 x 3` planting layout
- per-cell interaction

Each cell can be:

- empty
- growing
- ready to harvest

## Progression

- field 1 and field 2 start unlocked
- fields 3-12 are locked
- locked fields are bought one by one later
- buying a field unlocks all 9 of its cells

## Storage Model

The shed holds:

- seeds
- harvested produce

For now:

- planting consumes seeds from the shed
- harvesting sends produce into the shed
- produce does not automatically enter the main roster inventory
- later we can add transfer from shed to player inventory

## Interaction Model

### Cell Interaction

Right click on a field cell opens context actions.

Possible actions:

- `Plant`
- `Harvest`
- `Buy field` if the field is still locked

### Shed Interaction

At the shed the player can inspect:

- all available seed stock
- all harvested produce stock

## Crop List

First farming pass includes 10 plantables:

1. Wheat
2. Carrot
3. Potato
4. Cabbage
5. Tomato
6. Cucumber
7. Onion
8. Pumpkin
9. Corn
10. Apple tree

## Visual Direction

We use code-drawn crop mini-models directly in cells:

- wheat and corn use stalk silhouettes
- carrot uses root shapes
- potato uses soil mounds
- cabbage uses dense round foliage
- tomato uses clustered fruit circles
- cucumber uses vine-like shape
- onion uses a bulb form
- pumpkin uses a broad round cluster
- apple tree uses trunk + canopy + fruit

This keeps the first implementation lightweight while still making each crop readable.

## First Implementation Scope

- bridge transition from town
- 12 visible fenced fields
- 9 cells per field
- 2 unlocked fields by default
- locked field purchase flow
- right-click context menu per cell
- shed storage for seeds and produce
- 10 crop definitions
- simple crop visuals
- save/load via `GameState` and `WorldState`

## Follow-Up Ideas

- watering, fertilizer, or care actions
- crop quality tiers
- move produce from shed into player inventory
- recipes tied to specific crops
- medicine and buffs from crops
- tree re-harvest loops instead of one-shot harvest
- animals as a later adjacent system
