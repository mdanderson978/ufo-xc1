extends Node
## Global signal hub. Screens and systems communicate across module
## boundaries only through these signals, never by direct reference.

## Ask the screen router to switch top-level screens.
## screen_id: one of Main.SCREENS keys. payload: screen-specific dict.
signal screen_change_requested(screen_id: String, payload: Dictionary)

## Emitted by GameState whenever campaign state mutates in a way UI
## should reflect (funds, personnel, research, calendar...).
signal campaign_state_changed()

## Battlescape lifecycle.
signal battle_started(battle_setup: Dictionary)
signal battle_finished(battle_result: Dictionary)
