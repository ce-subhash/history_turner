## GameManager.gd
## Autoload Singleton managing global gameplay state, speed progression,
## distance tracking, and the Political Balance Engine (People vs. Government).
extends Node

# --- Signals ---
## Emitted when the runner encounters a terminal obstacle or fails a run condition.
signal game_over(reason: String)

## Emitted when the run is reset or restarted.
signal game_restarted()

## Emitted whenever either political meter changes (for animated HUD updates).
signal power_changed(people: float, govt: float)

## Emitted when a historic decision is resolved at a Decision Gate.
signal decision_notification(text: String)

# --- State Variables ---
## Current movement speed of the runner along the track (-Z axis).
@export var current_speed: float = 12.0

## Total distance covered in meters / game units during the active run.
var distance_traveled: float = 0.0

## Flags whether the current session has ended due to collision or player failure.
var is_game_over: bool = false

# --- Progression Settings ---
const INITIAL_SPEED: float = 12.0
const MAX_SPEED: float = 28.0
const SPEED_ACCELERATION: float = 0.15

# --- Political Balance Engine State (Phase 2) ---
## People Favor: Range 0.0 - 100.0. Balanced initially at 50.0.
var people_power: float = 50.0

## Government Favor: Range 0.0 - 100.0. Balanced initially at 50.0.
var govt_power: float = 50.0

## Decay rate per second for both meters to force active item collection and strategic steering.
const DECAY_RATE: float = 0.5


func _ready() -> void:
	reset_state()


func _process(delta: float) -> void:
	if is_game_over:
		return

	# Accumulate distance traveled based on current velocity
	distance_traveled += current_speed * delta

	# Gradual speed progression over time up to MAX_SPEED
	if current_speed < MAX_SPEED:
		current_speed = minf(current_speed + SPEED_ACCELERATION * delta, MAX_SPEED)

	# Apply political balance meter decay (0.5/sec)
	# Delta is scaled by Engine.time_scale automatically in _process
	_apply_meter_decay(delta)


## Applies constant baseline decay to both political factions.
func _apply_meter_decay(delta: float) -> void:
	var decay: float = DECAY_RATE * delta
	people_power -= decay
	govt_power -= decay

	power_changed.emit(people_power, govt_power)
	_evaluate_political_stability()


## Checks failure thresholds for popular revolt or royal coup.
func _evaluate_political_stability() -> void:
	if is_game_over:
		return

	# People Power failure conditions
	if people_power <= 0.0 or people_power >= 100.0:
		trigger_game_over("Overthrown by Popular Revolt!")
		return

	# Government Power failure conditions
	if govt_power <= 0.0 or govt_power >= 100.0:
		trigger_game_over("Deposed by Royal Coup!")
		return


## Helper: Adds or subtracts People Power and checks stability.
func add_people_power(val: float) -> void:
	if is_game_over:
		return
	people_power = clampf(people_power + val, 0.0, 100.0)
	power_changed.emit(people_power, govt_power)
	_evaluate_political_stability()


## Helper: Adds or subtracts Government Power and checks stability.
func add_govt_power(val: float) -> void:
	if is_game_over:
		return
	govt_power = clampf(govt_power + val, 0.0, 100.0)
	power_changed.emit(people_power, govt_power)
	_evaluate_political_stability()


## Resolves a Decision Gate option, applying meter shifts and triggering notification.
func apply_decision(people_delta: float, govt_delta: float, notification: String) -> void:
	if is_game_over:
		return

	people_power = clampf(people_power + people_delta, 0.0, 100.0)
	govt_power = clampf(govt_power + govt_delta, 0.0, 100.0)
	power_changed.emit(people_power, govt_power)
	decision_notification.emit(notification)
	_evaluate_political_stability()


## Triggers game over state, stops forward progression, resets time scale, and notifies listeners.
func trigger_game_over(reason: String = "Collision with obstacle") -> void:
	if is_game_over:
		return

	is_game_over = true
	current_speed = 0.0
	Engine.time_scale = 1.0 # Ensure bullet-time is cleared
	print("[GameManager] Game Over! Reason: %s | Distance: %.1fm" % [reason, distance_traveled])
	game_over.emit(reason)


## Resets all internal run metrics and political meters back to baseline.
func reset_state() -> void:
	is_game_over = false
	current_speed = INITIAL_SPEED
	distance_traveled = 0.0
	people_power = 50.0
	govt_power = 50.0
	Engine.time_scale = 1.0
	power_changed.emit(people_power, govt_power)


## Reloads the current scene and resets game metrics for a clean restart.
func restart_game() -> void:
	reset_state()
	game_restarted.emit()
	get_tree().reload_current_scene()
