extends RayCast2D
class_name UltimateLaser

@export var max_length := 460.0
@export var tick_interval := 0.12
@export var tick_damage := 1
@export var aoe_radius := 36.0
@export var aoe_damage := 1
@export var base_width := 14.0

@onready var _beam_outer: Line2D = $BeamOuter
@onready var _beam_core: Line2D = $BeamCore

var _active := false
var _tick_timer := 0.0
var _pulse_time := 0.0

func _ready() -> void:
	target_position = Vector2(0.0, -max_length)
	collide_with_areas = true
	collide_with_bodies = true
	set_active(false)

func set_active(active: bool) -> void:
	_active = active
	enabled = active
	visible = active
	_tick_timer = 0.0
	if not active:
		_update_line(Vector2(0.0, -max_length))

func _physics_process(delta: float) -> void:
	if not _active:
		return

	_pulse_time += delta * 18.0
	var pulse := sin(_pulse_time) * 2.5
	if _beam_outer != null:
		_beam_outer.width = base_width + pulse
	if _beam_core != null:
		_beam_core.width = (base_width * 0.45) + (pulse * 0.5)

	force_raycast_update()
	var end_point := Vector2(0.0, -max_length)
	var hit_target: Node = null

	if is_colliding():
		end_point = to_local(get_collision_point())
		var collider := get_collider()
		if collider != null and collider.has_method(&"take_damage"):
			hit_target = collider
		elif collider is Node and collider.get_parent() != null and collider.get_parent().has_method(&"take_damage"):
			hit_target = collider.get_parent()

	_update_line(end_point)

	_tick_timer -= delta
	if _tick_timer <= 0.0 and hit_target != null:
		_tick_timer = tick_interval
		hit_target.take_damage(tick_damage)
		AoEBurst.trigger(
			get_tree(),
			get_collision_point(),
			aoe_radius,
			aoe_damage,
			hit_target,
			Vector2(0.28, 0.28)
		)

func _update_line(local_end: Vector2) -> void:
	var pts := PackedVector2Array([Vector2.ZERO, local_end])
	if _beam_outer != null:
		_beam_outer.points = pts
	if _beam_core != null:
		_beam_core.points = pts
