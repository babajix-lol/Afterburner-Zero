extends PlayerBullet
class_name UltimateMissile

@export var aoe_radius := 42.0
@export var aoe_damage := 1
@export var explosion_sfx: AudioStream

func _ready() -> void:
	if homing_turn_rate <= 0.0:
		homing_turn_rate = 3.5
	super._ready()

func _hit(target: Node) -> void:
	if target == null or not target.has_method(&"take_damage"):
		return
	target.take_damage(damage)
	AoEBurst.trigger(get_tree(), global_position, aoe_radius, aoe_damage, target, Vector2(0.35, 0.35))
	if explosion_sfx != null:
		AudioManager.play_sfx(explosion_sfx)
	queue_free()
