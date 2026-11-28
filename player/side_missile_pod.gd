extends Node2D
class_name SideMissilePod

@export var missile_scene: PackedScene
@export var fire_interval := 0.25
@export var missile_speed := 400.0
@export var missile_damage := 1
@export var missile_turn_rate := 4.0

var _active := false
var _fire_timer := 0.0

func set_active(active: bool) -> void:
	_active = active
	visible = active
	_fire_timer = 0.08 if active else 0.0
	queue_redraw()

func _draw() -> void:
	if not _active:
		return
	var body := PackedVector2Array([
		Vector2(0.0, -6.0),
		Vector2(3.0, 2.0),
		Vector2(2.0, 6.0),
		Vector2(-2.0, 6.0),
		Vector2(-3.0, 2.0),
	])
	draw_colored_polygon(body, Color(0.25, 0.85, 1.0, 0.95))
	draw_circle(Vector2(0.0, -2.0), 1.5, Color.WHITE)

func _physics_process(delta: float) -> void:
	if not _active or missile_scene == null:
		return
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = fire_interval
		_fire_missile()

func _fire_missile() -> void:
	var missile := missile_scene.instantiate() as PlayerBullet
	if missile == null:
		return

	var target := _nearest_enemy()
	var dir := (target.global_position - global_position).normalized() if target != null else Vector2.UP
	missile.configure(missile_speed, missile_damage, dir, missile_turn_rate, false)
	missile.global_position = global_position

	var container := get_tree().get_first_node_in_group(&"entities")
	if container != null:
		container.add_child(missile)
	else:
		get_tree().current_scene.add_child(missile)

func _nearest_enemy() -> Node2D:
	var closest: Node2D = null
	var min_dist := INF
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Node2D
		if enemy != null and is_instance_valid(enemy):
			var dist := global_position.distance_squared_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = enemy
	return closest
