extends Node2D
class_name ShieldRing
## Procedural shield bubble (design spec §4.2).
##
## Drawn with _draw() so the shield needs no art file, and `energy` (0..1) tracks
## the remaining lifetime so the bubble visibly thins out as it expires.

const RADIUS := 26.0

var energy := 0.0

var _phase := 0.0
var _redraw := false


## 1.0 right after a pick-up, falling to 0 as the timer runs out.
func set_energy(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(energy, clamped):
		return
	energy = clamped
	_redraw = energy > 0.0
	visible = energy > 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if not _redraw:
		return
	_phase += delta
	queue_redraw()


func _draw() -> void:
	if energy <= 0.0:
		return
	var tint := Color(0.35, 0.78, 1.0)
	var pulse := 0.75 + 0.25 * sin(_phase * 8.0)
	draw_circle(Vector2.ZERO, RADIUS, Color(tint, 0.10 * energy))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, Color(tint, 0.85 * energy * pulse), 1.5, true)
