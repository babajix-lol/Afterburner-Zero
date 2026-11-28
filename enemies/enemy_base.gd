extends Area2D
class_name Enemy

const GROUP: StringName = &"enemies"
const DESPAWN_MARGIN := 48.0
const BURST_GAP := 0.12
const HIT_FLASH_TIME := 0.07

@export var data: EnemyData
@export var fallback_bullet_scene: PackedScene
@export var movement_speed := 42.0
@export var fire_speed := 130.0
@export var bullet_damage := 1
@export var bullet_tint := Color(1.0, 0.6, 0.45)
@export var bullet_scale := 1.0
@export var sine_amplitude := 40.0
@export var sine_frequency := 2.0
@export var hover_distance := 90.0
@export var dive_delay := 0.6
@export var death_sfx: AudioStream
@export var hit_sfx: AudioStream

@onready var _sprite: Sprite2D = $Sprite

var _base_modulate := Color.WHITE
var _health := 1
var _dead := false
var _age := 0.0
var _traveled := 0.0
var _origin := Vector2.ZERO
var _origin_set := false
var _has_entered_view := false
var _fire_timer := 0.0
var _fire_interval := 1.5
var _hit_flash := 0.0
var _speed_mult := 1.0
var _fire_rate_mult := 1.0
var _hp_bonus := 0

var _pending_directions: Array[Vector2] = []
var _pending_offsets: Array[Vector2] = []
var _pending_gap := 0.0
var _shot_timer := 0.0

func _ready() -> void:
	add_to_group(GROUP)
	_base_modulate = _sprite.modulate
	_read_difficulty()
	_apply_data()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		if body.has_method(&"take_damage"):
			body.take_damage(1)
		take_damage(1)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group(&"player"):
		if area.has_method(&"take_damage"):
			area.take_damage(1)
		take_damage(1)
	elif area.name == "Hurtbox":
		var player := area.get_parent()
		if player != null and player.is_in_group(&"player") and player.has_method(&"take_damage"):
			player.take_damage(1)
		take_damage(1)

func is_alive() -> bool:
	return not _dead and is_inside_tree() and not is_queued_for_deletion()

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not _origin_set:
		_origin = global_position
		_origin_set = true
	_age += delta
	_update_hit_flash(delta)
	if not _update_view_state():
		return
	_move(delta)
	_update_fire(delta)

func _get_camera_bottom() -> float:
	var view_size := get_viewport_rect().size
	var center := view_size * 0.5
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		if not is_zero_approx(camera.zoom.y):
			view_size.y /= camera.zoom.y
		center = camera.get_screen_center_position()
	return center.y + view_size.y * 0.5

func _update_view_state() -> bool:
	var camera_bottom := _get_camera_bottom()
	if global_position.y > camera_bottom + 120.0:
		queue_free()
		return false
	if not _has_entered_view:
		if _is_inside_view(0.0):
			_has_entered_view = true
		return true
	if not _is_inside_view(DESPAWN_MARGIN):
		queue_free()
		return false
	return true

func _is_inside_view(margin: float) -> bool:
	var view_size := get_viewport_rect().size
	var center := view_size * 0.5
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		if not is_zero_approx(camera.zoom.x) and not is_zero_approx(camera.zoom.y):
			view_size /= camera.zoom
		center = camera.get_screen_center_position()
	var limit := view_size * 0.5 + Vector2(margin, margin)
	var offset := (global_position - center).abs()
	return offset.x <= limit.x and offset.y <= limit.y

func _move(delta: float) -> void:
	var behavior: StringName = data.move_pattern if (data != null and not data.move_pattern.is_empty()) else &"straight"
	var effective_speed := movement_speed * _speed_mult
	match behavior:
		&"sine":
			_traveled += effective_speed * delta
			global_position.y = _origin.y + _traveled
			global_position.x = _origin.x + sin(_age * sine_frequency) * sine_amplitude
		&"hover":
			if _traveled < hover_distance:
				var step := minf(effective_speed * delta, hover_distance - _traveled)
				global_position.y += step
				_traveled += step
			else:
				global_position.x = _origin.x + sin(_age * 1.5) * 20.0
		&"dive":
			if _age < dive_delay:
				global_position.y += effective_speed * 0.3 * delta
			else:
				var player := get_tree().get_first_node_in_group(&"player") as Node2D
				var heading := Vector2.DOWN
				if player != null:
					heading = (player.global_position - global_position).normalized()
				global_position += heading * effective_speed * 1.5 * delta
		&"turret", &"static":
			pass
		_:
			global_position.y += effective_speed * delta

func _update_fire(delta: float) -> void:
	if not _has_entered_view or _fire_interval <= 0.0:
		return
	_drain_shot_queue(delta)
	_fire_timer -= delta
	if _fire_timer > 0.0:
		return
	_fire_timer = _fire_interval
	_fire_attack()

func _fire_attack() -> void:
	var bullet_scene := data.bullet_scene if data != null and data.bullet_scene != null else fallback_bullet_scene
	if bullet_scene == null:
		return
	var pattern: StringName = data.fire_pattern if (data != null and not data.fire_pattern.is_empty()) else &"straight"
	match pattern:
		&"burst", &"burst3":
			_queue_shots([Vector2.DOWN, Vector2.DOWN, Vector2.DOWN], BURST_GAP)
		&"aimed":
			_queue_shots([_aim_at_player()], 0.0)
		&"spread", &"spread_fan", &"triple":
			_queue_shots(_fan(3, 40.0), 0.0)
		&"carpet":
			_queue_shots(_fan(5, 50.0), 0.0)
		&"radial":
			_queue_shots(_radial(6), 0.0)
		&"none":
			pass
		_:
			_queue_shots([Vector2.DOWN], 0.0)

func _queue_shots(directions: Array[Vector2], gap: float) -> void:
	_pending_directions = directions
	_pending_gap = gap
	_shot_timer = 0.0

func _drain_shot_queue(delta: float) -> void:
	if _pending_directions.is_empty():
		return
	_shot_timer -= delta
	if _shot_timer > 0.0:
		return
	if _pending_gap <= 0.0:
		while not _pending_directions.is_empty():
			_fire_one_bullet(_pending_directions.pop_front())
		return
	_fire_one_bullet(_pending_directions.pop_front())
	_shot_timer = _pending_gap

func _fire_one_bullet(direction: Vector2) -> void:
	var bullet_scene := data.bullet_scene if data != null and data.bullet_scene != null else fallback_bullet_scene
	if bullet_scene == null:
		return
	var bullet := bullet_scene.instantiate()
	if bullet is EnemyBullet:
		bullet.configure(fire_speed, bullet_damage, direction, bullet_tint, bullet_scale)
	var container := _entity_container()
	if container == null:
		bullet.queue_free()
		return
	container.add_child(bullet)
	if bullet is Node2D:
		bullet.global_position = global_position

func _aim_at_player() -> Vector2:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return Vector2.DOWN
	var to_player := player.global_position - global_position
	if to_player.is_zero_approx():
		return Vector2.DOWN
	return to_player.normalized()

func _fan(count: int, spread_degrees: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var spread := deg_to_rad(spread_degrees)
	var step := spread / float(maxi(count - 1, 1))
	for i in count:
		out.append(Vector2.DOWN.rotated(-spread * 0.5 + step * float(i)))
	return out

func _radial(count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var step := TAU / float(maxi(count, 1))
	for i in count:
		out.append(Vector2.DOWN.rotated(step * float(i)))
	return out

func _entity_container() -> Node:
	var container := get_tree().get_first_node_in_group(&"entities")
	return container if container != null else get_tree().current_scene

func take_damage(amount: int = 1) -> void:
	if _dead:
		return
	_health -= maxi(amount, 0)
	if _health <= 0:
		_die()
		return
	_hit_flash = HIT_FLASH_TIME
	if hit_sfx != null:
		AudioManager.play_sfx(hit_sfx)
	else:
		AudioManager.play_sfx_path("res://assets/audio/sfx/sfx_hit.wav")

func _die() -> void:
	if _dead:
		return
	_dead = true
	set_physics_process(false)
	var hitbox := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if hitbox != null:
		hitbox.set_deferred("disabled", true)
	if data != null:
		var tracker := get_tree().get_first_node_in_group(&"combo_tracker") as ComboTracker
		if tracker != null:
			tracker.register_kill(data.score_value)
		else:
			GameManager.add_score(data.score_value)
	_spawn_drop()
	if death_sfx != null:
		AudioManager.play_sfx(death_sfx)
	else:
		AudioManager.play_sfx_path("res://assets/audio/sfx/sfx_die_small.wav")
	var parent_node := get_parent()
	if parent_node != null:
		var exp_node = preload("res://effects/explosion.gd").new()
		exp_node.scale = Vector2(0.45, 0.45)
		parent_node.add_child(exp_node)
		exp_node.global_position = global_position
	var tween := create_tween()
	tween.tween_property(self, "scale", scale * 1.5, 0.18)
	tween.parallel().tween_property(_sprite, "modulate:a", 0.0, 0.18)
	tween.tween_callback(queue_free)

func _update_hit_flash(delta: float) -> void:
	if _hit_flash <= 0.0:
		return
	_hit_flash = maxf(_hit_flash - delta, 0.0)
	_sprite.modulate = Color(3.0, 3.0, 3.0) if _hit_flash > 0.0 else _base_modulate

func _read_difficulty() -> void:
	var level := GameManager.level_data
	if level == null:
		return
	var difficulty := level.difficulty
	_speed_mult = float(difficulty.get("enemy_speed_mult", 1.0))
	_hp_bonus = int(difficulty.get("enemy_hp_bonus", 0))
	_fire_rate_mult = float(difficulty.get("fire_rate_mult", 1.0))

func _apply_data() -> void:
	_health = 1
	_fire_interval = 1.5
	if data == null:
		return
	_health = maxi(data.max_health, 1) + _hp_bonus
	_fire_interval = maxf(data.fire_interval, 0.05) / maxf(_fire_rate_mult, 0.01)
	if data.is_elite:
		scale = Vector2.ONE * data.elite_scale
		_base_modulate = data.elite_modulate
		_sprite.modulate = _base_modulate
		_health += 2
	_fire_timer = _fire_interval * randf_range(0.35, 1.0)

func _spawn_drop() -> void:
	if data == null or data.drop_table.is_empty():
		return
	var scene := _pick_drop()
	if scene == null:
		return
	var container := _entity_container()
	if container == null:
		return
	var pickup := scene.instantiate()
	container.add_child(pickup)
	if pickup is Node2D:
		pickup.global_position = global_position

func _pick_drop() -> PackedScene:
	var roll := randf()
	var accumulated := 0.0
	for entry in data.drop_table:
		accumulated += float(entry.get("weight", 1.0))
		if roll <= accumulated:
			return entry.get("scene") as PackedScene
	return null
