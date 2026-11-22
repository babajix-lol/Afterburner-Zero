extends Node
## The single door for scene changes (design spec §5.3, §5.6).
##
## Fade, cleanup and level-data loading live here so no level or menu has to
## know how transitions look or what a level needs before it starts.

const LEVEL_DATA_DIR := "res://data/levels/"
const LEVEL_SCENE_DIR := "res://levels/"
const MAIN_MENU_SCENE := "res://ui/main_menu.tscn"
const FADE_SECONDS := 0.3

var _fade: ColorRect
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.name = "TransitionLayer"
	layer.layer = 128
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func level_data_path(index: int) -> String:
	return "%slevel_%02d.tres" % [LEVEL_DATA_DIR, index]


func level_scene_path(index: int) -> String:
	return "%slevel_%02d.tscn" % [LEVEL_SCENE_DIR, index]


## Loads data/levels/level_0N.tres, hands it to GameManager, then swaps in
## levels/level_0N.tscn.
func goto_level(index: int) -> void:
	if _busy:
		return
	var data_path := level_data_path(index)
	var scene_path := level_scene_path(index)
	if not ResourceLoader.exists(data_path) or not ResourceLoader.exists(scene_path):
		push_warning("SceneRouter: level %d is not built yet (%s / %s)." % [index, data_path, scene_path])
		return
	var data := load(data_path) as LevelData
	GameManager.begin_level(index, data)
	await _change_scene(scene_path)


func goto_scene(path: String) -> void:
	if _busy:
		return
	if not ResourceLoader.exists(path):
		push_warning("SceneRouter: scene '%s' does not exist yet." % path)
		return
	await _change_scene(path)


func goto_main_menu() -> void:
	await goto_scene(MAIN_MENU_SCENE)


func reload_current_level() -> void:
	if GameManager.current_level > 0:
		await goto_level(GameManager.current_level)


func fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade, "color:a", alpha, FADE_SECONDS)
	await tween.finished


func _change_scene(path: String) -> void:
	_busy = true
	await fade_to(1.0)
	# A level left the tree paused behind it? Start the new scene clean.
	get_tree().paused = false
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneRouter: change_scene_to_file('%s') failed (%s)." % [path, error_string(err)])
		_fade.color.a = 0.0
		_busy = false
		return
	await get_tree().process_frame
	await fade_to(0.0)
	_busy = false
