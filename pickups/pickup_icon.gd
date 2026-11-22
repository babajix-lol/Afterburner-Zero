extends Node2D
class_name PickupIcon
## Procedurally drawn pick-up icon (design spec §4.2).
##
## The 32x32 UI sheet that shipped with the assets is fully transparent, so the
## Shield, Bomb and Weapon Crate icons are drawn here instead of loaded — the same
## trick as the shield bubble, and it adds no art file (§7).

const PULSE_HZ := 2.5
const PULSE_AMOUNT := 0.08

## &"shield", &"bomb" or &"crate".
@export var shape: StringName = &"shield"
@export var color := Color(0.35, 0.78, 1.0)

var _phase := 0.0


func _process(delta: float) -> void:
	_phase += delta
	scale = Vector2.ONE * (1.0 + sin(_phase * PULSE_HZ) * PULSE_AMOUNT)
	queue_redraw()


func _draw() -> void:
	match shape:
		&"bomb":
			_draw_bomb()
		&"crate":
			_draw_crate()
		_:
			_draw_shield()


func _draw_shield() -> void:
	var points := PackedVector2Array([
		Vector2(-8.0, -7.0),
		Vector2(8.0, -7.0),
		Vector2(8.0, 1.0),
		Vector2(0.0, 9.0),
		Vector2(-8.0, 1.0),
	])
	draw_colored_polygon(points, Color(color, 0.85))
	points.append(points[0])
	draw_polyline(points, color, 1.5, true)


func _draw_bomb() -> void:
	draw_circle(Vector2(0.0, 2.0), 7.0, Color(color, 0.9))
	draw_line(Vector2(3.0, -4.0), Vector2(6.0, -9.0), color, 1.5, true)
	draw_circle(Vector2(6.5, -9.5), 1.8, Color(1.0, 0.9, 0.4))


func _draw_crate() -> void:
	var box := Rect2(-8.0, -7.0, 16.0, 14.0)
	draw_rect(box, Color(color, 0.35))
	draw_rect(box, color, false, 1.5)
	draw_line(Vector2(0.0, -7.0), Vector2(0.0, 7.0), Color(color, 0.8), 1.0)
	draw_line(Vector2(-8.0, 0.0), Vector2(8.0, 0.0), Color(color, 0.8), 1.0)
