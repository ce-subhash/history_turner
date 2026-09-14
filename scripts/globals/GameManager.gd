## GameManager.gd
## Autoload Singleton managing global gameplay state, speed progression,
## distance tracking, and game-over state.
extends Node

# --- Signals ---
## Emitted when the runner encounters a terminal obstacle or fails a run condition.
signal game_over(reason: String)

## Emitted when the run is reset or restarted.
signal game_restarted()

# --- State Variables ---
## Current movement speed of the runner along the track (-Z axis).
@export var current_speed: float = 12.0

## Total distance covered in meters / game units during the active run.
var distance_traveled: float = 0.0

## Flags whether the current session has ended due to collision or player failure.
var is_game_over: bool = false

# --- Progression Settings ---
## Initial base speed when run starts.
const INITIAL_SPEED: float = 12.0

## Maximum speed cap to keep controls responsive yet challenging.
const MAX_SPEED: float = 28.0

## Speed increase rate per second to introduce strategic difficulty progression.
const SPEED_ACCELERATION: float = 0.15


func _ready() -> void:
	# Initialize run values
	reset_state()


func _process(delta: float) -> void:
	if is_game_over:
		return

	# Accumulate distance traveled based on current velocity
	distance_traveled += current_speed * delta

	# Gradual speed progression over time up to MAX_SPEED
	if current_speed < MAX_SPEED:
		current_speed = minf(current_speed + SPEED_ACCELERATION * delta, MAX_SPEED)


## Triggers game over state, stops forward progression, and notifies listeners.
func trigger_game_over(reason: String = "Collision with obstacle") -> void:
	if is_game_over:
		return

	is_game_over = true
	current_speed = 0.0
	print("[GameManager] Game Over! Reason: %s | Distance: %.1fm" % [reason, distance_traveled])
	game_over.emit(reason)


## Resets all internal run metrics back to baseline.
func reset_state() -> void:
	is_game_over = false
	current_speed = INITIAL_SPEED
	distance_traveled = 0.0


## Reloads the current scene and resets game metrics for a clean restart.
func restart_game() -> void:
	reset_state()
	game_restarted.emit()
	get_tree().reload_current_scene()
