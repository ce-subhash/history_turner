## MainMenu.gd
## Main Menu screen for "Timetracks: Rulers & Rebels".
## Provides entry to Character Selection, Direct Run, and Timeline Codex.
extends Control

@onready var start_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/StartButton
@onready var codex_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/CodexButton
@onready var quick_run_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/QuickRunButton
@onready var quit_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/QuitButton
@onready var active_ruler_label: Label = $TopContainer/ActiveRulerLabel
@onready var relics_label: Label = $TopContainer/RelicsLabel


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	codex_button.pressed.connect(_on_codex_pressed)
	quick_run_button.pressed.connect(_on_quick_run_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	_update_loadout_preview()


func _update_loadout_preview() -> void:
	if CharacterManager and CharacterManager.active_character:
		active_ruler_label.text = "Ruler: %s" % CharacterManager.active_character.get("character_name")

	if SaveManager:
		var equipped: Array = SaveManager.save_data.get("equipped_relics", [])
		var relic_names: Array = []
		for r in equipped:
			if SaveManager.RELIC_CATALOG.has(r):
				relic_names.append(SaveManager.RELIC_CATALOG[r]["icon"] + " " + SaveManager.RELIC_CATALOG[r]["name"])
		relic_label_text(relic_names)


func relic_label_text(relic_names: Array) -> void:
	if relics_label:
		if relic_names.size() > 0:
			relic_label_text_set("Relics: " + " | ".join(relic_names))
		else:
			relic_label_text_set("Relics: None Equipped")


func relic_label_text_set(text: String) -> void:
	relics_label.text = text


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/CharacterSelectScreen.tscn")


func _on_codex_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/TimelineCodexScreen.tscn")


func _on_quick_run_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
