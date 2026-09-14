## Main.gd
## Manages overall scene coordination, HUD updates (Distance, Speed),
## and Game Over UI overlay with restart handling.
extends Node3D

@onready var distance_label: Label = $HUD/MarginContainer/VBoxContainer/DistanceLabel
@onready var speed_label: Label = $HUD/MarginContainer/VBoxContainer/SpeedLabel
@onready var game_over_panel: Control = $HUD/GameOverPanel
@onready var game_over_reason_label: Label = $HUD/GameOverPanel/VBoxContainer/ReasonLabel
@onready var final_score_label: Label = $HUD/GameOverPanel/VBoxContainer/FinalScoreLabel
@onready var restart_button: Button = $HUD/GameOverPanel/VBoxContainer/RestartButton


func _ready() -> void:
	game_over_panel.visible = false

	# Connect signals from GameManager autoload
	GameManager.game_over.connect(_on_game_over)

	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)


func _process(_delta: float) -> void:
	if not GameManager.is_game_over:
		distance_label.text = "DISTANCE: %d m" % int(GameManager.distance_traveled)
		speed_label.text = "SPEED: %.1f m/s" % GameManager.current_speed


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_game_over:
		# Any restart trigger key (Space, Enter, R) or touch
		if event is InputEventKey and event.is_pressed() and not event.is_echo():
			if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_R]:
				_restart()
		elif (event is InputEventScreenTouch and event.is_pressed()) or (event is InputEventMouseButton and event.is_pressed()):
			_restart()


func _on_game_over(reason: String) -> void:
	game_over_panel.visible = true
	game_over_reason_label.text = reason
	final_score_label.text = "Distance: %d meters" % int(GameManager.distance_traveled)


func _on_restart_pressed() -> void:
	_restart()


func _restart() -> void:
	GameManager.restart_game()
