extends Resource
class_name WeaponData
## A player weapon (design spec §6.3, behaviour table §4.1).
##
## Default cannon, spread, laser and homing are all the same class with
## different values, so a weapon crate only swaps one of these.

@export var display_name: String = "Default Cannon"

## Projectile spawned per shot. May be null for the built-in default cannon,
## which draws from the player scene instead.
@export var bullet_scene: PackedScene

## Shots per second.
@export var fire_rate: float = 8.0

@export var damage: int = 1

## Bullets fired per shot (spread fires 3, homing fires 2).
@export_range(1, 12, 1) var projectile_count: int = 1

## Total fan width in degrees. 0 = all bullets fly straight.
@export var spread_angle: float = 0.0

## When true each projectile turns toward the nearest enemy (missiles).
@export var is_homing: bool = false
