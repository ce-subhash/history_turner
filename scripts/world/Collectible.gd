## Collectible.gd
## Floating 3D pickup token:
## - People Fist: Red Mesh Sphere (+5 People Power)
## - Govt Crown: Blue Mesh Cube (+5 Govt Power)
## Performs continuous bobbing and spin animations, and applies power on player overlap.
extends Area3D
class_name Collectible

enum CollectibleType {
	PEOPLE_FIST, # Red Sphere (+5 People Power)
	GOVT_CROWN   # Blue Cube (+5 Govt Power)
}

@export var type: CollectibleType = CollectibleType.PEOPLE_FIST

var is_collected: bool = false
var base_y: float = 1.0
var time_accum: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	base_y = position.y


func _process(delta: float) -> void:
	if is_collected:
		return

	# Idle Spin and vertical floating bob
	time_accum += delta * 3.0
	rotate_y(delta * 2.5)
	position.y = base_y + sin(time_accum) * 0.15


func _on_body_entered(body: Node3D) -> void:
	if is_collected or not body.is_in_group("player"):
		return

	is_collected = true

	# Apply political balance bonus
	if type == CollectibleType.PEOPLE_FIST:
		GameManager.add_people_power(5.0)
	else:
		GameManager.add_govt_power(5.0)

	# Smooth pickup pop animation before queue_free
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector3(1.6, 1.6, 1.6), 0.15)
	tween.parallel().tween_property(self, "position:y", position.y + 0.8, 0.15)
	tween.tween_callback(queue_free)
