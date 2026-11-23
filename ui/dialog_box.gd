extends CanvasLayer
class_name DialogBox
## Modal briefing / victory dialog (design spec §3.5, §5.2).
##
## BaseLevel builds one of these, calls `play()` and awaits `closed` — before the
## waves start (briefing) and before moving to the next level (victory). The tree
## is paused while the box is up, so the briefing holds the level still (§3.5) and
## a held fire key cannot skip the victory text.

## Emitted once the player dismisses the dialog.
signal closed

@onready var _title: Label = $Root/Panel/Margin/VBox/TitleLabel
@onready var _body: Label = $Root/Panel/Margin/VBox/BodyLabel
@onready var _continue_button: Button = $Root/Panel/Margin/VBox/ContinueButton

var _open := false
var _armed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_continue_button.pressed.connect(_on_continue_pressed)


## Shows the dialog and pauses the game until it is dismissed.
func play(title: String, lines: Array[String]) -> void:
	if lines.is_empty():
		return
	_title.text = title
	_body.text = "\n".join(lines)
	visible = true
	_open = true
	# The fight below may still be holding a key down; ignore input briefly so
	# the dialog is not dismissed by the same press that opened it.
	_armed = false
	_wait_until_armed()
	get_tree().paused = true
	_continue_button.grab_focus()


func _wait_until_armed() -> void:
	await get_tree().create_timer(0.25).timeout
	_armed = true


func _unhandled_input(event: InputEvent) -> void:
	if not _open or not _armed:
		return
	if event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		_close()


func _on_continue_pressed() -> void:
	if _armed:
		_close()


func _close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	get_tree().paused = false
	closed.emit()
