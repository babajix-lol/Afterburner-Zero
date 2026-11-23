extends Node2D
class_name BaseLevel
## Reusable level template (design spec §5.2).
##
## Every level inherits or instances this structure. The only things that differ
## are the environment tint (the per-level background palette), the LevelData
## resource, and the boss scene that data points at. The briefing/victory
## dialogs, the pause overlay and the run-over routing live here so no level
## scene has to repeat them (§5.6: one door for the shared flow).

const DIALOG_SCENE := preload("res://ui/dialog_box.tscn")
const PAUSE_SCENE := preload("res://ui/pause_menu.tscn")
const GAME_OVER_SCENE := "res://ui/game_over.tscn"
const VICTORY_SCENE := "res://ui/victory.tscn"

## Palette tinted onto the background so each level reads as siang / sore /
## mendung / malam / merah (§3.3) by recolouring reused art, not adding new PNGs.
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

## How far the auto-scroll moved the camera this physics frame. The player adds
## it to its own position so the jet holds its screen position while the world
## scrolls beneath it (instead of drifting backwards when no key is pressed).
var camera_delta := Vector2.ZERO


func _enter_tree() -> void:
	# Registered before the children's _ready(), so the Player can find the level
	# and read `camera_delta` on its very first frame.
	add_to_group(&"level")


func _ready() -> void:
	_entities.add_to_group(&"entities")
	if _backdrop != null:
		_backdrop.modulate = environment_tint
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
	_make_overlays()
	EventBus.level_completed.connect(_on_level_completed)
	EventBus.player_died.connect(_on_player_died)
	# §3.5: the briefing holds the level still until the player dismisses it.
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


## §5.3/§5.6: the pause overlay is shared by every level, so it is built here
## rather than duplicated in each level scene.
func _make_overlays() -> void:
	_dialog = DIALOG_SCENE.instantiate() as DialogBox
	add_child(_dialog)
	_pause_menu = PAUSE_SCENE.instantiate() as PauseMenu
	add_child(_pause_menu)


## Shows a modal dialog and returns once the player dismisses it.
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
	var arena := get_node_or_null("BossArena") as Marker2D
	if arena != null:
		_camera.position = arena.global_position
	var boss := data.boss_scene.instantiate()
	_entities.add_child(boss)
	if boss is Node2D and arena != null:
		boss.global_position = arena.global_position + Vector2(0, -80)
	EventBus.boss_started.emit(boss)


## §5.3: boss dead (or last wave cleared) -> save progress -> victory dialog ->
## next level, or the ending screen after Level 5.
func _on_level_completed(index: int) -> void:
	if _completing:
		return
	_completing = true
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


## §2: lives ran out -> Game Over screen (retry the same level, or leave).
func _on_player_died() -> void:
	await get_tree().create_timer(2.0).timeout
	if not is_inside_tree():
		return
	SceneRouter.goto_scene(GAME_OVER_SCENE)
