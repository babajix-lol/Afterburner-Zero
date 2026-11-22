extends Node
class_name WaveManager
## Drives enemy waves from LevelData (design spec §5.2, §6.2).
##
## Reads GameManager.level_data.waves and spawns each one in sequence: wait
## delay_before, then spawn count enemies at interval, in the requested
## formation from the requested spawn_group markers.

const SPAWN_GROUPS: Array[StringName] = [&"spawn_top", &"spawn_left", &"spawn_right"]

var _waves: Array[WaveData] = []
var _current_wave := -1
var _enemies_spawned := 0
var _spawn_timer := 0.0
var _delay_timer := 0.0
var _waiting_for_clear := false
var _done := false
var _level_node: Node = null


func start(level: Node) -> void:
	_level_node = level
	var data := GameManager.level_data
	if data == null or data.waves.is_empty():
		push_warning("WaveManager: no waves in LevelData.")
		return
	_waves = data.waves
	_current_wave = -1
	_done = false
	_advance_wave()


func _process(delta: float) -> void:
	if _done or _waves.is_empty():
		return
	if _delay_timer > 0.0:
		_delay_timer -= delta
		return
	if _waiting_for_clear:
		if _living_enemy_count() == 0:
			_waiting_for_clear = false
			_advance_wave()
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_next_enemy()


func _advance_wave() -> void:
	_current_wave += 1
	if _current_wave >= _waves.size():
		_done = true
		_on_all_waves_done()
		return
	var wave := _waves[_current_wave]
	_enemies_spawned = 0
	_delay_timer = wave.delay_before
	_spawn_timer = 0.0
	EventBus.wave_started.emit(_current_wave, _waves.size())
	if wave.is_boss_arena:
		_signal_boss_arena()


func _spawn_next_enemy() -> void:
	var wave := _waves[_current_wave]
	if _enemies_spawned >= wave.count:
		_waiting_for_clear = true
		return
	var enemy := _create_enemy(wave)
	if enemy != null:
		_position_enemy(enemy, wave, _enemies_spawned, wave.count)
		var container := _entity_container()
		container.add_child(enemy)
	_enemies_spawned += 1
	_spawn_timer = wave.interval


func _create_enemy(wave: WaveData) -> Node:
	if wave.enemy_scene == null:
		push_warning("WaveManager: wave %d has no enemy_scene." % _current_wave)
		return null
	return wave.enemy_scene.instantiate()


func _position_enemy(enemy: Node, wave: WaveData, index: int, total: int) -> void:
	var marker := _pick_spawn_marker(wave.spawn_group)
	if marker == null:
		if enemy is Node2D:
			var view_size := Vector2(640, 360)
			if _level_node is CanvasItem:
				view_size = (_level_node as CanvasItem).get_viewport_rect().size
			(enemy as Node2D).global_position = Vector2(view_size.x * 0.5, -40.0)
		return
	var base_pos := marker.global_position
	var offset := _formation_offset(wave.formation, index, total)
	if enemy is Node2D:
		enemy.global_position = base_pos + offset


func _pick_spawn_marker(group: StringName) -> Node2D:
	var markers := get_tree().get_nodes_in_group(group)
	if markers.is_empty():
		return null
	return markers[randi() % markers.size()] as Node2D


func _formation_offset(formation: StringName, index: int, total: int) -> Vector2:
	var spacing := 36.0
	match formation:
		&"line":
			var half := float(total - 1) * 0.5
			return Vector2((float(index) - half) * spacing, 0.0)
		&"vee":
			var half := float(total - 1) * 0.5
			var x := (float(index) - half) * spacing
			var y := absf(float(index) - half) * spacing * 0.5
			return Vector2(x, y)
		_:
			return Vector2(randf_range(-100.0, 100.0), randf_range(-20.0, 20.0))


func _entity_container() -> Node:
	if _level_node != null:
		var entities := _level_node.get_node_or_null("Entities")
		if entities != null:
			return entities
	var container := get_tree().get_first_node_in_group(&"entities")
	return container if container != null else get_tree().current_scene


func _living_enemy_count() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group(&"enemies"):
		if node is Enemy and node.is_alive():
			count += 1
	return count


func _signal_boss_arena() -> void:
	if _level_node != null and _level_node.has_method(&"enter_boss_arena"):
		_level_node.enter_boss_arena()


func _on_all_waves_done() -> void:
	var data := GameManager.level_data
	if data == null or data.boss_scene != null:
		return
	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree():
		return
	if _living_enemy_count() > 0:
		_done = false
		_waiting_for_clear = true
		return
	EventBus.level_completed.emit(GameManager.current_level)
