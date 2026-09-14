## PlayerController.gd
## Handles 3D character movement, 3-lane horizontal snapping with tweens,
## vertical jump & gravity, slide mechanics, Character Abilities, and Phase 4 Fever States.
extends CharacterBody3D

const CharacterDataScript = preload("res://scripts/resources/CharacterData.gd")
const CollectibleScript = preload("res://scripts/world/Collectible.gd")

const CAESAR_MODEL = preload("res://assets/characters/caesar.glb")
const JOAN_MODEL = preload("res://assets/characters/joan.glb")
const HARRIET_MODEL = preload("res://assets/characters/harriet.glb")

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

# Magnetism constants
const MAGNET_RADIUS: float = 14.0
const MAGNET_PULL_SPEED: float = 22.0
const FEVER_MAGNET_RADIUS: float = 20.0
const FEVER_MAGNET_SPEED: float = 32.0

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

# Phase 4 Fever State Tracking
var is_peasant_fever: bool = false
var is_divine_fever: bool = false
var artillery_timer: float = 0.0

# Phase 5 Relic State Tracking
var cleopatra_asp_used: bool = false
var tesla_magnet_timer: float = 0.0

# Passive: Zealot's Faith tracker
var zealot_emergency_triggered: bool = false
var emergency_shield_timer: float = 0.0

# Procedural 3D Character Model Rig & Animation
var current_model_root: Node3D = null
var left_arm_node: Node3D = null
var right_arm_node: Node3D = null
var left_leg_node: Node3D = null
var right_leg_node: Node3D = null
var torso_node: Node3D = null
var cape_node: Node3D = null
var lantern_light: OmniLight3D = null
var run_anim_time: float = 0.0

# --- Node References ---
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visual_model: Node3D = $VisualModel
@onready var camera: Camera3D = $Camera3D

var shield_mesh: MeshInstance3D
var original_shape_height: float = DEFAULT_HEIGHT
var original_shape_y: float = 0.9


func _ready() -> void:
	position.x = LANE_CENTER
	current_lane = 0
	_init_collision_cache()
	_setup_camera()
	_setup_ability_visuals()

	if GameManager:
		GameManager.game_over.connect(_on_game_over)
		GameManager.power_changed.connect(_on_power_changed)
		GameManager.fever_state_started.connect(_on_fever_started)
		GameManager.fever_state_ended.connect(_on_fever_ended)

	if CharacterManager:
		CharacterManager.ability_activated.connect(_on_ability_activated)
		CharacterManager.ability_deactivated.connect(_on_ability_deactivated)
		CharacterManager.character_selected.connect(_on_character_selected)
		if CharacterManager.active_character:
			_apply_character_visuals(CharacterManager.active_character)
		else:
			_apply_character_visuals(null)


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


func _setup_ability_visuals() -> void:
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
	if is_peasant_fever:
		return # Already floating
	if is_on_floor():
		if is_sliding:
			_end_slide()
		velocity.y = JUMP_VELOCITY


func slide() -> void:
	if is_peasant_fever:
		return # Hovering
	if not is_sliding:
		is_sliding = true
		slide_timer = SLIDE_DURATION
		_set_collision_height(original_shape_height * SLIDE_HEIGHT_RATIO)

		if visual_model:
			var visual_tween = create_tween()
			visual_tween.tween_property(visual_model, "position:y", 0.35, 0.1)
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
		visual_tween.tween_property(visual_model, "position:y", original_shape_y, 0.1)


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

	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0.0:
			_end_slide()

	if emergency_shield_timer > 0.0:
		emergency_shield_timer -= delta
		if emergency_shield_timer <= 0.0:
			is_invulnerable = false
			shield_mesh.visible = false

	# Forward Speed
	var speed_modifier: float = 1.0
	if CharacterManager and CharacterManager.active_character:
		speed_modifier = CharacterManager.active_character.base_speed_modifier

	velocity.z = -GameManager.current_speed * speed_modifier

	# Peasant Revolution Flight Mode: Glide smoothly at Y = 2.4m
	if is_peasant_fever:
		position.y = lerpf(position.y, 2.4, 8.0 * delta)
		velocity.y = 0.0
	else:
		if not is_on_floor():
			velocity.y -= GRAVITY_MULTIPLIER * delta
		elif velocity.y < 0:
			velocity.y = 0.0

	move_and_slide()
	_update_procedural_animations(delta)

	# Divine Right Artillery Barrage: Clears upcoming obstacles every 0.6s
	if is_divine_fever:
		artillery_timer -= delta
		if artillery_timer <= 0.0:
			artillery_timer = 0.6
			_execute_artillery_strike()

	# Process Active Magnetism (Harriet, Fever, or Tesla Watch)
	if has_magnet_active or is_peasant_fever or is_divine_fever or tesla_magnet_timer > 0.0:
		if tesla_magnet_timer > 0.0:
			tesla_magnet_timer -= delta
		_process_magnetism(delta)

	_check_collisions()


## Activates Tesla's Pocket Watch 3.0s magnetism burst.
func activate_tesla_magnet(duration: float = 3.0) -> void:
	tesla_magnet_timer = duration
	print("[Relic: Tesla's Pocket Watch] Activated %.1fs magnetism burst!" % duration)


## Pulls relevant collectibles toward player based on active state.
func _process_magnetism(delta: float) -> void:
	var radius: float = FEVER_MAGNET_RADIUS if (is_peasant_fever or is_divine_fever or tesla_magnet_timer > 0.0) else MAGNET_RADIUS
	var speed: float = FEVER_MAGNET_SPEED if (is_peasant_fever or is_divine_fever or tesla_magnet_timer > 0.0) else MAGNET_PULL_SPEED

	for node in get_tree().root.find_children("*", "Area3D", true, false):
		if node is CollectibleScript and not node.is_collected:
			# Filter in fever mode unless Tesla Watch is pulling everything
			if tesla_magnet_timer <= 0.0:
				if is_peasant_fever and node.get("type") != CollectibleScript.CollectibleType.PEOPLE_FIST:
					continue
				if is_divine_fever and node.get("type") != CollectibleScript.CollectibleType.GOVT_CROWN:
					continue

			var dist: float = global_position.distance_to(node.global_position)
			if dist <= radius:
				var pull_dir: Vector3 = (global_position + Vector3(0, 0.5, 0) - node.global_position).normalized()
				node.global_position += pull_dir * speed * delta


## Divine Right: Royal artillery clears hazards ahead of the player across all 3 lanes.
func _execute_artillery_strike() -> void:
	for node in get_tree().root.find_children("Obstacle_*", "StaticBody3D", true, false):
		var dz: float = node.global_position.z - global_position.z
		if dz < -5.0 and dz > -35.0:
			_transmute_obstacle(node as Node3D)


func _check_collisions() -> void:
	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision3D = get_slide_collision(i)
		var collider: Object = collision.get_collider()

		if collider and (collider.is_in_group("obstacles") or collider.name.begins_with("Obstacle")):
			if is_peasant_fever:
				_smash_obstacle(collider as Node3D)
				continue

			if is_invulnerable:
				_pulse_shield_impact()
				continue

			if is_ghost_mode:
				continue

			if has_divine_aura:
				_transmute_obstacle(collider as Node3D)
				continue

			# Relic Perk: Cleopatra's Asp (Prevents fatal damage once per run, resets meters to 50%)
			if has_node("/root/SaveManager"):
				var sm = get_node("/root/SaveManager")
				if sm.is_relic_equipped("cleopatra_asp") and not cleopatra_asp_used:
					cleopatra_asp_used = true
					_trigger_cleopatra_asp()
					continue

			var reason: String = "Crashed into %s" % collider.name
			GameManager.trigger_game_over(reason)
			break


## Cleopatra's Asp: Emergency revival resetting meters to 50/50 with 3.5s invulnerability.
func _trigger_cleopatra_asp() -> void:
	GameManager.people_power = 50.0
	GameManager.govt_power = 50.0
	GameManager.power_changed.emit(50.0, 50.0)
	emergency_shield_timer = 3.5
	is_invulnerable = true
	shield_mesh.visible = true
	shield_mesh.material_override.albedo_color = Color(0.2, 0.95, 0.45, 0.6)
	shield_mesh.material_override.emission = Color(0.2, 0.9, 0.4)
	if GameManager:
		GameManager.decision_notification.emit("🐍 CLEOPATRA'S ASP: Fatal collapse averted! Meters stabilized at 50%!")



func _smash_obstacle(obstacle: Node3D) -> void:
	if not obstacle:
		return
	GameManager.add_people_power(3.0)
	var tween: Tween = create_tween()
	tween.tween_property(obstacle, "scale", Vector3(1.3, 0.2, 1.3), 0.1)
	tween.tween_callback(obstacle.queue_free)


func _transmute_obstacle(obstacle: Node3D) -> void:
	if not obstacle:
		return
	GameManager.add_people_power(4.0)
	GameManager.add_govt_power(4.0)
	var tween: Tween = create_tween()
	tween.tween_property(obstacle, "scale", Vector3.ZERO, 0.2)
	tween.tween_callback(obstacle.queue_free)


func _pulse_shield_impact() -> void:
	if not shield_mesh:
		return
	var tween: Tween = create_tween()
	tween.tween_property(shield_mesh, "scale", Vector3(1.2, 1.2, 1.2), 0.08)
	tween.tween_property(shield_mesh, "scale", Vector3.ONE, 0.08)


# --- Phase 4 Fever State Callbacks ---

func _on_fever_started(fever_type: String, _duration: float) -> void:
	shield_mesh.visible = true
	if fever_type == "peasant_revolution":
		is_peasant_fever = true
		shield_mesh.material_override.albedo_color = Color(1.0, 0.2, 0.2, 0.6)
		shield_mesh.material_override.emission = Color(1.0, 0.15, 0.2)
	else:
		is_divine_fever = true
		shield_mesh.material_override.albedo_color = Color(0.2, 0.6, 1.0, 0.6)
		shield_mesh.material_override.emission = Color(0.2, 0.5, 1.0)


func _on_fever_ended(_fever_type: String) -> void:
	is_peasant_fever = false
	is_divine_fever = false
	if not is_invulnerable and not is_ghost_mode:
		shield_mesh.visible = false


# --- Ability & Perk Event Handlers ---

func _on_ability_activated(character: Resource, _duration: float) -> void:
	match character.get("character_name"):
		"Julius Caesar":
			is_invulnerable = true
			shield_mesh.visible = true
			shield_mesh.material_override.albedo_color = Color(1.0, 0.8, 0.2, 0.45)
			shield_mesh.material_override.emission = Color(1.0, 0.75, 0.2)

		"Joan of Arc":
			has_divine_aura = true
			shield_mesh.visible = true
			shield_mesh.material_override.albedo_color = Color(0.9, 0.95, 1.0, 0.5)
			shield_mesh.material_override.emission = Color(0.95, 0.9, 0.4)

		"Harriet Tubman":
			is_ghost_mode = true
			has_magnet_active = true
			shield_mesh.visible = true
			shield_mesh.material_override.albedo_color = Color(0.2, 0.9, 0.6, 0.35)
			shield_mesh.material_override.emission = Color(0.2, 0.85, 0.5)

			if visual_model:
				visual_model.modulate = Color(1, 1, 1, 0.4)


func _on_ability_deactivated(_character: Resource) -> void:
	is_invulnerable = false
	has_divine_aura = false
	is_ghost_mode = false
	has_magnet_active = false
	if not is_peasant_fever and not is_divine_fever:
		shield_mesh.visible = false

	if visual_model:
		visual_model.modulate = Color(1, 1, 1, 1)


func _on_power_changed(people: float, govt: float) -> void:
	if not CharacterManager or not CharacterManager.active_character:
		return

	if CharacterManager.active_character.get("passive_perk_type") == "zealots_faith":
		if (people < 15.0 or govt < 15.0) and not zealot_emergency_triggered:
			zealot_emergency_triggered = true
			emergency_shield_timer = 4.0
			is_invulnerable = true
			shield_mesh.visible = true
			shield_mesh.material_override.albedo_color = Color(1.0, 0.3, 0.3, 0.5)
			shield_mesh.material_override.emission = Color(1.0, 0.2, 0.2)
			print("[Perk: Zealot's Faith] Emergency 4s Invincibility Shield activated!")
		elif people >= 25.0 and govt >= 25.0:
			zealot_emergency_triggered = false


func _on_character_selected(character: Resource) -> void:
	_apply_character_visuals(character)


func _apply_character_visuals(character: Resource) -> void:
	if not visual_model:
		return

	# Hide prototype primitive meshes if present
	var body_mesh_inst: Node = visual_model.get_node_or_null("BodyMesh")
	if body_mesh_inst:
		body_mesh_inst.visible = false
	var visor_mesh_inst: Node = visual_model.get_node_or_null("VisorMesh")
	if visor_mesh_inst:
		visor_mesh_inst.visible = false

	# Remove previous character model
	if current_model_root and is_instance_valid(current_model_root):
		current_model_root.queue_free()
		current_model_root = null

	var char_name: String = character.get("character_name") if character else "Julius Caesar"
	var model_scene: PackedScene = CAESAR_MODEL
	match char_name:
		"Julius Caesar":
			model_scene = CAESAR_MODEL
		"Joan of Arc":
			model_scene = JOAN_MODEL
		"Harriet Tubman":
			model_scene = HARRIET_MODEL
		_:
			model_scene = CAESAR_MODEL

	if model_scene:
		current_model_root = model_scene.instantiate()
		current_model_root.name = "Character3DModel"
		visual_model.add_child(current_model_root)

		# Cache limb references for procedural runner animation
		left_arm_node = current_model_root.find_child("LeftArm", true, false)
		right_arm_node = current_model_root.find_child("RightArm", true, false)
		left_leg_node = current_model_root.find_child("LeftLeg", true, false)
		right_leg_node = current_model_root.find_child("RightLeg", true, false)
		torso_node = current_model_root.find_child("Torso", true, false)
		cape_node = current_model_root.find_child("Cape", true, false)

		# Attach Freedom Lantern dynamic illumination for Harriet Tubman
		if char_name == "Harriet Tubman" and right_arm_node:
			lantern_light = OmniLight3D.new()
			lantern_light.name = "FreedomLanternLight"
			lantern_light.light_color = Color(1.0, 0.78, 0.35)
			lantern_light.light_energy = 3.5
			lantern_light.omni_range = 14.0
			lantern_light.omni_attenuation = 1.2
			lantern_light.position = Vector3(0.0, -0.65, 0.12)
			right_arm_node.add_child(lantern_light)


## Procedurally animates limbs, torso, cape flutter, and lantern sway based on movement state.
func _update_procedural_animations(delta: float) -> void:
	if not left_leg_node or not right_leg_node or not left_arm_node or not right_arm_node or not torso_node:
		return

	if GameManager.is_game_over:
		torso_node.rotation.x = lerp_angle(torso_node.rotation.x, deg_to_rad(20.0), 5.0 * delta)
		left_arm_node.rotation.x = lerp_angle(left_arm_node.rotation.x, 0.0, 5.0 * delta)
		right_arm_node.rotation.x = lerp_angle(right_arm_node.rotation.x, 0.0, 5.0 * delta)
		left_leg_node.rotation.x = lerp_angle(left_leg_node.rotation.x, 0.0, 5.0 * delta)
		right_leg_node.rotation.x = lerp_angle(right_leg_node.rotation.x, 0.0, 5.0 * delta)
		return

	if is_peasant_fever:
		# Floating superhero flying pose
		torso_node.rotation.x = lerp_angle(torso_node.rotation.x, deg_to_rad(-35.0), 8.0 * delta)
		left_leg_node.rotation.x = lerp_angle(left_leg_node.rotation.x, deg_to_rad(-15.0), 8.0 * delta)
		right_leg_node.rotation.x = lerp_angle(right_leg_node.rotation.x, deg_to_rad(-15.0), 8.0 * delta)
		left_arm_node.rotation.x = lerp_angle(left_arm_node.rotation.x, deg_to_rad(45.0), 8.0 * delta)
		right_arm_node.rotation.x = lerp_angle(right_arm_node.rotation.x, deg_to_rad(45.0), 8.0 * delta)
		if cape_node:
			cape_node.rotation.x = deg_to_rad(45.0 + sin(run_anim_time * 3.0) * 8.0)
		return

	if is_sliding:
		# Low crouch slide pose
		torso_node.rotation.x = lerp_angle(torso_node.rotation.x, deg_to_rad(25.0), 12.0 * delta)
		left_leg_node.rotation.x = lerp_angle(left_leg_node.rotation.x, deg_to_rad(65.0), 12.0 * delta)
		right_leg_node.rotation.x = lerp_angle(right_leg_node.rotation.x, deg_to_rad(60.0), 12.0 * delta)
		left_arm_node.rotation.x = lerp_angle(left_arm_node.rotation.x, deg_to_rad(-35.0), 12.0 * delta)
		right_arm_node.rotation.x = lerp_angle(right_arm_node.rotation.x, deg_to_rad(-35.0), 12.0 * delta)
		if cape_node:
			cape_node.rotation.x = lerp_angle(cape_node.rotation.x, deg_to_rad(-15.0), 12.0 * delta)
		return

	if not is_on_floor():
		# Airborne jump tuck pose
		torso_node.rotation.x = lerp_angle(torso_node.rotation.x, deg_to_rad(-5.0), 10.0 * delta)
		left_leg_node.rotation.x = lerp_angle(left_leg_node.rotation.x, deg_to_rad(-35.0), 10.0 * delta)
		right_leg_node.rotation.x = lerp_angle(right_leg_node.rotation.x, deg_to_rad(-45.0), 10.0 * delta)
		left_arm_node.rotation.x = lerp_angle(left_arm_node.rotation.x, deg_to_rad(35.0), 10.0 * delta)
		right_arm_node.rotation.x = lerp_angle(right_arm_node.rotation.x, deg_to_rad(35.0), 10.0 * delta)
		if cape_node:
			cape_node.rotation.x = lerp_angle(cape_node.rotation.x, deg_to_rad(30.0), 10.0 * delta)
		return

	# Ground Running stride cycle
	var run_freq: float = 12.0 * (GameManager.current_speed / 12.0)
	run_anim_time += delta * run_freq
	var stride: float = sin(run_anim_time) * 0.65
	left_leg_node.rotation.x = stride
	right_leg_node.rotation.x = -stride
	var arm_stride: float = -sin(run_anim_time) * 0.55
	left_arm_node.rotation.x = arm_stride
	right_arm_node.rotation.x = -arm_stride

	# Forward tilt and running bounce
	torso_node.rotation.x = deg_to_rad(-7.0)
	torso_node.position.y = 0.86 + abs(sin(run_anim_time * 2.0)) * 0.04

	# Dynamic cape fluttering
	if cape_node:
		var cape_flutter: float = deg_to_rad(18.0 + sin(run_anim_time * 2.2) * 8.0 + (GameManager.current_speed - 12.0) * 1.2)
		cape_node.rotation.x = cape_flutter


func _on_game_over(_reason: String) -> void:
	if lane_tween and lane_tween.is_running():
		lane_tween.kill()
	is_invulnerable = false
	is_ghost_mode = false
	has_divine_aura = false
	has_magnet_active = false
	is_peasant_fever = false
	is_divine_fever = false
	if shield_mesh:
		shield_mesh.visible = false
