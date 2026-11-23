extends Control
class_name HUD
## In-game heads-up display (design spec §5.2).
##
## Reads every value through EventBus signals, so it never reaches into
## GameManager or the player directly. GameManager._announce_all() pushes the
## initial state right after a level loads.

@onready var _score_label: Label = $MarginContainer/TopBar/ScoreLabel
@onready var _lives_container: HBoxContainer = $MarginContainer/TopBar/LivesContainer
@onready var _bomb_label: Label = $MarginContainer/TopBar/BombLabel
@onready var _weapon_label: Label = $MarginContainer/TopBar/WeaponLabel
@onready var _combo_label: Label = $MarginContainer/TopBar/ComboLabel
@onready var _wave_label: Label = $MarginContainer/BottomBar/WaveLabel
@onready var _boss_bar: VBoxContainer = $BossBar
@onready var _boss_name: Label = $BossBar/BossName
@onready var _boss_health: ProgressBar = $BossBar/BossHealth

const HEART_FULL := preload("res://assets/sprites/heart.png")
const HEART_EMPTY := preload("res://assets/sprites/heart_empty.png")
const MAX_HEARTS := 5

var _boss_display_name := "BOSS"
var _boss_phase := 0
var _boss_phase_count := 1


func _ready() -> void:
	EventBus.score_changed.connect(_on_score_changed)
	EventBus.lives_changed.connect(_on_lives_changed)
	EventBus.bomb_changed.connect(_on_bomb_changed)
	EventBus.weapon_changed.connect(_on_weapon_changed)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.boss_started.connect(_on_boss_started)
	EventBus.boss_health_changed.connect(_on_boss_health_changed)
	EventBus.boss_phase_changed.connect(_on_boss_phase_changed)
	if EventBus.has_signal(&"combo_changed"):
		EventBus.combo_changed.connect(_on_combo_changed)
	_wave_label.text = ""
	_combo_label.text = ""
	_boss_bar.visible = false


func _on_score_changed(value: int) -> void:
	_score_label.text = "SCORE: %d" % value


func _on_lives_changed(value: int) -> void:
	for child in _lives_container.get_children():
		child.queue_free()
	for i in MAX_HEARTS:
		var icon := TextureRect.new()
		icon.texture = HEART_FULL if i < value else HEART_EMPTY
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(16, 16)
		_lives_container.add_child(icon)


func _on_bomb_changed(value: int) -> void:
	_bomb_label.text = "BOMB: %d" % value


func _on_weapon_changed(weapon_data: WeaponData) -> void:
	if weapon_data == null:
		_weapon_label.text = "DEFAULT"
	else:
		_weapon_label.text = weapon_data.display_name.to_upper()


func _on_wave_started(index: int, total: int) -> void:
	_wave_label.text = "WAVE %d/%d" % [index + 1, total]
	var tween := create_tween()
	tween.tween_property(_wave_label, "modulate:a", 1.0, 0.2)
	tween.tween_interval(2.0)
	tween.tween_property(_wave_label, "modulate:a", 0.0, 0.5)


func _on_combo_changed(value: int) -> void:
	if value <= 1:
		_combo_label.text = ""
		return
	_combo_label.text = "x%d" % value
	_combo_label.modulate = Color(1.0, 0.85, 0.2) if value < 5 else Color(1.0, 0.3, 0.2)
	var tween := create_tween()
	tween.tween_property(_combo_label, "scale", Vector2(1.3, 1.3), 0.08)
	tween.tween_property(_combo_label, "scale", Vector2.ONE, 0.12)


## §3.3/§3.4: the boss bar. The boss announces its name when it enters the arena,
## then reports health on spawn / every hit / zero on death.
func _on_boss_started(boss: Node) -> void:
	var name_value: Variant = null
	if boss != null:
		name_value = boss.get(&"display_name")
	_boss_display_name = str(name_value) if name_value != null else "BOSS"
	_boss_bar.visible = true
	_update_boss_label()


func _on_boss_health_changed(current: int, maximum: int) -> void:
	if maximum <= 0:
		return
	if current <= 0:
		_boss_bar.visible = false
		return
	_boss_bar.visible = true
	_boss_health.max_value = float(maximum)
	_boss_health.value = float(clampi(current, 0, maximum))
	_update_boss_label()


func _on_boss_phase_changed(phase: int, total: int) -> void:
	_boss_phase = phase
	_boss_phase_count = maxi(total, 1)
	_update_boss_label()


## The name doubles as the phase readout so a multi-phase boss needs no extra widget.
func _update_boss_label() -> void:
	var text := _boss_display_name
	if _boss_phase_count > 1:
		text += "  -  FASE %d/%d" % [_boss_phase + 1, _boss_phase_count]
	_boss_name.text = text
