extends Node2D
class_name PickupIcon

const PULSE_HZ := 2.5
const PULSE_AMOUNT := 0.08

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
		&"ultimate":
			_draw_ultimate()
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

func _draw_ultimate() -> void:
	# Aura glow luar berdenyut agar mencolok dibanding item biasa
	var glow_radius := 13.0 + sin(_phase * 5.0) * 2.0
	draw_circle(Vector2.ZERO, glow_radius, Color(color, 0.22))
	draw_arc(Vector2.ZERO, 10.5, _phase * 2.0, _phase * 2.0 + TAU * 0.75, 18, Color(1.0, 0.9, 0.35, 0.9), 1.6, true)

	# Bintang 4-sudut berputar
	var rot := _phase * 1.6
	var star := PackedVector2Array()
	for i in 8:
		var angle := rot + (float(i) * PI * 0.25)
		var r := 9.5 if i % 2 == 0 else 4.0
		star.append(Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(star, Color(color, 0.92))
	star.append(star[0])
	draw_polyline(star, Color.WHITE, 1.4, true)
	draw_circle(Vector2.ZERO, 2.8, Color(1.0, 0.95, 0.6))
