## PlayerController.gd
## Handles 3D character movement, 3-lane horizontal snapping with tweens,
## vertical jump & gravity, slide mechanics, and Character Roster ability/passive integration.
extends CharacterBody3D
const CharacterDataScript = preload("res://scripts/resources/CharacterData.gd")
const CollectibleScript = preload("res://scripts/world/Collectible.gd")

# --- Constants & Configuration ---
const LANE_LEFT: float = -2.5
const LANE_CENTER: float = 0.0
const LANE_RIGHT: float = 2.5
const LANE_WIDTH: float = 2.5
const LANE_SWITCH_DURATION: float = 0.15

const JUMP_VELOCITY: float = 9.0
const GRAVITY_MULTIPLIER: float = 26.0

const SLIDE_DURATION: float = 0.8
const DEFAULT_HEIGHT: float = 1.8
const SLIDE_HEIGHT_RATIO: float = 0.5
const SWIPE_THRESHOLD: float = 40.0

# Magnetism radius for Harriet's Freedom Lantern
const MAGNET_RADIUS: float = 14.0
const MAGNET_PULL_SPEED: float = 22.0

# --- State Variables ---
var current_lane: int = 0
var is_sliding: bool = false
var slide_timer: float = 0.0

var touch_start_pos: Vector2 = Vector2.ZERO
var is_touch_active: bool = false
var lane_tween: Tween = null

# Active Ability & Passive State
var is_invulnerable: bool = false
var is_ghost_mode: bool = false
var has_divine_aura: bool = false
var has_magnet_active: bool = false

# Passive: Zealot's Faith cooldown tracker (prevents infinite re-triggering)
var zealot_emergency_triggered: bool = false
var emergency_shield_timer: float = 0.0

# --- Node References ---
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visual_model: Node3D = $VisualModel
@onready var camera: Camera3D = $Camera3D

# Dynamic Visual Effects Nodes
var shield_mesh: MeshInstance3D
var aura_particles: Node3D

var original_shape_height: float = DEFAULT_HEIGHT
var original_shape_y: float = 0.9


func _ready() -> void:
	position.x = LANE_CENTER
	current_lane = 0
	_init_collision_cache()
	_setup_camera()
	_setup_ability_visuals()

	# Connect signals
	if GameManager:
		GameManager.game_over.connect(_on_game_over)
		GameManager.power_changed.connect(_on_power_changed)

	if CharacterManager:
		CharacterManager.ability_activated.connect(_on_ability_activated)
		CharacterManager.ability_deactivated.connect(_on_ability_deactivated)
		CharacterManager.character_selected.connect(_on_character_selected)
		# Initialize appearance / settings for current active character
		if CharacterManager.active_character:
			_apply_character_visuals(CharacterManager.active_character)


func _init_collision_cache() -> void:
	if collision_shape and collision_shape.shape:
		if collision_shape.shape is CapsuleShape3D:
			original_shape_height = (collision_shape.shape as CapsuleShape3D).height
		elif collision_shape.shape is BoxShape3D:
			original_shape_height = (collision_shape.shape as BoxShape3D).size.y
		original_shape_y = collision_shape.position.y
	else:
		original_shape_height = DEFAULT_HEIGHT
		original_shape_y = DEFAULT_HEIGHT * 0.5


func _setup_camera() -> void:
	if not camera:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)

	camera.position = Vector3(0.0, 3.0, 5.0)
	camera.rotation_degrees = Vector3(-16.0, 0.0, 0.0)
	camera.current = true


## Builds the 3D visual shield / aura node used for active abilities.
func _setup_ability_visuals() -> void:
	# Golden / Translucent Shield Dome
	shield_mesh = MeshInstance3D.new()
	shield_mesh.name = "AbilityShield"
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 1.1
	sphere.height = 2.2
	shield_mesh.mesh = sphere

	var shield_mat: StandardMaterial3D = StandardMaterial3D.new()
	shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_mat.albedo_color = Color(1.0, 0.85, 0.2, 0.35)
	shield_mat.emission_enabled = true
	shield_mat.emission = Color(1.0, 0.8, 0.2)
	shield_mat.emission_energy_multiplier = 1.2
	shield_mesh.material_override = shield_mat
	shield_mesh.position = Vector3(0.0, 1.0, 0.0)
	shield_mesh.visible = false
	add_child(shield_mesh)


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_game_over:
		return

	# 1. Keyboard Input System: A/D/Arrows for lanes, Space/Up/W jump, S/Down slide, E/F for ability
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match event.keycode:
			KEY_A, KEY_LEFT:
				switch_lane(-1)
			KEY_D, KEY_RIGHT:
				switch_lane(1)
			KEY_SPACE, KEY_UP, KEY_W:
				jump()
			KEY_S, KEY_DOWN:
				slide()
			KEY_E, KEY_F:
				if CharacterManager:
					CharacterManager.trigger_active_ability()

	# 2. Mobile Touch Input System (Swipes)
	if event is InputEventScreenTouch:
		if event.is_pressed():
			touch_start_pos = event.position
			is_touch_active = true
		else:
			is_touch_active = false

	elif event is InputEventScreenDrag and is_touch_active:
		var swipe_vec: Vector2 = event.position - touch_start_pos
		if swipe_vec.length() >= SWIPE_THRESHOLD:
			_process_swipe(swipe_vec)
			is_touch_active = false

	# Mouse fallback for desktop testing
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				touch_start_pos = event.position
				is_touch_active = true
			else:
				is_touch_active = false
	elif event is InputEventMouseMotion and is_touch_active:
		var swipe_vec: Vector2 = event.position - touch_start_pos
		if swipe_vec.length() >= SWIPE_THRESHOLD:
			_process_swipe(swipe_vec)
			is_touch_active = false


func _process_swipe(swipe_vec: Vector2) -> void:
	if abs(swipe_vec.x) > abs(swipe_vec.y):
		if swipe_vec.x < 0.0:
			switch_lane(-1)
		else:
			switch_lane(1)
	else:
		if swipe_vec.y < 0.0:
			jump()
		else:
			slide()


func switch_lane(direction: int) -> void:
	var target_lane: int = clampi(current_lane + direction, -1, 1)
	if target_lane == current_lane:
		return

	current_lane = target_lane
	var target_x: float = current_lane * LANE_WIDTH

	if lane_tween and lane_tween.is_running():
		lane_tween.kill()

	lane_tween = create_tween()
	lane_tween.set_trans(Tween.TRANS_QUAD)
	lane_tween.set_ease(Tween.EASE_OUT)
	lane_tween.tween_property(self, "position:x", target_x, LANE_SWITCH_DURATION)


func jump() -> void:
	if is_on_floor():
		if is_sliding:
			_end_slide()
		velocity.y = JUMP_VELOCITY


func slide() -> void:
	if not is_sliding:
		is_sliding = true
		slide_timer = SLIDE_DURATION
		_set_collision_height(original_shape_height * SLIDE_HEIGHT_RATIO)

		if visual_model:
			var visual_tween = create_tween()
			visual_tween.tween_property(visual_model, "scale", Vector3(1.1, SLIDE_HEIGHT_RATIO, 1.1), 0.1)
			visual_tween.parallel().tween_property(visual_model, "position:y", 0.45, 0.1)
	else:
		slide_timer = SLIDE_DURATION


func _end_slide() -> void:
	if not is_sliding:
		return

	is_sliding = false
	slide_timer = 0.0
	_set_collision_height(original_shape_height)

	if visual_model:
		var visual_tween = create_tween()
		visual_tween.tween_property(visual_model, "scale", Vector3.ONE, 0.1)
		visual_tween.parallel().tween_property(visual_model, "position:y", original_shape_y, 0.1)


func _set_collision_height(new_height: float) -> void:
	if not collision_shape or not collision_shape.shape:
		return

	if collision_shape.shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = collision_shape.shape
		capsule.height = new_height
	elif collision_shape.shape is BoxShape3D:
		var box: BoxShape3D = collision_shape.shape
		box.size.y = new_height

	collision_shape.position.y = new_height * 0.5


func _physics_process(delta: float) -> void:
	if GameManager.is_game_over:
		velocity = Vector3.ZERO
		return

	# Handle slide timer
	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0.0:
			_end_slide()

	# Handle emergency shield from Zealot's Faith
	if emergency_shield_timer > 0.0:
		emergency_shield_timer -= delta
		if emergency_shield_timer <= 0.0:
			is_invulnerable = false
			shield_mesh.visible = false

	# Calculate speed with character base_speed_modifier
	var speed_modifier: float = 1.0
	if CharacterManager and CharacterManager.active_character:
		speed_modifier = CharacterManager.active_character.base_speed_modifier

	velocity.z = -GameManager.current_speed * speed_modifier

	# Apply gravity
	if not is_on_floor():
		velocity.y -= GRAVITY_MULTIPLIER * delta
	elif velocity.y < 0:
		velocity.y = 0.0

	move_and_slide()

	# Process active magnetism (Harriet's Freedom Lantern)
	if has_magnet_active:
		_process_magnetism(delta)

	# Check for obstacle collisions
	_check_collisions()


## Magnetizes nearby Collectibles, drawing them directly to the runner.
func _process_magnetism(delta: float) -> void:
	var collectibles = get_tree().get_nodes_in_group("collectibles")
	# Also find any Collectible nodes in scene tree
	for node in get_tree().root.find_children("*", "Area3D", true, false):
		if node is CollectibleScript and not node.is_collected:
			var dist: float = global_position.distance_to(node.global_position)
			if dist <= MAGNET_RADIUS:
				var pull_dir: Vector3 = (global_position + Vector3(0, 0.5, 0) - node.global_position).normalized()
				node.global_position += pull_dir * MAGNET_PULL_SPEED * delta


## Detects obstacle collisions, handling Invulnerability, Divine Aura, and Ghost Phase.
func _check_collisions() -> void:
	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision3D = get_slide_collision(i)
		var collider: Object = collision.get_collider()

		if collider and (collider.is_in_group("obstacles") or collider.name.begins_with("Obstacle")):
			# 1. Caesar: Testudo Shield Wall (Full invulnerability) or Emergency Shield
			if is_invulnerable:
				_pulse_shield_impact()
				continue

			# 2. Harriet: Freedom Lantern (Ghost Mode phase-through)
			if is_ghost_mode:
				continue

			# 3. Joan of Arc: Divine Aura (Transmutes obstacle to gold reward)
			if has_divine_aura:
				_transmute_obstacle(collider as Node3D)
				continue

			# Standard collision: triggers game over
			var reason: String = "Crashed into %s" % collider.name
			GameManager.trigger_game_over(reason)
			break


## Joan of Arc Divine Aura: Converts obstacle into holy relic / gold bonus.
func _transmute_obstacle(obstacle: Node3D) -> void:
	if not obstacle:
		return

	# Add bonus favor to both meters
	GameManager.add_people_power(4.0)
	GameManager.add_govt_power(4.0)

	# Visual transmutation effect
	var tween: Tween = create_tween()
	tween.tween_property(obstacle, "scale", Vector3.ZERO, 0.2)
	tween.tween_callback(obstacle.queue_free)


## Pulses the shield dome upon absorbing an obstacle impact.
func _pulse_shield_impact() -> void:
	if not shield_mesh:
		return
	var tween: Tween = create_tween()
	tween.tween_property(shield_mesh, "scale", Vector3(1.2, 1.2, 1.2), 0.08)
	tween.tween_property(shield_mesh, "scale", Vector3.ONE, 0.08)


# --- Ability & Perk Event Handlers ---

func _on_ability_activated(character: Resource, _duration: float) -> void:
	match character.get("character_name"):
		"Julius Caesar":
			# Testudo Shield Wall: 6s Invulnerability
			is_invulnerable = true
			shield_mesh.visible = true
			shield_mesh.material_override.albedo_color = Color(1.0, 0.8, 0.2, 0.45)
			shield_mesh.material_override.emission = Color(1.0, 0.75, 0.2)

		"Joan of Arc":
			# Divine Aura: 6s Hazard Transmutation
			has_divine_aura = true
			shield_mesh.visible = true
			shield_mesh.material_override.albedo_color = Color(0.9, 0.95, 1.0, 0.5)
			shield_mesh.material_override.emission = Color(0.95, 0.9, 0.4)

		"Harriet Tubman":
			# Freedom Lantern: 8s Ghost Mode + Magnet
			is_ghost_mode = true
			has_magnet_active = true
			shield_mesh.visible = true
			shield_mesh.material_override.albedo_color = Color(0.2, 0.9, 0.6, 0.35)
			shield_mesh.material_override.emission = Color(0.2, 0.85, 0.5)

			# Ghost visual effect on body
			if visual_model:
				visual_model.modulate = Color(1, 1, 1, 0.4)


func _on_ability_deactivated(_character: Resource) -> void:
	is_invulnerable = false
	has_divine_aura = false
	is_ghost_mode = false
	has_magnet_active = false
	shield_mesh.visible = false

	if visual_model:
		visual_model.modulate = Color(1, 1, 1, 1)


## Monitors political meters for Joan of Arc's Zealot's Faith passive.
func _on_power_changed(people: float, govt: float) -> void:
	if not CharacterManager or not CharacterManager.active_character:
		return

	if CharacterManager.active_character.get("passive_perk_type") == "zealots_faith":
		# If either meter drops below 15% and not already triggered this danger threshold
		if (people < 15.0 or govt < 15.0) and not zealot_emergency_triggered:
			zealot_emergency_triggered = true
			emergency_shield_timer = 4.0
			is_invulnerable = true
			shield_mesh.visible = true
			shield_mesh.material_override.albedo_color = Color(1.0, 0.3, 0.3, 0.5)
			shield_mesh.material_override.emission = Color(1.0, 0.2, 0.2)
			print("[Perk: Zealot's Faith] Emergency 4s Invincibility Shield activated!")
		elif people >= 25.0 and govt >= 25.0:
			# Reset trigger once player recovers into safe zone
			zealot_emergency_triggered = false


func _on_character_selected(character: Resource) -> void:
	_apply_character_visuals(character)


## Updates visual theme accents based on active ruler.
func _apply_character_visuals(character: Resource) -> void:
	if visual_model:
		var body_mesh_inst: MeshInstance3D = visual_model.get_node_or_null("BodyMesh")
		if body_mesh_inst and character:
			var theme_col: Color = character.get("theme_color") if character.get("theme_color") else Color.WHITE
			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.albedo_color = theme_col
			mat.roughness = 0.3
			mat.emission_enabled = true
			mat.emission = theme_col * 0.4
			body_mesh_inst.material_override = mat


func _on_game_over(_reason: String) -> void:
	if lane_tween and lane_tween.is_running():
		lane_tween.kill()
	is_invulnerable = false
	is_ghost_mode = false
	has_divine_aura = false
	has_magnet_active = false
	if shield_mesh:
		shield_mesh.visible = false
