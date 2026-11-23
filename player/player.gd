extends CharacterBody2D
class_name Player
## The AFTERBURNER jet: 8-way flight, the basic gun, the Barrel Roll and the two
## defensive resources (design spec §4.1-§4.3, §5.1).
##
## Everything that can hurt the jet calls take_damage(); everything that helps it
## calls grant_shield(). The jet never reaches into the HUD — it only reports on
## EventBus, so the HUD can be rebuilt without touching gameplay.

## Flight speed in px/s.
const MOVE_SPEED := 170.0
## Roll speed in px/s (§4.3: a fast burst in the input direction).
const ROLL_SPEED := 520.0
## §4.3: the roll's length, and the i-frames that come with it.
const ROLL_DURATION := 0.3
## §4.3: roughly one second between rolls.
const ROLL_COOLDOWN := 1.0
## Post-hit grace, so a single collision cannot drain several hearts.
const HIT_INVULNERABILITY := 1.2
## §4.2: how long a Shield pick-up keeps the jet immune.
const SHIELD_DURATION := 6.0
## Keeps the jet fully inside the playfield.
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

@onready var _ship: Sprite2D = $Ship
@onready var _engine_flame: AnimatedSprite2D = $EngineFlame
@onready var _shield_ring: ShieldRing = $ShieldRing
@onready var _weapon: PlayerWeapon = $Weapon
@onready var _hurtbox: Area2D = $Hurtbox

## The level that owns the auto-scrolling camera. Read for `camera_delta` so the
## jet can cancel the scroll and hold its screen position (see _physics_process).
var _level: BaseLevel = null

var _invuln_timer := 0.0
var _shield_timer := 0.0
var _shield_span := SHIELD_DURATION
var _roll_timer := 0.0
var _roll_cooldown := 0.0
var _roll_direction := Vector2.DOWN
var _is_rolling := false
var _is_dead := false


func _ready() -> void:
	add_to_group(&"player")
	# The level registers itself in _enter_tree(), which runs before this, so the
	# lookup succeeds on the first frame. Null in standalone test scenes.
	_level = get_tree().get_first_node_in_group(&"level") as BaseLevel
	_build_engine_flame()
	_shield_ring.set_energy(0.0)
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
	# §: the level scrolls the camera, so add that same displacement back to the
	# jet. Idle input then leaves it fixed on screen instead of drifting backward,
	# while its world position (and the Entities around it) still comes along.
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


## The Barrel Roll (§4.3). Melesat in the input direction — straight back when
## the stick is neutral — and turns the jet immune for the length of the roll.
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


## True while the jet cannot be hit: rolling, shielded, or in post-hit grace.
func is_invulnerable() -> bool:
	return _invuln_timer > 0.0 or _shield_timer > 0.0


func is_rolling() -> bool:
	return _is_rolling


func is_alive() -> bool:
	return not _is_dead


## One hit costs one heart (§2: the jet has no separate hit points). Returns true
## while the jet keeps flying.
func take_damage(_amount: int = 1) -> bool:
	if _is_dead or is_invulnerable():
		return false
	_invuln_timer = HIT_INVULNERABILITY
	AudioManager.play_sfx(hit_sfx)
	var alive := GameManager.lose_life()
	if not alive:
		_die()
	return alive


## §4.2: temporary immunity from a Shield pick-up. Picking up another one while
## shielded refreshes the timer rather than stacking it.
func grant_shield(duration := SHIELD_DURATION) -> void:
	if _is_dead:
		return
	_shield_span = maxf(duration, 0.001)
	_shield_timer = duration
	_shield_ring.set_energy(1.0)
	AudioManager.play_sfx(shield_sfx)
	EventBus.shield_changed.emit(_shield_timer)


func _tick_timers(delta: float) -> void:
	_invuln_timer = maxf(_invuln_timer - delta, 0.0)
	_roll_cooldown = maxf(_roll_cooldown - delta, 0.0)
	if _shield_timer <= 0.0:
		return
	var previous := _shield_timer
	_shield_timer = maxf(_shield_timer - delta, 0.0)
	if _shield_timer <= 0.0:
		_shield_ring.set_energy(0.0)
		EventBus.shield_changed.emit(0.0)
	elif floori(_shield_timer * 10.0) != floori(previous * 10.0):
		# Announce in tenths instead of every frame; the HUD only shows one digit.
		EventBus.shield_changed.emit(_shield_timer)


func _update_roll(delta: float) -> void:
	_roll_timer = maxf(_roll_timer - delta, 0.0)
	velocity = _roll_direction * ROLL_SPEED
	if _roll_timer <= 0.0:
		_is_rolling = false


## Keeps the whole jet inside whatever the camera currently shows, so it can fly
## forward, backward, left and right without ever leaving the viewport.
func _clamp_to_playfield() -> void:
	var rect := _visible_world_rect()
	var half := _sprite_half_extent()
	global_position = global_position.clamp(rect.position + half, rect.end - half)


## Half the ship sprite, so the clamp leaves a margin wide enough for the jet
## itself. Never smaller than PLAYFIELD_MARGIN.
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


## 1.0 in level flight; during a roll it sweeps 1 -> 0 -> -1 -> 0 -> 1, which
## reads as the classic top-down barrel roll.
func _roll_amount() -> float:
	if not _is_rolling:
		return 1.0
	return cos((1.0 - _roll_timer / ROLL_DURATION) * TAU)


## SpriteFrames built in code so the three flame PNGs stay the only art needed.
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


func _on_hurtbox_area_entered(_area: Area2D) -> void:
	take_damage()


func _on_hurtbox_body_entered(_body: Node2D) -> void:
	take_damage()


## Screen-clear bomb (§4.2): destroys all enemy bullets and deals heavy damage
## to every enemy on screen.
func _use_bomb() -> void:
	if _is_dead or not GameManager.use_bomb():
		return
	for bullet in get_tree().get_nodes_in_group(&"enemy_bullets"):
		bullet.queue_free()
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if enemy.has_method(&"take_damage"):
			enemy.take_damage(10)
