## MainMenu.gd
## Main Menu screen for "Timetracks: Rulers & Rebels".
## Provides entry to Character Selection, Direct Run, and Timeline Codex.
## Includes live ruler showcase card and audio integration.
extends Control

@onready var quick_run_button: Button = $MainLayout/LeftMenuColumn/MenuPanel/Margin/Buttons/QuickRunButton
@onready var start_button: Button = $MainLayout/LeftMenuColumn/MenuPanel/Margin/Buttons/StartButton
@onready var codex_button: Button = $MainLayout/LeftMenuColumn/MenuPanel/Margin/Buttons/CodexButton
@onready var quit_button: Button = $MainLayout/LeftMenuColumn/MenuPanel/Margin/Buttons/QuitButton

@onready var active_ruler_label: Label = $MainLayout/RightShowcaseColumn/ShowcasePanel/Margin/Content/ActiveRulerLabel
@onready var era_label: Label = $MainLayout/RightShowcaseColumn/ShowcasePanel/Margin/Content/EraLabel
@onready var ability_label: Label = $MainLayout/RightShowcaseColumn/ShowcasePanel/Margin/Content/AbilityLabel
@onready var passive_label: Label = $MainLayout/RightShowcaseColumn/ShowcasePanel/Margin/Content/PassiveLabel
@onready var relics_label: Label = $MainLayout/RightShowcaseColumn/ShowcasePanel/Margin/Content/RelicsLabel


func _ready() -> void:
	quick_run_button.pressed.connect(_on_quick_run_pressed)
	start_button.pressed.connect(_on_start_pressed)
	codex_button.pressed.connect(_on_codex_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Audio feedback on button hovers
	for btn in [quick_run_button, start_button, codex_button, quit_button]:
		btn.mouse_entered.connect(_on_button_hovered)

	_update_loadout_preview()


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

		var perk_desc = "Standard"
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
			relics_label.text = "None Equipped (Visit Codex)"


func _on_quick_run_pressed() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_gate()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_start_pressed() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_collect_crown()
	get_tree().change_scene_to_file("res://scenes/ui/CharacterSelectScreen.tscn")


func _on_codex_pressed() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_collect_crown()
	get_tree().change_scene_to_file("res://scenes/ui/TimelineCodexScreen.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
