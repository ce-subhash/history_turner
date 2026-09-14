## HUDController.gd
## Manages the strategic political balance meters (People vs. Government),
## animated progress bar transitions, distance tracking, and historic shift notification banners.
extends Control
class_name HUDController

# --- Node References ---
@onready var people_bar: ProgressBar = $TopBar/HBoxContainer/PeopleContainer/PeopleBar
@onready var people_label: Label = $TopBar/HBoxContainer/PeopleContainer/PeopleValue
@onready var govt_bar: ProgressBar = $TopBar/HBoxContainer/GovtContainer/GovtBar
@onready var govt_label: Label = $TopBar/HBoxContainer/GovtContainer/GovtValue
@onready var distance_label: Label = $TopBar/HBoxContainer/CenterContainer/DistanceLabel
@onready var speed_label: Label = $TopBar/HBoxContainer/CenterContainer/SpeedLabel

@onready var banner_panel: PanelContainer = $NotificationBanner
@onready var banner_label: Label = $NotificationBanner/BannerLabel

@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var game_over_reason_label: Label = $GameOverPanel/VBoxContainer/ReasonLabel
@onready var final_score_label: Label = $GameOverPanel/VBoxContainer/FinalScoreLabel
@onready var restart_button: Button = $GameOverPanel/VBoxContainer/RestartButton

# --- Tweens ---
var people_tween: Tween = null
var govt_tween: Tween = null
var banner_tween: Tween = null


func _ready() -> void:
	if banner_panel:
		banner_panel.visible = false
		banner_panel.modulate.a = 0.0

	if game_over_panel:
		game_over_panel.visible = false

	# Connect to GameManager autoload
	if GameManager:
		GameManager.power_changed.connect(_on_power_changed)
		GameManager.decision_notification.connect(_on_decision_notification)
		GameManager.game_over.connect(_on_game_over)

		# Initial values
		_update_meter_visuals(GameManager.people_power, GameManager.govt_power)

	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)


func _process(_delta: float) -> void:
	if not GameManager.is_game_over:
		# Format distance (e.g. "1,250 m")
		var dist_int: int = int(GameManager.distance_traveled)
		distance_label.text = "%s m" % _format_number_with_commas(dist_int)
		speed_label.text = "SPEED: %.1f m/s" % GameManager.current_speed


## Smoothly animates meter changes using Tweens.
func _on_power_changed(people: float, govt: float) -> void:
	# 1. Animate People Meter (Red)
	if people_bar:
		if people_tween and people_tween.is_running():
			people_tween.kill()
		people_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		people_tween.tween_property(people_bar, "value", people, 0.25)

	if people_label:
		people_label.text = "%d%%" % int(people)
		# Danger color pulsing if near collapse
		if people <= 20.0 or people >= 80.0:
			people_label.modulate = Color(1.0, 0.2, 0.2)
		else:
			people_label.modulate = Color.WHITE

	# 2. Animate Govt Meter (Blue)
	if govt_bar:
		if govt_tween and govt_tween.is_running():
			govt_tween.kill()
		govt_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		govt_tween.tween_property(govt_bar, "value", govt, 0.25)

	if govt_label:
		govt_label.text = "%d%%" % int(govt)
		# Danger color pulsing if near coup
		if govt <= 20.0 or govt >= 80.0:
			govt_label.modulate = Color(1.0, 0.2, 0.2)
		else:
			govt_label.modulate = Color.WHITE


## Direct setter without tweens for instant reset.
func _update_meter_visuals(people: float, govt: float) -> void:
	if people_bar:
		people_bar.value = people
	if people_label:
		people_label.text = "%d%%" % int(people)
	if govt_bar:
		govt_bar.value = govt
	if govt_label:
		govt_label.text = "%d%%" % int(govt)


## Displays a stylish 1-line historic shift banner with fade-in and fade-out tweens.
func _on_decision_notification(text: String) -> void:
	if not banner_panel or not banner_label:
		return

	banner_label.text = text
	banner_panel.visible = true

	if banner_tween and banner_tween.is_running():
		banner_tween.kill()

	banner_tween = create_tween()
	# Fade in and slide slightly downward
	banner_panel.modulate.a = 0.0
	banner_panel.position.y = 80.0
	banner_tween.tween_property(banner_panel, "modulate:a", 1.0, 0.25)
	banner_tween.parallel().tween_property(banner_panel, "position:y", 95.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Hold readable duration
	banner_tween.tween_interval(3.2)

	# Fade out
	banner_tween.tween_property(banner_panel, "modulate:a", 0.0, 0.35)
	banner_tween.parallel().tween_property(banner_panel, "position:y", 80.0, 0.35)
	banner_tween.tween_callback(func(): banner_panel.visible = false)


## Displays game over overlay.
func _on_game_over(reason: String) -> void:
	if game_over_panel:
		game_over_panel.visible = true
		game_over_reason_label.text = reason
		final_score_label.text = "Distance: %s meters" % _format_number_with_commas(int(GameManager.distance_traveled))


func _on_restart_pressed() -> void:
	GameManager.restart_game()


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_game_over:
		if event is InputEventKey and event.is_pressed() and not event.is_echo():
			if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_R]:
				GameManager.restart_game()
		elif (event is InputEventScreenTouch and event.is_pressed()) or (event is InputEventMouseButton and event.is_pressed()):
			GameManager.restart_game()


## Helper: Adds thousand comma separators to integers.
func _format_number_with_commas(n: int) -> String:
	var s: String = str(n)
	var result: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		result = s[i] + result
		count += 1
		if count % 3 == 0 and i > 0:
			result = "," + result
	return result
