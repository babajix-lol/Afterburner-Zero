extends Node2D
class_name BaseLevel

const DIALOG_SCENE := preload("res://ui/dialog_box.tscn")
const PAUSE_SCENE := preload("res://ui/pause_menu.tscn")
const GAME_OVER_SCENE := "res://ui/game_over.tscn"
const VICTORY_SCENE := "res://ui/victory.tscn"
const BOSS_BGM_PATH := "res://assets/audio/bgm/bgm_boss.wav"
const VICTORY_BGM_PATH := "res://assets/audio/bgm/bgm_victory.wav"

@export var environment_tint: Color = Color.WHITE

@onready var _camera: Camera2D = $Camera2D
@onready var _wave_manager: WaveManager = $WaveManager
@onready var _entities: Node2D = $Entities
@onready var _hud: CanvasLayer = $HUD
@onready var _backdrop: Sprite2D = $Background/Backdrop

var _scrolling := true
var _scroll_speed := 60.0
var _dialog: DialogBox = null
var _pause_menu: PauseMenu = null
var _completing := false
var camera_delta := Vector2.ZERO

func _enter_tree() -> void:
	add_to_group(&"level")

func _ready() -> void:
	_entities.add_to_group(&"entities")
	if _backdrop != null:
		_backdrop.modulate = environment_tint
	var data := GameManager.level_data
	if data == null:
		var scene_name := name
		var fallback_path := "res://data/levels/level_01.tres"
		if scene_name.begins_with("Level"):
			var num_str := scene_name.trim_prefix("Level")
			if num_str.is_valid_int():
				fallback_path = "res://data/levels/level_%02d.tres" % num_str.to_int()
		var fallback := load(fallback_path) as LevelData
		if fallback != null:
			GameManager.begin_level(fallback.level_index, fallback)
			data = fallback
	if data != null:
		_scroll_speed = data.scroll_speed
		if data.background_music != null:
			AudioManager.play_music(data.background_music)
	_make_overlays()
	EventBus.level_completed.connect(_on_level_completed)
	EventBus.player_died.connect(_on_player_died)
	if data != null and not data.briefing_lines.is_empty():
		await _show_dialog("BRIEFING", data.briefing_lines)
	if not is_inside_tree():
		return
	_wave_manager.start(self)

func _physics_process(delta: float) -> void:
	if _scrolling:
		var step := Vector2(0.0, -_scroll_speed * delta)
		_camera.position += step
		camera_delta = step
	else:
		camera_delta = Vector2.ZERO

func _make_overlays() -> void:
	_dialog = DIALOG_SCENE.instantiate() as DialogBox
	add_child(_dialog)
	_pause_menu = PAUSE_SCENE.instantiate() as PauseMenu
	add_child(_pause_menu)

func _show_dialog(title: String, lines: Array[String]) -> void:
	if _dialog == null or lines.is_empty():
		return
	_dialog.play(title, lines)
	await _dialog.closed

func enter_boss_arena() -> void:
	_scrolling = false
	var data := GameManager.level_data
	if data == null or data.boss_scene == null:
		return
	AudioManager.play_music_path(BOSS_BGM_PATH, 0.35)
	var cam_center := _camera.get_screen_center_position()
	var arena := get_node_or_null("BossArena") as Marker2D
	if arena != null:
		arena.global_position = cam_center
	var boss := data.boss_scene.instantiate()
	_entities.add_child(boss)
	if boss.has_method(&"setup_arena"):
		boss.setup_arena(cam_center)
	elif boss is Node2D:
		boss.global_position = Vector2(cam_center.x, cam_center.y - 230.0)
	EventBus.boss_started.emit(boss)

func _on_level_completed(index: int) -> void:
	if _completing:
		return
	_completing = true
	AudioManager.play_music_path(VICTORY_BGM_PATH, 0.3)
	SaveManager.unlock_level(index + 1)
	SaveManager.submit_score(GameManager.score)
	var data := GameManager.level_data
	if data != null and not data.victory_lines.is_empty():
		await _show_dialog("MISSION COMPLETE", data.victory_lines)
	if not is_inside_tree():
		return
	if index >= 5:
		SceneRouter.goto_scene(VICTORY_SCENE)
	else:
		SceneRouter.goto_level(index + 1)

func _on_player_died() -> void:
	await get_tree().create_timer(2.0).timeout
	if not is_inside_tree():
		return
	SceneRouter.goto_scene(GAME_OVER_SCENE)
