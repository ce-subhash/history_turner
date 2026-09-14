## HUDController.gd
## Manages the strategic political balance meters (People vs. Government),
## animated progress bar transitions, distance tracking, decision banners,
## and Character Active Ability button with cooldown indicators.
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

# Ability HUD Widget
@onready var ability_container: Control = $AbilityWidget
@onready var ability_button: Button = $AbilityWidget/VBoxContainer/AbilityButton
@onready var ability_name_label: Label = $AbilityWidget/VBoxContainer/AbilityNameLabel
@onready var ability_status_label: Label = $AbilityWidget/VBoxContainer/AbilityStatusLabel
@onready var ability_progress_bar: ProgressBar = $AbilityWidget/VBoxContainer/AbilityProgressBar
@onready var ruler_name_label: Label = $AbilityWidget/VBoxContainer/RulerNameLabel

# Game Over & Restart
@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var game_over_reason_label: Label = $GameOverPanel/VBoxContainer/ReasonLabel
@onready var final_score_label: Label = $GameOverPanel/VBoxContainer/FinalScoreLabel
@onready var restart_button: Button = $GameOverPanel/VBoxContainer/RestartButton

# Tweens
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
		_update_meter_visuals(GameManager.people_power, GameManager.govt_power)

	# Connect to CharacterManager autoload
	if CharacterManager:
		CharacterManager.ability_activated.connect(_on_ability_activated)
		CharacterManager.ability_deactivated.connect(_on_ability_deactivated)
		CharacterManager.cooldown_updated.connect(_on_cooldown_updated)
		CharacterManager.character_selected.connect(_on_character_selected)

		if CharacterManager.active_character:
			_update_character_ui(CharacterManager.active_character)

	if ability_button:
		ability_button.pressed.connect(_on_ability_button_pressed)

	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)


func _process(_delta: float) -> void:
	if not GameManager.is_game_over:
		var dist_int: int = int(GameManager.distance_traveled)
		distance_label.text = "%s m" % _format_number_with_commas(dist_int)
		speed_label.text = "SPEED: %.1f m/s" % GameManager.current_speed

		# Update active ability duration text if active
		if CharacterManager and CharacterManager.is_ability_active:
			ability_status_label.text = "ACTIVE: %.1fs" % CharacterManager.active_timer
			ability_progress_bar.max_value = CharacterManager.active_character.active_duration
			ability_progress_bar.value = CharacterManager.active_timer


func _on_power_changed(people: float, govt: float) -> void:
	# 1. Animate People Meter (Red)
	if people_bar:
		if people_tween and people_tween.is_running():
			people_tween.kill()
		people_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		people_tween.tween_property(people_bar, "value", people, 0.25)

	if people_label:
		people_label.text = "%d%%" % int(people)
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
		if govt <= 20.0 or govt >= 80.0:
			govt_label.modulate = Color(1.0, 0.2, 0.2)
		else:
			govt_label.modulate = Color.WHITE


func _update_meter_visuals(people: float, govt: float) -> void:
	if people_bar:
		people_bar.value = people
	if people_label:
		people_label.text = "%d%%" % int(people)
	if govt_bar:
		govt_bar.value = govt
	if govt_label:
		govt_label.text = "%d%%" % int(govt)


func _on_decision_notification(text: String) -> void:
	if not banner_panel or not banner_label:
		return

	banner_label.text = text
	banner_panel.visible = true

	if banner_tween and banner_tween.is_running():
		banner_tween.kill()

	banner_tween = create_tween()
	banner_panel.modulate.a = 0.0
	banner_panel.position.y = 80.0
	banner_tween.tween_property(banner_panel, "modulate:a", 1.0, 0.25)
	banner_tween.parallel().tween_property(banner_panel, "position:y", 95.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner_tween.tween_interval(3.2)
	banner_tween.tween_property(banner_panel, "modulate:a", 0.0, 0.35)
	banner_tween.parallel().tween_property(banner_panel, "position:y", 80.0, 0.35)
	banner_tween.tween_callback(func(): banner_panel.visible = false)


# --- Ability & Roster UI Handlers ---

func _on_ability_button_pressed() -> void:
	if CharacterManager:
		CharacterManager.trigger_active_ability()


func _on_ability_activated(_character: Resource, duration: float) -> void:
	ability_status_label.text = "ACTIVE: %.1fs" % duration
	ability_status_label.modulate = Color(1.0, 0.9, 0.2)
	ability_progress_bar.max_value = duration
	ability_progress_bar.value = duration
	_pulse_ability_widget(Color(1.0, 0.85, 0.2))


func _on_ability_deactivated(character: Resource) -> void:
	ability_status_label.text = "COOLDOWN"
	ability_status_label.modulate = Color(0.7, 0.7, 0.7)
	var cooldown_val: float = character.get("active_cooldown") if character else 20.0
	ability_progress_bar.max_value = cooldown_val
	ability_progress_bar.value = cooldown_val


func _on_cooldown_updated(time_remaining: float, max_cooldown: float) -> void:
	if time_remaining <= 0.0:
		ability_status_label.text = "READY [E]"
		ability_status_label.modulate = Color(0.3, 1.0, 0.5)
		ability_progress_bar.value = 0.0
	else:
		ability_status_label.text = "%.1fs" % time_remaining
		ability_status_label.modulate = Color(0.8, 0.8, 0.8)
		ability_progress_bar.max_value = max_cooldown
		ability_progress_bar.value = time_remaining


func _on_character_selected(character: Resource) -> void:
	_update_character_ui(character)


func _update_character_ui(character: Resource) -> void:
	if not character:
		return
	if ruler_name_label:
		ruler_name_label.text = str(character.get("character_name")).to_upper()
	if ability_name_label:
		ability_name_label.text = str(character.get("active_ability_name"))
	if ability_status_label:
		ability_status_label.text = "READY [E]"
		ability_status_label.modulate = Color(0.3, 1.0, 0.5)


func _pulse_ability_widget(color: Color) -> void:
	if not ability_container:
		return
	var tween: Tween = create_tween()
	ability_container.modulate = color
	tween.tween_property(ability_container, "modulate", Color.WHITE, 0.3)


# --- Game Over & Reset Handlers ---

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
	else:
		# Quick Ruler Switcher for Phase 3 Testing (Keys 1, 2, 3)
		if event is InputEventKey and event.is_pressed() and not event.is_echo():
			match event.keycode:
				KEY_1:
					if CharacterManager:
						CharacterManager.select_character_by_name("caesar")
				KEY_2:
					if CharacterManager:
						CharacterManager.select_character_by_name("joan")
				KEY_3:
					if CharacterManager:
						CharacterManager.select_character_by_name("harriet")


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
