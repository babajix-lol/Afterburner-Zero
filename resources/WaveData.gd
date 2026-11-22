extends Resource
class_name WaveData
## One spawn wave inside a level (design spec §6.2).
##
## A wave is plain data: which enemy, how many, from where, how fast. The
## WaveManager reads it; nothing about the wave lives in a scene.

## Enemy scene to instantiate. Army / humvee / heli / bomber / turret.
@export var enemy_scene: PackedScene

@export_range(0, 100, 1) var count: int = 1

## Which Marker2D group in the level to spawn from: &"spawn_top",
## &"spawn_left" or &"spawn_right".
@export var spawn_group: StringName = &"spawn_top"

## Seconds between each enemy of this wave.
@export var interval: float = 0.5

## Seconds to wait after the previous wave ends before this one starts.
@export var delay_before: float = 1.0

## &"line", &"vee" or &"random" — shapes the spawn offsets.
@export var formation: StringName = &"line"

## Marks the wave that spawns the boss and stops the camera at BossArena.
@export var is_boss_arena: bool = false
