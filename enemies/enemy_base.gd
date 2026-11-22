extends Area2D
class_name Enemy
## Base enemy for every ground and air unit (design spec §4.4, §4.5, §6.4).
##
## Army, Humvee, Heli, Bomber and Turret all run this one script: what makes them
## different lives in their EnemyData (move pattern, fire pattern, health, drops)
## and in their scene (sprite, hitbox, scale). Elite and boss variants only
## recolour and rescale the same sprite (§3.3, §7 — no new art).
##
## Collision is one-directional on purpose: the player's Hurtbox has mask 4|8, so
## it sees this Area and takes contact damage, while the player's bullets have
## mask 4 and call take_damage() here. Nothing can be damaged twice.

const GROUP: StringName = &"enemies"

## How far past the screen edge an enemy keeps going before it is recycled.
const DESPAWN_MARGIN := 48.0
## Gap between the pellets of a burst-3 volley.
const BURST_GAP := 0.12
const HIT_FLASH_TIME := 0.07

@export var data: EnemyData
## Used when `data` carries no bullet_scene, so a scene can fire on its own.
@export var fallback_bullet_scene: PackedScene

## Px/s the move pattern descends at, before the level's difficulty multiplier.
@export var movement_speed := 70.0
## Px/s the enemy's own bullets travel.
@export var fire_speed := 170.0
@export var bullet_damage := 1
## §4.4: fire patterns are told apart by bullet colour.
@export var bullet_tint := Color(1.0, 0.6, 0.45)
@export var bullet_scale := 1.0

## &"sine" horizontal swing, in px and Hz.
@export var sine_amplitude := 40.0
@export var sine_frequency := 2.0
## &"hover" depth — how far the enemy descends before holding position.
@export var hover_distance := 90.0
## &"dive" pause before the enemy accelerates downward.
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

## A volley in flight: directions and (optional) spawn offsets, drained one per
## _pending_gap seconds so burst-3 and single shots share one code path.
var _pending_directions: Array[Vector2] = []
var _pending_offsets: Array[Vector2] = []
var _pending_gap := 0.0
var _shot_timer := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	_base_modulate = _sprite.modulate
	_read_difficulty()
	_apply_data()


func is_alive() -> bool:
	return not _dead


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


## Enemies spawn from markers that may sit just outside the camera, so a unit is
## only recycled once it has actually been on screen and then left again.
## Returns false when the enemy was just freed.
func _update_view_state() -> bool:
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
		view_size /= camera.zoom
		center = camera.get_screen_center_position()
	var limit := view_size * 0.5 + Vector2(margin, margin)
	var offset := (global_position - center).abs()
	return offset.x <= limit.x and offset.y <= limit.y


func _move(delta: float) -> void:
	var pattern := data.move_pattern if data != null else &"straight"
	var speed := movement_speed * _speed_mult
	match pattern:
		&"static":
			pass
		&"sine":
			global_position.y += speed * delta
			global_position.x = _origin.x + sin(_age * sine_frequency) * sine_amplitude
		&"hover":
			if _traveled < hover_distance:
				var step := minf(speed * delta, hover_distance - _traveled)
				global_position.y += step
				_traveled += step
		&"dive":
			var dive_speed := speed
			if _age > dive_delay:
				dive_speed = speed * (1.0 + 2.0 * minf(_age - dive_delay, 1.0))
			global_position.y += dive_speed * delta
		_:
			global_position.y += speed * delta


func _update_fire(delta: float) -> void:
	var pattern := data.fire_pattern if data != null else &"none"
	if pattern != &"none" and _has_entered_view:
		_fire_timer -= delta
		if _fire_timer <= 0.0:
			_fire_timer = _fire_interval
			_load_pattern(pattern)
	_drain_shot_queue(delta)


func _load_pattern(pattern: StringName) -> void:
	match pattern:
		&"straight":
			_queue([Vector2.DOWN], 0.0)
		&"burst3":
			_queue([Vector2.DOWN, Vector2.DOWN, Vector2.DOWN], BURST_GAP)
		&"aimed":
			_queue([_aim_at_player()], 0.0)
		&"spread_fan":
			_queue(_fan(5, 60.0), 0.0)
		&"triple":
			_queue(_fan(3, 60.0), 0.0)
		&"carpet":
			_queue(_fan(5, 110.0), 0.0)
		&"cross_volley":
			_queue([
				Vector2.DOWN.rotated(deg_to_rad(-45.0)),
				Vector2.DOWN.rotated(deg_to_rad(45.0)),
				Vector2.DOWN.rotated(deg_to_rad(-135.0)),
				Vector2.DOWN.rotated(deg_to_rad(135.0)),
			], 0.0)
		&"sweep_line":
			_queue_line(5, 20.0)
		_:
			pass


## Symmetric fan of `count` directions spanning `spread_degrees` around straight
## down.
func _fan(count: int, spread_degrees: float) -> Array[Vector2]:
	var directions: Array[Vector2] = []
	var spread := deg_to_rad(spread_degrees)
	var step := spread / float(maxi(count - 1, 1))
	for i in count:
		directions.append(Vector2.DOWN.rotated(-spread * 0.5 + step * float(i)))
	return directions


## A literal horizontal row of shots that falls straight down (§4.4 Sweep-Line):
## direction is shared, the offsets spread the pellets across the screen.
func _queue_line(count: int, spacing: float) -> void:
	var directions: Array[Vector2] = []
	var offsets: Array[Vector2] = []
	var half := float(count - 1) * 0.5
	for i in count:
		directions.append(Vector2.DOWN)
		offsets.append(Vector2((float(i) - half) * spacing, 0.0))
	_queue(directions, 0.0)
	_pending_offsets = offsets


func _queue(directions: Array[Vector2], gap: float) -> void:
	_pending_directions = directions
	_pending_offsets.clear()
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
	_spawn_bullet(direction, offset)


func _spawn_bullet(direction: Vector2, offset: Vector2) -> void:
	var scene := fallback_bullet_scene
	if data != null and data.bullet_scene != null:
		scene = data.bullet_scene
	if scene == null:
		return
	var bullet := scene.instantiate()
	if bullet is EnemyBullet:
		bullet.configure(fire_speed, bullet_damage, direction, bullet_tint, bullet_scale)
	var container := _entity_container()
	if container == null:
		bullet.queue_free()
		return
	container.add_child(bullet)
	if bullet is Node2D:
		bullet.global_position = global_position + offset


func _aim_at_player() -> Vector2:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return Vector2.DOWN
	var to_player := player.global_position - global_position
	if to_player.is_zero_approx():
		return Vector2.DOWN
	return to_player.normalized()


## One hit costs one point of health; the death animation then plays out while
## the node is already harmless.
func take_damage(amount: int = 1) -> void:
	if _dead:
		return
	_health -= maxi(amount, 0)
	if _health <= 0:
		_die()
		return
	_hit_flash = HIT_FLASH_TIME
	AudioManager.play_sfx(hit_sfx)


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
	AudioManager.play_sfx(death_sfx)
	var tween := create_tween()
	tween.tween_property(self, "scale", scale * 1.5, 0.18)
	tween.parallel().tween_property(_sprite, "modulate:a", 0.0, 0.18)
	tween.tween_callback(queue_free)


func _update_hit_flash(delta: float) -> void:
	if _hit_flash <= 0.0:
		return
	_hit_flash = maxf(_hit_flash - delta, 0.0)
	_sprite.modulate = Color(3.0, 3.0, 3.0) if _hit_flash > 0.0 else _base_modulate


## §4.7: the level's difficulty table is the single source of truth, so an enemy
## reads its multipliers instead of carrying per-level duplicates.
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
	# Stagger the first shot so a wave does not open as one synchronized volley.
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


## Weighted pick from the drop_table: [{ "scene": PackedScene, "weight": float }].
func _pick_drop() -> PackedScene:
	var total := 0.0
	for entry in data.drop_table:
		total += _drop_weight(entry)
	if total <= 0.0:
		return null
	var roll := randf() * total
	for entry in data.drop_table:
		roll -= _drop_weight(entry)
		if roll <= 0.0:
			var candidate: Dictionary = entry
			return candidate.get("scene") as PackedScene
	return null


func _drop_weight(entry: Variant) -> float:
	var candidate: Dictionary = entry
	return float(candidate.get("weight", 0.0))


## Enemies and drops join the level's Entities node (§5.6) so a level change
## clears them in one pass; standalone scenes fall back to the scene root.
func _entity_container() -> Node:
	var container := get_tree().get_first_node_in_group(&"entities")
	return container if container != null else get_tree().current_scene
