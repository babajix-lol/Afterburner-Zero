extends Area2D
class_name Boss

const GROUP: StringName = &"enemies"
const HIT_FLASH_TIME := 0.06
const SPIRAL_STEP := 0.12
const SPIRAL_SPIN := 24.0
const ADD_INTERVAL := 3.0

@export_enum("heli", "bomber", "twin", "dreadnought") var boss_kind: String = "heli"
@export var display_name: String = "GUNSHIP HELI"
@export var max_health_override: int = 0
@export var score_value: int = 2000
@export var bullet_scene: PackedScene
@export var add_scene: PackedScene
@export var add_scene_alt: PackedScene

@export var muzzle_offsets: Array[Vector2] = [Vector2.ZERO]

@export var fire_speed := 135.0
@export var bullet_damage := 1
@export var hover_amplitude := 90.0
@export var hover_frequency := 0.35
@export var hover_depth := 20.0

@export var death_sfx: AudioStream
@export var hit_sfx: AudioStream

@onready var _sprite: Sprite2D = $Sprite

var _max_health := 1
var _health := 1
var _dead := false
var _phase := 0
var _phase_count := 1
var _age := 0.0
var _origin_x := 0.0
var _home_y := 0.0
var _entered := false
var _spawn_initialized := false
var _fire_timer := 0.0
var _add_timer := 0.0
var _spiral_timer := 0.0
var _spiral_angle := 0.0
var _sweep_flip := false
var _base_modulate := Color.WHITE
var _phases: Array[Dictionary] = []

var _pending_directions: Array[Vector2] = []
var _pending_offsets: Array[Vector2] = []
var _pending_gap := 0.0
var _shot_timer := 0.0

func _ready() -> void:
	add_to_group(GROUP)
	_base_modulate = _sprite.modulate
	_configure_kind()
	if max_health_override > 0:
		_max_health = max_health_override
	_health = _max_health
	_fire_timer = 1.2
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	EventBus.boss_health_changed.emit(_health, _max_health)
	EventBus.boss_phase_changed.emit(_phase, _phase_count)

func setup_arena(center: Vector2) -> void:
	_origin_x = center.x
	_home_y = center.y - 95.0
	global_position = Vector2(_origin_x, center.y - 230.0)
	_entered = false
	_spawn_initialized = true
	EventBus.boss_health_changed.emit(_health, _max_health)
	EventBus.boss_phase_changed.emit(_phase, _phase_count)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player") and body.has_method(&"take_damage"):
		body.take_damage(1)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group(&"player") and area.has_method(&"take_damage"):
		area.take_damage(1)
	elif area.name == "Hurtbox":
		var player := area.get_parent()
		if player != null and player.is_in_group(&"player") and player.has_method(&"take_damage"):
			player.take_damage(1)

func is_alive() -> bool:
	return not _dead and is_inside_tree() and not is_queued_for_deletion()

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not _spawn_initialized:
		_init_spawn_position()
	_age += delta
	_update_phase()
	_move(delta)
	_update_fire(delta)
	_update_adds(delta)

func _init_spawn_position() -> void:
	_spawn_initialized = true
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		var cam := camera.get_screen_center_position()
		_origin_x = cam.x
		_home_y = cam.y - 95.0
		if global_position.is_zero_approx() or global_position.y < cam.y - 300.0 or global_position.y > cam.y + 300.0:
			global_position = Vector2(_origin_x, cam.y - 230.0)
	else:
		_origin_x = global_position.x
		_home_y = global_position.y + hover_depth

func _configure_kind() -> void:
	match boss_kind:
		"bomber":
			_max_health = 48
			_phases = [
				{"threshold": 1.0, "interval": 2.4, "pattern": &"carpet"},
				{"threshold": 0.5, "interval": 2.0, "pattern": &"carpet_sweep"},
			]
		"twin":
			_max_health = 44
			_phases = [
				{"threshold": 1.0, "interval": 1.6, "pattern": &"fan"},
				{"threshold": 0.5, "interval": 1.2, "pattern": &"fan_aimed"},
			]
		"dreadnought":
			_max_health = 90
			_phases = [
				{"threshold": 1.0, "interval": 1.8, "pattern": &"fan", "adds": true},
				{"threshold": 0.66, "interval": 1.6, "pattern": &"carpet_sweep"},
				{"threshold": 0.33, "interval": 1.4, "pattern": &"spiral", "adds": true},
			]
		_:
			_max_health = 24
			_phases = [
				{"threshold": 1.0, "interval": 1.8, "pattern": &"fan"},
			]
	_phase_count = _phases.size()

func _update_phase() -> void:
	var fraction := float(_health) / float(maxi(_max_health, 1))
	var target := 0
	for i in _phases.size():
		if fraction <= float(_phases[i].get("threshold", 1.0)):
			target = i
	if target == _phase:
		return
	_phase = target
	EventBus.boss_phase_changed.emit(_phase, _phase_count)

func _move(delta: float) -> void:
	if not _entered:
		var remaining := maxf(_home_y - global_position.y, 0.0)
		global_position.y += minf(60.0 * delta, remaining)
		if remaining <= 1.0:
			_entered = true
			global_position.y = _home_y
	else:
		global_position.y = _home_y
	global_position.x = _origin_x + sin(_age * TAU * hover_frequency) * hover_amplitude

func _update_fire(delta: float) -> void:
	if not _entered or _phases.is_empty():
		return
	var pattern := StringName(_phases[_phase].get("pattern", &"fan"))
	if pattern == &"spiral":
		_spiral_timer -= delta
		if _spiral_timer <= 0.0:
			_spiral_timer = SPIRAL_STEP
			_spiral_angle += deg_to_rad(SPIRAL_SPIN)
			for muzzle in muzzle_offsets:
				_fire_direction(Vector2.DOWN.rotated(_spiral_angle), muzzle)
		return
	_drain_shot_queue(delta)
	_fire_timer -= delta
	if _fire_timer > 0.0:
		return
	_fire_timer = float(_phases[_phase].get("interval", 1.8))
	_load_pattern(pattern)

func _load_pattern(pattern: StringName) -> void:
	match pattern:
		&"carpet":
			_queue_all(_fan(5, 110.0), [], 0.0)
		&"carpet_sweep":
			_sweep_flip = not _sweep_flip
			if _sweep_flip:
				_queue_all(_fan(5, 110.0), [], 0.0)
			else:
				_queue_all(_down_line(5), _line_offsets(5, 22.0), 0.0)
		&"fan_aimed":
			var directions := _fan(5, 60.0)
			directions.append(_aim_at_player())
			_queue_all(directions, [], 0.0)
		&"spiral":
			pass
		_:
			_queue_all(_fan(5, 60.0), [], 0.0)

func _update_adds(delta: float) -> void:
	if not _entered or _phases.is_empty():
		return
	if not bool(_phases[_phase].get("adds", false)):
		_add_timer = 0.0
		return
	var scene := add_scene_alt if (_phase >= 2 and add_scene_alt != null) else add_scene
	if scene == null:
		return
	var active_adds := get_tree().get_nodes_in_group(&"enemies").size() - 1
	if active_adds >= 3:
		return
	_add_timer -= delta
	if _add_timer > 0.0:
		return
	_add_timer = ADD_INTERVAL
	var container := _entity_container()
	if container == null:
		return
	var minion := scene.instantiate()
	container.add_child(minion)
	if minion is Node2D:
		minion.global_position = global_position + Vector2(randf_range(-120.0, 120.0), -60.0)

func take_damage(amount: int = 1) -> void:
	if _dead:
		return
	_health = maxi(_health - maxi(amount, 0), 0)
	EventBus.boss_health_changed.emit(_health, _max_health)
	if _health <= 0:
		_die()
		return
	if hit_sfx != null:
		AudioManager.play_sfx(hit_sfx)
	else:
		AudioManager.play_sfx_path("res://assets/audio/sfx/sfx_hit.wav")
	_flash()

func _flash() -> void:
	_sprite.modulate = Color(2.5, 2.5, 2.5)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", _base_modulate, HIT_FLASH_TIME)

func _die() -> void:
	if _dead:
		return
	_dead = true
	set_physics_process(false)
	var hitbox := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if hitbox != null:
		hitbox.set_deferred("disabled", true)
	EventBus.boss_health_changed.emit(0, _max_health)
	GameManager.add_score(score_value)
	if death_sfx != null:
		AudioManager.play_sfx(death_sfx)
	else:
		AudioManager.play_sfx_path("res://assets/audio/sfx/sfx_die_large.wav")
	for bullet in get_tree().get_nodes_in_group(&"enemy_bullets"):
		bullet.queue_free()
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if enemy != self and enemy.has_method(&"take_damage"):
			enemy.take_damage(99)
	var parent_node := get_parent()
	if parent_node != null:
		var exp_node = preload("res://effects/explosion.gd").new()
		exp_node.scale = Vector2(1.0, 1.0)
		parent_node.add_child(exp_node)
		exp_node.global_position = global_position
	var tween := create_tween()
	tween.tween_property(self, "scale", scale * 1.4, 0.5)
	tween.parallel().tween_property(_sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
	EventBus.level_completed.emit(GameManager.current_level)

func get_health() -> int:
	return _health

func get_max_health() -> int:
	return _max_health

func get_phase() -> int:
	return _phase

func get_phase_count() -> int:
	return _phase_count

func _queue_all(directions: Array[Vector2], extra_offsets: Array[Vector2], gap: float) -> void:
	var out_directions: Array[Vector2] = []
	var out_offsets: Array[Vector2] = []
	for muzzle in muzzle_offsets:
		for i in directions.size():
			out_directions.append(directions[i])
			var extra := extra_offsets[i] if i < extra_offsets.size() else Vector2.ZERO
			out_offsets.append(muzzle + extra)
	_pending_directions = out_directions
	_pending_offsets = out_offsets
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
			_fire_queued_shot()
		return
	_fire_queued_shot()
	_shot_timer = _pending_gap

func _fire_queued_shot() -> void:
	var direction: Vector2 = _pending_directions.pop_front()
	var offset := Vector2.ZERO
	if not _pending_offsets.is_empty():
		offset = _pending_offsets.pop_front()
	_fire_direction(direction, offset)

func _fire_direction(direction: Vector2, offset: Vector2) -> void:
	if bullet_scene == null:
		return
	var bullet := bullet_scene.instantiate()
	if bullet is EnemyBullet:
		bullet.configure(fire_speed, bullet_damage, direction, Color(1.0, 0.35, 0.3), 1.2)
	var container := _entity_container()
	if container == null:
		bullet.queue_free()
		return
	container.add_child(bullet)
	if bullet is Node2D:
		bullet.global_position = global_position + offset

func _fan(count: int, spread_degrees: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var spread := deg_to_rad(spread_degrees)
	var step := spread / float(maxi(count - 1, 1))
	for i in count:
		out.append(Vector2.DOWN.rotated(-spread * 0.5 + step * float(i)))
	return out

func _down_line(count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in count:
		out.append(Vector2.DOWN)
	return out

func _line_offsets(count: int, spacing: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var half := float(count - 1) * 0.5
	for i in count:
		out.append(Vector2((float(i) - half) * spacing, 0.0))
	return out

func _aim_at_player() -> Vector2:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return Vector2.DOWN
	var to_player := player.global_position - global_position
	if to_player.is_zero_approx():
		return Vector2.DOWN
	return to_player.normalized()

func _entity_container() -> Node:
	var container := get_tree().get_first_node_in_group(&"entities")
	return container if container != null else get_tree().current_scene
