extends Control

const LEVEL_DATA_PATH := "res://data/levels/level_%02d.tres"
const MENU_BGM_PATH := "res://assets/audio/bgm/bgm_menu.wav"
const LEVEL_COUNT := 5

@onready var _list: VBoxContainer = $Center/Panel/Margin/VBox/List
@onready var _back_button: Button = $Center/Panel/Margin/VBox/BackButton

var _busy := false
var _buttons: Array[Button] = []

func _ready() -> void:
	AudioManager.play_music_path(MENU_BGM_PATH, 0.35)
	_back_button.pressed.connect(_on_back)
	_build_buttons()

func _build_buttons() -> void:
	var unlocked := SaveManager.get_unlocked_level()
	for index in range(1, LEVEL_COUNT + 1):
		var button := Button.new()
		button.text = _label_for(index)
		button.disabled = index > unlocked
		button.pressed.connect(_on_level_pressed.bind(index))
		_list.add_child(button)
		_buttons.append(button)
	for button in _buttons:
		if not button.disabled:
			button.grab_focus()
			break

func _label_for(index: int) -> String:
	var text := "LEVEL %d" % index
	var path := LEVEL_DATA_PATH % index
	if ResourceLoader.exists(path):
		var data := load(path) as LevelData
		if data != null and not data.level_name.is_empty():
			text = "%d. %s" % [index, data.level_name]
	if index > SaveManager.get_unlocked_level():
		text += "   (TERKUNCI)"
	return text

func _on_level_pressed(index: int) -> void:
	if _busy:
		return
	_busy = true
	GameManager.start_run()
	await SceneRouter.goto_level(index)

func _on_back() -> void:
	if _busy:
		return
	_busy = true
	await SceneRouter.goto_main_menu()
