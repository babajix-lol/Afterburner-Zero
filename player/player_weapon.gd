extends Node2D
class_name PlayerWeapon

@export var default_bullet_scene: PackedScene
@export var default_fire_rate := 8.0
@export var default_damage := 1
@export var bullet_speed := 460.0
@export var homing_turn_rate := 4.0
@export var shot_sfx: AudioStream

var _trigger_held := false
var _cooldown := 0.0

func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _trigger_held:
		_try_fire()

func set_trigger(held: bool) -> void:
	_trigger_held = held
	if held:
		_try_fire()

func fire_rate() -> float:
	var data := GameManager.weapon
	return data.fire_rate if data != null else default_fire_rate

func _try_fire() -> void:
	if _cooldown > 0.0:
		return
	_fire()
	_cooldown = 1.0 / maxf(fire_rate(), 0.01)

func _fire() -> void:
	var data := GameManager.weapon
	var bullet_scene := default_bullet_scene
	var count := 1
	var spread := 0.0
	var damage := default_damage
	var homing := false
	var shot_path := "res://assets/audio/sfx/sfx_shoot_cannon.wav"
	if data != null:
		if data.bullet_scene != null:
			bullet_scene = data.bullet_scene
		count = maxi(data.projectile_count, 1)
		spread = data.spread_angle
		damage = data.damage
		homing = data.is_homing
		match data.display_name:
			"Laser":
				shot_path = "res://assets/audio/sfx/sfx_shoot_laser.wav"
			"Spread":
				shot_path = "res://assets/audio/sfx/sfx_shoot_spread.wav"
			"Homing", "Missile":
				shot_path = "res://assets/audio/sfx/sfx_shoot_missile.wav"
	if bullet_scene == null:
		return
	for angle in _spread_angles(count, spread):
		_spawn(bullet_scene, angle, damage, homing)
	if shot_sfx != null:
		AudioManager.play_sfx(shot_sfx)
	else:
		AudioManager.play_sfx_path(shot_path)

func _spread_angles(count: int, spread_degrees: float) -> Array[float]:
	var angles: Array[float] = []
	if count <= 1 or is_zero_approx(spread_degrees):
		for i in count:
			angles.append(0.0)
		return angles
	var spread := deg_to_rad(spread_degrees)
	var step := spread / float(count - 1)
	for i in count:
		angles.append(-spread * 0.5 + step * float(i))
	return angles

func _spawn(bullet_scene: PackedScene, angle: float, damage: int, homing: bool) -> void:
	var container := _projectile_container()
	if container == null:
		return
	var bullet := bullet_scene.instantiate()
	if bullet is PlayerBullet:
		var spd: float = bullet.speed if not is_equal_approx(bullet.speed, 460.0) else bullet_speed
		var turn: float = homing_turn_rate if homing else (bullet.homing_turn_rate if bullet.homing_turn_rate > 0.0 else 0.0)
		bullet.configure(spd, damage, Vector2.UP.rotated(angle), turn, bullet.is_piercing)
	container.add_child(bullet)
	if bullet is Node2D:
		bullet.global_position = global_position

func _projectile_container() -> Node:
	var container := get_tree().get_first_node_in_group(&"entities")
	return container if container != null else get_tree().current_scene
