extends Control
## Game Over screen (design spec §2: retry the same level from the start).
##
## Retry restarts the run at the level the player died on — GameManager.start_run()
## restores lives/bombs/score, then goto_level() re-loads it. Since start_run()
## clears current_level, the index is captured first.

@onready var _score_label: Label = $Center/Panel/Margin/VBox/ScoreLabel
@onready var _retry_button: Button = $Center/Panel/Margin/VBox/RetryButton
@onready var _menu_button: Button = $Center/Panel/Margin/VBox/MenuButton

var _busy := false


func _ready() -> void:
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
