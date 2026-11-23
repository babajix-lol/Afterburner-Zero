extends CanvasLayer
class_name PauseMenu
## In-game pause overlay (design spec §5.6).
##
## BaseLevel builds one per level. `process_mode = ALWAYS` keeps it listening
## while `get_tree().paused` is true, which is what lets the same key both open
## and close it. It never steals a pause that a briefing/victory dialog owns.

@onready var _root: Control = $Root
@onready var _resume_button: Button = $Root/Panel/Margin/VBox/ResumeButton
@onready var _restart_button: Button = $Root/Panel/Margin/VBox/RestartButton
@onready var _menu_button: Button = $Root/Panel/Margin/VBox/MenuButton

var _open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	_resume_button.pressed.connect(_resume)
	_restart_button.pressed.connect(_restart)
	_menu_button.pressed.connect(_to_main_menu)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _open:
		_resume()
	elif not get_tree().paused:
		# A dialog also pauses the tree; leave that pause to the dialog.
		_pause()
	get_viewport().set_input_as_handled()


func _pause() -> void:
	_open = true
	_root.visible = true
	get_tree().paused = true
	_resume_button.grab_focus()


func _resume() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	get_tree().paused = false


func _restart() -> void:
	_resume()
	await SceneRouter.reload_current_level()


func _to_main_menu() -> void:
	_resume()
	await SceneRouter.goto_main_menu()
