extends Resource
class_name LevelData

@export_range(1, 5, 1) var level_index: int = 1
@export var level_name: String = "Highway Breach"
@export var briefing_lines: Array[String] = []
@export var victory_lines: Array[String] = []
@export var background_music: AudioStream
@export var scroll_speed: float = 60.0
@export var boss_scene: PackedScene
@export var waves: Array[WaveData] = []
@export var difficulty: Dictionary = {
	"enemy_speed_mult": 1.0,
	"enemy_hp_bonus": 0,
	"fire_rate_mult": 1.0,
	"spawn_density_mult": 1.0,
}
