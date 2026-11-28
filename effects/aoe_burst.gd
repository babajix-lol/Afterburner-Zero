class_name AoEBurst

const EXPLOSION_SCRIPT := preload("res://effects/explosion.gd")

static func trigger(
	tree: SceneTree,
	origin: Vector2,
	radius: float,
	aoe_damage: int,
	primary_target: Node = null,
	vfx_scale := Vector2(0.35, 0.35)
) -> void:
	var radius_sq := radius * radius
	for node in tree.get_nodes_in_group(&"enemies"):
		if node == primary_target or not is_instance_valid(node):
			continue
		if node is Node2D and node.has_method(&"take_damage"):
			if origin.distance_squared_to(node.global_position) <= radius_sq:
				node.take_damage(aoe_damage)

	var vfx := AnimatedSprite2D.new()
	vfx.set_script(EXPLOSION_SCRIPT)
	vfx.scale = vfx_scale
	vfx.global_position = origin
	var container := tree.get_first_node_in_group(&"entities")
	if container != null:
		container.add_child(vfx)
	else:
		tree.current_scene.add_child(vfx)
