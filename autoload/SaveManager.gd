extends Node
## Persistent progress and settings (design spec §5.4).
##
## Stores only what §2 keeps between sessions: the highest unlocked level, the
## best score and the settings dictionary. Nothing about the run in progress
## lives here.

const SAVE_PATH := "user://afterburner_zero_save.json"

const DEFAULT_SETTINGS := {
	"bgm_volume": 1.0,
	"sfx_volume": 1.0,
}

## Known top-level keys — anything else in the file is ignored, so an old or
## hand-edited save cannot inject surprise keys.
const LEVEL_KEY := "unlocked_level"
const SCORE_KEY := "best_score"
const SETTINGS_KEY := "settings"

var data: Dictionary = {}


func _ready() -> void:
	load_data()


func load_data() -> void:
	data = {
		LEVEL_KEY: 1,
		SCORE_KEY: 0,
		SETTINGS_KEY: DEFAULT_SETTINGS.duplicate(true),
	}
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: cannot open %s for reading." % SAVE_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager: %s is corrupt; starting fresh." % SAVE_PATH)
		return
	var loaded: Dictionary = parsed
	data[LEVEL_KEY] = int(loaded.get(LEVEL_KEY, 1))
	data[SCORE_KEY] = int(loaded.get(SCORE_KEY, 0))
	var settings: Dictionary = data[SETTINGS_KEY]
	var saved_settings: Variant = loaded.get(SETTINGS_KEY, {})
	if typeof(saved_settings) == TYPE_DICTIONARY:
		for key in settings.keys():
			settings[key] = saved_settings.get(key, settings[key])


func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot open %s for writing." % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


## Records how far the player reached. Only ever moves forward.
func unlock_level(index: int) -> void:
	if index <= int(data[LEVEL_KEY]):
		return
	data[LEVEL_KEY] = index
	save_data()


## Keeps the best score seen so far.
func submit_score(value: int) -> void:
	if value <= int(data[SCORE_KEY]):
		return
	data[SCORE_KEY] = value
	save_data()


func get_unlocked_level() -> int:
	return int(data[LEVEL_KEY])


func get_best_score() -> int:
	return int(data[SCORE_KEY])


func get_setting(key: String, fallback: Variant = null) -> Variant:
	var settings: Dictionary = data.get(SETTINGS_KEY, {})
	return settings.get(key, fallback)


func set_setting(key: String, value: Variant) -> void:
	var settings: Dictionary = data.get(SETTINGS_KEY, {})
	settings[key] = value
	data[SETTINGS_KEY] = settings
	save_data()
