extends Area2D
class_name Pickup
## Everything a fallen enemy can leave behind (design spec §4.2).
##
## One script covers all four pick-ups because what a pick-up *does* is a `kind`,
## not a class: Heart / Shield / Bomb / Weapon Crate differ only in one line of
## effect plus their icon.
##
## The Area watches for the Player body rather than the other way round, so the
## player scene needs no pick-up detector and layer 16 stays clear of the
## player's damage masks (4|8 in the Hurtbox).

const GROUP: StringName = &"pickups"

## Seconds an uncollected pick-up survives before it fades away.
const LIFETIME := 12.0
## The last stretch of LIFETIME, during which the icon blinks as a warning.
const BLINK_TIME := 3.0
const BLINK_HZ := 6.0

## Vertical bob of the icon, so a drop reads as an item and not scenery.
const BOB_AMPLITUDE := 2.5
const BOB_SPEED := 5.0

## &"heart", &"shield", &"bomb" or &"weapon".
@export var kind: StringName = &"heart"
@export var heal_amount := 1
@export var shield_duration := 6.0
@export var bomb_amount := 1
## The weapon a &"weapon" crate grants. A crate without one is left on the field.
@export var weapon_data: WeaponData
@export var pickup_sfx: AudioStream

@onready var _icon: Node2D = $Icon

var _age := 0.0
var _taken := false


func _ready() -> void:
	add_to_group(GROUP)
	body_entered.connect(_on_body_entered)


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


## Returns false when the pick-up cannot be applied, so the player can try again
## (or simply fly away) instead of the drop silently vanishing.
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
		&"weapon":
			var chosen := weapon_data
			if chosen == null:
				chosen = WEAPON_POOL[randi() % WEAPON_POOL.size()]
			GameManager.set_weapon(chosen)
	return true
