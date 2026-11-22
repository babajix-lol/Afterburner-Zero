extends Node2D
class_name BaseLevel
## Reusable level template (design spec §5.2).
##
## Every level inherits or instances this structure. The only things that differ
## are the TileMapLayers (swapped per-level) and the LevelData resource that
## WaveManager reads from GameManager.

@onready var _camera: Camera2D = $Camera2D
@onready var _wave_manager: WaveManager = $WaveManager
@onready var _entities: Node2D = $Entities
@onready var _hud: CanvasLayer = $HUD

var _scrolling := true
var _scroll_speed := 60.0


func _ready() -> void:
	_entities.add_to_group(&"entities")
	var data := GameManager.level_data
	if data == null:
		# Direct F5 test: load level 1 data so the level works without SceneRouter.
		var fallback := load("res://data/levels/level_01.tres") as LevelData
		if fallback != null:
			GameManager.begin_level(fallback.level_index, fallback)
			data = fallback
	if data != null:
		_scroll_speed = data.scroll_speed
		if data.background_music != null:
			AudioManager.play_music(data.background_music)
	_wave_manager.start(self)
	EventBus.level_completed.connect(_on_level_completed)
	EventBus.player_died.connect(_on_player_died)


func _physics_process(delta: float) -> void:
	if _scrolling:
		_camera.position.y -= _scroll_speed * delta


func enter_boss_arena() -> void:
	_scrolling = false
	var data := GameManager.level_data
	if data == null or data.boss_scene == null:
		return
	var arena := get_node_or_null("BossArena") as Marker2D
	if arena != null:
		_camera.position = arena.global_position
	var boss := data.boss_scene.instantiate()
	_entities.add_child(boss)
	if boss is Node2D and arena != null:
		boss.global_position = arena.global_position + Vector2(0, -80)
	EventBus.boss_started.emit(boss)


func _on_level_completed(index: int) -> void:
	SaveManager.unlock_level(index + 1)
	SaveManager.submit_score(GameManager.score)


func _on_player_died() -> void:
	await get_tree().create_timer(2.0).timeout
	if not is_inside_tree():
		return
	SceneRouter.reload_current_level()
