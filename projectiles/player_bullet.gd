extends Area2D
class_name PlayerBullet
## Player projectile (design spec §5.1, weapon table §4.1).
##
## A single scene covers the default cannon, the spread pellets, the laser and
## the homing missiles: a weapon only changes speed, damage, direction and
## homing, so a new weapon never needs new bullet art.

## How far past the screen edge a bullet keeps flying before it is recycled.
const DESPAWN_MARGIN := 32.0

## Travel speed in px/s. Lasers are set faster than cannon rounds.
@export var speed := 460.0

@export var damage := 1

## Unit vector the bullet flies along. Straight up by default (vertical shmup).
@export var direction := Vector2.UP

## Turn rate toward the nearest enemy, in radians per second. 0 = dumb fire.
@export var homing_turn_rate := 0.0

var _velocity := Vector2.ZERO


func _ready() -> void:
	_apply_direction()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


## Fills in everything a weapon cares about. Called before the bullet enters the
## tree so _ready() can build its velocity from the final numbers.
func configure(p_speed: float, p_damage: int, p_direction: Vector2, p_homing_turn_rate := 0.0) -> void:
	speed = p_speed
	damage = p_damage
	direction = p_direction
	homing_turn_rate = p_homing_turn_rate


func _physics_process(delta: float) -> void:
	if homing_turn_rate > 0.0:
		_steer(delta)
	position += _velocity * delta
	if _is_outside_view():
		queue_free()


## Rotates the heading toward the closest node in the "enemies" group, capped at
## homing_turn_rate radians per second so missiles arc instead of snapping.
func _steer(delta: float) -> void:
	var target := _nearest_enemy()
	if target == null:
		return
	var desired := (target.global_position - global_position).normalized() * speed
	var turn := clampf(_velocity.angle_to(desired), -homing_turn_rate * delta, homing_turn_rate * delta)
	_velocity = _velocity.rotated(turn)


func _nearest_enemy() -> Node2D:
	var closest: Node2D = null
	var closest_distance := INF
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var candidate := node as Node2D
		if candidate == null:
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest = candidate
	return closest


func _apply_direction() -> void:
	_velocity = direction.normalized() * speed
	rotation = _velocity.angle() + PI * 0.5


## Bullets are cheap and long-lived, so they recycle themselves off screen rather
## than relying on a level cleanup pass.
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


func _on_area_entered(area: Area2D) -> void:
	# Enemy hitboxes are Areas parented to the enemy, but a barricade may be the
	# Area itself, so both shapes are accepted.
	if area.has_method(&"take_damage"):
		_hit(area)
		return
	_hit(area.get_parent())


func _on_body_entered(body: Node2D) -> void:
	_hit(body)


func _hit(target: Node) -> void:
	if target == null or not target.has_method(&"take_damage"):
		return
	target.take_damage(damage)
	queue_free()
