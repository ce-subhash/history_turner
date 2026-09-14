## TimelineCodexScreen.gd
## Displays the player's collection of unlocked alternate history cards,
## chronicling divergent timelines forged during runs.
extends Control

@onready var card_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/CardContainer
@onready var count_label: Label = $MarginContainer/VBoxContainer/Header/CountLabel
@onready var back_button: Button = $MarginContainer/VBoxContainer/Header/BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_populate_cards()


func _populate_cards() -> void:
	for child in card_container.get_children():
		child.queue_free()

	var cards: Array = []
	if SaveManager:
		cards = SaveManager.save_data.get("unlocked_timeline_cards", [])

	count_label.text = "Alternate Timelines Forged: %d" % cards.size()

	if cards.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No divergent timeline cards unlocked yet.\nPass Decision Gates or survive climax events to discover alternate histories!"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.modulate = Color(0.7, 0.7, 0.7)
		card_container.add_child(empty_label)
		return

	# Render each unlocked card
	for i in range(cards.size()):
		var card: Dictionary = cards[i]
		var card_panel: PanelContainer = _create_card_panel(i + 1, card)
		card_container.add_child(card_panel)


func _create_card_panel(index: int, card: Dictionary) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.18, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.9, 0.75, 0.25, 0.8)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	panel.add_theme_stylebox_override("panel", style)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Card Number & Title
	var title_label: Label = Label.new()
	title_label.text = "📜 Card #%02d - %s" % [index, card.get("title", "Alternate Timeline")]
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title_label.add_theme_font_size_override("font_size", 17)
	vbox.add_child(title_label)

	# Lore Blurb
	var blurb_label: Label = Label.new()
	blurb_label.text = '"%s"' % card.get("blurb", "")
	blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	blurb_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(blurb_label)

	# Timestamp
	var time_label: Label = Label.new()
	time_label.text = "Chronos Inscription: %s" % card.get("timestamp", "Unknown Epoch")
	time_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	time_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(time_label)

	return panel


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
