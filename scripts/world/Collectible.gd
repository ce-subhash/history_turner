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


# Static combo streak tracking
static var last_collect_time: float = 0.0
static var combo_count: int = 0


func _on_body_entered(body: Node3D) -> void:
	if is_collected or not body.is_in_group("player"):
		return

	is_collected = true
	var collect_pos: Vector3 = global_position if is_inside_tree() else position

	# Disable collision immediately
	set_deferred("monitoring", false)
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)

	# Immediately vanish 3D model/sprite from the track
	visible = false

	# Calculate ascending musical pitch and combo streak
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - last_collect_time < 1.6:
		combo_count += 1
	else:
		combo_count = 1
	last_collect_time = now

	var pitch: float = 1.0 + minf((combo_count - 1) * 0.08, 0.6)

	# Trigger streak bonus notification at milestone combos
	if combo_count >= 5 and combo_count % 5 == 0:
		if GameManager:
			GameManager.decision_notification.emit("🔥 %dx TOKEN STREAK! (+Bonus)" % combo_count)
		if body.has_method("trigger_combo_popup"):
			body.trigger_combo_popup(combo_count)

	# Apply political balance bonus and audio
	if type == CollectibleType.PEOPLE_FIST:
		GameManager.add_people_power(5.0)
		if is_inside_tree() and has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx_collect_fist(pitch)
	else:
		GameManager.add_govt_power(5.0)
		if is_inside_tree() and has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx_collect_crown(pitch)

	# Emit signal for sleek 2D flying particle to the top score counter
	if GameManager:
		GameManager.collectible_picked_up.emit(type, collect_pos)

	queue_free()

