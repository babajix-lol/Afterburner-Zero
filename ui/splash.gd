extends Control
## Splash / premise intro (design spec §3.1).
##
## Shows the two-line premise, then hands over to the main menu on any accept
## press. This is the project's entry scene (project.godot run/main_scene).

@onready var _continue_button: Button = $Center/Panel/Margin/VBox/ContinueButton

var _busy := false


func _ready() -> void:
	_continue_button.pressed.connect(_continue)
	_continue_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		_continue()


func _continue() -> void:
	if _busy:
		return
	_busy = true
	await SceneRouter.goto_main_menu()
