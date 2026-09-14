## CharacterSelectScreen.gd
## Manages character roster selection, milestone unlocks,
## and 2-slot Equippable Relic loadouts.
extends Control

# Starter Characters
const CAESAR_RES = preload("res://resources/characters/caesar.tres")
const JOAN_RES = preload("res://resources/characters/joan.tres")
const HARRIET_RES = preload("res://resources/characters/harriet.tres")

# UI Node References
@onready var ruler_name_label: Label = $MainLayout/DetailsPanel/Margin/VBox/RulerName
@onready var era_label: Label = $MainLayout/DetailsPanel/Margin/VBox/EraLabel
@onready var ability_label: Label = $MainLayout/DetailsPanel/Margin/VBox/AbilityLabel
@onready var passive_label: Label = $MainLayout/DetailsPanel/Margin/VBox/PassiveLabel
@onready var deploy_button: Button = $MainLayout/DetailsPanel/Margin/VBox/DeployButton
@onready var back_button: Button = $Header/HBox/BackButton

# Relic Checkboxes
@onready var asp_check: CheckBox = $MainLayout/RelicsPanel/Margin/VBox/RelicList/AspCheck
@onready var telescope_check: CheckBox = $MainLayout/RelicsPanel/Margin/VBox/RelicList/TelescopeCheck
@onready var watch_check: CheckBox = $MainLayout/RelicsPanel/Margin/VBox/RelicList/WatchCheck
@onready var relic_limit_label: Label = $MainLayout/RelicsPanel/Margin/VBox/RelicLimitLabel

# Character Buttons
@onready var caesar_btn: Button = $MainLayout/RosterPanel/Margin/VBox/Grid/CaesarBtn
@onready var joan_btn: Button = $MainLayout/RosterPanel/Margin/VBox/Grid/JoanBtn
@onready var harriet_btn: Button = $MainLayout/RosterPanel/Margin/VBox/Grid/HarrietBtn
@onready var napoleon_btn: Button = $MainLayout/RosterPanel/Margin/VBox/Grid/NapoleonBtn
@onready var cleopatra_btn: Button = $MainLayout/RosterPanel/Margin/VBox/Grid/CleopatraBtn
@onready var nobunaga_btn: Button = $MainLayout/RosterPanel/Margin/VBox/Grid/NobunagaBtn


func _ready() -> void:
	# Wire navigation
	deploy_button.pressed.connect(_on_deploy_pressed)
	back_button.pressed.connect(_on_back_pressed)

	# Wire character selectors
	caesar_btn.pressed.connect(func(): _select_starter_character(CAESAR_RES))
	joan_btn.pressed.connect(func(): _select_starter_character(JOAN_RES))
	harriet_btn.pressed.connect(func(): _select_starter_character(HARRIET_RES))

	# Wire locked rulers
	napoleon_btn.pressed.connect(func(): _select_locked_character("Napoleon"))
	cleopatra_btn.pressed.connect(func(): _select_locked_character("Cleopatra"))
	nobunaga_btn.pressed.connect(func(): _select_locked_character("Nobunaga"))

	# Wire relics
	asp_check.toggled.connect(func(active): _toggle_relic("cleopatra_asp", active))
	telescope_check.toggled.connect(func(active): _toggle_relic("napoleon_telescope", active))
	watch_check.toggled.connect(func(active): _toggle_relic("tesla_watch", active))

	_refresh_relic_checks()
	_refresh_locked_rulers()

	# Select current active ruler
	if CharacterManager and CharacterManager.active_character:
		_display_character_info(CharacterManager.active_character)
	else:
		_select_starter_character(CAESAR_RES)


func _select_starter_character(res: Resource) -> void:
	if CharacterManager:
		CharacterManager.select_character(res)
	_display_character_info(res)
	deploy_button.disabled = false
	deploy_button.text = "⚡ DEPLOY TO TIMELINE"


func _select_locked_character(ruler_id: String) -> void:
	if not SaveManager or not SaveManager.LOCKED_RULERS.has(ruler_id):
		return

	var info: Dictionary = SaveManager.LOCKED_RULERS[ruler_id]
	var is_unlocked: bool = SaveManager.is_character_unlocked(ruler_id)

	ruler_name_label.text = info["name"]
	era_label.text = info["era"]

	if is_unlocked:
		ability_label.text = "Active: Conscript Imperial Guard"
		passive_label.text = "Passive: Standard of Conquest"
		deploy_button.disabled = false
		deploy_button.text = "⚡ DEPLOY TO TIMELINE"
	else:
		ability_label.text = "🔒 LOCKED RULER"
		passive_label.text = "Milestone Requirement: %s" % info["requirement"]
		deploy_button.disabled = true
		deploy_button.text = "🔒 MILESTONE NOT MET"


func _display_character_info(res: Resource) -> void:
	if not res:
		return
	ruler_name_label.text = res.get("character_name")
	era_label.text = res.get("era_name")
	ability_label.text = "Active: %s (%s)" % [res.get("active_ability_name"), res.get("ability_description")]
	passive_label.text = "Passive: %s" % res.get("passive_description")


func _refresh_locked_rulers() -> void:
	if not SaveManager:
		return

	if SaveManager.is_character_unlocked("Napoleon"):
		napoleon_btn.text = "Napoleon Bonaparte\n(Unlocked)"
	else:
		napoleon_btn.text = "🔒 Napoleon\n(5 Caesar Gates)"

	if SaveManager.is_character_unlocked("Cleopatra"):
		cleopatra_btn.text = "Cleopatra VII\n(Unlocked)"
	else:
		cleopatra_btn.text = "🔒 Cleopatra\n(50 Favor Tokens)"

	if SaveManager.is_character_unlocked("Nobunaga"):
		nobunaga_btn.text = "Oda Nobunaga\n(Unlocked)"
	else:
		nobunaga_btn.text = "🔒 Nobunaga\n(1 Boss Defeated)"


func _refresh_relic_checks() -> void:
	if not SaveManager:
		return
	asp_check.set_pressed_no_signal(SaveManager.is_relic_equipped("cleopatra_asp"))
	telescope_check.set_pressed_no_signal(SaveManager.is_relic_equipped("napoleon_telescope"))
	watch_check.set_pressed_no_signal(SaveManager.is_relic_equipped("tesla_watch"))
	_update_relic_count_label()


func _toggle_relic(relic_id: String, active: bool) -> void:
	if not SaveManager:
		return

	if active:
		SaveManager.equip_relic(relic_id)
	else:
		SaveManager.unequip_relic(relic_id)

	_refresh_relic_checks()


func _update_relic_count_label() -> void:
	if SaveManager:
		var count: int = SaveManager.save_data.get("equipped_relics", []).size()
		relic_limit_label.text = "Equipped Relics: %d / 2" % count


func _on_deploy_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
