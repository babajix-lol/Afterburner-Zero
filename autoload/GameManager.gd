extends Node
## Session state for the current run (design spec §5.1).
##
## Owns score, lives, bombs and the active weapon so no level, HUD or pickup
## keeps its own copy. Every change is announced on EventBus; readers that need
## the value immediately call the matching getter.

const STARTING_LIVES := 3
const STARTING_BOMBS := 1

var current_level: int = 0
var level_data: LevelData = null
var score: int = 0
var lives: int = STARTING_LIVES
var bombs: int = STARTING_BOMBS
## The weapon picked up this level, or null for the default cannon. Per §4.1 it
## is reset when the player dies and never carries over between levels.
var weapon: WeaponData = null
var is_run_active: bool = false


func start_run() -> void:
	current_level = 0
	level_data = null
	score = 0
	lives = STARTING_LIVES
	bombs = STARTING_BOMBS
	weapon = null
	is_run_active = true
	_announce_all()


## Called by SceneRouter right before a level scene is instantiated.
func begin_level(index: int, data: LevelData) -> void:
	current_level = index
	level_data = data
	# §4.2: every level starts with one bomb. Lives, score and weapon persist
	# for the duration of the run.
	bombs = STARTING_BOMBS
	_announce_all()


func add_score(value: int) -> void:
	if value == 0:
		return
	score = maxi(score + value, 0)
	EventBus.score_changed.emit(score)


func add_life(amount: int = 1) -> void:
	if amount == 0:
		return
	lives = maxi(lives + amount, 0)
	EventBus.lives_changed.emit(lives)


## Consumes one life. Returns true while the run may continue.
func lose_life() -> bool:
	lives = maxi(lives - 1, 0)
	weapon = null
	EventBus.lives_changed.emit(lives)
	EventBus.weapon_changed.emit(weapon)
	if lives <= 0:
		is_run_active = false
		EventBus.player_died.emit()
		return false
	return true


func add_bomb(amount: int = 1) -> void:
	if amount == 0:
		return
	bombs = maxi(bombs + amount, 0)
	EventBus.bomb_changed.emit(bombs)


## Spends one bomb. Returns false when the player has none left.
func use_bomb() -> bool:
	if bombs <= 0:
		return false
	bombs -= 1
	EventBus.bomb_changed.emit(bombs)
	return true


func set_weapon(data: WeaponData) -> void:
	weapon = data
	EventBus.weapon_changed.emit(weapon)


func end_run() -> void:
	is_run_active = false
	SaveManager.submit_score(score)


## Pushes every value out once, for HUDs that just finished connecting: signals
## do not replay, so the first draw needs an explicit nudge.
func _announce_all() -> void:
	EventBus.score_changed.emit(score)
	EventBus.lives_changed.emit(lives)
	EventBus.bomb_changed.emit(bombs)
	EventBus.weapon_changed.emit(weapon)
