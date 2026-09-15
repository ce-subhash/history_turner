## JumpRamp.gd
## Launches the player upward when they hit or run onto the ramp.
extends Area3D
class_name JumpRamp

@export var launch_velocity: float = 14.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body is CharacterBody3D:
		body.velocity.y = launch_velocity
		# Trigger audio or visual feedback
		if AudioManager:
			AudioManager.play_sfx("ability")
