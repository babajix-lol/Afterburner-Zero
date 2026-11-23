extends Control
## Ending screen after Level 5 (design spec §5.3).
##
## Reads the final level's victory lines straight from level_05.tres so the
## ending text lives in the same place as every other line of dialog.

const FINAL_LEVEL_DATA := "res://data/levels/level_05.tres"

@onready var _ending_label: Label = $Center/Panel/Margin/VBox/EndingLabel
@onready var _score_label: Label = $Center/Panel/Margin/VBox/ScoreLabel
@onready var _menu_button: Button = $Center/Panel/Margin/VBox/MenuButton

var _busy := false


func _ready() -> void:
	# Score was already submitted per level; this keeps the run closed out.
	GameManager.end_run()
	_ending_label.text = _ending_text()
	_score_label.text = "FINAL SCORE: %d\nBEST SCORE: %d" % [GameManager.score, SaveManager.get_best_score()]
	_menu_button.pressed.connect(_to_main_menu)
	_menu_button.grab_focus()


func _ending_text() -> String:
	if ResourceLoader.exists(FINAL_LEVEL_DATA):
		var data := load(FINAL_LEVEL_DATA) as LevelData
		if data != null and not data.victory_lines.is_empty():
			return "\n".join(data.victory_lines)
	return "MISSION COMPLETE."


func _to_main_menu() -> void:
	if _busy:
		return
	_busy = true
	await SceneRouter.goto_main_menu()
