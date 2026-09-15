## MovingObstacle.gd
## Attached to dynamic moving obstacles like the Bull Cart or patrolling Police Dog.
extends Node3D
class_name MovingObstacle

@export var speed: float = 2.8 # m/s
@export var move_direction: Vector3 = Vector3(0, 0, 1.0) # Moves towards camera / oncoming or forward
@export var bob_amplitude: float = 0.04
@export var bob_frequency: float = 4.0

var _time: float = 0.0
var _initial_y: float = 0.0

func _ready() -> void:
	_initial_y = position.y

func _process(delta: float) -> void:
	_time += delta
	# Advance along lane
	position += move_direction * speed * delta
	# Subtle natural wobble/bob for cart or walking animal
	position.y = _initial_y + sin(_time * bob_frequency) * bob_amplitude
