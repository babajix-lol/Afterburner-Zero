extends Resource
class_name LevelData
## Everything that defines one level (design spec §6.1).
##
## SceneRouter loads data/levels/level_0N.tres, hands it to GameManager, then
## swaps in levels/level_0N.tscn — the level scene reads this back and adds no
## balancing of its own. §4.7's difficulty table lives in `difficulty`.

@export_range(1, 5, 1) var level_index: int = 1

@export var level_name: String = "Highway Breach"

## 2-3 lines shown in the pre-level briefing dialog.
@export var briefing_lines: Array[String] = []

## 1-2 lines shown after the boss dies.
@export var victory_lines: Array[String] = []

@export var background_music: AudioStream

## Camera scroll speed for the auto-scroll segment (px/s at the level's scale).
@export var scroll_speed: float = 60.0

## Boss to spawn at BossArena. Null for Level 1, which ends on a wave.
@export var boss_scene: PackedScene

@export var waves: Array[WaveData] = []

## Central difficulty multipliers (§4.7). Read by enemies and WaveManager:
## enemy_speed_mult, enemy_hp_bonus, fire_rate_mult, spawn_density_mult.
@export var difficulty: Dictionary = {
	"enemy_speed_mult": 1.0,
	"enemy_hp_bonus": 0,
	"fire_rate_mult": 1.0,
	"spawn_density_mult": 1.0,
}
