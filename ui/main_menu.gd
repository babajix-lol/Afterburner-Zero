extends Control
## Main menu (design spec §5.1, §5.3).
##
## Play starts a fresh run at Level 1; Level Select jumps to any unlocked level;
## Settings exposes the two persisted volume sliders (§3.5 settings). Everything
## routes through SceneRouter so transitions stay in one place.

@onready var _play_button: Button = $Center/Panel/Margin/VBox/PlayButton
@onready var _level_select_button: Button = $Center/Panel/Margin/VBox/LevelSelectButton
@onready var _settings_button: Button = $Center/Panel/Margin/VBox/SettingsButton
@onready var _quit_button: Button = $Center/Panel/Margin/VBox/QuitButton
@onready var _best_label: Label = $Center/Panel/Margin/VBox/BestLabel

@onready var _settings_panel: PanelContainer = $SettingsPanel
@onready var _bgm_slider: HSlider = $SettingsPanel/Margin/VBox/BgmRow/BgmSlider
@onready var _sfx_slider: HSlider = $SettingsPanel/Margin/VBox/SfxRow/SfxSlider
@onready var _close_settings_button: Button = $SettingsPanel/Margin/VBox/CloseButton

var _busy := false


func _ready() -> void:
	_play_button.pressed.connect(_on_play)
	_level_select_button.pressed.connect(_on_level_select)
	_settings_button.pressed.connect(_open_settings)
	_quit_button.pressed.connect(_on_quit)
	_close_settings_button.pressed.connect(_close_settings)

	_settings_panel.visible = false
	# Set the slider values *before* connecting, so restoring the saved volumes
	# does not immediately write them back through the change handler.
	_bgm_slider.value = float(SaveManager.get_setting("bgm_volume", 1.0))
	_sfx_slider.value = float(SaveManager.get_setting("sfx_volume", 1.0))
	_bgm_slider.value_changed.connect(_on_bgm_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)

	_best_label.text = "BEST SCORE: %d" % SaveManager.get_best_score()
	_play_button.grab_focus()


func _on_play() -> void:
	if _busy:
		return
	_busy = true
	GameManager.start_run()
	await SceneRouter.goto_level(1)


func _on_level_select() -> void:
	if _busy:
		return
	_busy = true
	await SceneRouter.goto_scene("res://ui/level_select.tscn")


func _open_settings() -> void:
	_settings_panel.visible = true
	_bgm_slider.grab_focus()


func _close_settings() -> void:
	_settings_panel.visible = false
	_play_button.grab_focus()


func _on_bgm_changed(value: float) -> void:
	AudioManager.set_bgm_volume(value)


func _on_sfx_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value)


func _on_quit() -> void:
	get_tree().quit()
