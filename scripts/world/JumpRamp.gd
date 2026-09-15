## JumpRamp.gd
## Interactive speed launch ramp.
## Launches the player skyward and grants a momentary speed boost.
extends Area3D
class_name JumpRamp

@export var launch_velocity: float = 13.5
@export var speed_boost: float = 6.5
@export var boost_duration: float = 2.5

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body is CharacterBody3D:
		if body.has_method("apply_ramp_boost"):
			body.apply_ramp_boost(launch_velocity, speed_boost, boost_duration)
		else:
			body.velocity.y = launch_velocity
