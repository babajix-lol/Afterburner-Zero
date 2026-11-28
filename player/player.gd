extends CharacterBody2D
class_name Player

const MOVE_SPEED := 170.0
const ROLL_SPEED := 520.0
const ROLL_DURATION := 0.3
const ROLL_COOLDOWN := 1.0
const HIT_INVULNERABILITY := 1.0
const SHIELD_DURATION := 5.0
const ULTIMATE_DURATION := 2.0
const PLAYFIELD_MARGIN := 10.0

const ENGINE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/engine_1.png"),
	preload("res://assets/sprites/engine_2.png"),
	preload("res://assets/sprites/engine_3.png"),
]
const ENGINE_FPS := 14.0

@export var roll_sfx: AudioStream
@export var hit_sfx: AudioStream
@export var shield_sfx: AudioStream
@export var ultimate_sfx: AudioStream

@onready var _ship: Sprite2D = $Ship
@onready var _engine_flame: AnimatedSprite2D = $EngineFlame
@onready var _shield_ring: ShieldRing = $ShieldRing
@onready var _weapon: PlayerWeapon = $Weapon
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _ultimate_laser: UltimateLaser = $UltimateLaser
@onready var _left_pod: SideMissilePod = $LeftMissilePod
@onready var _right_pod: SideMissilePod = $RightMissilePod

var _level: BaseLevel = null

var _invuln_timer := 0.0
var _shield_timer := 0.0
var _shield_span := SHIELD_DURATION
var _ultimate_timer := 0.0
var _roll_timer := 0.0
var _roll_cooldown := 0.0
var _roll_direction := Vector2.DOWN
var _is_rolling := false
var _is_dead := false

func _ready() -> void:
	add_to_group(&"player")
	_level = get_tree().get_first_node_in_group(&"level") as BaseLevel
	_build_engine_flame()
	_shield_ring.set_energy(0.0)
	_set_ultimate_active(false)
	_hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	_hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	EventBus.player_died.connect(_on_player_died)
	EventBus.shield_changed.emit(0.0)

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_tick_timers(delta)
	if _is_rolling:
		_update_roll(delta)
	else:
		velocity = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down") * MOVE_SPEED
	move_and_slide()
	if _level != null:
		global_position += _level.camera_delta
	_clamp_to_playfield()
	_weapon.set_trigger(Input.is_action_pressed(&"fire"))
	_update_visuals()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"barrel_roll"):
		start_roll()
	if event.is_action_pressed(&"bomb"):
		_use_bomb()
	if event.is_action_pressed(&"activate_ultimate"):
		_activate_ultimate()

func start_roll() -> void:
	if _is_dead or _is_rolling or _roll_cooldown > 0.0:
		return
	var input_direction := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	_roll_direction = input_direction.normalized() if input_direction != Vector2.ZERO else Vector2.DOWN
	_is_rolling = true
	_roll_timer = ROLL_DURATION
	_roll_cooldown = ROLL_COOLDOWN
	_invuln_timer = maxf(_invuln_timer, ROLL_DURATION)
	AudioManager.play_sfx(roll_sfx)

func is_invulnerable() -> bool:
	return _invuln_timer > 0.0 or _shield_timer > 0.0

func is_rolling() -> bool:
	return _is_rolling

func is_alive() -> bool:
	return not _is_dead

func take_damage(_amount: int = 1) -> bool:
	if _is_dead:
		return false
	if _shield_timer > 0.0:
		_shield_timer = maxf(_shield_timer - 1.5, 0.0)
		_invuln_timer = 0.3
		if _shield_timer <= 0.0:
			_shield_ring.set_energy(0.0)
			EventBus.shield_changed.emit(0.0)
		return true
	if is_invulnerable():
		return false
	_invuln_timer = HIT_INVULNERABILITY
	AudioManager.play_sfx(hit_sfx)
	var alive := GameManager.lose_life()
	if not alive:
		_die()
	return alive

func grant_shield(duration := SHIELD_DURATION) -> void:
	if _is_dead:
		return
	_shield_span = maxf(duration, 0.001)
	_shield_timer = duration
	_shield_ring.set_energy(1.0)
	AudioManager.play_sfx(shield_sfx)
	EventBus.shield_changed.emit(_shield_timer)

func _activate_ultimate() -> void:
	if _is_dead or _ultimate_timer > 0.0:
		return
	if not GameManager.is_ultimate_allowed_level():
		return
	if not GameManager.use_ultimate_charge():
		return
	_ultimate_timer = ULTIMATE_DURATION
	_set_ultimate_active(true)
	AudioManager.play_sfx(ultimate_sfx)
	EventBus.ultimate_activated.emit(ULTIMATE_DURATION)

func _set_ultimate_active(active: bool) -> void:
	if _ultimate_laser != null:
		_ultimate_laser.set_active(active)
	if _left_pod != null:
		_left_pod.set_active(active)
	if _right_pod != null:
		_right_pod.set_active(active)

func _tick_timers(delta: float) -> void:
	_invuln_timer = maxf(_invuln_timer - delta, 0.0)
	_roll_cooldown = maxf(_roll_cooldown - delta, 0.0)
	if _ultimate_timer > 0.0:
		_ultimate_timer = maxf(_ultimate_timer - delta, 0.0)
		if _ultimate_timer <= 0.0:
			_set_ultimate_active(false)
	if _shield_timer <= 0.0:
		return
	var previous := _shield_timer
	_shield_timer = maxf(_shield_timer - delta, 0.0)
	if _shield_timer <= 0.0:
		_shield_ring.set_energy(0.0)
		EventBus.shield_changed.emit(0.0)
	elif floori(_shield_timer * 10.0) != floori(previous * 10.0):
		EventBus.shield_changed.emit(_shield_timer)

func _update_roll(delta: float) -> void:
	_roll_timer = maxf(_roll_timer - delta, 0.0)
	velocity = _roll_direction * ROLL_SPEED
	if _roll_timer <= 0.0:
		_is_rolling = false

func _clamp_to_playfield() -> void:
	var rect := _visible_world_rect()
	var half := _sprite_half_extent()
	global_position = global_position.clamp(rect.position + half, rect.end - half)

func _sprite_half_extent() -> Vector2:
	if _ship == null or _ship.texture == null:
		return Vector2(PLAYFIELD_MARGIN, PLAYFIELD_MARGIN)
	var half := _ship.texture.get_size() * 0.5
	return Vector2(maxf(half.x, PLAYFIELD_MARGIN), maxf(half.y, PLAYFIELD_MARGIN))

func _visible_world_rect() -> Rect2:
	var view_size := get_viewport_rect().size
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return Rect2(Vector2.ZERO, view_size)
	var world_size := view_size / camera.zoom
	return Rect2(camera.get_screen_center_position() - world_size * 0.5, world_size)

func _update_visuals() -> void:
	_ship.scale = Vector2(_roll_amount(), 1.0)
	var alpha := 1.0
	if _invuln_timer > 0.0:
		alpha = 0.35 if fmod(_invuln_timer, 0.16) < 0.08 else 1.0
	_ship.modulate.a = alpha
	_engine_flame.modulate.a = alpha
	if _shield_timer > 0.0:
		_shield_ring.set_energy(_shield_timer / _shield_span)

func _roll_amount() -> float:
	if not _is_rolling:
		return 1.0
	return cos((1.0 - _roll_timer / ROLL_DURATION) * TAU)

func _build_engine_flame() -> void:
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", ENGINE_FPS)
	for texture in ENGINE_TEXTURES:
		frames.add_frame(&"default", texture)
	_engine_flame.sprite_frames = frames
	_engine_flame.play(&"default")

func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	_weapon.set_process(false)
	_shield_timer = 0.0
	_shield_ring.set_energy(0.0)
	EventBus.shield_changed.emit(0.0)
	var tween := create_tween()
	tween.tween_property(_ship, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(_engine_flame, "modulate:a", 0.0, 0.4)

func _on_player_died() -> void:
	_die()

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group(&"enemy_bullets"):
		take_damage()
		area.call_deferred(&"queue_free")
	elif area.is_in_group(&"enemies"):
		take_damage()
		if area.has_method(&"take_damage"):
			area.take_damage(1)

func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"enemies") or body.is_in_group(&"enemy_bullets"):
		take_damage()
		if body.has_method(&"take_damage"):
			body.take_damage(1)

func _use_bomb() -> void:
	if _is_dead or not GameManager.use_bomb():
		return
	for bullet in get_tree().get_nodes_in_group(&"enemy_bullets"):
		bullet.queue_free()
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if enemy.has_method(&"take_damage"):
			enemy.take_damage(10)
