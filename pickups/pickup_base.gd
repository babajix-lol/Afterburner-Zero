extends Area2D
class_name Pickup

const GROUP: StringName = &"pickups"
const LIFETIME := 12.0
const BLINK_TIME := 3.0
const BLINK_HZ := 6.0
const BOB_AMPLITUDE := 2.5
const BOB_SPEED := 5.0

@export var kind: StringName = &"heart"
@export var heal_amount := 1
@export var shield_duration := 6.0
@export var bomb_amount := 1
@export var ultimate_amount := 1
@export var weapon_data: WeaponData
@export var pickup_sfx: AudioStream

@onready var _icon: Node2D = $Icon

var _age := 0.0
var _taken := false

func _ready() -> void:
	if kind == &"ultimate" and not GameManager.is_ultimate_allowed_level():
		queue_free()
		return
	add_to_group(GROUP)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if _taken:
		return
	var player := area.get_parent() as Node2D
	if player != null and player.is_in_group(&"player"):
		_on_body_entered(player)

func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	_icon.position.y = sin(_age * BOB_SPEED) * BOB_AMPLITUDE
	var remaining := LIFETIME - _age
	if remaining < BLINK_TIME and fmod(remaining * BLINK_HZ, 1.0) < 0.5:
		_icon.modulate.a = 0.35
	else:
		_icon.modulate.a = 1.0

const WEAPON_POOL := [
	preload("res://data/weapons/spread.tres"),
	preload("res://data/weapons/laser.tres"),
	preload("res://data/weapons/homing.tres"),
]

func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group(&"player"):
		return
	if not _apply(body):
		return
	_taken = true
	AudioManager.play_sfx(pickup_sfx)
	queue_free()

func _apply(player: Node2D) -> bool:
	match kind:
		&"heart":
			GameManager.add_life(heal_amount)
		&"shield":
			if not player.has_method(&"grant_shield"):
				return false
			player.grant_shield(shield_duration)
		&"bomb":
			GameManager.add_bomb(bomb_amount)
		&"ultimate":
			return GameManager.add_ultimate_charge(ultimate_amount)
		&"weapon":
			var chosen := weapon_data
			if chosen == null:
				chosen = WEAPON_POOL[randi() % WEAPON_POOL.size()]
			GameManager.set_weapon(chosen)
	return true
