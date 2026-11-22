extends Area2D
class_name EnemyBullet
## Enemy projectile (design spec §4.4, §5.1).
##
## One scene covers every enemy pattern — straight, burst-3, aimed, fan, carpet
## — because a pattern only changes direction, speed, tint and size (§4.4:
## "semua memakai peluru dasar dengan warna/skala berbeda").
##
## The bullet damages nothing on its own path check: the player's Hurtbox has
## mask 4|8, so it sees this bullet the moment they overlap. The body check here
## only exists so the bullet disappears on impact instead of flying through.

## How far past the screen edge a bullet keeps flying before it is recycled.
const DESPAWN_MARGIN := 32.0

## The bomb power-up sweeps this group for its screen clear (§4.2).
const GROUP: StringName = &"enemy_bullets"

@export var speed := 170.0
@export var damage := 1

## Unit vector the bullet flies along. Straight down by default.
@export var direction := Vector2.DOWN

## §4.4: patterns are told apart by bullet colour, so every enemy tints its own.
@export var tint := Color(1.0, 0.6, 0.45)
@export var bullet_scale := 1.0

var _velocity := Vector2.ZERO


func _ready() -> void:
	add_to_group(GROUP)
	modulate = tint
	scale = Vector2.ONE * bullet_scale
	_apply_direction()
	body_entered.connect(_on_body_entered)


## Fills in everything a fire pattern cares about. Called before the bullet
## enters the tree so _ready() can build its velocity from the final numbers.
func configure(
	p_speed: float,
	p_damage: int,
	p_direction: Vector2,
	p_tint := Color(1.0, 0.6, 0.45),
	p_scale := 1.0
) -> void:
	speed = p_speed
	damage = p_damage
	direction = p_direction
	tint = p_tint
	bullet_scale = p_scale


func _physics_process(delta: float) -> void:
	position += _velocity * delta
	if _is_outside_view():
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not body.has_method(&"take_damage"):
		return
	body.take_damage(damage)
	queue_free()


func _apply_direction() -> void:
	_velocity = direction.normalized() * speed
	# The art is drawn pointing down, so a downward shot needs no rotation.
	rotation = _velocity.angle() - PI * 0.5


## Bullets recycle themselves off screen rather than relying on a cleanup pass,
## because a level can spawn hundreds of them.
func _is_outside_view() -> bool:
	var view_size := get_viewport_rect().size
	var center := view_size * 0.5
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		view_size /= camera.zoom
		center = camera.get_screen_center_position()
	var limit := view_size * 0.5 + Vector2(DESPAWN_MARGIN, DESPAWN_MARGIN)
	var offset := global_position - center
	return absf(offset.x) > limit.x or absf(offset.y) > limit.y
