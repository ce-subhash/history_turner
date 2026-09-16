## MainMenu.gd
## Mobile Portrait Main Menu screen for "Timetracks: Rulers & Rebels".
## Provides entry to Start Running, Choose Ruler, and Exit.
extends Control

@onready var start_run_button: Button = $MainMargin/VBox/Buttons/StartRunButton
@onready var choose_ruler_button: Button = $MainMargin/VBox/Buttons/SubRow/ChooseRulerButton
@onready var quit_button: Button = $MainMargin/VBox/Buttons/SubRow/QuitButton

@onready var active_ruler_label: Label = $MainMargin/VBox/ShowcasePanel/Margin/Content/ActiveRulerLabel
@onready var era_label: Label = $MainMargin/VBox/ShowcasePanel/Margin/Content/EraLabel
@onready var ability_label: Label = $MainMargin/VBox/ShowcasePanel/Margin/Content/AbilityLabel
@onready var passive_label: Label = $MainMargin/VBox/ShowcasePanel/Margin/Content/PassiveLabel
@onready var relics_label: Label = $MainMargin/VBox/ShowcasePanel/Margin/Content/RelicsLabel

var _pulse_tween: Tween


func _ready() -> void:
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	start_run_button.pressed.connect(_on_start_run_pressed)
	choose_ruler_button.pressed.connect(_on_choose_ruler_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	for btn in [start_run_button, choose_ruler_button, quit_button]:
		btn.mouse_entered.connect(_on_button_hovered)

	_update_loadout_preview()
	_start_pulse_animation()


func _start_pulse_animation() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(start_run_button, "scale", Vector2(1.03, 1.03), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(start_run_button, "scale", Vector2(0.98, 0.98), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_button_hovered() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_lane_switch(0)


func _update_loadout_preview() -> void:
	var cm = get_node_or_null("/root/CharacterManager")
	if cm and cm.active_character:
		var char_res = cm.active_character
		active_ruler_label.text = char_res.get("character_name")
		era_label.text = "🏛️ %s" % char_res.get("era_name")
		ability_label.text = "Active: %s" % char_res.get("active_ability_name")

		var perk_desc = "Standard Leadership"
		match char_res.get("passive_perk_type"):
			"pax_romana":
				perk_desc = "Pax Romana: -15% Govt Decay"
			"zealots_faith":
				perk_desc = "Zealot's Faith: 4s Emergency Shield"
			"railroad_spirit":
				perk_desc = "Railroad Spirit: +20% Relic Magnetism"
		passive_label.text = "Passive: %s" % perk_desc

	var sm = get_node_or_null("/root/SaveManager")
	if sm:
		var equipped: Array = sm.save_data.get("equipped_relics", [])
		var relic_names: Array = []
		for r in equipped:
			if sm.RELIC_CATALOG.has(r):
				relic_names.append(sm.RELIC_CATALOG[r]["icon"] + " " + sm.RELIC_CATALOG[r]["name"])
		if relic_names.size() > 0:
			relics_label.text = " | ".join(relic_names)
		else:
			relics_label.text = "None Equipped"


func _on_start_run_pressed() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_gate()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_choose_ruler_pressed() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_collect_crown()
	get_tree().change_scene_to_file("res://scenes/ui/CharacterSelectScreen.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
