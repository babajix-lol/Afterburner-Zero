extends Node2D
## One-off Tahap 1 check for the player scene. Runs as a real main scene so the
## autoloads and the input map behave exactly as they do in gameplay.

const PLAYER_SCENE := preload("res://player/player.tscn")

var _shield_events: Array[float] = []


func _ready() -> void:
	print("=== T1 player smoke test ===")
	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var weapon := player.get_node("Weapon") as PlayerWeapon
	print("spawn position = ", player.position, " alive = ", player.is_alive())
	print("weapon fire rate = ", weapon.fire_rate(), " muzzle = ", weapon.position)

	EventBus.shield_changed.connect(func(value: float) -> void: _shield_events.append(value))

	# 8-way movement
	var start_x := player.position.x
	Input.action_press(&"move_right")
	for i in 12:
		await get_tree().physics_frame
	Input.action_release(&"move_right")
	print("moved right by = ", player.position.x - start_x)

	# basic fire
	Input.action_press(&"fire")
	for i in 6:
		await get_tree().physics_frame
	Input.action_release(&"fire")
	print("bullets alive after firing = ", _bullet_count())

	# Barrel Roll through the real input path
	var roll_event := InputEventAction.new()
	roll_event.action = &"barrel_roll"
	roll_event.pressed = true
	Input.parse_input_event(roll_event)
	await get_tree().physics_frame
	print("rolling = ", player.is_rolling(), " invulnerable = ", player.is_invulnerable())

	# outlast the roll i-frames and the roll cooldown
	for i in 70:
		await get_tree().physics_frame
	print("after roll: rolling = ", player.is_rolling(), " invulnerable = ", player.is_invulnerable())

	# hearts
	var lives_before := GameManager.lives
	var survived := player.take_damage()
	print("hit: lives ", lives_before, " -> ", GameManager.lives, " survived = ", survived)
	print("second hit inside grace survived = ", player.take_damage(), " lives = ", GameManager.lives)

	# shield
	player.grant_shield(2.0)
	print("shield: invulnerable = ", player.is_invulnerable(), " events = ", _shield_events)

	# a bullet recycles itself once it leaves the screen
	print("bullets before recycle wait = ", _bullet_count())
	for i in 40:
		await get_tree().physics_frame
	print("bullets after recycle wait = ", _bullet_count())

	# death
	while GameManager.lives > 0:
		GameManager.lose_life()
	await get_tree().physics_frame
	print("after draining hearts: alive = ", player.is_alive(), " lives = ", GameManager.lives)

	print("=== T1 player smoke test done ===")
	get_tree().quit()


func _bullet_count() -> int:
	var total := 0
	for child in get_children():
		if child is PlayerBullet:
			total += 1
	return total
