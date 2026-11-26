extends Control

const GAME_OVER_BGM_PATH := "res://assets/audio/bgm/bgm_gameover.wav"

@onready var _score_label: Label = $Center/Panel/Margin/VBox/ScoreLabel
@onready var _retry_button: Button = $Center/Panel/Margin/VBox/RetryButton
@onready var _menu_button: Button = $Center/Panel/Margin/VBox/MenuButton

var _busy := false

func _ready() -> void:
	AudioManager.play_music_path(GAME_OVER_BGM_PATH, 0.35)
	_score_label.text = "SCORE: %d" % GameManager.score
	_retry_button.pressed.connect(_retry)
	_menu_button.pressed.connect(_to_main_menu)
	_retry_button.grab_focus()

func _retry() -> void:
	if _busy:
		return
	_busy = true
	var index := clampi(GameManager.current_level, 1, 5)
	GameManager.start_run()
	await SceneRouter.goto_level(index)

func _to_main_menu() -> void:
	if _busy:
		return
	_busy = true
	await SceneRouter.goto_main_menu()
