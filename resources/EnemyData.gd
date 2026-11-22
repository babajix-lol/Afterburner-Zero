extends Resource
class_name EnemyData
## Per-enemy tuning (design spec §6.4).
##
## Kept separate from the enemy scene so one scene (say the army soldier) can
## be reused as a tougher elite by pointing at a different EnemyData.

@export var max_health: int = 1

## How the enemy moves: &"straight", &"sine", &"hover", &"dive", &"static".
@export var move_pattern: StringName = &"straight"

## How the enemy shoots: &"none", &"straight", &"burst3", &"aimed",
## &"spread_fan", &"triple", &"sweep_line".
@export var fire_pattern: StringName = &"none"

## Seconds between shots.
@export var fire_interval: float = 1.5

## Enemy projectile scene.
@export var bullet_scene: PackedScene

@export var score_value: int = 100

## Weighted pickups: [{ "scene": PackedScene, "weight": float }, ...].
@export var drop_table: Array = []
