extends Node
## Global signals that keep the HUD and gameplay decoupled (design spec §5.5).
##
## Gameplay systems emit here; HUD, dialogs and audio listen. Neither side
## holds a reference to the other, so a level can be rebuilt without touching
## the UI and vice versa.
##
## Signals do not replay: a listener that connects late must read the current
## value from GameManager (which re-announces on level start).

## Score changed. `value` is the new total, not a delta.
signal score_changed(value: int)

## Lives remaining (hearts).
signal lives_changed(value: int)

## Bombs remaining.
signal bomb_changed(value: int)

## Active weapon changed; `weapon_data` is null for the default cannon.
signal weapon_changed(weapon_data: WeaponData)

## Shield timer changed, in seconds remaining (0 = no shield).
signal shield_changed(value: float)

## A wave started. `index` is 0-based, `total` is the wave count of the level.
signal wave_started(index: int, total: int)

## The level's boss entered the arena.
signal boss_started(boss: Node)

## The level was cleared (§5.3: triggers save + victory dialog).
signal level_completed(index: int)

## Score multiplier changed (§4.6 combo system).
signal combo_changed(value: int)

## The run is over — lives hit zero.
signal player_died()
