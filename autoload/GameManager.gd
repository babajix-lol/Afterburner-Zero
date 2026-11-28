extends Node

const STARTING_LIVES := 3
const MAX_LIVES := 5
const STARTING_BOMBS := 1
const MAX_BOMBS := 3
const ULTIMATE_ALLOWED_LEVELS: Array[int] = [4, 5]
const MAX_ULTIMATE_CHARGES := 3
const MAX_ULTIMATE_SPAWNS_PER_LEVEL := 3
const MAX_ULTIMATE_COLLECTED_PER_LEVEL := 3

var current_level: int = 0
var level_data: LevelData = null
var score: int = 0
var lives: int = STARTING_LIVES
var bombs: int = STARTING_BOMBS
var ultimate_charges: int = 0
var ultimate_spawned_in_level: int = 0
var ultimate_collected_in_level: int = 0
var ultimate_max_spawns_this_level: int = 0
var weapon: WeaponData = null
var is_run_active: bool = false

func start_run() -> void:
	current_level = 0
	level_data = null
	score = 0
	lives = STARTING_LIVES
	bombs = STARTING_BOMBS
	ultimate_charges = 0
	ultimate_spawned_in_level = 0
	ultimate_collected_in_level = 0
	ultimate_max_spawns_this_level = 0
	weapon = null
	is_run_active = true
	_announce_all()

func begin_level(index: int, data: LevelData) -> void:
	current_level = index
	level_data = data
	ultimate_charges = 0
	ultimate_spawned_in_level = 0
	ultimate_collected_in_level = 0
	ultimate_max_spawns_this_level = randi_range(1, MAX_ULTIMATE_SPAWNS_PER_LEVEL) if is_ultimate_allowed_level() else 0
	_announce_all()

func add_score(value: int) -> void:
	if value == 0:
		return
	score = maxi(score + value, 0)
	EventBus.score_changed.emit(score)

func add_life(amount: int = 1) -> void:
	if amount == 0:
		return
	lives = clampi(lives + amount, 0, MAX_LIVES)
	EventBus.lives_changed.emit(lives)

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
	bombs = clampi(bombs + amount, 0, MAX_BOMBS)
	EventBus.bomb_changed.emit(bombs)

func use_bomb() -> bool:
	if bombs <= 0:
		return false
	bombs -= 1
	EventBus.bomb_changed.emit(bombs)
	return true

func is_ultimate_allowed_level() -> bool:
	return current_level in ULTIMATE_ALLOWED_LEVELS

func can_spawn_ultimate_pickup() -> bool:
	return is_ultimate_allowed_level() and ultimate_spawned_in_level < ultimate_max_spawns_this_level

func register_ultimate_spawn() -> void:
	ultimate_spawned_in_level = mini(ultimate_spawned_in_level + 1, ultimate_max_spawns_this_level)

func try_reserve_ultimate_spawn() -> bool:
	if not can_spawn_ultimate_pickup():
		return false
	ultimate_spawned_in_level += 1
	return true

func add_ultimate_charge(amount: int = 1) -> bool:
	if not is_ultimate_allowed_level() or amount <= 0:
		return false
	if ultimate_collected_in_level >= MAX_ULTIMATE_COLLECTED_PER_LEVEL:
		return false
	if ultimate_charges >= MAX_ULTIMATE_CHARGES:
		return false
	ultimate_collected_in_level += 1
	ultimate_charges = clampi(ultimate_charges + amount, 0, MAX_ULTIMATE_CHARGES)
	EventBus.ultimate_changed.emit(ultimate_charges)
	return true

func use_ultimate_charge() -> bool:
	if not is_ultimate_allowed_level() or ultimate_charges <= 0:
		return false
	ultimate_charges -= 1
	EventBus.ultimate_changed.emit(ultimate_charges)
	return true

func set_weapon(data: WeaponData) -> void:
	weapon = data
	EventBus.weapon_changed.emit(weapon)

func end_run() -> void:
	is_run_active = false
	SaveManager.submit_score(score)

func _announce_all() -> void:
	EventBus.score_changed.emit(score)
	EventBus.lives_changed.emit(lives)
	EventBus.bomb_changed.emit(bombs)
	EventBus.ultimate_changed.emit(ultimate_charges)
	EventBus.weapon_changed.emit(weapon)
