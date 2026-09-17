## HUDController.gd
## Manages the strategic political balance meters, animated progress bars,
## distance tracking, Decision banners, Character Ability HUD,
## Phase 4 Boss Chase countdowns & Fever State banners, and Phase 5 Codex unlocks & Menu routing.
extends Control
class_name HUDController

# --- Top Bar Nodes ---
@onready var people_bar: ProgressBar = get_node_or_null("TopBar/HBoxContainer/PeopleContainer/PeopleBar")
@onready var people_label: Label = get_node_or_null("TopBar/HBoxContainer/PeopleContainer/PeopleValue")
@onready var govt_bar: ProgressBar = get_node_or_null("TopBar/HBoxContainer/GovtContainer/GovtBar")
@onready var govt_label: Label = get_node_or_null("TopBar/HBoxContainer/GovtContainer/GovtValue")
@onready var distance_label: Label = get_node_or_null("TopBar/HBoxContainer/CenterContainer/DistanceLabel")
@onready var speed_label: Label = get_node_or_null("TopBar/HBoxContainer/CenterContainer/SpeedLabel")

# Reference 1 Visual Elements
@onready var balance_needle: Label = get_node_or_null("TopBar/HBoxContainer/CenterContainer/BalanceWidget/NeedleTrack/Needle")
@onready var people_count_label: Label = get_node_or_null("TopBar/HBoxContainer/PeopleBadge/HBox/VBox/PeopleCount")
@onready var govt_count_label: Label = get_node_or_null("TopBar/HBoxContainer/GovtBadge/HBox/VBox/GovtCount")
@onready var pause_button: Button = get_node_or_null("TopBar/HBoxContainer/PauseButton")

# Touch Control Buttons
@onready var touch_left_btn: Button = get_node_or_null("BottomControls/LeftControls/ButtonHBox/TouchLeft")
@onready var touch_right_btn: Button = get_node_or_null("BottomControls/LeftControls/ButtonHBox/TouchRight")
@onready var touch_jump_btn: Button = get_node_or_null("BottomControls/RightControls/TouchJump")

# Banners
@onready var banner_panel: PanelContainer = $NotificationBanner
@onready var banner_label: Label = $NotificationBanner/BannerLabel

# Phase 4 Boss Bar
@onready var boss_bar_panel: PanelContainer = $BossPanel
@onready var boss_title_label: Label = $BossPanel/HBoxContainer/BossTitleLabel
@onready var boss_countdown_label: Label = $BossPanel/HBoxContainer/BossCountdownLabel
@onready var boss_progress_bar: ProgressBar = $BossPanel/HBoxContainer/BossProgressBar

# Phase 4 Fever Banner
@onready var fever_panel: PanelContainer = $FeverBanner
@onready var fever_label: Label = $FeverBanner/FeverLabel

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
@onready var menu_button: Button = $GameOverPanel/VBoxContainer/MenuButton

# State & Tweens
var people_tween: Tween = null
var govt_tween: Tween = null
var banner_tween: Tween = null
var fever_tween: Tween = null
var restart_pulse_tween: Tween = null

var is_boss_chase_active: bool = false
var boss_timer: float = 0.0
var boss_max_duration: float = 30.0
var current_boss_name: String = ""


func _ready() -> void:
	# Ensure HUD panels do not block touch/swipe gestures, while keeping buttons responsive
	_configure_mouse_filters(self)

	if banner_panel:
		banner_panel.visible = false
		banner_panel.modulate.a = 0.0

	if boss_bar_panel:
		boss_bar_panel.visible = false

	if fever_panel:
		fever_panel.visible = false
		fever_panel.modulate.a = 0.0

	if game_over_panel:
		game_over_panel.visible = false

	# Connect to GameManager autoload
	if GameManager:
		GameManager.power_changed.connect(_on_power_changed)
		if GameManager.has_signal("coins_updated"):
			GameManager.coins_updated.connect(_on_coins_updated)
		GameManager.decision_notification.connect(_on_decision_notification)
		GameManager.game_over.connect(_on_game_over)
		GameManager.fever_state_started.connect(_on_fever_started)
		GameManager.fever_state_ended.connect(_on_fever_ended)
		GameManager.era_shifted.connect(_on_era_shifted)
		GameManager.boss_started.connect(_on_boss_started)
		GameManager.boss_ended.connect(_on_boss_ended)
		_update_meter_visuals(GameManager.people_power, GameManager.govt_power)

	# Clean Top Bar: Hide Balance Meter/Needle, show Distance & Coin Badges
	var balance_widget = get_node_or_null("TopBar/HBoxContainer/CenterContainer/BalanceWidget")
	if balance_widget:
		balance_widget.visible = false
	if distance_label:
		distance_label.visible = true

	var people_title = get_node_or_null("TopBar/HBoxContainer/PeopleBadge/HBox/VBox/PeopleTitle")
	if people_title:
		people_title.text = "People Coins"
	var govt_title = get_node_or_null("TopBar/HBoxContainer/GovtBadge/HBox/VBox/GovtTitle")
	if govt_title:
		govt_title.text = "Govt Coins"

	# User Request: Remove special ability button from screen
	if ability_container:
		ability_container.visible = false

	_apply_mobile_safe_area()

	# Connect to CharacterManager autoload
	if CharacterManager:
		CharacterManager.ability_activated.connect(_on_ability_activated)
		CharacterManager.ability_deactivated.connect(_on_ability_deactivated)
		CharacterManager.cooldown_updated.connect(_on_cooldown_updated)
		CharacterManager.character_selected.connect(_on_character_selected)
		if CharacterManager.active_character:
			_update_character_ui(CharacterManager.active_character)

	# Connect to SaveManager autoload
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		sm.card_unlocked.connect(_on_card_unlocked)

	if ability_button:
		ability_button.pressed.connect(_on_ability_button_pressed)

	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)

	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)

	if pause_button:
		pause_button.pressed.connect(_on_pause_button_pressed)

	if touch_left_btn:
		touch_left_btn.pressed.connect(func():
			var p = get_tree().get_first_node_in_group("player")
			if p and p.has_method("switch_lane"):
				p.switch_lane(-1)
		)

	if touch_right_btn:
		touch_right_btn.pressed.connect(func():
			var p = get_tree().get_first_node_in_group("player")
			if p and p.has_method("switch_lane"):
				p.switch_lane(1)
		)

	if touch_jump_btn:
		touch_jump_btn.pressed.connect(func():
			var p = get_tree().get_first_node_in_group("player")
			if p and p.has_method("jump"):
				p.jump()
		)


func _process(delta: float) -> void:
	if not GameManager.is_game_over:
		var dist_int: int = int(GameManager.distance_traveled)
		if distance_label:
			distance_label.text = "%s m" % _format_number_with_commas(dist_int)
		if speed_label:
			speed_label.text = "SPEED: %.1f m/s" % GameManager.current_speed

		# Update active ability duration text if active
		if CharacterManager and CharacterManager.is_ability_active:
			ability_status_label.text = "ACTIVE: %.1fs" % CharacterManager.active_timer
			ability_progress_bar.max_value = CharacterManager.active_character.get("active_duration")
			ability_progress_bar.value = CharacterManager.active_timer

		# Handle Boss Survival Countdown Bar
		if is_boss_chase_active:
			boss_timer -= delta
			if boss_timer > 0.0:
				boss_countdown_label.text = "SURVIVE: %.1fs" % boss_timer
				boss_progress_bar.value = boss_timer
			else:
				boss_countdown_label.text = "VICTORY!"


func _on_pause_button_pressed() -> void:
	var paused = get_tree().paused
	get_tree().paused = !paused
	if pause_button:
		pause_button.text = "▶" if get_tree().paused else "⏸"


func _on_power_changed(people: float, govt: float) -> void:
	if people_bar:
		if people_tween and people_tween.is_running():
			people_tween.kill()
		people_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		people_tween.tween_property(people_bar, "value", people, 0.25)

	if people_label:
		people_label.text = "%d%%" % int(people)

	if govt_bar:
		if govt_tween and govt_tween.is_running():
			govt_tween.kill()
		govt_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		govt_tween.tween_property(govt_bar, "value", govt, 0.25)

	if govt_label:
		govt_label.text = "%d%%" % int(govt)

	_update_meter_visuals(people, govt)


func _on_coins_updated(people_coins: int, govt_coins: int) -> void:
	if people_count_label:
		people_count_label.text = str(people_coins)
	if govt_count_label:
		govt_count_label.text = str(govt_coins)


func _update_meter_visuals(people: float, govt: float) -> void:
	if people_bar:
		people_bar.value = people
	if people_label:
		people_label.text = "%d" % GameManager.people_coins
	if govt_bar:
		govt_bar.value = govt
	if govt_label:
		govt_label.text = "%d" % GameManager.govt_coins

	if balance_needle:
		var total: float = maxf(people + govt, 1.0)
		var ratio: float = clampf(people / total, 0.05, 0.95)
		var target_x: float = ratio * 200.0 + 10.0 - (balance_needle.size.x * 0.5)
		var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(balance_needle, "position:x", target_x, 0.2)

	if people_count_label:
		people_count_label.text = str(GameManager.people_coins)

	if govt_count_label:
		govt_count_label.text = str(GameManager.govt_coins)


# --- Phase 5 Timeline Codex Popup ---

func _on_card_unlocked(card: Dictionary) -> void:
	_show_custom_banner("📜 CODEX DISCOVERY: " + card.get("title", ""))


# --- Phase 4 Events ---

func _on_boss_started(boss_name: String, duration: float) -> void:
	is_boss_chase_active = true
	current_boss_name = boss_name
	boss_timer = duration
	boss_max_duration = duration

	if boss_bar_panel:
		boss_bar_panel.visible = true
		boss_title_label.text = "⚠️ NEMESIS: %s" % boss_name.to_upper()
		boss_countdown_label.text = "SURVIVE: %.1fs" % duration
		boss_progress_bar.max_value = duration
		boss_progress_bar.value = duration


func _on_boss_ended(_victory: bool) -> void:
	is_boss_chase_active = false
	if boss_bar_panel:
		var tween: Tween = create_tween()
		tween.tween_interval(1.5)
		tween.tween_callback(func(): boss_bar_panel.visible = false)


func _on_fever_started(fever_type: String, duration: float) -> void:
	if not fever_panel or not fever_label:
		return

	if fever_type == "peasant_revolution":
		fever_label.text = "⚡ FEVER: PEASANT REVOLUTION! (FLIGHT & SMASH) ⚡"
		fever_label.modulate = Color(1.0, 0.3, 0.3)
	else:
		fever_label.text = "⚡ FEVER: DIVINE RIGHT! (ARTILLERY BARRAGE) ⚡"
		fever_label.modulate = Color(0.3, 0.8, 1.0)

	fever_panel.visible = true

	if fever_tween and fever_tween.is_running():
		fever_tween.kill()

	fever_tween = create_tween()
	fever_panel.modulate.a = 0.0
	fever_tween.tween_property(fever_panel, "modulate:a", 1.0, 0.3)
	fever_tween.tween_interval(duration - 0.6)
	fever_tween.tween_property(fever_panel, "modulate:a", 0.0, 0.3)
	fever_tween.tween_callback(func(): fever_panel.visible = false)


func _on_fever_ended(_fever_type: String) -> void:
	if fever_panel:
		fever_panel.visible = false


func _on_era_shifted(era_name: String) -> void:
	_show_custom_banner("EPOCH MORPHED: %s" % era_name.to_upper())


func _on_decision_notification(text: String) -> void:
	_show_custom_banner(text)


func _show_custom_banner(text: String) -> void:
	if not banner_panel or not banner_label:
		return

	banner_label.text = text
	banner_panel.visible = true

	if banner_tween and banner_tween.is_running():
		banner_tween.kill()

	var top_bar = get_node_or_null("TopBar")
	var target_y: float = (top_bar.position.y + top_bar.size.y + 8.0) if top_bar else 95.0
	var start_y: float = target_y - 15.0

	banner_tween = create_tween()
	banner_panel.modulate.a = 0.0
	banner_panel.position.y = start_y
	banner_tween.tween_property(banner_panel, "modulate:a", 1.0, 0.25)
	banner_tween.parallel().tween_property(banner_panel, "position:y", target_y, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner_tween.tween_interval(3.2)
	banner_tween.tween_property(banner_panel, "modulate:a", 0.0, 0.35)
	banner_tween.parallel().tween_property(banner_panel, "position:y", start_y, 0.35)
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
		ability_status_label.text = "READY [TAP]"
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
		ability_status_label.text = "READY [TAP]"
		ability_status_label.modulate = Color(0.3, 1.0, 0.5)
	if ability_container:
		ability_container.visible = false


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
		var title_lbl = game_over_panel.get_node_or_null("VBoxContainer/TitleLabel")
		if title_lbl:
			title_lbl.text = "YOU FAILED"
		if game_over_reason_label:
			game_over_reason_label.visible = false
			game_over_reason_label.text = ""
		final_score_label.text = "Distance: %s meters\n❤️ %d Coins  |  🏛️ %d Coins" % [
			_format_number_with_commas(int(GameManager.distance_traveled)),
			GameManager.people_coins,
			GameManager.govt_coins
		]

		# Pulse animation on the large primary Restart button
		if restart_button:
			restart_button.pivot_offset = Vector2(206, 42)
			if restart_pulse_tween and restart_pulse_tween.is_running():
				restart_pulse_tween.kill()
			restart_pulse_tween = create_tween().set_loops()
			restart_pulse_tween.tween_property(restart_button, "scale", Vector2(1.03, 1.03), 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			restart_pulse_tween.tween_property(restart_button, "scale", Vector2(0.98, 0.98), 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Phase 5: Check if death condition unlocks tragic timeline card
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		if "Popular Revolt" in reason:
			sm.unlock_card("end_revolt", "The People's Guillotine", "The masses rose up and tore down the imperial palace.")
		elif "Royal Coup" in reason:
			sm.unlock_card("end_coup", "The Praetorian Betrayal", "The palace guard liquidated your command at dawn.")


func _on_restart_pressed() -> void:
	if restart_pulse_tween:
		restart_pulse_tween.kill()
	GameManager.restart_game()


func _on_menu_pressed() -> void:
	if restart_pulse_tween:
		restart_pulse_tween.kill()
	GameManager.reset_state()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_game_over:
		if event is InputEventKey and event.is_pressed() and not event.is_echo():
			if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_R]:
				GameManager.restart_game()
			elif event.keycode == KEY_ESCAPE:
				_on_menu_pressed()
		elif (event is InputEventScreenTouch and event.is_pressed()) or (event is InputEventMouseButton and event.is_pressed()):
			# On game over, user can tap screen or press buttons
			pass
	else:
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


func _configure_mouse_filters(node: Node) -> void:
	if node is BaseButton:
		node.mouse_filter = Control.MOUSE_FILTER_STOP
	elif node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for child in node.get_children():
		_configure_mouse_filters(child)


## Automatically applies safe area insets for notches, punch-holes, and home indicators on mobile screens.
func _apply_mobile_safe_area() -> void:
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	var window_size: Vector2i = DisplayServer.window_get_size()
	var vp_size: Vector2 = get_viewport().get_visible_rect().size

	var scale_y: float = vp_size.y / float(window_size.y) if window_size.y > 0 else 1.0
	var scale_x: float = vp_size.x / float(window_size.x) if window_size.x > 0 else 1.0

	var safe_top: int = int(safe_area.position.y * scale_y) if safe_area.position.y > 0 else 0
	var safe_bottom: int = int((window_size.y - (safe_area.position.y + safe_area.size.y)) * scale_y) if safe_area.size.y > 0 and window_size.y > 0 else 0
	var safe_left: int = int(safe_area.position.x * scale_x) if safe_area.position.x > 0 else 0
	var safe_right: int = int((window_size.x - (safe_area.position.x + safe_area.size.x)) * scale_x) if safe_area.size.x > 0 and window_size.x > 0 else 0

	var top_bar = get_node_or_null("TopBar")
	if top_bar:
		top_bar.add_theme_constant_override("margin_top", max(safe_top + 12, 16))
		top_bar.add_theme_constant_override("margin_left", max(safe_left + 16, 24))
		top_bar.add_theme_constant_override("margin_right", max(safe_right + 16, 24))

	var bottom_controls = get_node_or_null("BottomControls")
	if bottom_controls:
		var bottom_inset = max(safe_bottom, 0)
		bottom_controls.offset_bottom = -bottom_inset
		bottom_controls.offset_top = -bottom_inset - 140.0

	# Responsive banner panel width clamping to fit cleanly on narrow screens
	if banner_panel:
		var max_w = minf(640.0, vp_size.x - 32.0)
		banner_panel.offset_left = -max_w * 0.5
		banner_panel.offset_right = max_w * 0.5

	if not get_tree().root.size_changed.is_connected(_on_screen_resized):
		get_tree().root.size_changed.connect(_on_screen_resized)


func _on_screen_resized() -> void:
	_apply_mobile_safe_area()
