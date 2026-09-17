## GameManager.gd
## Autoload Singleton managing global gameplay state, speed progression,
## distance tracking, the Political Balance Engine, and Phase 4 Fever States.
extends Node

# --- Signals ---
signal game_over(reason: String)
signal game_restarted()
signal power_changed(people: float, govt: float)
signal decision_notification(text: String)
signal coins_updated(people_coins: int, govt_coins: int)

# Phase 4 Signals
signal fever_state_started(fever_type: String, duration: float)
signal fever_state_ended(fever_type: String)
signal era_shifted(era_name: String)
signal boss_started(boss_name: String, duration: float)
signal boss_ended(victory: bool)

# --- State Variables ---
@export var current_speed: float = 12.0
var distance_traveled: float = 0.0
var is_game_over: bool = false

# Progression Settings
const INITIAL_SPEED: float = 12.0
const MAX_SPEED: float = 28.0
const SPEED_ACCELERATION: float = 0.15

# Collectible Coin Counters & Energy State
var people_coins: int = 0
var govt_coins: int = 0
var people_power: float = 0.0
var govt_power: float = 0.0
const DECAY_RATE: float = 0.0
var govt_decay_modifier: float = 1.0

# --- Phase 4: High-Risk Fever States ---
const FEVER_THRESHOLD: float = 85.0
const FEVER_RESET_THRESHOLD: float = 75.0
const FEVER_DURATION: float = 2.5

var is_fever_active: bool = false
var current_fever_type: String = "" # "peasant_revolution" or "divine_right"
var fever_timer: float = 0.0
var can_trigger_peasant_fever: bool = true
var can_trigger_divine_fever: bool = true


func _ready() -> void:
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	reset_state()


func _process(delta: float) -> void:
	if is_game_over:
		return

	distance_traveled += current_speed * delta

	if current_speed < MAX_SPEED:
		current_speed = minf(current_speed + SPEED_ACCELERATION * delta, MAX_SPEED)

	# Handle active Fever State countdown
	if is_fever_active:
		fever_timer -= delta
		if fever_timer <= 0.0:
			_end_fever_state()

	_apply_meter_decay(delta)
	_evaluate_fever_thresholds()


func _apply_meter_decay(_delta: float) -> void:
	# Political collapse disabled: coins and abilities accumulate without stress timer
	pass


func _evaluate_political_stability() -> void:
	# Character NEVER dies from meter collapse! Only obstacle crashes and void falls end the run.
	pass


## Evaluates 90% threshold for Peasant Revolution & Divine Right fever states.
func _evaluate_fever_thresholds() -> void:
	if is_fever_active or is_game_over:
		return

	# Reset trigger eligibility if meter fell below reset threshold
	if people_power < FEVER_RESET_THRESHOLD:
		can_trigger_peasant_fever = true
	if govt_power < FEVER_RESET_THRESHOLD:
		can_trigger_divine_fever = true

	# 1. Peasant Revolution: People Power >= 90%
	if people_power >= FEVER_THRESHOLD and can_trigger_peasant_fever:
		_start_fever_state("peasant_revolution")

	# 2. Divine Right: Govt Power >= 90%
	elif govt_power >= FEVER_THRESHOLD and can_trigger_divine_fever:
		_start_fever_state("divine_right")


func _start_fever_state(fever_type: String) -> void:
	is_fever_active = true
	current_fever_type = fever_type
	fever_timer = FEVER_DURATION

	if fever_type == "peasant_revolution":
		can_trigger_peasant_fever = false
		print("[GameManager] FEVER ACTIVATED: PEASANT REVOLUTION! (8s Flight & Smashing)")
	else:
		can_trigger_divine_fever = false
		print("[GameManager] FEVER ACTIVATED: DIVINE RIGHT! (8s Royal Artillery Barrage)")

	fever_state_started.emit(fever_type, FEVER_DURATION)


func _end_fever_state() -> void:
	if not is_fever_active:
		return
	var ended_type: String = current_fever_type
	is_fever_active = false
	current_fever_type = ""
	fever_timer = 0.0
	if ended_type == "peasant_revolution":
		people_power = 70.0
	elif ended_type == "divine_right":
		govt_power = 70.0
	power_changed.emit(people_power, govt_power)
	print("[GameManager] Fever state ended: %s" % ended_type)
	fever_state_ended.emit(ended_type)


func add_people_power(val: float) -> void:
	if is_game_over:
		return
	people_coins += 1
	var final_val: float = val * (2.0 if (is_fever_active and current_fever_type == "peasant_revolution") else 1.0)
	people_power = clampf(people_power + final_val, 0.0, 100.0)
	power_changed.emit(people_power, govt_power)
	coins_updated.emit(people_coins, govt_coins)
	_evaluate_fever_thresholds()


func add_govt_power(val: float) -> void:
	if is_game_over:
		return
	govt_coins += 1
	var final_val: float = val * (2.0 if (is_fever_active and current_fever_type == "divine_right") else 1.0)
	govt_power = clampf(govt_power + final_val, 0.0, 100.0)
	power_changed.emit(people_power, govt_power)
	coins_updated.emit(people_coins, govt_coins)
	_evaluate_fever_thresholds()


func apply_decision(people_delta: float, govt_delta: float, notification: String) -> void:
	if is_game_over:
		return

	people_power = clampf(people_power + people_delta, 0.0, 100.0)
	govt_power = clampf(govt_power + govt_delta, 0.0, 100.0)
	if people_delta > 0:
		people_coins += int(people_delta / 5.0)
	if govt_delta > 0:
		govt_coins += int(govt_delta / 5.0)
	power_changed.emit(people_power, govt_power)
	coins_updated.emit(people_coins, govt_coins)
	decision_notification.emit(notification)
	_evaluate_fever_thresholds()


func trigger_game_over(reason: String = "Collision with obstacle") -> void:
	if is_game_over:
		return

	is_game_over = true
	current_speed = 0.0
	is_fever_active = false
	Engine.time_scale = 1.0
	print("[GameManager] Game Over! Reason: %s | Distance: %.1fm" % [reason, distance_traveled])
	game_over.emit(reason)


func reset_state() -> void:
	is_game_over = false
	current_speed = INITIAL_SPEED
	distance_traveled = 0.0
	people_coins = 0
	govt_coins = 0
	people_power = 0.0
	govt_power = 0.0
	is_fever_active = false
	current_fever_type = ""
	fever_timer = 0.0
	can_trigger_peasant_fever = true
	can_trigger_divine_fever = true
	Engine.time_scale = 1.0
	power_changed.emit(people_power, govt_power)
	coins_updated.emit(people_coins, govt_coins)


func restart_game() -> void:
	reset_state()
	game_restarted.emit()
	get_tree().reload_current_scene()
