extends Node2D
## One-off Tahap 1 smoke test, run as a real main scene so autoload _ready()
## has fired the way it will during actual gameplay.

func _ready() -> void:
	print("=== T1 smoke test ===")
	print("SaveManager.data = ", SaveManager.data)
	print("unlocked = ", SaveManager.get_unlocked_level(), " best = ", SaveManager.get_best_score())

	SaveManager.set_setting("master_volume", 0.5)
	print("master_volume after set = ", SaveManager.get_setting("master_volume"))
	SaveManager.set_setting("master_volume", 1.0)

	if FileAccess.file_exists(SaveManager.SAVE_PATH):
		var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.READ)
		print("save file content = ", f.get_as_text())
		f.close()

	print("GameManager lives = ", GameManager.lives, " bombs = ", GameManager.bombs, " score = ", GameManager.score)
	GameManager.start_run()
	print("after start_run: lives = ", GameManager.lives, " score = ", GameManager.score)

	AudioManager.play_sfx(null)
	AudioManager.play_music(null)
	print("AudioManager calls with null streams survived OK")

	var total := 0
	for a in ["move_up", "move_down", "move_left", "move_right", "fire", "barrel_roll"]:
		if InputMap.has_action(a):
			total += InputMap.action_get_events(a).size()
		else:
			push_error("missing action: " + a)
	print("input actions total events = ", total)

	print("=== T1 smoke test done ===")
	get_tree().quit()
