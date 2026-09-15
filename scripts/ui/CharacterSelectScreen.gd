## CharacterSelectScreen.gd
## Manages character roster selection, milestone unlocks,
## and 2-slot Equippable Relic loadouts.
extends Control

# Starter Characters
const CAESAR_RES = preload("res://resources/characters/caesar.tres")
const JOAN_RES = preload("res://resources/characters/joan.tres")
const HARRIET_RES = preload("res://resources/characters/harriet.tres")

# Pure Rear-View 2.5D Character Sprites
const CAESAR_SPRITE = preload("res://assets/sprites/characters/caesar_rear_run1.png")
const JOAN_SPRITE = preload("res://assets/sprites/characters/joan_rear_run1.png")
const HARRIET_SPRITE = preload("res://assets/sprites/characters/harriet_rear_run1.png")

# 3D Preview Nodes
var preview_viewport_container: SubViewportContainer
var preview_viewport: SubViewport
var preview_model_pivot: Node3D
var preview_sprite: Sprite3D
var preview_time: float = 0.0

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
	_setup_3d_preview()

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


func _process(delta: float) -> void:
	preview_time += delta
	if preview_model_pivot:
		# Gentle idle float and subtle sway
		preview_model_pivot.rotation.y = sin(preview_time * 1.4) * 0.12
		if preview_sprite:
			preview_sprite.position.y = 0.9 + sin(preview_time * 2.2) * 0.03


func _setup_3d_preview() -> void:
	var vbox = $MainLayout/DetailsPanel/Margin/VBox
	preview_viewport_container = SubViewportContainer.new()
	preview_viewport_container.name = "PreviewContainer"
	preview_viewport_container.custom_minimum_size = Vector2(0, 180)
	preview_viewport_container.stretch = true
	preview_viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(preview_viewport_container)
	vbox.move_child(preview_viewport_container, 0)

	preview_viewport = SubViewport.new()
	preview_viewport.name = "PreviewSubViewport"
	preview_viewport.transparent_bg = true
	preview_viewport.handle_input_locally = false
	preview_viewport.size = Vector2i(260, 180)
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_viewport_container.add_child(preview_viewport)

	# Camera looking slightly down at character
	var cam = Camera3D.new()
	cam.position = Vector3(0.0, 1.05, 2.5)
	cam.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
	cam.fov = 38.0
	preview_viewport.add_child(cam)

	# Key Light
	var dir_light = DirectionalLight3D.new()
	dir_light.rotation_degrees = Vector3(-25.0, 35.0, 0.0)
	dir_light.light_color = Color(1.0, 0.95, 0.9)
	dir_light.light_energy = 1.4
	preview_viewport.add_child(dir_light)

	# Fill Light
	var fill_light = OmniLight3D.new()
	fill_light.position = Vector3(0.0, 1.8, 1.2)
	fill_light.light_color = Color(0.7, 0.85, 1.0)
	fill_light.light_energy = 1.0
	fill_light.omni_range = 6.0
	preview_viewport.add_child(fill_light)

	# Rotating Model Pivot
	preview_model_pivot = Node3D.new()
	preview_model_pivot.name = "ModelPivot"
	preview_model_pivot.rotation_degrees.y = 0.0
	preview_viewport.add_child(preview_model_pivot)

	# Pedestal
	var pedestal = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.60
	cyl.height = 0.08
	pedestal.mesh = cyl
	pedestal.position = Vector3(0.0, -0.04, 0.0)
	var ped_mat = StandardMaterial3D.new()
	ped_mat.albedo_color = Color(0.12, 0.14, 0.2)
	ped_mat.metallic = 0.8
	ped_mat.roughness = 0.3
	pedestal.material_override = ped_mat
	preview_model_pivot.add_child(pedestal)


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
		_update_3d_preview(info["name"])
	else:
		ability_label.text = "🔒 LOCKED RULER"
		passive_label.text = "Milestone Requirement: %s" % info["requirement"]
		deploy_button.disabled = true
		deploy_button.text = "🔒 MILESTONE NOT MET"
		_update_3d_preview_locked()


func _display_character_info(res: Resource) -> void:
	if not res:
		return
	var char_name: String = res.get("character_name")
	ruler_name_label.text = char_name
	era_label.text = res.get("era_name")
	ability_label.text = "Active: %s (%s)" % [res.get("active_ability_name"), res.get("ability_description")]
	passive_label.text = "Passive: %s" % res.get("passive_description")
	_update_3d_preview(char_name)


func _update_3d_preview(char_name: String) -> void:
	if not preview_model_pivot:
		return

	# Remove any previous model children except the pedestal
	for child in preview_model_pivot.get_children():
		if child is MeshInstance3D and child.name == "Pedestal":
			continue
		preview_model_pivot.remove_child(child)
		child.queue_free()
	preview_sprite = null

	var sprite_tex: Texture2D = CAESAR_SPRITE
	var light_col: Color = Color(1.0, 0.85, 0.4)
	var light_energy: float = 2.4

	match char_name:
		"Julius Caesar":
			sprite_tex = CAESAR_SPRITE
			light_col = Color(1.0, 0.85, 0.4)
			light_energy = 2.4
		"Joan of Arc":
			sprite_tex = JOAN_SPRITE
			light_col = Color(0.75, 0.9, 1.0)
			light_energy = 2.8
		"Harriet Tubman":
			sprite_tex = HARRIET_SPRITE
			light_col = Color(1.0, 0.78, 0.35)
			light_energy = 3.6
		_:
			sprite_tex = CAESAR_SPRITE

	if sprite_tex:
		preview_sprite = Sprite3D.new()
		preview_sprite.name = "PreviewSprite3D"
		preview_sprite.texture = sprite_tex
		preview_sprite.centered = true
		preview_sprite.alpha_cut = Sprite3D.ALPHA_CUT_DISCARD
		preview_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		preview_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		preview_sprite.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
		preview_sprite.pixel_size = 1.8 / float(sprite_tex.get_height())
		preview_sprite.position = Vector3(0.0, 0.9, 0.0)
		preview_model_pivot.add_child(preview_sprite)

		var dynamic_light = OmniLight3D.new()
		dynamic_light.name = "PreviewDynamicLight"
		dynamic_light.light_color = light_col
		dynamic_light.light_energy = light_energy
		dynamic_light.omni_range = 8.0
		dynamic_light.position = Vector3(0.0, 1.0, 0.2)
		preview_sprite.add_child(dynamic_light)


func _update_3d_preview_locked() -> void:
	if not preview_model_pivot:
		return

	for child in preview_model_pivot.get_children():
		if child is MeshInstance3D and child.name == "Pedestal":
			continue
		preview_model_pivot.remove_child(child)
		child.queue_free()
	preview_sprite = null

	preview_sprite = Sprite3D.new()
	preview_sprite.name = "PreviewSprite3D"
	preview_sprite.texture = CAESAR_SPRITE
	preview_sprite.centered = true
	preview_sprite.alpha_cut = Sprite3D.ALPHA_CUT_DISCARD
	preview_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	preview_sprite.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
	preview_sprite.pixel_size = 1.8 / float(CAESAR_SPRITE.get_height())
	preview_sprite.position = Vector3(0.0, 0.9, 0.0)
	preview_sprite.modulate = Color(0.12, 0.12, 0.18, 0.85)
	preview_model_pivot.add_child(preview_sprite)


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
