extends Pickup
class_name CollectibleItem

func _ready() -> void:
	kind = &"ultimate"
	if not GameManager.is_ultimate_allowed_level():
		queue_free()
		return
	super._ready()

func _apply(_player: Node2D) -> bool:
	return GameManager.add_ultimate_charge(ultimate_amount)
