extends SceneTree
## One-off probe: input map, autoload wiring, project settings.

func _initialize() -> void:
	var probe := InputEventKey.new()
	print("new InputEventKey device = ", probe.device, " (DEVICE_ID_EMULATION=", InputEvent.DEVICE_ID_EMULATION, ")")

	var builtin := InputMap.action_get_events(&"ui_accept")
	if not builtin.is_empty():
		print("engine ui_accept[0] device = ", builtin[0].device)

	for a in ["move_up", "fire", "barrel_roll"]:
		var desc: Array[String] = []
		for e: InputEventKey in InputMap.action_get_events(a):
			desc.append("%s(dev=%d)" % [OS.get_keycode_string(e.physical_keycode), e.device])
		print(a, " => ", ", ".join(desc))

	# Matching is exact on device; a real OS event carries the engine default,
	# which is what InputEventKey.new() reports here.
	var fk := InputEventKey.new()
	fk.pressed = true
	fk.physical_keycode = KEY_SPACE
	print("space(default dev) is_action(fire) = ", InputMap.event_is_action(fk, &"fire"))
	fk.physical_keycode = KEY_W
	print("W(default dev) is_action(move_up) = ", InputMap.event_is_action(fk, &"move_up"))
	fk.physical_keycode = KEY_SHIFT
	print("shift(default dev) is_action(barrel_roll) = ", InputMap.event_is_action(fk, &"barrel_roll"))

	print("texture_filter setting = ", ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"))

	var bus := root.get_node_or_null(^"EventBus")
	var gm := root.get_node_or_null(^"GameManager")
	var sm := root.get_node_or_null(^"SaveManager")
	print("autoloads: EventBus=", bus, " GameManager=", gm, " SaveManager=", sm)

	if bus and gm:
		var seen: Array[int] = []
		bus.lives_changed.connect(func(v: int) -> void: seen.append(v))
		gm.start_run()
		gm.lose_life()
		print("lives_changed emissions = ", seen, " (lives now ", gm.lives, ")")
	if sm:
		print("sm.data = ", sm.data)

	print("buses: ", AudioServer.bus_count, " -> ", AudioServer.get_bus_name(1), ", ", AudioServer.get_bus_name(2))
	quit()
